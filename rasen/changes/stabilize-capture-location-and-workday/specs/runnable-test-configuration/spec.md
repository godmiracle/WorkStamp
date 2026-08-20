## ADDED Requirements

### Requirement: Test host and shared test configuration target the DayMark product
The `WorkStampTests` host configuration SHALL reference the current `DayMark.app` product and executable, and a shared scheme or test plan SHALL include the app's unit-test and UI-test targets with valid build-for-testing/test execution settings.

#### Scenario: Unit test host resolves to the app product
- **WHEN** `xcodebuild` resolves the `WorkStampTests` target for a unit-test action
- **THEN** the test host points to the built `DayMark.app` executable rather than the historical `WorkStamp.app` product

#### Scenario: Shared test configuration includes both test targets
- **WHEN** the configured scheme or test plan is used for a test action
- **THEN** both `WorkStampTests` and `WorkStampUITests` are discoverable as executable test targets

### Requirement: Core stability behavior has focused automated coverage
The unit-test target SHALL cover capture single-flight and exactly-once terminal outcomes, location freshness/cancellation boundaries, 2026 holiday and adjusted-workday boundaries, and all three attendance states. Tests MUST exercise deterministic value/state seams rather than relying only on a successful app build.

#### Scenario: Focused unit tests run through xcodebuild
- **WHEN** the configured unit-test command runs on an available simulator destination
- **THEN** the test runner discovers and executes the focused unit tests without a target-membership or test-host configuration failure

#### Scenario: Boundary tests protect business rules
- **WHEN** the unit suite evaluates official holiday dates, adjusted weekends, attendance thresholds, and unavailable/cancelled capture metadata
- **THEN** the expected boundary behavior is asserted and a regression changes the test result rather than remaining invisible

### Requirement: UI tests assert an observable current-app behavior
The UI test target SHALL replace template-only launch/performance coverage with at least one meaningful assertion that fits the existing permission-gated camera/settings UI, while treating unavailable simulator/device permissions as an explicit environment blocker rather than a pass.

#### Scenario: UI launch exposes the current product shell
- **WHEN** the UI test launches the app with the test's permission/environment setup
- **THEN** it asserts an observable current-app element such as the camera shell, capture control, or settings entry instead of only asserting that launch returned

#### Scenario: UI environment cannot provide the required destination
- **WHEN** no concrete simulator/device or permission-capable UI destination is available
- **THEN** the test attempt is recorded as blocked with the exact environment error and is not reported as UI acceptance

### Requirement: Strict concurrency warnings are resolved by safe contracts
The `CameraService`, `LocationService`, and `PhotoLibrarySaver` SHALL build under `SWIFT_STRICT_CONCURRENCY=complete` without relying on blanket `@preconcurrency` imports or warning suppression for their callback, continuation, AVFoundation, or Photos boundaries.

#### Scenario: Strict-concurrency build is executed
- **WHEN** the generic app build is run with `SWIFT_STRICT_CONCURRENCY=complete`
- **THEN** service-level concurrency diagnostics are absent or each remaining warning is explicitly classified as an unrelated external SDK/environment limitation in the session evidence
