# Ship Log: stabilize-capture-location-and-workday

**Date:** 2026-08-27 14:12:41 +0800
**Mode:** push
**Branch:** main
**Commit:** 07a17f939e670335abd022602f23b8db33064d69
**Tree:** 137f5491506c96562115e7e11a4175103edb3ed6
**Status:** Pushed

## Pre-Flight Results

- Verification: pass — `review-cycle-report.md` verdict is `CLEAN`; the earlier Major Photos-cancellation finding is retained in `review-report.md` as historical evidence and was re-reviewed as resolved.
- Tasks: 15/16 complete. Task 2.4 remains intentionally unchecked because the `SWIFT_STRICT_CONCURRENCY=complete` build stopped at the Xcode 27 SwiftUI macro sandbox failure before a complete source-level result. No suppression or `@preconcurrency` workaround was added. The user explicitly authorized local delivery with this gap recorded.
- Ship log: no existing candidate or reserved `## Archive` heading was present before this log.
- Branch: `main`, not detached.

## Test Gate

- Required scope: `git diff --check`, current-worktree iPhone build/install/launch, version metadata inspection, and the configured unit test target. The scope is broad enough for the camera/location/Photos concurrency changes, workday rules, version UI, and test-host/scheme configuration; a full repository suite was not inferred.
- Rationale: the change crosses camera, location, Photos, SwiftUI capture flow, business-rule calculation, and Xcode test configuration. The connected-device test command exercised the current app and both configured test targets.
- `git diff --check`: exit 0.
- `xcodebuild -project WorkStamp.xcodeproj -scheme WorkStamp -configuration Debug -destination id=A67DE9B5-C985-51C3-83BE-FBC006C114A4 -derivedDataPath /tmp/WorkStampDeviceDerivedData build`: exit 0.
- `xcrun devicectl device install app --device A67DE9B5-C985-51C3-83BE-FBC006C114A4 /tmp/WorkStampDeviceDerivedData/Build/Products/Debug-iphoneos/DayMark.app`: install succeeded.
- `xcrun devicectl device process launch --device A67DE9B5-C985-51C3-83BE-FBC006C114A4 --terminate-existing com.godmiracle.WorkStamp`: launch succeeded.
- `xcodebuild -project WorkStamp.xcodeproj -scheme WorkStamp -destination id=A67DE9B5-C985-51C3-83BE-FBC006C114A4 -derivedDataPath /tmp/WorkStampDeviceTestDerivedData -resultBundlePath /tmp/WorkStampDeviceTests.xcresult -only-testing:WorkStampTests -only-testing:WorkStampUITests test`: exit 0; `WorkStampTests` 16/16 passed and `WorkStampUITests` 1/1 passed.
- Result bundle: `/tmp/WorkStampDeviceTests.xcresult`.
- Device: paired physical device `哥谭之王` (iPhone Air), ID `A67DE9B5-C985-51C3-83BE-FBC006C114A4`.
- Strict-concurrency command: `SWIFT_STRICT_CONCURRENCY=complete /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project WorkStamp.xcodeproj -scheme WorkStamp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/WorkStampStrictReviewData build`: exit 65 at SwiftUI macro sandbox/plugin errors; this is the recorded reason task 2.4 remains incomplete.
- Supplementary `xcresulttool get test-results summary` readback was blocked by an Xcode 27 permission error while creating a temporary `TestReport` file; it does not override the successful `xcodebuild` result and test counts above.
- Current follow-up Debug iPhoneOS build: exit 0; generated bundle metadata `CFBundleShortVersionString=1.0`, `CFBundleVersion=3`.
- Current follow-up `devicectl device install app` and `device process launch`: succeeded on `哥谭之王` (iPhone Air); user confirmed the Settings version display is normal.
- Current follow-up `WorkStampTests` execution: interrupted before tests because Xcode reported the physical device was locked; the app and test bundles compiled successfully.
- Simulator fallback: blocked by CoreSimulatorService connection refusal while booting the available iOS 27.0 runtime.
- Tree: `8a13f4ae6e51f0424e65066c407603bd00e0082e`.

## Delivery

- Commit `7fdf5fc` created and pushed directly to `main` via the verified GitHub SSH endpoint; no PR or merge was used.
- Before commit, the working tree contained only the named implementation/docs/Rasen change files plus intentionally untracked `.codex/`, `.rasen/`, and `rasen/config.yaml`.
- The code commit contains 14 explicitly staged files; this ship-log update is recorded separately.
- The process-only `.codex/`, `.rasen/`, and `rasen/config.yaml` remain untracked and untouched.

## Previous Delivery

- `0235f1c5a49ef8db948e08625f9f6718029d3a6d` was previously recorded as a local delivery on 2026-08-20; this entry supersedes its delivery status after the follow-up commit was pushed.

## Follow-up Delivery

- Commit `07a17f9` was committed on `main` and pushed successfully to `git@github.com:godmiracle/WorkStamp.git` after the HTTPS credential helper rejected username input.
- The delivered version is `1.0.1 (4)`; the generated `DayMark.app` metadata was independently checked as `CFBundleShortVersionString=1.0.1` and `CFBundleVersion=4`.
- The final versioned build was installed to the paired iPhone Air with `devicectl`; database sequence number `4060`; process launch succeeded.
- The build gate was `xcodebuild ... -destination 'generic/platform=iOS' ... build`: `BUILD SUCCEEDED`; `git diff --check` passed.
- The visible location diagnostic UI was removed while the real refresh/address-resolution chain, internal diagnostics, and regression tests were retained.
