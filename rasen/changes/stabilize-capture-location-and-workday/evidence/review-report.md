# Review Report

## Verdict

MAJOR — one provable cancellation defect; the review is not CLEAN.

## Summary

The scoped implementation provides the stated capture gate/context, location generation and coordinate checks, 2026 workday/attendance rules, and shared DayMark test configuration. One required terminal-state contract is incomplete: cancellation during Photos authorization/save is not propagated to the capture caller.

## Findings

### Major

- **[Major] Photos save ignores caller cancellation.** [`/Users/v/XBP/WorkStamp/WorkStamp/PhotoLibrarySaver.swift:28`] suspends on `withCheckedThrowingContinuation` without a cancellation handler or post-completion cancellation check. The caller only cancels the location task in [`/Users/v/XBP/WorkStamp/WorkStamp/ContentView.swift:756`] and then records success at [`/Users/v/XBP/WorkStamp/WorkStamp/ContentView.swift:805`]. If the capture task is cancelled while authorization or `performChanges` is pending, it can wait for Photos and still publish “saved”, violating the capture-cancellation requirement in [`/Users/v/XBP/WorkStamp/rasen/changes/stabilize-capture-location-and-workday/specs/capture-integrity/spec.md:36`].

## Verification

- Camera single-flight and late-callback identity: `AppSettings.swift:205-225`, `CameraService.swift:211-230,345-385`.
- Bounded two-second refresh and immutable capture context: `ContentView.swift:750-804`, `LocationService.swift:164-227`.
- Location request generations and coordinate-gated geocoding: `AppSettings.swift:229-244`, `LocationService.swift:343-365,551-562`.
- 2026 holiday/adjusted-workday table, precedence, and attendance boundaries: `WorkdayCalculator.swift:47-72,145-166`; tests: `WorkStampTests.swift:92-221`.
- DayMark host and shared unit/UI test targets: `project.pbxproj:459-482`, `WorkStamp.xcscheme:15-78`; observable UI assertions: `WorkStampUITests.swift:16-28`.
- Pre-scoped evidence records generic build/build-for-testing as passed; strict build is blocked by SwiftUI macro sandbox failure and simulator tests by CoreSimulatorService connection refusal (`docs/sessions/2026-08-20.md:17-44`).

## Residual Risks / Blocked Evidence

- Strict-concurrency source-level completion remains unverified because the build stops in the SwiftUI macro sandbox.
- No simulator or physical-device tap-through exists; camera, Photos cancellation, permissions, and runtime callback behavior remain unverified.
- Generic build/build-for-testing does not constitute runtime acceptance.
