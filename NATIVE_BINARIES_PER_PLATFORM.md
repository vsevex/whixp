# Configuring native binaries per platform

The optional Rust transport is loaded via FFI. Each platform expects the built library in a specific place. This document describes the layout and how to configure it.

## Summary: where each binary lives

| Platform            | Path (relative to package root)   | File name(s)               |
| ------------------- | --------------------------------- | -------------------------- |
| **Android**         | `android/src/main/jniLibs/<abi>/` | `libwhixp_transport.so`    |
| **iOS (device)**    | `ios/`                            | `libwhixp_transport.a`     |
| **iOS (simulator)** | `ios/`                            | `libwhixp_transport_sim.a` |
| **macOS**           | `macos/`                          | `libwhixp_transport.dylib` |
| **Linux**           | `linux/`                          | `libwhixp_transport.so`    |
| **Windows**         | `windows/`                        | `whixp_transport.dll`      |

---

## Android

- **Directory:** `android/src/main/jniLibs/`
- **ABIs:** One subfolder per ABI; each must contain `libwhixp_transport.so`.
  - `arm64-v8a/` — 64-bit ARM (most devices)
  - `armeabi-v7a/` — 32-bit ARM
  - `x86_64/` — 64-bit x86 (emulator / some devices)
- **Config:** `android/build.gradle` already sets `jniLibs.srcDirs = ['src/main/jniLibs']`, so any `.so` in the layout above is packaged into the app.
- **Flutter:** The package is registered as a Flutter plugin (Android). When an app depends on `whixp` and builds for Android, this module is included and the jniLibs are merged into the app. No extra config in the app is needed.

**Loading (Dart):** `DynamicLibrary.open('libwhixp_transport.so')` — the system finds it from the app’s lib path (from jniLibs).

---

## iOS

- **Device:** `ios/libwhixp_transport.a` (static lib, arm64).
- **Simulator:** `ios/libwhixp_transport_sim.a` (arm64 + x86_64 for sim).
- **Config:** `ios/whixp_transport.podspec` has `s.vendored_libraries = 'libwhixp_transport.a'`. Xcode/CocoaPods link the device lib for device builds. For simulator builds you may need to ensure the sim lib is used (e.g. via pod subspecs or a single XCFramework if you want one artifact).
- **Flutter:** The package is registered as a Flutter plugin (iOS). The app’s Podfile includes the plugin; building the app links the vendored library. No extra config in the app is needed.

**Loading (Dart):** `DynamicLibrary.process()` — the static lib is linked into the app, so the symbol table is in the process.

---

## macOS

- **Directory:** `macos/`
- **File:** `libwhixp_transport.dylib`
- **Config:** No extra Gradle/Podfile config. The Dart code looks up the lib by name or from the package root (see “How the Dart side finds the lib” below).
- **Flutter (macOS app):** Copy the dylib into the app bundle or ensure it’s next to the executable / in the package’s `macos/` when running. If the app depends on `whixp` and the package’s `macos/` is present (e.g. from `pub get` or from an unpacked release zip), the loader will use it when the code calls `_openFromPackageRoot('macos', 'libwhixp_transport.dylib')`.

**Loading (Dart):** First `DynamicLibrary.open('libwhixp_transport.dylib')` (app bundle / working dir), then fallback `_openFromPackageRoot('macos', 'libwhixp_transport.dylib')`.

---

## Linux

- **Directory:** `linux/`
- **File:** `libwhixp_transport.so`
- **Config:** No extra config. Same idea as macOS: the lib must be on the library path or in the package’s `linux/` so `_openFromPackageRoot` can find it.

**Loading (Dart):** First `DynamicLibrary.open('libwhixp_transport.so')`, then fallback `_openFromPackageRoot('linux', 'libwhixp_transport.so')`.

---

## Windows

- **Directory:** `windows/`
- **File:** `whixp_transport.dll`
- **Config:** No extra config. The DLL must be next to the executable or in the package’s `windows/` directory.

**Loading (Dart):** First `DynamicLibrary.open('whixp_transport.dll')`, then fallback `_openFromPackageRoot('windows', 'whixp_transport.dll')`.

---

## How the Dart side finds the lib

See `lib/src/native/transport_ffi.dart`:

- **Android:** `DynamicLibrary.open('libwhixp_transport.so')` — system finds it from the app’s native lib dir (from jniLibs).
- **iOS:** `DynamicLibrary.process()` — lib is linked into the app.
- **macOS / Linux / Windows:** Tries by simple name first (so the lib is in the app bundle or on `PATH`/`LD_LIBRARY_PATH`), then `_openFromPackageRoot(platformDir, libName)` which resolves relative to the script path or current working directory (e.g. `.../whixp/macos/libwhixp_transport.dylib`).

So for desktop and for `dart run`, having the correct file in the package’s `macos/`, `linux/`, or `windows/` folder is enough as long as the process’s working directory or script location is under or next to the package root.

---

## Ensuring binaries are present

1. **From pub:** If the published package (or your fork) includes the built libs in `android/.../jniLibs/`, `ios/`, `macos/`, `linux/`, `windows/`, then `flutter pub get` / `dart pub get` is enough.
2. **From release:** Download `whixp-native-<version>.zip` from [Releases](https://github.com/vsevex/whixp/releases), unzip, and copy the contents into the package’s platform folders so the layout matches the table above.
3. **From source:** From the package root run `make`, or `make android`, `make ios`, `make macos`, `make linux`, `make windows` as needed (see [native/README.md](../native/README.md)).

---

## Flutter plugin registration

The package declares a Flutter plugin for **Android** and **iOS** in `pubspec.yaml`:

```yaml
flutter:
  plugin:
    platforms:
      android:
        package: com.whixp.transport
        pluginClass: WhixpTransportPlugin
      ios:
        pluginClass: WhixpTransportPlugin
```

That makes Flutter include the Android and iOS native code (jniLibs and vendored libs) when building an app. **macOS, Linux, and Windows** are not registered as plugin platforms; the Dart code loads the dylib/so/dll from the package’s `macos/`, `linux/`, or `windows/` directories as described above.

---

## Troubleshooting: "Failed to lookup symbol 'whixp_transport_create': symbol not found"

The app is not linking the right native library for the current target.

- **iOS Simulator:** The pod was only linking the device static lib (`libwhixp_transport.a`), so the simulator build had no valid slice. **Fix:** Use an XCFramework that includes both device and simulator. In the whixp repo run `make ios-xcframework` to create `ios/WhixpTransport.xcframework`. The podspec uses it when present. Then in your app: `flutter clean`, `cd ios && pod install`, build again.
- **iOS Device:** Ensure `pod install` ran and the plugin is linked. The XCFramework from `make ios-xcframework` (or a release zip) includes both device and simulator.
- **macOS:** The dylib may be wrong architecture (Intel vs Apple Silicon) or an old build. Rebuild with `make macos` and ensure `macos/libwhixp_transport.dylib` matches your run destination.
- **Android:** The `.so` must be in `android/src/main/jniLibs/<abi>/`. Confirm the ABI matches your device and the plugin's jniLibs are included in the app.
