# Install Claude Pocket Checker

**macOS 14 or later.** The universal app contains Apple Silicon and Intel code. No Xcode, Swift tools, API key or separate Claude login is needed. The official Claude Desktop app must already be installed. Intel code is cross-compiled; runtime acceptance on an Intel Mac remains open.

## Download and install

1. Download the **universal-macOS.dmg** from the [preview releases](https://github.com/RaDeleon/Claude-Pocket-Checker/releases). The ZIP is an alternative containing the same app.
2. Open the disk image and drag **Claude Pocket Checker.app** onto **Applications**. With the ZIP, extract it and move the app to Applications. Quit an existing Pocket Checker before replacing it.
3. Eject the disk image. Open the installed copy from Applications.

## First-launch approval

This experimental preview is **ad-hoc signed, not Developer ID signed or notarized by Apple**. A valid local signature does not establish an identified developer. macOS may initially prevent it from opening.

If you reviewed the source and trust this download, try opening the app once, then use **System Settings → Privacy & Security → Open Anyway** for this app. Confirm the system prompt. Follow [Apple's guidance for opening apps from unidentified developers](https://support.apple.com/en-us/102445). Organization policy may prohibit approval; contact your administrator in that case. If macOS reports malware or that the app is damaged, stop and verify the download rather than overriding that warning.

Do not disable Gatekeeper, remove quarantine attributes, or change Claude's permissions to install this companion.

## Set up your accounts

1. In Pocket Checker, open **Account labels for this Mac**. Enter the exact labels shown at the bottom-left of your own Claude Desktop window for Personal and Work. Unknown/ambiguous labels pause accounting.
2. Enable **Claude Pocket Checker** in **System Settings → Privacy & Security → Accessibility** when prompted by its permission control. Some macOS versions use **Device Control and Data Access**. Add the installed Applications copy if needed.
3. Open a regular Claude Desktop Chat. Existing messages are baselined; new settled responses add estimates. Draft advice stays local and in memory. You choose the model and effort in Claude yourself.

The app has no startup item. Open it when you want it; close its panel or choose Quit to stop it. An update may need Accessibility to be re-enabled. Keep the browser extension and desktop totals separate; they can observe the same activity.

## Verify your download

Download `SHA256SUMS-macos.txt` alongside the DMG or ZIP. In Terminal, from the download folder, run:

```sh
shasum -a 256 Claude-Pocket-Checker-0.2.2-universal-macOS.dmg
```

Compare the result with the matching filename in the checksum file. Checksums detect a changed download; they are not a replacement for Developer ID signing or notarization.

## Remove the app

Quit Pocket Checker, remove its Accessibility permission, and delete its installed app. Saved totals stay in `~/Library/Application Support/ClaudePocketChecker/`; remove that folder separately to erase them. Claude Desktop and any older companion with a different identity are unaffected.
