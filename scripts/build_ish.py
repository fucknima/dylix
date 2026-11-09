#!/usr/bin/env python3
"""Build embedded iSH, never the standalone iSH application or a host shell.

Apple clang compiles host iOS objects; LLVM LLD only links the guest ELF VDSO.
Device and simulator archives are kept in different directories and validated.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REVISION = "c5c264da19148512167aa493d7bd4e50aae1b74e"
LIBS = ("libish.a", "libish_emu.a", "libfakefs.a")

def source_digest(source=None):
    """Include paths and contents, so edits/deletions invalidate cached archives."""
    source = source or ROOT / 'Vendor/iSH'
    digest = hashlib.sha256()
    for path in sorted(source.rglob('*')):
        if path.is_file() and '.git' not in path.parts:
            digest.update(path.relative_to(source).as_posix().encode())
            digest.update(b'\0')
            digest.update(path.read_bytes())
    digest.update(Path(__file__).read_bytes())
    return digest.hexdigest()

def run(argv, **kwargs):
    subprocess.run([str(x) for x in argv], check=True, **kwargs)

def build(platform, source=None, output=None):
    source = (source or ROOT / 'Vendor/iSH').resolve()
    output = (output or ROOT / 'build/ish' / platform).resolve()
    output.mkdir(parents=True, exist_ok=True)
    sdk = 'iphoneos' if platform == 'device' else 'iphonesimulator'
    sdkroot = subprocess.check_output(['xcrun', '--sdk', sdk, '--show-sdk-path'], text=True).strip()
    clang = subprocess.check_output(['xcrun', '--find', 'clang'], text=True).strip()
    # A short, ASCII alias also supports old upstream scripts and toolchains.
    alias = Path('/tmp') / ('dylix-ish-sdk-' + sdk)
    if alias.is_symlink(): alias.unlink()
    if not alias.exists(): alias.symlink_to(sdkroot, target_is_directory=True)
    target = 'arm64-apple-ios15.0' + ('-simulator' if platform == 'simulator' else '')
    cross = output / 'cross.ini'
    flags = ['-target', target, '-isysroot', str(alias)]
    ar = str(Path(clang).with_name('ar'))
    strip = str(Path(clang).with_name('strip'))
    cross.write_text("[binaries]\nc = " + repr([clang, *flags]) + "\nar = " + repr(ar) + "\nstrip = " + repr(strip) + "\npkg-config = '/usr/bin/false'\n"
        "[host_machine]\nsystem = 'darwin'\ncpu_family = 'aarch64'\ncpu = 'aarch64'\nendian = 'little'\n"
        "[properties]\nneeds_exe_wrapper = true\n[built-in options]\nc_link_args = " + repr(flags) + "\n")
    env = os.environ.copy()
    env.update({'LC_ALL': 'C', 'LANG': 'C'})
    env.pop('SDKROOT', None)
    env.pop('DYLD_LIBRARY_PATH', None)
    env.pop('DYLD_FRAMEWORK_PATH', None)
    # Do not put a downloaded clang/ld64 ahead of Apple's tools.
    lld = env.get('DYLIX_LLD') or shutil.which('ld.lld')
    if not lld: raise SystemExit('Set DYLIX_LLD to LLVM ld.lld (guest ELF linker).')
    bindir = output / 'tools'; bindir.mkdir(exist_ok=True)
    link = bindir / 'ld.lld'
    if link.is_symlink(): link.unlink()
    link.symlink_to(Path(lld).resolve())
    env['PATH'] = str(bindir) + os.pathsep + env['PATH']
    meson = shutil.which('meson')
    ninja = shutil.which('ninja')
    if not meson or not ninja: raise SystemExit('Install meson and ninja in your Python environment.')
    builddir = output / 'meson'
    command = [meson, 'setup', str(builddir), str(source), '--cross-file', str(cross),
        '-Dguest_arch=arm64', '-Dengine=asbestos', '-Djit=false', '-Dc_args=-DDYLIX_EMBEDDED_SANDBOX=1', '--buildtype=release']
    if (builddir / 'build.ninja').exists(): command.append('--reconfigure')
    run(command, env=env)
    run([ninja, '-C', builddir, *LIBS], env=env)
    for name in LIBS: shutil.copy2(builddir / name, output / name)
    # Rootfs import/export is a library operation, not a subprocess on iOS.
    extra = []
    for file in ['tools/fakefs.c', 'util/fchdir.c']:
        obj = output / (Path(file).stem + '.o')
        run([clang, *flags, '-O2', '-DISH_INTERNAL', '-DGUEST_ARM64=1',
             '-I' + str(source), '-I' + str(ROOT / 'Vendor/libarchive-headers'),
             '-c', source / file, '-o', obj], env=env)
        extra.append(obj)
    run([ar, 'rcs', output / 'libish_rootfs.a', *extra], env=env)
    libraries = [*LIBS, 'libish_rootfs.a']
    manifest = {'source': 'https://github.com/OpenMinis/ish-arm64', 'revision': REVISION,
        'platform': sdk, 'architecture': 'arm64', 'guest': 'aarch64-linux', 'engine': 'asbestos',
        'jit': False, 'target': target, 'sourceDigest': source_digest(source),
        'libraries': {n: hashlib.sha256((output/n).read_bytes()).hexdigest() for n in libraries}}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(output)
    return output

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--platform', choices=['device', 'simulator'], default='device')
    p.add_argument('--source', type=Path)
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    build(a.platform, a.source, a.output)
