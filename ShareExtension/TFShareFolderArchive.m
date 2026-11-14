#import "TFShareFolderArchive.h"
#import "../Vendor/libarchive-headers/archive.h"
#import "../Vendor/libarchive-headers/archive_entry.h"
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <dirent.h>
#import <errno.h>
#import <string.h>

static BOOL Fail(NSError **error, NSString *message) {
    if(error)*error=[NSError errorWithDomain:@"Dylix.ShareFolder" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}
static BOOL SafeName(NSString *s) {
    return s.length && ![s isEqual:@"."] && ![s isEqual:@".."] &&
        ![s containsString:@"/"] && ![s containsString:@"\\"] &&
        [s rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;
}
typedef struct { uint64_t bytes; NSUInteger entries; CFAbsoluteTime started; } Budget;
static BOOL Add(struct archive *a,int fd,NSString *path,struct stat st,Budget *budget,NSError **error) {
    if(path.pathComponents.count>128 || strlen(path.UTF8String)>4096)
        return Fail(error,@"文件夹层级或名称过长，请缩短后重试。");
    if(++budget->entries>10000 || budget->bytes>512ULL*1024*1024 || CFAbsoluteTimeGetCurrent()-budget->started>90)
        return Fail(error,@"文件夹超过 10000 项 / 512 MiB，或处理时间过长。请分批分享。");
    if(!S_ISDIR(st.st_mode)&&!S_ISREG(st.st_mode))return Fail(error,@"文件夹含符号链接或特殊文件，请移除后重试。不会跟随链接读取其他目录。");
    if(S_ISREG(st.st_mode)) {
        if(st.st_size<0 || (uint64_t)st.st_size>512ULL*1024*1024-budget->bytes)
            return Fail(error,@"文件夹内容超过 512 MiB，请分批分享。");
        budget->bytes+=(uint64_t)st.st_size;
    }
    struct archive_entry *en=archive_entry_new();
    archive_entry_set_pathname(en,path.UTF8String);
    archive_entry_set_filetype(en,S_ISDIR(st.st_mode)?AE_IFDIR:AE_IFREG);
    archive_entry_set_perm(en,S_ISDIR(st.st_mode)?0700:0600);
    archive_entry_set_mtime(en,st.st_mtime,0);
    archive_entry_set_size(en,S_ISDIR(st.st_mode)?0:st.st_size);
    BOOL ok=archive_write_header(a,en)==ARCHIVE_OK;archive_entry_free(en);
    if(!ok)return Fail(error,@"无法写入文件夹 ZIP 副本，请检查可用存储空间。");
    if(S_ISREG(st.st_mode)) {
        uint8_t buffer[65536];int64_t remaining=st.st_size;
        while(remaining>0) {
            if(CFAbsoluteTimeGetCurrent()-budget->started>90)return Fail(error,@"文件夹读取时间过长，请下载到本机后分批分享。");
            ssize_t n=read(fd,buffer,(size_t)MIN((int64_t)sizeof(buffer),remaining));
            if(n<0&&errno==EINTR)continue;
            if(n<=0||archive_write_data(a,buffer,n)!=n)return Fail(error,@"文件读取或 ZIP 写入失败，请确认文件已下载且有可用存储空间。");
            remaining-=n;
        }
        struct stat after;
        if(fstat(fd,&after)||after.st_size!=st.st_size||after.st_mtimespec.tv_sec!=st.st_mtimespec.tv_sec||after.st_mtimespec.tv_nsec!=st.st_mtimespec.tv_nsec)
            return Fail(error,@"分享期间文件发生变化，请等修改完成后重试。");
        return YES;
    }
    int duplicate=dup(fd);DIR *dir=duplicate<0?NULL:fdopendir(duplicate);if(!dir){if(duplicate>=0)close(duplicate);return Fail(error,@"无法列出文件夹内容。");}
    while(ok) {
        errno=0;struct dirent *item=readdir(dir);
        if(!item){if(errno)ok=Fail(error,@"无法完整读取文件夹内容。");break;}
        if(!strcmp(item->d_name,".")||!strcmp(item->d_name,".."))continue;
        NSError *childError=nil;
        @autoreleasepool {
            BOOL (^visit)(NSError **)=^BOOL(NSError **failure){
                NSString *name=[NSFileManager.defaultManager stringWithFileSystemRepresentation:item->d_name length:strlen(item->d_name)];
                struct stat child;
                if(!SafeName(name)||fstatat(fd,item->d_name,&child,AT_SYMLINK_NOFOLLOW))return Fail(failure,@"文件夹内有无法读取的名称或项目。");
                if(!S_ISDIR(child.st_mode)&&!S_ISREG(child.st_mode))return Fail(failure,@"文件夹含符号链接或特殊文件，请移除后重试。不会跟随链接读取其他目录。");
                int opened=openat(fd,item->d_name,O_RDONLY|O_NOFOLLOW|O_NONBLOCK|(S_ISDIR(child.st_mode)?O_DIRECTORY:0));
                struct stat actual;
                if(opened<0)return Fail(failure,@"无法读取文件夹中的项目，请确认其已下载到本机。");
                if(fstat(opened,&actual)||actual.st_dev!=child.st_dev||actual.st_ino!=child.st_ino){close(opened);return Fail(failure,@"文件夹在分享期间发生变化，请重试。");}
                BOOL result=Add(a,opened,[path stringByAppendingPathComponent:name],actual,budget,failure);close(opened);return result;
            };
            ok=visit(&childError);
        }
        if(!ok&&error)*error=childError;
    }
    closedir(dir);return ok;
}
NSURL *TFShareFolderArchive(NSURL *folder,NSString *name,NSError **error) {
    if(!SafeName(name))name=@"SharedFolder";
    int fd=open(folder.fileSystemRepresentation,O_RDONLY|O_DIRECTORY|O_NOFOLLOW);
    struct stat st;if(fd<0){Fail(error,@"无法读取分享的文件夹，请先下载到本机。");return nil;}
    if(fstat(fd,&st)||!S_ISDIR(st.st_mode)){close(fd);Fail(error,@"分享来源已不再是文件夹。");return nil;}
    NSURL *temp=[[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:[@"DylixFolder-" stringByAppendingString:NSUUID.UUID.UUIDString] isDirectory:YES];
    if(![NSFileManager.defaultManager createDirectoryAtURL:temp withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error]){close(fd);return nil;}
    NSURL *zip=[temp URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"zip"]];
    struct archive *a=archive_write_new();archive_write_set_format_zip(a);
    BOOL ok=archive_write_open_filename(a,zip.fileSystemRepresentation)==ARCHIVE_OK;
    Budget budget={0,0,CFAbsoluteTimeGetCurrent()};
    if(ok)ok=Add(a,fd,name,st,&budget,error);else Fail(error,@"无法创建文件夹 ZIP 副本。");
    close(fd);
    if(archive_write_close(a)!=ARCHIVE_OK){if(ok)Fail(error,@"无法完成文件夹 ZIP，请检查存储空间。");ok=NO;}
    archive_write_free(a);
    if(!ok){[NSFileManager.defaultManager removeItemAtURL:temp error:nil];return nil;}
    return zip;
}
