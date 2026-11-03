# Build status

Updated November 3, 2026. The [handoff](../FitCheck-Build-Handoff.md) defines the product and acceptance criteria; the [build backlog](https://github.com/ysxiaixsy/fitcheck/issues/1) tracks delivery.

## Milestones

| Milestone | Implementation | Remaining sign-off |
| --- | --- | --- |
| [1. Foundation](https://github.com/ysxiaixsy/fitcheck/issues/2) | Android/iOS/web scaffold, semantic Light/Dark themes, bundled typography, navigation, email auth flow, appearance settings | Live Auth activation, real-phone verification |
| [2. Wardrobe](https://github.com/ysxiaixsy/fitcheck/issues/3) | Required item fields, category/formality/occasion selection, photos, per-user Firestore repository, filters/search, laundry status, mark washed | Live Storage setup, offline-save improvements, real-phone verification |
| [3. Today](https://github.com/ysxiaixsy/fitcheck/issues/4) | New-user checklist, Add clothes entry point, outfit picks and reasons, per-item/full swaps, View outfit, persisted daily wear recording with duplicate-wear protection | Planned-occasion/reservation integration with milestone 5, real-phone verification |
| [4. Fragrance](https://github.com/ysxiaixsy/fitcheck/issues/5) | Backlog | Collection management, weather, ranking, Change fragrance |
| [5. Planner](https://github.com/ysxiaixsy/fitcheck/issues/6) | Month calendar and date selection | Saved plans, repeats, reservations, laundry warnings |
| [6. Reminders and polish](https://github.com/ysxiaixsy/fitcheck/issues/7) | Theme contrast and enlarged-text checks are part of foundation testing | Local notifications, full accessibility/device pass, release assets/signing |

Milestone completion requires the handoff's checks on a real phone in both themes. An implemented screen or a successful web build alone does not close a milestone.

## Verification

The CI workflow checks formatting, static analysis, Flutter tests, Firestore/Storage ownership rules, browser flows against Firebase emulators, and a separate production web build. Local commands are in the [README](../README.md#verify). Browser screenshots and failure traces go under `artifacts/`.

Current evidence:

- The integrated source passed formatting and static analysis; 57 Flutter tests passed, with one optional capture test skipped.
- The final combined browser run passed Wardrobe and Today on November 3 (two tests, one minute), with no page errors. Same-user Firestore reads confirmed one wear per selected item and zero for the unused alternative, before and after reload.
- All seven wardrobe, photo, and daily-outfit ownership/validation rules tests passed against the November 3 emulator run (2.1 seconds). Worn outfit records reject changes and deletion.
- The integrated Today source built successfully for production web with `flutter build web --release --no-wasm-dry-run` on November 3 (49.8 seconds).
- The CI workflow passed Actionlint 1.7.12; its pinned action commits resolve in the official repositories.

Screenshots cover the new-user screen, item entry, wardrobe in both themes, outfit swaps, and full outfit details after wearing. Use CI results for verification of the exact pushed revision.

## Cloud and device setup

- Firebase project: `fitcheck-ysxiaixsy`; Android, iOS, and web apps are registered.
- Firestore: Standard edition, free tier, `asia-southeast1`, deletion protection enabled; owner-only wardrobe and occasion rules deployed.
- Live Authentication: not activated yet; the configuration currently returns `CONFIGURATION_NOT_FOUND`. Console setup needs the project owner's Google session to be reauthenticated.
- Live Storage: bucket not provisioned. Firebase's [current requirements](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024) require the Blaze plan for Cloud Storage.
- Local tests use only `demo-fitcheck` Auth, Firestore, and Storage emulators.
- No physical phone was connected during the initial build. Android licenses remain outstanding on this workstation; iOS compilation requires macOS/Xcode.

## Current product choices

- Color names are typed text.
- Clothing categories are top, bottom, and shoes; accessories are outside the initial wardrobe slice.
- Authentication uses email/password for the foundation flow. Its UI is minimal because the supplied final Figma page has no auth frame.
- The final Figma Mobile prototype frames guide the UI. Dark surfaces use the supplied semantic tokens while additional dark frames remain unapproved.

The [open decisions issue](https://github.com/ysxiaixsy/fitcheck/issues/8) retains onboarding, item editing, fragrance weather-band ownership, and further design work. These features are not represented as complete.

## Known limitations

- Adding a clothing item waits for Firestore server acknowledgement. Without a connection, the form remains pending; queued-write feedback, recovery, and an idempotent add flow are not implemented or fully verified.
- Daily outfit changes and recording wears use transactions and require a connection. Offline transaction recovery has not been verified.
- Planned occasions and reservations are supported by selection logic but are not connected to the Planner UI yet.
