# FitCheck

A Flutter mobile app for choosing outfits and fragrances from your own wardrobe, matching them to your plans and weather, and tracking laundry.

The build is in progress. Foundation, wardrobe, and daily outfit selection/swapping/wear recording are implemented; planner integration, later milestones, and release verification remain open. See [build status](docs/build-status.md) and the [GitHub backlog](https://github.com/ysxiaixsy/fitcheck/issues/1).

## Requirements

- Flutter **3.47.2**, including Dart **3.13.2**.
- Node.js **24** and npm for Firebase emulators and browser/rules tests.
- Java **21** for the Firestore and Storage emulators.
- Chrome for local review. Android requires its SDK and accepted licenses; iOS builds require macOS and Xcode.

## Run locally

Install dependencies and start the local backend:

```sh
flutter pub get
npm ci
npx firebase emulators:start --only auth,firestore,storage --project demo-fitcheck
```

In a second terminal, run the app:

```sh
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

Create an account in the app to start. Emulator accounts and wardrobe data stay local. Data resets when the emulators restart unless exported and imported with the Firebase CLI. The Emulator UI is at [localhost:4000](http://127.0.0.1:4000).

The Android emulator uses `10.0.2.2` automatically. An explicit development host can be supplied with `--dart-define=FIREBASE_EMULATOR_HOST=<host>`. Emulator mode is blocked in release builds.

## Verify

Run the Flutter checks:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

With the local emulators running, build and exercise the web target:

```sh
npx playwright install chromium
flutter build web --debug --dart-define=USE_FIREBASE_EMULATORS=true --output=build/web-emulator --no-wasm-dry-run
npm run test:rules
npm run test:web
```

Playwright starts the test build at `http://127.0.0.1:5174`. Screenshots and failure traces are written under `artifacts/`. Browser tests cover account creation, validation, photo upload, wardrobe persistence, outfit swaps/details, persisted wear counts, theme switching, reset-password requests, and sign-in/sign-out. Rules tests check owner isolation, invalid wardrobe/outfit writes, photo restrictions, and immutable worn outfit records.

CI runs these checks against a fresh `demo-fitcheck` emulator project, then builds the production web target separately:

```sh
flutter build web --release --no-wasm-dry-run
```

The web target is a review and testing surface; Android and iOS remain the product targets.

## Firebase environments

| Environment | Project | Purpose |
| --- | --- | --- |
| Local development and CI | `demo-fitcheck` | Auth, Firestore, and Storage emulators; no cloud project connection |
| Cloud | `fitcheck-ysxiaixsy` | Registered Android, iOS, and web apps; Firestore database in `asia-southeast1` |

Cloud Authentication activation and a production Storage bucket are still pending. Emulator success does not establish that live sign-in or cloud photo upload works. Firebase currently requires the Blaze plan for Cloud Storage; see its [bucket and billing requirements](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).

Item saves currently wait for server acknowledgement, and daily outfit changes require a connection. Offline write recovery remains unfinished; see the [known limitations](docs/build-status.md#known-limitations).

## Project references

- [Build handoff](FitCheck-Build-Handoff.md): behavior, data model, accessibility requirements, and milestone acceptance checks.
- [Final Figma screens](https://www.figma.com/design/leBVZp8eURCGW8T82kjvH8/FitCheck?node-id=115-43): the **Mobile prototype** page is the screen source of truth.
- [Asset sources and font license](assets/README.md).
- [Agent configuration](AGENTS.md): shared by Codex and Claude Code through `CLAUDE.md`.
