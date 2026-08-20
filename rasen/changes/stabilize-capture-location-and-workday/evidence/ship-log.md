# Ship Log: stabilize-capture-location-and-workday

**Date:** 2026-08-20 13:42:13 +0800
**Mode:** local
**Branch:** main
**Commit:** 0235f1c5a49ef8db948e08625f9f6718029d3a6d
**Tree:** 8cda46d081c926d17bc41f9ad8ee305d315e07a7
**Status:** Committed (delivery deferred to portfolio level)

## Pre-Flight Results

- Verification: pass — `review-cycle-report.md` verdict is `CLEAN`; the earlier Major Photos-cancellation finding is retained in `review-report.md` as historical evidence and was re-reviewed as resolved.
- Tasks: 15/16 complete. Task 2.4 remains intentionally unchecked because the `SWIFT_STRICT_CONCURRENCY=complete` build stopped at the Xcode 27 SwiftUI macro sandbox failure before a complete source-level result. No suppression or `@preconcurrency` workaround was added. The user explicitly authorized local delivery with this gap recorded.
- Ship log: no existing candidate or reserved `## Archive` heading was present before this log.
- Branch: `main`, not detached.

## Test Gate

- Required scope: `git diff --check`, current-worktree iPhone build/install/launch, and the configured on-device unit/UI test targets. The scope is broad enough for the camera/location/Photos concurrency changes, workday rules, and test-host/scheme configuration; a full repository suite was not inferred.
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
- Tree: `8cda46d081c926d17bc41f9ad8ee305d315e07a7`.

## Delivery

- Local commit created; no push, PR, merge, or remote write was performed.
- Before commit, the working tree contained only the named implementation/docs/Rasen change files plus intentionally untracked `.codex/`, `.rasen/`, and `rasen/config.yaml`.
- The commit contains 26 explicitly staged files. The empty `handoff/` directory had no files to stage.
- After the code commit, `main` is ahead of `origin/main` by 1 commit. The process-only `.codex/`, `.rasen/`, and `rasen/config.yaml` remain untracked and untouched.
