# Reverse tools corresponding sources

Dylix does not modify the bundled Alpine radare2/r2ghidra binaries. They execute inside the per-session iSH Linux guest using a separate prefix and loader; they are not linked into the iOS application. Native adapter implementation is in App/AI/Sandbox/TFAIISHRuntime.m.

Included source archives and build recipes reproduce the upstream versions in Resources/iSH/reverse-tools.json. Archives and the Alpine patch are verified against SHA-512 values in the pinned APKBUILD recipes, not inferred from a tag name. sources.json records local file hashes. Keep source headers and license files intact when extracting or redistributing.

- radare2 6.2.6-r0: aports c74a6cfebe42557a0989654176b4263bd13e8b3c / community/radare2; includes radare2 6.2.6, sdb 2.6.2, QuickJS b51e5278439b2fa0510fbb1f3b3dff9f0064d5d7.
- r2ghidra 6.2.6-r0: aports aeae0145e82f476825fb1745ce3a0c8ce6d37bff / testing/r2ghidra; includes Ghidra native 0.7.2 and unchanged Alpine use-system-zlib.patch.

The APKBUILD files document build dependencies, preparation, Meson options and installation. Build within Alpine aarch64 with the matching dependencies; do not execute these recipes in the host macOS shell. Individual library dependencies retain their own licenses and source recipes, pinned per package in reverse-tools.json. This directory is source material, not runtime code automatically executed by Dylix.

To restore the exact signed offline APK bundle, run scripts/fetch_reverse_tools.py; it validates the checked-in manifest. Refreshing versions is explicit and requires updating/retesting the matching runtime adapter. Source archives are not copied into the IPA; the IPA carries their license texts, exact package manifest and official source references.
