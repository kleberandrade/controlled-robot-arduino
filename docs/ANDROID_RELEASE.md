# Signed Android release APK

The GitHub test release includes an optimized, non-debuggable APK for Android
API 24+. It retains the same robot protocol as the original debug build. Version
1.0.0 build 2 distinguishes this release artifact from the debug APK (build 1).
This is still a hardware-unvalidated test release, not a store deployment.

## Build locally

1. Generate your own signing identity, using a JDK keytool:

   ```sh
   cd app/android
   keytool -genkeypair -storetype PKCS12 -keystore release-signing.p12 \
     -alias robot-test-release -keyalg RSA -keysize 3072 -validity 10000
   ```

   Follow the password and certificate prompts. This creates a new identity;
   use the existing private key instead when updating a previously signed APK.
2. Create `app/android/key.properties` locally:

   ```properties
   storeFile=release-signing.p12
   storePassword=YOUR_PRIVATE_PASSWORD
   keyAlias=robot-test-release
   keyPassword=YOUR_PRIVATE_PASSWORD
   ```

   `storeFile` is resolved relative to `app/android`. Use a strong password and
   restrict both files to your user (`chmod 600 key.properties release-signing.p12`
   on macOS/Linux). Never commit or upload either file. Both are ignored by git.
3. From `app/`, run:

   ```sh
   flutter pub get --enforce-lockfile
   flutter analyze --fatal-infos
   flutter test
   flutter build apk --release
   ```

   Output: `app/build/app/outputs/flutter-apk/app-release.apk`, relative to the
   repository root. The universal APK includes ARMv7, ARM64 and x86_64, so phone
   users do not have to choose an architecture. Flutter AOT, icon tree shaking,
   R8 minification and resource shrinking reduce size compared with debug mode.
   For architecture-specific APKs, use `--split-per-abi` in your own build.

Release builds fail if `key.properties` is missing. There is no fallback to the
Android debug signing key. Keep an encrypted backup of the keystore and its
password outside the repository; future updates require the same private key.
The locally generated test-release identity is not registered with Google Play.

## Verify before distributing

Use Android SDK tools (replace SDK/build-tools paths with installed versions):

```sh
apksigner verify --verbose --print-certs app-release.apk
apkanalyzer manifest debuggable app-release.apk
```

The signature must verify and the second command must print `false`. Check the
package version/code and SHA-256 of the exact file being uploaded. A successful
build or signature check does not test the radio, phone UI or physical robot.

The committed CI workflow builds both modes. Its release signing identity is
generated per run, used solely to verify the build, and never published as the
project's update identity. No production signing key is stored in CI or git.

## Switching from debug to release

The published release APK uses the same application ID and a different signing
certificate from the first debug APK. Android cannot update across those
identities. If you installed the debug APK, uninstall Controlled Robot once
(removing its local data), then install the release APK. Subsequent builds signed
with the same release key and a suitable version code can update it normally.
The HC-05 pairing belongs to Android system Bluetooth settings, not app storage.

The existing `v1.0.0-test.1` tag still identifies the original source commit; it
is not rewritten. The release notes identify the separate source commit for
the added build-2 release APK. The original debug asset remains available.

References: [Flutter Android deployment](https://docs.flutter.dev/deployment/android)
and [Android app signing](https://developer.android.com/studio/publish/app-signing).
