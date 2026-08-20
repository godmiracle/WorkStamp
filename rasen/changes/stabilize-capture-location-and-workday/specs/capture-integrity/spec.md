## ADDED Requirements

### Requirement: Capture service enforces single-flight delivery
The capture service SHALL permit at most one in-flight photo capture. A second request made while the first request is in flight SHALL return a deterministic busy/rejected result without replacing, attaching to, or leaving the first request's completion unresolved.

#### Scenario: Duplicate capture request is rejected deterministically
- **WHEN** a second capture request arrives before the first request has completed
- **THEN** the second request receives the documented busy result and the first request continues with its original completion boundary

#### Scenario: Capture completion is delivered exactly once
- **WHEN** the camera reports a successful photo, an error, or cancellation for an in-flight request
- **THEN** the request completes exactly once and the service returns to an idle state that can accept a later request

### Requirement: Capture uses a bounded fresh metadata policy
The capture pipeline SHALL establish one capture context containing the photo timestamp and the best location metadata available within a bounded refresh window. It MUST NOT treat a snapshot read immediately after starting an asynchronous refresh as fresh.

#### Scenario: Fresh location arrives within the capture window
- **WHEN** a capture requests a bounded one-shot location refresh and a newer authorized location is delivered before the deadline
- **THEN** the capture context uses that matching location snapshot for all downstream work

#### Scenario: Fresh location is unavailable before the deadline
- **WHEN** the bounded refresh is denied, fails, is cancelled, or produces no matching fresh snapshot before the deadline
- **THEN** the capture follows an explicit safe fallback that does not silently attach an older location or synthetic accuracy/altitude values

### Requirement: Watermark and photo metadata share one capture context
The rendered watermark and the `PHAsset` metadata SHALL be derived from the same immutable capture context. The pipeline MUST NOT independently reread mutable current location state between rendering and saving.

#### Scenario: Location changes during rendering or saving
- **WHEN** a newer location snapshot arrives after the capture context has been created but before the image is saved
- **THEN** the watermark and saved asset metadata remain based on the original capture context rather than being mixed with the newer snapshot

#### Scenario: Location metadata is unavailable
- **WHEN** the capture context contains no valid location metadata
- **THEN** the watermark explicitly represents unavailable location data and the photo save omits unsupported location/altitude metadata instead of writing stale or synthetic values

### Requirement: Capture cancellation releases all in-flight state
The capture pipeline SHALL propagate cancellation or save failure to its caller and clear its single-flight state exactly once, while preserving the existing UI-level protection against accidental repeated taps.

#### Scenario: Caller cancels an in-flight capture
- **WHEN** the caller task is cancelled while capture, rendering, or saving is in progress
- **THEN** the operation returns cancellation, camera/save callbacks are settled at most once, and a subsequent capture can start
