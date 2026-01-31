---
name: release
description: Build a signed, notarized macOS .app and publish a GitHub release. Use when cutting a new version of WisprDuck.
disable-model-invocation: true
allowed-tools: Bash(*), Read, Edit, Write, Glob, Grep
argument-hint: <version e.g. 1.4.0>
---

# Release WisprDuck

Build a signed, notarized, and stapled `.app`, then publish it as a GitHub release.

**Target version:** $ARGUMENTS

## Pre-flight

1. Confirm the working tree is clean (`git status`). Abort if there are uncommitted changes.
2. Confirm the version `$ARGUMENTS` does not already have a git tag or GitHub release.
3. If not on `main`, merge the current branch into `main` and switch to it:
   ```
   git checkout main
   git merge <branch> --no-edit
   ```

## Step 1 — Bump version numbers

Update **all** of the following to `$ARGUMENTS`:

| File | Field | Format |
|------|-------|--------|
| `WisprDuck.xcodeproj/project.pbxproj` | `MARKETING_VERSION` (both Debug and Release) | Short: `1.4` (no patch) |
| `site/index.html` | `"softwareVersion"` in the Schema.org JSON-LD | Semver: `1.4.0` |
| `site/package.json` | `"version"` | Semver: `1.4.0` |

`MARKETING_VERSION` uses Xcode's short version format (e.g., `1.4` not `1.4.0`). The other files use full semver.

Do **not** touch `CURRENT_PROJECT_VERSION` (build number) — leave it as-is.

After updating, verify with `grep` that no stale version strings remain in those files.

## Step 2 — Commit and push

```
git add WisprDuck.xcodeproj/project.pbxproj site/index.html site/package.json
git commit -m "Bump version to $ARGUMENTS"
git push origin main
```

## Step 3 — Archive

Run as a **single line** (multiline backslash escaping can break in some shell environments):

```bash
xcodebuild archive -project WisprDuck.xcodeproj -scheme WisprDuck -configuration Release -archivePath /tmp/WisprDuck.xcarchive "CODE_SIGN_IDENTITY=Developer ID Application: Tiny Anvil, LLC (T4GBHCYB7P)" DEVELOPMENT_TEAM=T4GBHCYB7P CODE_SIGN_STYLE=Manual
```

Note: `CODE_SIGN_IDENTITY` must be quoted because the value contains spaces and a comma.

Confirm output ends with `** ARCHIVE SUCCEEDED **`.

## Step 4 — Export

Write this ExportOptions.plist to /tmp:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>T4GBHCYB7P</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Developer ID Application</string>
</dict>
</plist>
```

Then export:

```bash
xcodebuild -exportArchive -archivePath /tmp/WisprDuck.xcarchive -exportPath /tmp/WisprDuckExport -exportOptionsPlist /tmp/ExportOptions.plist
```

Confirm `** EXPORT SUCCEEDED **`.

## Step 5 — Verify signing

```bash
codesign -dv --verbose=2 /tmp/WisprDuckExport/WisprDuck.app
```

Confirm:
- `Authority=Developer ID Application: Tiny Anvil, LLC (T4GBHCYB7P)`
- `flags=0x10000(runtime)` (hardened runtime)

If signing is wrong, stop and diagnose.

## Step 6 — Notarize

```bash
ditto -c -k --keepParent /tmp/WisprDuckExport/WisprDuck.app /tmp/WisprDuck-$ARGUMENTS.zip

xcrun notarytool submit /tmp/WisprDuck-$ARGUMENTS.zip --keychain-profile "WisprDuck-Notarize" --wait
```

If the keychain profile is missing, ask the user to run:

```
xcrun notarytool store-credentials "WisprDuck-Notarize" --key ~/Desktop/wispr-duck-certs/AuthKey_4MM3YQXN45.p8 --key-id 4MM3YQXN45 --issuer 69a6de83-bf58-47e3-e053-5b8c7c11a4d1
```

Then retry. Confirm status is `Accepted`.

## Step 7 — Staple

```bash
xcrun stapler staple /tmp/WisprDuckExport/WisprDuck.app
xcrun stapler validate /tmp/WisprDuckExport/WisprDuck.app
```

Confirm `The staple and validate action worked!`.

Re-create the zip with the stapled app:

```bash
rm /tmp/WisprDuck-$ARGUMENTS.zip
ditto -c -k --keepParent /tmp/WisprDuckExport/WisprDuck.app /tmp/WisprDuck-$ARGUMENTS.zip
```

## Step 8 — Create GitHub release

```bash
gh release create v$ARGUMENTS /tmp/WisprDuck-$ARGUMENTS.zip --repo kalepail/wispr-duck --title "WisprDuck v$ARGUMENTS" --generate-notes
```

Print the release URL when done.

## Step 9 — Clean up

```bash
rm -rf /tmp/WisprDuck.xcarchive /tmp/WisprDuckExport /tmp/ExportOptions.plist /tmp/WisprDuck-$ARGUMENTS.zip
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `No Keychain password item found for profile: notarytool` | Re-run the `store-credentials` command from Step 6 |
| `Developer ID Application` identity not found | Open Keychain Access and verify the cert is in the login keychain. Import from `~/Desktop/wispr-duck-certs/` if needed. |
| Notarization status `Invalid` | Run `xcrun notarytool log <submission-id> --keychain-profile "WisprDuck-Notarize"` and fix the reported issues |
| `ARCHIVE FAILED` with signing errors | Ensure `CODE_SIGN_STYLE=Manual` and the full identity string matches `security find-identity -v -p codesigning` output |
| `Unknown build action ''` from xcodebuild | Multiline backslash escaping broke — use single-line commands instead |
| `No App Category is set` warning during archive | Non-blocking. Can be fixed by adding `LSApplicationCategoryType` to Info.plist if desired. |
