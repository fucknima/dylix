- (NSURL *)shareFixture241{
 NSString *folder=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"FolderShare241"];
 [NSFileManager.defaultManager createDirectoryAtPath:[folder stringByAppendingPathComponent:@"nested/empty"] withIntermediateDirectories:YES attributes:nil error:nil];
 [@"SHARE_DIRECTORY_241_OK" writeToFile:[folder stringByAppendingPathComponent:@"nested/verify.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
 return [NSURL fileURLWithPath:folder];
}
- (void)compatibility241:(UITableViewController *)page{
 [page chooseFolderCompatible:YES];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 UIDocumentPickerViewController *picker=[page valueForKey:@"folderPicker"];
 [self record:@"compatibility_uses_isolated_native_window" passed:picker&&!picker.allowsMultipleSelection&&[page valueForKey:@"pickerWindow"]!=nil detail:nil];
 [(id<UIDocumentPickerDelegate>)page documentPickerWasCancelled:picker];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self record:@"isolated_window_released_after_cancel" passed:[page valueForKey:@"pickerWindow"]==nil&&![page valueForKey:@"folderPicker"] detail:nil];[self verifyFolderTrace242:^{[self shareProvider241];}];});
 });
}
- (void)shareProvider241{
 NSURL *folder=[self shareFixture241];NSItemProvider *provider=[[NSItemProvider alloc]initWithItem:folder typeIdentifier:UTTypeFileURL.identifier];
 [self record:@"folder_provider_recognized_ios" passed:TFShareProviderHasFile(provider) detail:nil];
 TFShareLoadFile(provider,^(NSURL *url,NSString *name,NSError *error){
  NSError *failure=error;NSURL *copy=[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"FolderShare241-verification.zip"];
  [NSFileManager.defaultManager removeItemAtURL:copy error:nil];
  BOOL copied=url&&[NSFileManager.defaultManager copyItemAtURL:url toURL:copy error:&failure];
  struct archive *a=archive_read_new();archive_read_support_format_zip(a);BOOL payload=NO,empty=NO;
  if(copied&&archive_read_open_filename(a,copy.fileSystemRepresentation,65536)==ARCHIVE_OK){struct archive_entry *e;while(archive_read_next_header(a,&e)==ARCHIVE_OK){NSString *path=@(archive_entry_pathname(e));if([path isEqual:@"FolderShare241/nested/verify.txt"]){char buffer[64]={0};la_ssize_t n=archive_read_data(a,buffer,63);payload=n==strlen("SHARE_DIRECTORY_241_OK")&&!strcmp(buffer,"SHARE_DIRECTORY_241_OK");}if([path isEqual:@"FolderShare241/nested/empty/"])empty=YES;}}
  archive_read_free(a);[NSFileManager.defaultManager removeItemAtURL:copy error:nil];
  dispatch_async(dispatch_get_main_queue(),^{[self record:@"folder_provider_snapshot_zip_ios" passed:copied&&[name isEqual:@"FolderShare241.zip"] detail:failure.localizedDescription];[self record:@"folder_zip_nested_contents_ios" passed:payload detail:nil];[self record:@"folder_zip_empty_directory_ios" passed:empty detail:nil];[self data237BackupUI];});
 });
}

- (void)verifyFolderTrace242:(void(^)(void))done{
 NSString *root=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"DylixDiagnostics"];
 BOOL clean=![NSFileManager.defaultManager fileExistsAtPath:[root stringByAppendingPathComponent:@"FolderPicker"]]&&![NSFileManager.defaultManager fileExistsAtPath:[root stringByAppendingPathComponent:@"file-ui.log"]];
 [self record:@"folder_authorization_generates_no_trace_files" passed:clean detail:nil];done();
}
