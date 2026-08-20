## Why

DayMark 的核心拍照链路存在竞态：快速重复拍摄可能覆盖相机回调，拍照时读取的定位快照可能已经过期，旧的定位或地址回调也可能覆盖较新的结果，导致照片水印与系统照片元数据不一致。与此同时，严格并发检查暴露了相机、定位和相册保存边界的问题，现有测试宿主与 `DayMark` 产品名不一致且没有可执行的共享测试配置；内置 2026 年节假日表也与国务院办公厅正式安排不符。

本 change 将这些已确认、可独立验证的稳定性问题收敛到一次安全的小范围修复，使“拍摄结果可信、工作日计算正确、核心路径可测试”成为可落地的契约。

## What Changes

- 为拍照建立 single-flight 契约：同一时刻只允许一个拍摄操作，重复触发得到确定的忙碌/拒绝结果；成功、失败和取消都必须完成且只完成一次，保留现有 UI 防抖作为体验层保护。
- 统一一次拍摄使用的时间、位置、地址、海拔和精度快照：优先取得有界的新鲜定位结果；无法取得时明确降级，不静默复用旧位置或 synthetic accuracy/altitude。水印内容与 `PHAsset` 元数据必须来自同一份捕获上下文。
- 约束定位与反解析结果的时效和 actor 边界：只有仍匹配当前请求/位置的回调才能提交状态；生命周期停止、授权变化和从设置页返回时能取消或重置刷新状态，避免永久显示“刷新中”。
- 在 `SWIFT_STRICT_CONCURRENCY=complete` 下收口 `CameraService`、`LocationService`、`PhotoLibrarySaver` 的回调、continuation、AVFoundation 和 Photos 边界；不得以单纯的 `@preconcurrency` 或 warning suppression 代替安全契约。
- 按国务院办公厅《[关于 2026 年部分节假日安排的通知](https://big5.www.gov.cn/gate/big5/www.gov.cn/zhengce/content/202511/content_7047090.htm)》修正年度表：补齐元旦、春节、劳动节及国庆调休边界，加入 1 月 4 日、2 月 14 日、5 月 9 日、9 月 20 日等调休工作日，移除错误的 4 月 26 日和 9 月 27 日调休标记，并保证调休工作日优先于周末排除。
- **BREAKING** 将上下班状态定义为“上班前 / 上班 / 下班”三态，使现有“上班时间”和“下班时间”设置都真正影响水印；只调整状态判定与文案，不引入考勤历史、打卡记录或新的业务模型。
- 修正测试宿主与当前 `DayMark` 产物一致，建立包含 unit/UI test targets 的 shared scheme 或 test plan；单元测试覆盖捕获/定位状态边界、2026 年日期和三态考勤，UI 测试必须包含真实断言而非仅启动应用。
- 本 change 不扩展水印 4K/渲染架构、不改变平台权限政策、不迁移现有 MapKit/`CLGeocoder` 地址策略；这些风险较高或与本次稳定性目标无关的事项仅保留为后续议题。

## Capabilities

### New Capabilities

- `capture-integrity`: 保证拍照操作 single-flight、结果只交付一次，并让最终照片的水印与系统元数据使用一致且可解释的捕获快照。
- `location-freshness-and-lifecycle`: 保证定位、地址反查和一次性刷新只提交当前有效结果，并在授权与页面生命周期变化时正确清理状态。
- `workday-and-attendance-rules`: 提供依据官方通知的 2026 年节假日/调休计算，以及有效的“上班前 / 上班 / 下班”时间边界语义。
- `runnable-test-configuration`: 让当前 `DayMark` app 的 unit/UI 测试可由共享 scheme/test plan 执行，并把严格并发和真实 UI 断言纳入核心验证入口。

### Modified Capabilities

<!-- rasen/specs 当前为空，因此本 proposal 不声明已有 capability 的修改；以上全部为新 capability。 -->

## Impact

- 主要代码影响 `CameraService`、`ContentView`、`LocationService`、`PhotoLibrarySaver`、`WorkdayCalculator`、`AppSettings` 和 `SettingsView`；核心结果是重复拍摄不再悬挂、位置与成片元数据不再跨请求串写，工作日与上下班水印可预测。
- 工程配置和验证影响 `WorkStamp.xcodeproj`、`WorkStampTests`、`WorkStampUITests` 及共享 scheme/test plan；测试宿主需使用当前产品名 `DayMark`，并保留 iPhone 真机/可用 concrete simulator 的端到端验证要求。
- 不新增第三方依赖，不改变本地处理和权限边界。实施阶段应同步记录受影响的 `docs/todo.md`、`docs/decisions.md` 与当日 session 文档；若真机或 CoreSimulator 不可用，必须明确记录阻塞，不以 build 成功替代 UI 验收。
