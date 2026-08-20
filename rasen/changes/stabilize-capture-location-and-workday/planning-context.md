# Planning Context

## User intent

用户要求：对项目进行 code review，找出潜在问题，给出修复和优化建议；随后明确要求“帮我落地”。本次自动流程应把已确认且可安全实现的高优先级问题落地，并用独立验证与 review 结论收口。

## Project context

- 项目是原生 SwiftUI iOS 应用 DayMark（代码目录仍为 `WorkStamp/`），bundle identifier 为 `com.godmiracle.WorkStamp`。
- 代码与文档已先行阅读：`README.md`、`AGENTS.md`、`docs/context.md`、`docs/architecture.md`、`docs/decisions.md`、`docs/todo.md`、`docs/testing.md`、`docs/privacy.md`、`docs/release.md`、`docs/roadmap.md`、`docs/changelog.md` 以及相关 session 文档。
- 当前主分支无 tracked diff；`.codex/` 与 `rasen/` 是已有的未跟踪工作流目录，必须保留，不要使用 `git add -A`。
- Rasen pipeline 为 `small-feature`：`propose -> apply -> verify -> review-loop -> ship -> archive`。当前执行视图为 Codex native Tier A；propose、apply、ship 有人工 gate，verify/review-loop 无 gate。

## Review findings to carry into planning

### Must address in this change unless implementation evidence shows a safe narrower boundary

1. **Capture single-flight (P1)**：`CameraService` 只有一个 `captureCompletion`，`ContentView.captureAndSave()` 通过异步 Task 调用，快速重复触发可能覆盖 callback 或让 continuation 悬挂。需要服务层保证一次只存在一个 capture，并让重复调用有确定结果；同时保留 UI 层防抖。
2. **Location request freshness and actor boundary (P1/P2)**：`LocationService` 的连续定位、单次刷新、反向地理编码回调缺少 request generation；旧回调可能覆盖新位置/地址，且严格并发构建已经暴露 `CLGeocoder`、回调隔离与 Sendable 警告。需要让结果只在 token/location 仍匹配时提交，并显式处理主 actor/Sendable 边界；不要仅通过关闭警告解决。
3. **Photo metadata freshness (P1)**：`ContentView` 调用 `refreshOneShot()` 后立即读取 `currentSnapshot`，照片可能写入旧快照或 synthetic accuracy/altitude。需要定义捕获时的快照一致性策略：优先等待 bounded fresh result，无法取得时明确不写 stale/synthetic metadata 或按现有产品语义降级，并增加可测试边界。
4. **2026 China holiday schedule (P1)**：`WorkdayCalculator.swift` 当前漏掉 Jan 2/3、Jan 4、Feb 14、May 9、Sep 20，并错误包含 Apr 26、Sep 27。按官方国务院 2026 安排修正，且 adjusted workday 优先级必须正确；补全边界测试。官方参考：[国务院办公厅关于2026年部分节假日安排的通知](https://zwfw.gansu.gov.cn/huixian/zczx/tzgg/art/2025/art_715c16a75e4e4d4c289c295e77772c7274.html)。
5. **Test infrastructure (P1)**：app product name 是 `DayMark`，但 `WorkStampTests` 的 `TEST_HOST` 仍指向 `WorkStamp.app/.../WorkStamp`；共享 scheme/test plan 不含可执行测试目标，当前 concrete-device/only-testing 证据失败。需要修正宿主配置，添加/配置 shared scheme 或 test plan，并让 unit/UI tests 对当前 app 可执行；UI 测试需有真实断言，不接受模板 launch-only 作为通过。
6. **Strict concurrency warnings (P1)**：在 `SWIFT_STRICT_CONCURRENCY=complete` 下，`CameraService`、`LocationService`、`PhotoLibrarySaver` 有跨 actor/non-Sendable 警告。实现应使 callback contract、continuation、AVFoundation/Photos 对象边界显式安全，避免 `@preconcurrency`/warning suppression 作为唯一方案。

### Include if it fits the same safe design without broad refactor

7. **Location lifecycle**：增加 stop/cancel 或 scene phase/background 处理；授权变化时清理 `isRefreshing`，避免永久显示刷新中；从 Settings 返回时刷新授权/状态。
8. **Attendance setting semantics**：`onDutyMinutes` 当前不影响 `AttendanceStatusResolver` 输出。应删除无效设置，或定义并测试 pre-shift/working/off-duty 三态；不要保留表面可配置但无效的行为。

### Defer unless needed by implementation

- Watermark 4K scale/main-actor cost and full-resolution SwiftUI retention：先记录风险，除非修改路径自然触及且有可靠的测试/证据。
- iPad/orientation policy、CLGeocoder -> modern MapKit migration、nearby address cache precision、dead code cleanup：不在本次主线强行重构；若确实需要，记录为 follow-up。

## Constraints and acceptance evidence

- 保持现有 SwiftUI/actor 架构，避免大规模重构与新增重依赖。
- 任何业务行为变化须有单元测试；核心捕获/定位流程至少有可测试的状态/快照边界。真实设备或 concrete simulator tap-through 若环境允许应执行；若 CoreSimulator 仍不稳定，必须明确记录 blocked，不把 build 当作 UI acceptance。
- Build baseline：`/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project WorkStamp.xcodeproj -scheme WorkStamp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/WorkStampReviewDerivedData build` 已成功。
- Strict baseline：同一 build 加 `SWIFT_STRICT_CONCURRENCY=complete` 可通过但有上述 warnings；修复后应重新运行并记录 warning 状态。
- 当前 deployment target/SDK 为 iOS 27；不要为兼容旧 SDK 引入未经验证的 API 分支。
- Docs policy from `AGENTS.md`：完成后同步受影响的 `docs/todo.md`、`docs/decisions.md`，并新增/更新 `docs/sessions/2026-08-20.md`；README 仅在产品范围变化时更新。

## Previous review evidence

- No tracked code changes existed before this change.
- `xcodebuild` generic app build passed.
- Full generic test failed because UI tests require a concrete device.
- `-only-testing:WorkStampTests` failed because the target was not a member of the scheme/test plan.
- No shared `.xcscheme` file was found during review.

## Durable planning guard

先阅读现有 specs（当前 `rasen/specs/` 无现有 spec 文件），再决定 proposal 的 capability 列表。Planner/implementer/reviewer 必须在各自角色内工作，不要生成彼此冲突的全量重构；所有新发现的长期约束追加到本文件，供后续阶段读取。

## Implementation verification constraints (2026-08-20)

- DayMark.app is the built product and executable, while the testable Swift module remains explicitly named WorkStamp; keep those three identities distinct in future project edits.
- Normal generic app/test compilation reaches source completion. The only source warnings observed there are the already-deferred iOS 26 CLGeocoder/reverse-geocoding deprecations.
- The strict-concurrency command is currently blocked by the host Xcode 27 environment: sandbox-exec: sandbox_apply: Operation not permitted causes SwiftUIMacros.StateMacro and PreviewsMacros.SwiftUIView malformed-plugin errors before a strict source result.
- The configured iPhone 17 test attempt built and entered testing, but simulator launch returned POSIX Code=3 (No such process) for com.godmiracle.WorkStamp; XCTest workers never materialized, so no unit/UI runtime pass is claimed.
