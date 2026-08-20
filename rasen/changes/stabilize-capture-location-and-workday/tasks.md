## 1. Capture integrity and metadata contracts

- [x] 1.1 Define immutable/sendable capture and photo-location value contracts so a capture can represent unavailable location data without synthetic altitude, accuracy, or timestamp values.
- [x] 1.2 Make `CameraService` single-flight: reject duplicate requests deterministically, identify each operation, settle success/failure/cancellation exactly once, ignore late callbacks, and keep UI protection as a secondary guard.
- [x] 1.3 Refactor `PhotoLibrarySaver` to an async/value-based Photos boundary that applies one capture context and only valid location metadata while resolving authorization and save failures explicitly.
- [x] 1.4 Refactor `ContentView` capture flow to await the bounded fresh-location result, create one immutable capture context, use it for watermark and photo metadata, and clear saving/countdown state on success, failure, or cancellation.

## 2. Location freshness, lifecycle, and strict concurrency

- [x] 2.1 Add request generations/tokens and coordinate matching across continuous location, Core Location geocoding, MapKit reverse geocoding, and nearby-POI callbacks so stale results cannot overwrite newer snapshots.
- [x] 2.2 Implement the bounded one-shot refresh result contract for success, authorization denial, error, timeout, cancellation, and no-fresh-result; clear `isRefreshing` exactly once on every terminal path.
- [x] 2.3 Add explicit start/stop/invalidation lifecycle handling and connect scene/page visibility plus return-from-Settings behavior to location authorization/status refresh.
- [ ] 2.4 Rework `CameraService`, `LocationService`, and `PhotoLibrarySaver` callback/continuation boundaries until the strict-concurrency build has no service-level warnings, without blanket `@preconcurrency` or warning suppression.

## 3. Workday and attendance rules

- [x] 3.1 Correct the 2026 official holiday and adjusted-workday table, retain valid existing holidays, remove April 26 and September 27 adjusted entries, and preserve adjusted-workday precedence.
- [x] 3.2 Implement the explicit `上班前` / `上班` / `下班` attendance enum and boundary semantics so both configured on-duty and off-duty times affect the watermark output.
- [x] 3.3 Add focused unit coverage for every 2026 schedule boundary, adjusted weekends, erroneous dates, first-day behavior, and all three attendance thresholds/settings.

## 4. Runnable unit and UI test configuration

- [x] 4.1 Correct Debug/Release `WorkStampTests` `TEST_HOST` to the `DayMark.app` product and `DayMark` executable, and add a shared scheme/test action containing both unit and UI test targets.
- [x] 4.2 Add deterministic unit seams/tests for capture single-flight/exactly-once outcomes, location freshness/cancellation state, and safe metadata fallback in addition to the workday/attendance tests.
- [x] 4.3 Replace template-only UI launch/performance tests with a permission-safe current-app launch flow that asserts the camera shell/settings controls and records unavailable destinations as blocked rather than passed.

## 5. Documentation and verification evidence

- [x] 5.1 Update only affected items in `docs/todo.md` and `docs/decisions.md`, add `docs/sessions/2026-08-20.md`, and document the three-state text change, bounded metadata fallback, strict-concurrency result, and any blocked simulator/device evidence.
- [x] 5.2 Run narrow tests/builds, the generic app build, the `SWIFT_STRICT_CONCURRENCY=complete` build, and the configured unit/UI test command; inspect the final diff for unrelated files, record exact results under the change evidence/session docs, and leave Rasen status/validation consistent.

> Verification note: 2.4 remains unchecked. The bounded final command was `SWIFT_STRICT_CONCURRENCY=complete /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project WorkStamp.xcodeproj -scheme WorkStamp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/WorkStampStrictReviewData build` (exit 65). It reached `LocationService.swift` and `PhotoLibrarySaver.swift`; the only service diagnostics were the existing iOS 26 `CLGeocoder`/`cancelGeocode()` deprecations, with no service-level strict-concurrency warning observed. The build then failed in `SettingsView.swift` before a complete strict result: `sandbox-exec: sandbox_apply: Operation not permitted`, followed by malformed `SwiftUIMacros.StateMacro` and `PreviewsMacros.SwiftUIView` plugin responses. No `@preconcurrency` or diagnostic suppression was added, and this is not claimed as a strict-build pass.
