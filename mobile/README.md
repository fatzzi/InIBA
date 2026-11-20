# InIBA mobile

Flutter app for Android and iOS.

## Setup

```
cd mobile
flutter pub get
flutter run
```

Run `flutter doctor` first if something isn't working.

## Android

Phone over USB: turn on Developer options and USB debugging, plug in, tap Allow on the phone, then `flutter run`.

Phone over Wi-Fi (Android 11+): Developer options > Wireless debugging > Pair device with pairing code, then

```
adb pair <ip>:<port>
adb connect <ip>:<port>
flutter run
```

Emulator: create one in Android Studio's Device Manager and set its back camera to Webcam0 or VirtualScene.

## iOS

Needs a Mac with Xcode. After the first build, add this inside `post_install` in `ios/Podfile` so the camera permission works:

```ruby
target.build_configurations.each do |config|
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'PERMISSION_CAMERA=1']
end
```

Then `cd ios && pod install`. The simulator has no camera, so use a real iPhone.

## Camera

The Post tab asks for camera permission, lets you take a photo and preview it. It doesn't post yet. The camera doesn't work in Chrome or on desktop.

## Common problems

- `adb` not found: add `<Android SDK>\platform-tools` to PATH.
- Build says the Android Gradle Plugin or compileSdk is too old: update the version in `android/settings.gradle.kts` or `android/app/build.gradle.kts` to what the error asks for.
- Out of memory or disk space: close other apps and make sure the drive with your Gradle cache (`%USERPROFILE%\.gradle`) has a few GB free.
