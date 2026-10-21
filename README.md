# Water World

Flutter app for local stock, production, purchasing, B2B orders, and reporting for a bottled-water business. It uses SQLite on each device; data does not sync between phones.

## Requirements

- Flutter SDK **3.44.4** was used for the latest local checks; `pubspec.yaml` requires Dart `^3.12.2` (minimum 3.12.2, not an exact pin)
- Git
- Android Studio with Android SDK and platform tools, or VS Code with the Flutter and Dart extensions
- Android emulator (Pixel 7 is fine) or a USB-debuggable Android phone
- Windows, macOS, or Linux development machine

No separate database server or manually installed Dart packages are needed. `flutter pub get` installs the Dart/Flutter packages listed in `pubspec.yaml`. Android Studio installs the Android build tools. The app uses the Android SQLite integration supplied through Flutter packages.

Optional: Python 3.9+ only if you want to run the separate LINE bridge. It has no third-party Python package dependencies; see [`Writeup/line_bridge/README.md`](../../Writeup/line_bridge/README.md).

## Install and run on Android

1. Install Flutter and Android Studio. In Android Studio, install the Android SDK and accept its licenses.
2. Check the toolchain:

   ```powershell
   flutter doctor
   ```

   Resolve any Android toolchain issues reported by `flutter doctor`.
3. Clone the project and enter its folder:

   ```powershell
   git clone --branch feature/waterworld-work2 https://github.com/lilbScratch/Water-World.git
   cd Water-World
   ```

   This branch contains the current Work2 app version. To run an older published baseline instead, clone `master` explicitly.

   If you received a ZIP instead, extract it and open the folder containing `pubspec.yaml`.
4. Fetch declared packages and check available devices:

   ```powershell
   flutter pub get
   flutter devices
   ```
5. Start an Android emulator in Android Studio Device Manager, or connect a phone with USB debugging enabled. Then run:

   ```powershell
   flutter run
   ```

   To select a specific device, use `flutter run -d <device-id>` with an ID shown by `flutter devices`. In VS Code, open this project folder, select the device in the status bar, then press **F5**.

## Demo sign-in

On a fresh local database, the demo manager account is `admin` with PIN `123456`. This is a presentation credential shipped in the source; do not reuse it for real business data. User accounts and inventory are stored in the local SQLite database on the device.

## Main workflows

1. Review inventory and create missing item records.
2. Record received materials or correct a counted balance.
3. Configure stock planning values and review low-stock suggestions.
4. Add a B2B customer and order. The app checks and reserves available materials before accepting production work.
5. Record production and dispatch; inspect transaction history and the dashboard.
6. For LINE stock requests, optionally run the separate bridge. Each request must be reviewed and confirmed in the app before it changes local stock. See [`Writeup/line_bridge/README.md`](../../Writeup/line_bridge/README.md).

## Dependencies

Direct application packages are declared in `pubspec.yaml` and locked in `pubspec.lock`:

- Flutter SDK: Material UI and Thai localization
- `provider`: app state and dependency access
- `sqflite`: local SQLite database
- `path`: database path handling
- `intl`: date and number formatting
- `cryptography`: password/PIN hashing
- `cupertino_icons`: icon set
- Development: `flutter_test`, `flutter_lints`, and `sqflite_common_ffi` for tests

Do not install these one by one; run `flutter pub get` from the folder containing `pubspec.yaml`.

## Test and build

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is created at `build/app/outputs/flutter-apk/app-debug.apk`.

## Project notes

- App entry and dependency setup: `lib/main.dart`
- Database schema and migrations: `lib/data/app_db.dart`
- Stock repository and transactions: `lib/data/stock_repository.dart`
- UI pages: `lib/screens/`
- State providers: `lib/providers/`
- Full file-by-file guide and workflows: kept in the course workspace at `Project/Writeup/docs/WORK2_CODE_GUIDE.md`.
- LINE bridge setup and security notes: kept in the course workspace at `Project/Writeup/line_bridge/README.md`.

## Data and security limits

SQLite is local to the device. Back up a device’s app data before reinstalling; uninstalling can remove its local database. This prototype has no cross-device synchronization. Never commit LINE channel secrets, access tokens, or bridge tokens. Use environment variables on the bridge host and the runtime token prompt in the app. Companion course writeups and the optional bridge service are outside this app repository; the `Project/Writeup` folder is part of the supplied local workspace only.
