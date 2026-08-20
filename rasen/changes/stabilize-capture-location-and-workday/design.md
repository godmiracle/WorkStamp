## Context

DayMark is a native SwiftUI iPhone app whose capture path currently spans `CameraService`, `ContentView`, `LocationService`, `WatermarkRenderer`, and `PhotoLibrarySaver`. The camera service stores one mutable completion callback, the location service publishes from several asynchronous Core Location/MapKit callbacks without a request generation, and `ContentView` starts a refresh before immediately reading the current snapshot. `LocationSnapshot.photoAssetLocation` also fills missing altitude/accuracy values with synthetic defaults. The app target produces `DayMark.app`, while the unit-test host and test configuration still refer to the historical `WorkStamp` product and no shared scheme currently executes both test targets.

The change must stay within the existing native frameworks and preserve the camera-first UI, local-only processing, existing MapKit/`CLGeocoder` strategy, and the configured-first-day workday contract. It must make asynchronous boundaries explicit enough for `SWIFT_STRICT_CONCURRENCY=complete`, while recognizing that simulator/device launch evidence is an environment-dependent layer separate from compilation.

## Goals / Non-Goals

**Goals:**

- Make capture service single-flight and deterministic for duplicate, success, failure, and cancellation paths.
- Build one immutable capture context and use it for both watermark rendering and photo metadata; wait only within a bounded fresh-location window and use an explicit no-location fallback when that window cannot produce a valid result.
- Prevent stale location, reverse-geocode, nearby-POI, and authorization callbacks from mutating newer state; make one-shot refresh and scene/page lifecycle terminal paths observable and cancellable.
- Remove strict-concurrency warnings in the three named services through actor/queue/value boundaries rather than warning suppression.
- Correct the official 2026 holiday/adjusted-workday table and implement the three attendance states with boundary tests.
- Correct the `DayMark` unit-test host, add a shared scheme/test action for unit and UI targets, and replace template-only UI tests with observable assertions.
- Record build/test/device evidence honestly in the affected project docs and the 2026-08-20 session log.

**Non-Goals:**

- No 4K watermark/rendering architecture or full-resolution performance redesign.
- No iPad/orientation policy decision, MapKit/`CLGeocoder` migration, address-cache redesign, or unrelated dead-code cleanup.
- No new backend, third-party dependency, permission policy, attendance history, or persistent capture database.
- No claim of simulator or physical-device acceptance when CoreSimulator or a device is unavailable.

## Decisions

### 1. Keep UI state on MainActor and use value-only callback crossings

`CameraService` and `LocationService` remain observable services isolated to the main actor because SwiftUI consumes their published state. Delegate/callback entry points that are not actor-isolated will be explicit nonisolated boundaries: AVFoundation/Core Location/MapKit objects are inspected at the callback edge and converted to immutable `Data`, strings, coordinates, dates, and numeric metadata before a `Task { @MainActor in ... }` handoff. Mutable service state is changed only on the main actor. This preserves the existing UI architecture and avoids sending framework objects or `UIImage` across actors.

For camera session work that must remain off the main thread, AVFoundation session/input/output access will stay behind the existing serial session queue with an explicit queue-owned controller/state boundary. The main-actor service owns operation identity and published flags; the queue owns session configuration and invokes a value-only completion handoff. The implementation will not add `@preconcurrency` imports or blanket diagnostic suppression.

### 2. Give every asynchronous request an identity and one terminal gate

The camera operation receives an identity and a per-operation delegate proxy, so a late callback from a cancelled operation cannot be mistaken for a later capture. The service sets its busy state before enqueueing work, rejects duplicates with `CameraError.captureInProgress`, and funnels success, decode failure, cancellation, and delegate error through one guarded finish path.

`LocationService` maintains a monotonically increasing generation for lifecycle/one-shot work and a coordinate key for reverse geocoding. A callback may publish only if its generation and coordinate still match. One-shot refresh returns an explicit success/failure result, owns its continuation and timeout task, and clears `isRefreshing` in one terminal path for success, denial, error, timeout, cancellation, and lifecycle invalidation. Continuous updates remain enabled only while the owning page/scene is active.

### 3. Use a bounded fresh snapshot, never a mutable reread, for capture

`ContentView` starts one bounded location refresh for the capture and records the capture date once. The refresh result is awaited within a small fixed timeout (two seconds); only a location callback accepted after that request's start and with valid source accuracy/timestamp can become the capture snapshot. If the refresh is denied, cancelled, fails, or times out, the capture context uses `LocationSnapshot.empty`. That fallback keeps the watermark's explicit “定位中或不可用/不可用” text and omits unsupported photo location metadata rather than reusing `locationService.snapshot` or inventing altitude/accuracy.

The context is a value containing the capture date and immutable snapshot. The renderer receives that value directly. Photo saving receives a value-only metadata projection and constructs a Photos location only when coordinates, timestamp, horizontal accuracy, and vertical accuracy are all valid; no default altitude, accuracy, or timestamp is synthesized. A later live location update cannot alter either output.

### 4. Make Photos saving data-based and async

`PhotoLibrarySaver` will expose an async throwing boundary. The rendered image is converted to JPEG `Data` before entering the Photos change block, and the change request adds that data as the photo resource while applying the capture date and only valid location metadata. This prevents a non-Sendable `UIImage` from being captured by a Photos `@Sendable` change block while retaining the current local save behavior. Authorization denial and Photos failures remain explicit errors.

### 5. Encode schedule overrides before ordinary exclusions

The 2026 provider keeps already-correct Qingming and Dragon Boat entries, adds the missing January 2–3 holiday and all confirmed 2026 adjusted workdays, and removes April 26 and September 27 from the adjusted set. `shouldCount` first checks an official adjusted workday, then weekend exclusion, then statutory-holiday exclusion. The configured first day remains day 1 before this loop. Attendance becomes a three-case value enum: before on-duty, on duty at/after the start and before the end, and off duty at/after the end; its display names are the required “上班前 / 上班 / 下班”.

### 6. Make the existing project testable without changing product identity

The test target's `TEST_HOST` will reference `$(BUILT_PRODUCTS_DIR)/DayMark.app/.../DayMark` in Debug and Release. A shared `WorkStamp` scheme will build the app and execute both `WorkStampTests` and `WorkStampUITests`; its test action will use the project target identifiers and remain usable by `xcodebuild`. Unit tests will remain focused on value/state seams. UI tests will pass a test-only launch argument that avoids requesting real camera/location permissions and assert the visible camera shell controls/settings flow; a blocked simulator/device remains a blocked test attempt, not a pass.

## Risks / Trade-offs

- [Risk] A two-second fresh-location window can produce a location-unavailable watermark in weak indoor signal conditions. → [Mitigation] Keep the fallback explicit, preserve the live preview's ongoing location updates, and record the bounded policy in tests/docs rather than silently using stale data.
- [Risk] Cancelling a camera continuation does not cancel an already-triggered hardware exposure. → [Mitigation] Invalidate the operation identity and ignore late delegate data before allowing a later capture; the per-operation delegate prevents callback crossover.
- [Risk] Existing MapKit/POI callbacks have several asynchronous branches. → [Mitigation] Thread the same generation and coordinate key through each branch, cancel previous request objects on replacement, and centralize terminal state cleanup.
- [Risk] Photos may reject resource data or restricted authorization on a given OS/device. → [Mitigation] Surface the save error, keep the in-memory capture result local, and test the value conversion separately from device-only Photos acceptance.
- [Risk] CoreSimulatorService or Swift plugin infrastructure may fail independently of source correctness. → [Mitigation] Run generic app build, strict build, unit build/discovery, and UI execution as separate evidence layers and write the exact blocker to `docs/sessions/2026-08-20.md`.

## Migration Plan

1. Update service/value contracts and business rules with focused unit tests.
2. Update `ContentView` lifecycle/capture flow and add observable UI identifiers/test launch handling.
3. Correct `TEST_HOST`, add the shared scheme, and replace template UI tests.
4. Run narrow tests, generic build, strict-concurrency build, and configured scheme test commands; record results and blockers.
5. No data migration or rollback script is required. If device testing exposes a runtime issue, revert the focused service/configuration changes without changing persisted settings keys.

## Open Questions

- Real-device validation of camera exposure, location freshness, reverse-geocoding quality, and Photos metadata remains dependent on an available authorized iPhone.
- Concrete simulator UI execution depends on CoreSimulatorService recovery; source-level UI assertions and test-plan discovery can still be validated separately when launch is blocked.
