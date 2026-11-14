# Embedded iSH in Dylix

Upstream: https://github.com/OpenMinis/ish-arm64
Pinned revision: c5c264da19148512167aa493d7bd4e50aae1b74e
License: GPLv3 plus LICENSE.IOS; original notices and sources are retained here.
The Dylix repository's LICENSE provides the GPL text.

Dylix modifications (2026-11-08):
- tools/staticdefine.sh: argv-safe Python implementation for Unicode/spaced paths.
- fs/path.c and kernel/fs.c: honor the guest root boundary for .., absolute symlinks and getcwd.
- fs/mount.c, kernel/fs.c and kernel/ptrace.c: guest mount/umount/chroot/ptrace disabled under DYLIX_EMBEDDED_SANDBOX.
- kernel/mm.h and kernel/mmap.c: allocation-boundary native memory refresh hook after suspension.
- fs/sock.c and fs/fd.h: loopback-only TCP listeners, context-bound port discovery and close notifications; UDP DNS remains unchanged.
- kernel/signal.c and fs/tty.c: reject cross-command/session signal and PTY access.

The native adapter in App/AI/Sandbox uses iSH's C APIs. Its boot/PTY structure
was researched in OpenMinis (ISHKernel / ISHShellExecutor) and Kelivo
(KelivoISHKernel / KelivoISHExecutor); their Swift/Flutter application UI is
not copied. iSH is statically linked, never a separately launched iOS app.
No host offload handlers or host directory mounts are registered.

Alpine minirootfs 3.21.0 aarch64:
https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/aarch64/alpine-minirootfs-3.21.0-aarch64.tar.gz
SHA-256 f31202c4070c4ef7de9e157e1bd01cb4da3a2150035d74ea5372c5e86f1efac1
Alpine package licenses remain those of their respective upstream packages;
package metadata/licenses are contained in the rootfs. The exact official
rootfs is redistributed without modification and verified before importing.

Terminal renderer: @xterm/xterm 5.5.0 and @xterm/addon-fit 0.10.0, MIT.
Their original LICENSE files are in Resources/Terminal.

Official offline development APK kit:
https://dl-cdn.alpinelinux.org/alpine/v3.21/{main,community}/aarch64/
Exact URLs, versions, hashes, licenses and package origins are recorded in
Resources/iSH/developer-tools.json. The unchanged signed APKs are bundled in
developer-tools.tar and verified by Alpine apk with its trusted signing keys.
Alpine source/build recipes: https://gitlab.alpinelinux.org/alpine/aports
Corresponding distfiles: https://distfiles.alpinelinux.org/distfiles/v3.21/
These package sources/build recipes are separate from iSH; their respective
upstream licenses apply. No --allow-untrusted or alternate mirror is used.

- 2026-11-09：修正 mount_find 父挂载缓存遮蔽嵌套挂载；每次按最长匹配选择 mount，防止会话只读技能视图落回可写 fakefs。
