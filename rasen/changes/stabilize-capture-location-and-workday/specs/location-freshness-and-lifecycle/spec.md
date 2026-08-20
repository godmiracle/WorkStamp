## ADDED Requirements

### Requirement: Location callbacks are generation- and snapshot-safe
The location service SHALL associate each refresh and reverse-geocoding request with a generation/token and SHALL commit a callback result only when that request is still current and, for geocoding, the result still corresponds to the current coordinate snapshot. Older callbacks MUST NOT overwrite newer location, address, authorization, or refreshing state.

#### Scenario: Older location callback arrives after a newer request
- **WHEN** a new location request starts and a callback from an earlier request arrives afterward
- **THEN** the earlier callback is ignored for state mutation and the newer request remains authoritative

#### Scenario: Reverse-geocode result belongs to an older coordinate
- **WHEN** a reverse-geocode response for coordinate A arrives after the service has accepted coordinate B as the current snapshot
- **THEN** the response for A is ignored and the address for B is not replaced by stale text

### Requirement: One-shot refresh has explicit authorization and cancellation outcomes
The location service SHALL expose a bounded one-shot refresh contract whose success, denial, error, timeout, and cancellation outcomes each settle exactly once. It SHALL clear its refreshing state on every terminal outcome, including authorization denial and errors.

#### Scenario: Location permission is denied during refresh
- **WHEN** a one-shot refresh observes denied or restricted authorization
- **THEN** the refresh completes with an explicit authorization outcome and the UI no longer reports an active refresh

#### Scenario: Refresh is cancelled or fails
- **WHEN** a one-shot refresh is cancelled, times out, or receives a non-transient location error
- **THEN** the caller receives the corresponding failure outcome, the refresh generation is invalidated, and refreshing state is cleared exactly once

### Requirement: Location lifecycle follows scene and page visibility
The location service and its owning pages SHALL start continuous updates only when the relevant page/scene is active, stop or invalidate requests when leaving that lifecycle, and re-evaluate authorization and status when returning from Settings.

#### Scenario: Camera page leaves the active scene
- **WHEN** the camera page or scene becomes inactive while a location or geocoding request is pending
- **THEN** continuous updates stop, pending work cannot publish stale results, and the next active session starts from a valid generation

#### Scenario: User returns from system Settings
- **WHEN** the app becomes active after the user changes location authorization in Settings
- **THEN** the service refreshes authorization-derived UI state, clears any stale refreshing indicator, and allows a new one-shot refresh under the new authorization

### Requirement: Location callback boundaries are explicit and strict-concurrency safe
The location service SHALL isolate mutable service state to its declared actor boundary and SHALL bridge Core Location and geocoder callbacks through explicit sendable-safe value results. The implementation MUST address strict-concurrency diagnostics through safe contracts rather than blanket warning suppression.

#### Scenario: Delegate callback crosses into service state
- **WHEN** a Core Location or geocoder callback is delivered on a callback queue
- **THEN** only immutable value data crosses the boundary and state mutation occurs on the service's isolated actor without a data race
