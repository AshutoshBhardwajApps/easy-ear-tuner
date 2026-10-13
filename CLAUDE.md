# Claude Conventions for Easy Ear Tune

A frequency tuner and hearing test. The Xcode project and target are still
named `Freq Test`; the display name is "Easy Ear Tune". It was built from the
shared iOS template, and in October 2026 its ads and consent setup were
brought up to CoopHockey's level. CoopHockey's `CLAUDE.md` is the longer
reference for every pattern below.

## Architecture

- SwiftUI app with a UIKit `AppDelegate` adaptor. `SettingsStore` and
  `PurchaseManager` are created as `@StateObject` in `FreqTestApp` and injected
  with `@EnvironmentObject`. Hearing results are stored with SwiftData
  (`HearingResult`).
- **This app uses `Constants.swift`** (the template convention): the app name,
  the Remove Ads product ID and the Release interstitial unit. CoopHockey
  doesn't, so keep using it here.
- UserDefaults keys are prefixed `easyeartune.` (`Constants.userDefaultsPrefix`).
- Classic Xcode project, not synchronized folders. **New files must be added
  to `project.pbxproj`** (file reference, group entry, and the Sources or
  Resources phase).
- The audio session is `.playback`: a tuner has to sound even with the silent
  switch on. Don't copy CoopHockey's `.ambient`.

## Launch order (do not change)

**UMP consent, then ATT, then preload ads**, on `didBecomeActive` plus 0.4s
(`AppDelegate.requestATTIfNeeded`). ATT used to fire from
`ContentView.onAppear`, which kept it waiting until onboarding was finished.
Calling it from `didFinishLaunching` silently no-ops, the mistake that got
CoopHockey 1.3(14) rejected. `ConsentManager.gather` always completes (it times
out after 5s).

## Ads (`AdManager`)

- DEBUG uses Google's test interstitial unit, Release uses
  `Constants.interstitialAdUnitID`. Test device hashes live in `AppDelegate`.
- Pacing is specific to this app: an ad every 3 stops (`minRoundsBetweenAds = 3`),
  with a forced Remove Ads promo every 5th stop plus random 1-in-8 rolls.
  `handleStop()` in `ContentView` is the only ad break; the hearing test shows no ads.
- Interstitials present from `AdPresenter`'s anchor. Anything inside a sheet or
  cover (Ad Inspector, a future rewarded ad) uses `AdManager.topmostPresenterVC()`.
- Mediation adapters (Meta, Liftoff/Vungle, Pangle) are linked through SPM, at
  CoopHockey's versions. `FBAdSettings.setAdvertiserTrackingEnabled` must stay
  ahead of `MobileAds.shared.start()`.

## IAP

StoreKit 2, one non-consumable: `com.ashutoshbhardwaj.easyeartune.premium`
(build 11 moved to this ID). It is offered on the main screen, through the
promo, and in Settings.

## Settings

`SettingsView` (reached from the main screen) holds Remove Ads and Restore,
plus a DEBUG section with "Reset consent" and Ad Inspector. To see the UMP form
outside the EEA, set `ConsentManager.forceEEAForTesting = true` (DEBUG only).

## app-ads.txt

`app-ads.txt` sits at the repo root and is served through GitHub Pages. Its
content is `google.com, pub-2320635595451132, DIRECT, f08c47fec0942fa0`. The
support and privacy pages live in the separate `easy-ear-tuner-support` repo.

## Versioning

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` appear twice each in
`project.pbxproj`. Bump the build on every upload.

## Not ported yet

- iPad (`TARGETED_DEVICE_FAMILY = 1`). CoopHockey ships on iPad, but this
  app's layout hasn't been checked there.
- Haptics or sound effects (the app's sound *is* the product), Game Center,
  and rewarded ads.

## Style

Terse comments that explain **why**. `// MARK: -` for sections. 4-space indent.
