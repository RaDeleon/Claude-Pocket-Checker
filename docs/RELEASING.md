# macOS preview release workflow

## Validate and package

Use a clean macOS checkout with Xcode's Swift toolchain. Packaging never launches an app, stops another process, installs anything, changes login items, or grants Accessibility.

```sh
swift test
python3 script/package_macos.py
python3 script/verify_macos.py
python3 script/check_publication.py
python3 script/source_archive.py
```

`package_macos.py` reads `VERSION`, builds optimized arm64 and x86_64 slices, combines them into one universal executable, removes debug symbols, creates an app icon and bundle, ad-hoc signs it, and writes a DMG, ZIP and SHA-256 file under ignored `dist/`. Temporary staging outside the checkout avoids File Provider metadata entering the app. Only system dynamic libraries are allowed. It refuses to publish a binary containing the builder's home path.

`verify_macos.py` extracts the actual ZIP and mounts the actual DMG read-only. It checks hashes, exact app members, both architecture slices, macOS 14 minimum, system-only linked libraries, strict signatures, the Applications shortcut, instructions and matching executables. It unmounts the image afterwards. It does not launch the GUI. CI repeats packaging/verification and uploads the DMG/ZIP/checksum as a downloadable workflow artifact with read-only repository permissions.

## Publish the reviewed preview

- Current version/tag: `0.2.2` / `v0.2.2`.
- Commit reviewed packaging/docs, pass CI, and confirm the exact source commit before tagging.
- Create a prerelease and attach only these explicit files from `dist/`:
  - `Claude-Pocket-Checker-0.2.2-universal-macOS.dmg`
  - `Claude-Pocket-Checker-0.2.2-universal-macOS.zip`
  - `SHA256SUMS-macos.txt`
  - `claude-pocket-checker-0.2.2-source.zip`
  - `SHA256SUMS-source.txt`
- Explain macOS 14+, the universal slices, Apple Silicon smoke-check scope, and Intel/clean-Mac acceptance still pending. Link [installation instructions](INSTALL.md).
- Label the build **ad-hoc signed, not Developer ID signed or Apple-notarized**. Never describe strict signature verification as Gatekeeper approval.
- Confirm uploaded asset sizes/digests and the public download links after publication. Do not upload `dist/` wholesale, local ledgers, account preferences, private devlogs or logs.

## Signing and notarization

A Developer ID Application certificate is not configured in this release environment. The preview's ad-hoc signature provides a local integrity seal; it does not identify an Apple developer. Gatekeeper assessment of the extracted preview rejects it, as expected for this distribution state. Users may approve the individual app through Apple's documented Open Anyway flow where policy allows. We do not ship instructions to disable Gatekeeper or strip quarantine attributes.

For a future notarized release, obtain the owner's Developer ID Application identity, sign the final app with hardened runtime and a trusted timestamp, submit the distributable with `notarytool`, staple the accepted ticket to the app/disk image, then recreate and reverify every archive/checksum. Validate the quarantined download on a fresh Mac before claiming a smooth first-launch experience. Never expose signing credentials in source or logs.

## Download badge

The README badge uses GitHub's release-asset download counts, including DMG, ZIP, source and checksum downloads. It does not count unique people, installations, Git clones or automatic source archives. No telemetry is added to the app. Use a per-asset Shields badge if measuring only one chosen binary format.
