# Release builds

`Build ALL` builds the desktop and Android packages. The independent `Validate iOS`
workflow tests, builds, and publishes the unsigned IPA.

## Signing

- Android: configure both `ANDROID_KEYSTORE` (base64 keystore) and
  `ANDROID_KEY_PROPERTIES` (the contents of `android/key.properties`) for signed
  release APKs. Without either secret, release APK names end in `-unsigned.apk`.
  These packages require signing before installation; release builds never fall
  back to the Android debug key. Incomplete signing configuration is an error.
- macOS: configure both `CERTIFICATE` (base64 PKCS#12) and `CERTIFICATE_PASSWORD`
  for certificate signing. Without either secret, the app uses ad hoc signing and
  the DMG name ends in `-adhoc.dmg`. This is not Developer ID signing or notarization.
  An invalid or incomplete certificate configuration fails instead of falling back.

## Recovering an existing release

Run `Build ALL` from the branch containing the build fixes and set `release_tag`
to an existing tag, such as `v1.6.4`. Leave it empty to build artifacts only.
The workflow checks that the tag matches `pubspec.yaml` and that application
source matches the tag. Only the explicitly listed build recipes and this
documentation may differ. The release tag is never moved.

Successful platforms can upload even when another platform fails. Failed builds
still remain failures in the run. Uploads use the workflow token and preserve
existing asset names, including the independently published IPA. Missing signing
identities are described in both package names and release notes.

Windows uses the Visual Studio 2022 runner because the current Windows plugins
do not compile with the newer MSVC toolchain on `windows-latest`. Its build script
fails on compiler or installer errors and verifies packages before uploading.
