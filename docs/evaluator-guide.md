# How to run FitCheck

## Before you start

Check that these four tools are installed. Run each command in a terminal. If a command fails or shows an older version, install the tool from its link, then close and reopen the terminal.

| Tool | Check with | Should show | Install from |
| --- | --- | --- | --- |
| Google Chrome | — | — | [google.com/chrome](https://www.google.com/chrome/) |
| Flutter | `flutter --version` | Flutter 3.47 or newer | [Flutter install guide](https://docs.flutter.dev/get-started/install) (choose your OS, then **Web**) |
| Node.js | `node --version` | v20 or newer | [nodejs.org](https://nodejs.org) (the **LTS** version) |
| Java | `java -version` | 21 or newer | [adoptium.net](https://adoptium.net) (Temurin 21 or newer) |

Last, run `flutter doctor`. The **Flutter** and **Chrome** lines should have a check mark. You can ignore warnings about Android, Xcode, and Visual Studio.

## Steps

1. Open a terminal in the `fitcheck` folder and install everything (first time only):

   ```sh
   flutter pub get
   npm ci
   ```

2. Start the local backend, and leave this terminal open:

   ```sh
   npx firebase emulators:start --only auth,firestore,storage --project demo-fitcheck
   ```

   Wait until it says **All emulators ready**.

3. Open a **second** terminal in the `fitcheck` folder and start the app:

   ```sh
   flutter run -d chrome --web-port=5050 --dart-define=USE_FIREBASE_EMULATORS=true
   ```

   A Chrome window opens. The first start takes about a minute, so wait for the sign-in screen.

4. Select **Create an account** and sign up with any made-up email (for example `tester@example.com`) and a password of 8 or more characters.

That's it. You're in the app.

## Good to know

- Use only the Chrome window that opened in step 3. Opening the app in another tab or browser can stop it.
- Everything stays on your computer. Accounts and data are erased when you close the terminal from step 2.
- To stop, press `q` in the second terminal, then `Ctrl+C` in the first.
