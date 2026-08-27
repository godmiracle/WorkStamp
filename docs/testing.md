# True Device Testing

DayMark（印记相机）当前以 iPhone 真机作为核心验收环境。本文件用于沉淀真机测试范围、步骤和记录模板。

## Test Environment

- Product Name: `DayMark`
- Display Name: `印记相机`
- Bundle Identifier: `com.godmiracle.WorkStamp`
- Current Marketing Version: `1.0`
- Current Build: `3`

## Core Verification Areas

### Camera

- [ ] 首页可正常拉起相机预览
- [ ] 后置拍照成功
- [ ] 前置拍照成功
- [ ] 前后摄切换后界面状态正常
- [ ] 倒计时拍照行为正常
- [ ] 闪光灯 `off / auto / on` 行为符合预期

### Watermark

- [ ] 预览水印与成片信息一致
- [ ] 成片中的时间正确
- [ ] 成片中的上班 / 下班状态正确
- [ ] 成片中的工作第 N 天正确
- [ ] 自定义模板文案 / 备注正确显示
- [ ] 浅色背景下白字可读
- [ ] 深色背景下白字可读

### Location

- [ ] 可获取经纬度
- [ ] 可获取海拔
- [ ] 地址反查结果可接受
- [ ] 照片 App 中能显示位置标题
- [ ] 照片 App 下拉详情中能显示地图

### Permissions

- [ ] 首次相机权限弹窗文案正确
- [ ] 首次定位权限弹窗文案正确
- [ ] 首次相册写入权限弹窗文案正确
- [ ] 拒绝权限后的降级状态可理解

### UI

- [ ] 顶部工具条在小屏设备不拥挤
- [ ] 底部主操作在单手拍摄时可接受
- [ ] 地点面板信息布局清晰
- [ ] 深色模式下整体对比度足够
- [ ] App Icon 在浅色 / 深色 / 着色模式下均正确

## Current Permission Copy

- Camera: `拍照用于生成带水印的现场记录照片`
- Location: `定位用于写入经纬度、地址和海拔水印`
- Photo Library Add: `保存带水印照片到系统相册`

## Suggested Test Matrix

### Basic

- 晴天室外
- 室内弱光
- 浅色墙面
- 深色背景

### Location

- 室外开阔地
- 室内办公区
- 弱信号区域

### Device State

- 首次安装
- 权限全允许
- 定位拒绝
- 相册拒绝
- 深色模式
- 图标着色模式

## Session Record Template

```md
## Device Test

日期：
设备：
iOS：
版本：
构建号：

### Passed

- ...

### Failed

- ...

### Notes

- ...
```

## 2026-08-20 Device Test Record

- 设备：已配对真机“哥谭之王”（iPhone Air）
- Bundle ID：`com.godmiracle.WorkStamp`
- Debug 构建：通过
- 安装与启动：通过
- `WorkStampTests`：16/16 通过
- `WorkStampUITests`：1/1 通过，验证拍照页拍照/设置控件存在并可进入设置页
- 尚未覆盖：真实相机取景与拍照、定位刷新、照片库写入和照片详情页元数据展示

## 2026-08-20 Location Fallback Regression

- 现象：预览水印有定位信息，成片的经纬度、地址和海拔全部显示不可用。
- 根因：拍照时一次性定位失败后，旧逻辑无条件使用空 `LocationSnapshot`，覆盖预览中的有效缓存。
- 修复：冻结拍照开始时的缓存快照；一次性定位失败时复用 45 秒内的缓存坐标，过期才降级为空。
- 回归测试：`WorkStampTests` 18/18（模拟器）通过，iPhoneOS Debug build 通过。
- 后续修复：拍照定位成功后等待逆地理编码完成，并在同一位置保留近期已解析地址，避免成片在地址回调到达前写入坐标兜底。
- 真机复验：修复包已重新安装并启动；用户确认实拍成片地址显示正常。

## 2026-08-20 Address Resolution Capture Fix

- 现象：经纬度和海拔已正常，但成片地址显示为 `当前位置附近（经纬度）`，没有具体地点或道路。
- 根因：一次性定位在拿到坐标后立即返回，逆地理编码仍在异步执行，拍照上下文读取到了“有坐标、无地址”的中间快照。
- 修复：新增拍照专用定位刷新，在地址解析链路完成前最多等待 4 秒；同一位置已有新鲜地址时保留该地址。
- 验证：iPhoneOS Debug 构建、真机安装与启动通过；用户确认真机实拍地址显示正常。
- 备注：模拟器本轮测试受到 CoreSimulator/SwiftUI 宏服务故障影响，未作为真机验收替代。

## 2026-08-24 Coordinate And Address Quality Gate

### Code-level regression coverage

- `poorFreshAccuracyDoesNotReplaceRecentCaptureSnapshot`：新坐标水平精度超过 120 米时，不覆盖 45 秒内的有效拍照缓存。
- `olderOrLessAccurateCandidateDoesNotReplaceStableLocation`：较旧或明显更差的候选坐标不能替换稳定坐标。
- `trustedPOIRequiresDistanceConsistentWithAccuracy`：POI 距离必须与定位精度一致，超过 100 米的区域缓存不能复用。
- `successfulFreshLocationKeepsRecentCachedAddress`：新坐标沿用近期地址时，明确记录为“近期缓存”并保存距离。

### Manual device matrix

在同一固定地点记录地点面板中的四项：经纬度、精度、地址来源、地点距离。每种环境至少连续刷新 3 次，再拍 1 张照片：

- 室外开阔地：确认精度通常低于 120 米，地址来源优先为系统地址或地图地址。
- 园区 / 商场 / 写字楼：确认附近地点的距离不超过定位精度，不把远处 POI 当作当前地点。
- 室内办公区：确认精度较差时不会写入远处具体 POI；存在新鲜缓存时显示“近期缓存”。
- 弱信号 / 地下室：确认没有新鲜有效坐标时，照片降级为无位置，而不是写入未经确认的具体地址。
- 同一地点移动 100 米以上后：确认旧区域地址不再被复用。

## 2026-08-25 原始回调序列与地图候选诊断

### 新增字段

- 首条原始样本：本次 `LocationService` 运行收到的第一条 `CLLocation` 回调坐标和时间。
- 原始样本统计：累计样本数与首条到最新样本的直线位移。
- 系统地址结果：`CLGeocoder` 返回的基础地址，不与坐标混写。
- 地图候选结果 / 附近 POI 候选：MapKit 选中的地点名、候选坐标、候选距离和精确/区域层级。

### 真机样本

终止旧进程后通过 `devicectl` 冷启动诊断包，在地点面板读取到：

- 首条原始样本：`31.323805, 121.481397`，时间 `2026-08-25 11:01:54`。
- 原始样本统计：`2` 条，首末位移约 `0m`。
- 最新原始坐标：`31.323805, 121.481397`；水平约 `±7m`，垂直约 `±30m`。
- 系统源标记：系统定位，软件模拟“否”，外接设备“否”。
- 页面坐标与原始坐标一致，页面地址仍为逸景佳苑。
- 最终命令行真机测试：`31/31` 通过，0 失败、0 跳过；结果包为 `/tmp/WorkStampRawTraceDeviceTests2/Logs/Test/Test-WorkStamp-2026.08.25_11-08-54-+0800.xcresult`。
- 地址链路摘要：系统地址已返回逸景佳苑；等待约 35 秒仍显示“MapKit 候选等待中”，未观察到 MapKit/附近 POI 覆盖地址。

### 结论边界

该样本可以确认应用内没有先收到科技园坐标再由地址解析改写成逸景佳苑；当前偏移发生在 Core Location 已输出的融合落点，或真实地点与该系统落点的对照判断上。`sourceInformation` 不能继续拆出 GNSS/Wi-Fi/蜂窝/室内的具体来源，因此下一轮应在同一点用系统照片或地图独立坐标做对照，并记录首条样本时间、精度和候选距离。

### Verification boundary

本轮已在已解锁的真机“哥谭之王”（iPhone Air，iOS 27.0）上用当前工作区代码完成 Debug 构建、部署并执行测试：`xcodebuild test` 成功，测试报告为 23/23 通过、0 失败、0 跳过。UI 测试实际启动了 `DayMark`，并验证拍照页控件和设置页入口。

`devicectl` 单独查询安装列表时受到本机 CoreSimulatorService 超时影响，但这不影响本次 `xcodebuild test` 已完成的设备部署与测试结果。真实相机取景、定位刷新、逆地理编码、拍照保存和 Photos 位置元数据仍需按上面的手工矩阵验证。

## 2026-08-24 Photo-Like POI Selection

### Code-level regression coverage

- `regionalPOIRequiresStrongVenueName`：区域级回退只接受强 POI 名称，并受距离上限约束。
- `strongPOINameSurvivesAddressDeduplication`：地址字段包含地点名时，科技园等强 POI 名称不会被去重逻辑吞掉。
- `strongRegionalPOIBeatsACloserGenericCandidate`：更近但语义弱的候选不能压过区域范围内的强地点名称。
- `selectedMapKitPOIIsPreferredOverCoreGeocoderFallback`：已选中的 MapKit POI 优先于系统地址回退。

### True-device verification

- 设备：哥谭之王（iPhone Air），UDID `00008150-001A4D5E1428401C`，iOS 27.0。
- 命令：`xcodebuild test -destination id=00008150-001A4D5E1428401C`。
- 最终结果包：`/tmp/WorkStampPhotosPOIFinal/Logs/Test/Test-WorkStamp-2026.08.24_10-52-55-+0800.xcresult`。
- 结果：`27/27` 通过，`0` 失败，`0` 跳过，测试状态 `succeeded`；覆盖率约 `64.88%`。
- Xcode 仍输出 DeviceSupport 符号缓存告警，但未阻止本次构建、部署和测试。

### Manual comparison still required

在同一固定位置先用系统照片拍照，再用 WorkStamp 拍照，对比两边详情页的地点标题和地图落点：

- 园区 / 商场 / 写字楼：确认地点名优先，并观察地点距离是否仍在定位精度允许范围内。
- 普通道路：确认没有强 POI 时仍显示可读道路地址，不误显示远处地标。
- 室内 / 弱信号：确认区域地点不会越过精度门槛，失去有效坐标时仍然安全降级。
- 拍照成片：确认水印地址与地点面板使用同一 POI 结果，Photos 资产的地图定位仍由坐标决定。

## 2026-08-24 Named Area POI Gate Regression

### Reproduction

- 新增测试 `namedCoreGeocoderAreaStillSearchesNearbyPOI`，输入系统地址 `逸景佳苑·高境镇` 且没有已选 MapKit POI。
- 修复前在 iPhone Air 真机测试中红灯，失败点与用户反馈一致：命名区域地址会跳过附近 POI 搜索。

### Fix verification

- 修复后通过 `xcodebuild test` 部署并测试真机。
- 结果包：`/tmp/WorkStampAddressGateGreen/Logs/Test/Test-WorkStamp-2026.08.24_11-03-33-+0800.xcresult`。
- 结果：`28/28` 通过，`0` 失败，`0` 跳过；覆盖率约 `65.05%`。

### Required user retest

在上海北大科技园重新打开地点面板并手动刷新，记录：

1. 经纬度；
2. 水平精度；
3. 地址来源；
4. 地点距离。

如果地址改为科技园，说明是地址搜索门控问题；如果仍是逸景佳苑，则用这四项数据判断坐标是否真的落在逸景佳苑附近。

## 2026-08-24 Raw Location Source Diagnosis

### Automated coverage

- `rawLocationSourceFlagsRemainVisibleWithoutCoordinateCorrection`：源标记只作为诊断信息，不改变坐标。
- `locationDiagnosticsKeepsRawAndAcceptedLocationsSeparate`：最新原始回调、参与决策回调和当前已采纳快照保持独立。
- `build-for-testing`：iPhoneOS arm64 构建和测试模块编译通过。
- 真机 `-only-testing:WorkStampTests`：`30/30` 通过，0 失败，0 跳过；结果包为 `/tmp/WorkStampRawSourceUnitFinal/Logs/Test/Test-WorkStamp-2026.08.24_14-59-54-+0800.xcresult`。

### True-device procedure

地点面板打开后会默认展开“原始定位诊断”，并提供大尺寸、可滚动的面板；连续点击“重新定位”至少 3 次，每次记录：

1. 最新原始坐标、原始回调时间和水平精度；
2. 系统源标记（是否软件模拟、是否外接定位设备）；
3. 快照处理结果（已采纳本次回调 / 保留当前快照）；
4. 当前原始快照坐标，以及“回调与快照距离”；
5. 地址来源和地点距离。

### 2026-08-24 真机样本

- 原始坐标：`31.323808, 121.481395`；原始回调时间：`2026-08-24 15:47:37`。
- 原始精度：水平约 `±7m`，垂直约 `±35m`；源标记为系统定位，软件模拟和外接设备均为“否”。
- 地点仍展示为逸景佳苑，且原始坐标与页面坐标一致；本次面板显示“保留当前快照”。因此本样本应归入原始 Core Location 落点问题，不能继续通过地址解析修正坐标。

### Interpretation

- 原始回调坐标已经在逸景佳苑附近：问题属于 Core Location 原始定位、设备环境或系统地图落点，不再从地址解析层修正。
- 原始回调坐标在上海北大科技园，但地址仍显示逸景佳苑：问题属于地址/POI 解析链，坐标本身不应被改写。
- 原始回调已经变化，但处理结果显示“保留当前快照”：问题属于候选晋级、时间新鲜度或缓存策略。
- 源标记为“软件模拟定位”或“外接定位设备”：先排除测试注入或外接设备影响。
- “系统定位（非模拟/非外接）”不等于某一种具体 GPS、Wi-Fi 或蜂窝来源；系统公开 API 没有提供更细粒度的来源诊断。

完整真机测试已完成编译、部署并运行 `31` 个测试，其中单元测试 `30/30` 通过；唯一失败是既有 UI 测试等待“设置”导航栏，且使用此前未包含本轮诊断代码的 `/tmp/WorkStampRelocationGreen` 构建产物单独重跑也复现同一失败。因此该失败目前归类为 UI 自动化 / CoreDevice 环境问题，不归因于原始定位诊断；Xcode 同时报告 `devicectl diagnose` 失败和 DeviceSupport 符号缓存告警。完整结果包为 `/tmp/WorkStampRawSourceDiagnosticsFinal/Logs/Test/Test-WorkStamp-2026.08.24_14-58-00-+0800.xcresult`。

## 2026-08-24 Coordinate Relocation Regression

### Reproduction

- 新增测试 `freshSignificantMoveCanReplaceAnOlderHighAccuracyFix`：旧定位精度 9 米，新定位移动约数百米但精度 80 米。
- 修复前真机红灯，旧晋级策略拒绝该新位置。

### Fix verification

- 新增 150 米最小明显移动距离，并要求移动距离超过新旧水平精度之和。
- 地点面板新增“定位时间”，帮助识别旧快照未更新。
- 修复后真机结果包：`/tmp/WorkStampRelocationGreen/Logs/Test/Test-WorkStamp-2026.08.24_11-40-50-+0800.xcresult`。
- 结果：`29/29` 通过，`0` 失败，`0` 跳过；覆盖率约 `65.22%`。

### Screenshot evidence

- 截图坐标：`31.323809, 121.481399`。
- 截图精度：约 `±9m`。
- 截图地址来源：`系统地址`。
- 公开地图条目中的逸景佳苑坐标约为 `31.323220, 121.482398`，两者约相差 115 米。
- 上海北大科技园公开资料地址为宝山区高逸路 88 号；园区实际坐标仍需在真机地图上核对。

## 2026-08-27 One-Shot Location Refresh Regression

### Change

- 一次性定位刷新按回调收到时的坐标质量和样本年龄判断是否可完成，不再要求 `CLLocation.timestamp` 晚于 `requestLocation()` 的调用时间。
- 候选被当前快照策略保留时，刷新仍返回当前有效快照，不再错误返回“当前位置暂时不可用”。

### Verification

- iPhone Air 真机 `-only-testing:WorkStampTests`：`33/33` 通过，0 失败、0 跳过。
- 修复后的 `DayMark.app` 已成功安装到设备。
- `devicectl` 命令行启动重试两次均被本机 CoreDevice/CoreSimulatorService 初始化超时阻断；不影响编译、测试和安装结果，但不作为冷启动验收结论。
- 仍需在上海北大科技园现场连续点击“重新定位”，记录地点面板的原始坐标、精度、时间、地址来源和 POI 距离。

### Follow-up gate fix

- MapKit 返回住宅小区等弱语义地点时继续执行附近 POI 搜索；科技园、园区、商场、写字楼等强语义地点才终止该搜索链。
- 回归测试 `weakSelectedAreaStillSearchesNearbyPOI` 在修复前验证为红灯，修复后与全量 `WorkStampTests` 一起在 iPhone Air 真机 `34/34` 通过。
- 修复包已重新安装；北大科技园现场仍需手动确认附近搜索是否实际返回目标 POI。

### MapKit pending fallback

- 当 `MKReverseGeocodingRequest` 超过 2 秒没有回调时，`LocationService` 会转入附近 POI 搜索，不再让地址链停留在第一层 `CLGeocoder` 的住宅小区名称。
- MapKit 后续回调仍会经过请求 ID、生命周期和坐标匹配；失效回调不能覆盖当前结果。
- iPhone Air 真机 `-only-testing:WorkStampTests`：`34/34` 通过，0 失败、0 跳过；修复包已安装。
- `devicectl` 命令行启动仍受本机 CoreDevice/CoreSimulatorService 初始化超时影响，因此现场冷启动和地图服务返回仍需手动复测。

## 2026-08-27 Apple Maps 对照与地址链强制刷新

### Change

- 用户确认同一现场的系统 Apple 地图显示“北大科技园”。
- 手动刷新即使保留当前坐标快照，也会强制重新发起地址解析，避免已有“逸景佳苑”地址让 MapKit/附近 POI 永远不再运行。
- 前台恢复和显式刷新会重新启动定位更新；显式刷新允许较新且有效、但精度较低的移动样本替换旧快照。

### Verification

- iPhone Air 真机 `-only-testing:WorkStampTests`：`35/35` 通过，0 失败、0 跳过。
- 结果包：`/tmp/WorkStampAddressRefreshGreen2.xcresult`。
- 最新 `DayMark.app` 已完成签名构建，路径为 `/tmp/WorkStampAddressRefreshGreen2/Build/Products/Debug-iphoneos/DayMark.app`。
- 安装重试因设备在 `devicectl` 连接阶段立即断开而失败；因此尚无本轮构建的安装/冷启动验收结论。

### Required user retest

在北大科技园安装上述最新构建后，强制退出并重新打开 App，进入“地点”并点击“重新定位”。重点记录：原始坐标、原始精度、MapKit 反查状态、附近 POI 状态、候选名称和候选距离。Apple 地图显示的地点名只能作为地址解析对照，不能用来改写照片经纬度。

## 2026-08-27 POI 区域距离回归修复

### Change

- 将强语义 POI 的区域候选距离上限从按精度动态收缩改为本次附近搜索的最大半径 `1500m`。
- 该调整针对 7 月包可命中、当前版本可能被距离门槛丢弃的 Apple Maps 园区/楼宇候选；不改变 Core Location 原始坐标。

### Verification

- 修复前 `400m` 强地点候选测试失败，修复后通过。
- iPhone Air 真机 `WorkStampTests`：`35/35` 通过，0 失败、0 跳过。
- 新构建已通过 `devicectl` 安装到 `com.godmiracle.WorkStamp`，数据库序号 `3920`。

### Required user retest

请强制退出并重新打开 App，再进入地点面板。若仍显示逸景佳苑，请提供最新“解析原始返回”三块内容，尤其是 MapKit 和附近 POI 的候选列表；这能直接判断是 Apple Maps 未返回候选，还是候选仍被后续逻辑丢弃。

## 2026-08-27 Nearby POI Failure Fallback

### Real-device log reproduction

- 未读取屏幕，仅使用 `devicectl` 启动 `com.godmiracle.WorkStamp` 并读取进程控制台日志。
- 原始回调坐标：`31.32380684,121.48139404`；水平精度约 `8–9m`；源标记为非模拟、非外接。
- `CLGeocoder` 返回逸景佳苑；`MKReverseGeocodingRequest` 返回逸景佳苑 23 号楼，距离约 `7.4m`，但没有 POI 分类。
- 附近 POI 请求半径 `600m` 仍失败，日志为 `MKErrorDomain error 5`。
- 名称检索 `query=科技园` 返回“上海北大科技园”，距离约 `489.09m`；选择层级为 `regional`。
- 最终地址日志为“上海北大科技园·中国上海市宝山区高逸路88号(殷高西路地铁站2号出口步行370米)”，不再拼接逸景佳苑。

### Verification

- 真机 `xcodebuild test`：`37` 个单元测试和 `1` 个 UI 测试全部通过。
- 最终签名构建：`/tmp/WorkStampNamedPOIFallbackFinal/Build/Products/Debug-iphoneos/DayMark.app`。
- 真机安装成功，`devicectl` 数据库序号：`3980`。

### Regression boundary

该兜底只在附近 POI 请求失败或为空且没有已选 POI 时执行一次；仍受强地点名称和 `1500m` 区域距离上限约束。名称与地址只影响展示，不改变照片写入的原始坐标。

## 2026-08-27 Raw CLLocation Reverse-Geocoding Regression

### Reproduction

在同一台 iPhone、同一条回调坐标上，分别把 Core Location 原始对象和当前代码由标量字段重建的对象交给 `CLGeocoder`：

- 原始对象：`31.323806863701463,121.48139405933466`，水平精度约 `18m`，返回“上海北大科技园·上海市宝山区高逸路98号”。
- 重建对象：经纬度、水平精度和时间相同，返回“逸景佳苑·上海市宝山区逸仙路1588弄”。

### Fix

- 状态机仍使用 `LocationValue` 保存 Sendable 标量状态，但同时保存当前最佳回调对应的原始 `CLLocation`。
- `CLGeocoder` 与 `MKReverseGeocodingRequest` 使用原始对象；地址结果不反向修改照片经纬度。
- 删除“科技园”自然语言检索兜底；附近 POI 只执行以当前坐标为中心的空间检索，区域地点仍受距离门槛约束。

### Verification Boundary

- 修复代码 iOS Debug 构建通过。
- 模拟器 `WorkStampTests` 命令退出码为 `0`。
- 真机随后恢复连接并完成修复包安装、冷启动和最终地点日志验收；详见下方记录。

## Final Raw CLLocation Fix Verification

### Physical-device log

- 修复构建已安装到 `com.godmiracle.WorkStamp`，`devicectl` 数据库序号为 `4028`。
- 未读取屏幕，仅读取进程日志。原始回调坐标为 `31.32381537030281,121.4813974768411`，水平精度约 `8.87m`，系统源标记为非模拟、非外接。
- `CLGeocoder` 日志为 `base=上海北大科技园·上海市宝山区高逸路98号`，最终 `address applied` 来源为 `coreGeocoder`，地址保持为上海北大科技园。
- MapKit 返回的候选为非 POI 门牌，距离约 `468.87m`，未被选用；附近 POI 空间请求半径 `180m` 返回 `MKErrorDomain error 5`，没有覆盖 Core Location 反解析结果。

### Acceptance

真机冷启动日志确认：原始 Core Location 回调、坐标状态、`CLGeocoder` 反解析和最终地址应用已闭环，当前结果为北大科技园。该结果来自原始 `CLLocation` 的坐标反解析，不是地点名称特判。

## 2026-08-27 Location Diagnostic UI Removal

### Verification

- 地点面板已移除“原始定位诊断”和“解析原始返回”测试展示；“重新定位”及正常地址、坐标、精度信息保留。
- 清理后的 iOS Debug 真机构建：`BUILD SUCCEEDED`。
- 真机安装成功，`devicectl` 数据库序号为 `4036`；应用启动成功并输出定位日志。
- 真机日志仍返回 `上海北大科技园·上海市宝山区高逸路98号`，来源为 `coreGeocoder`。
- 启动命令因控制台持续等待应用退出而达到 30 秒超时；这不是应用启动失败，启动期间已取得完整定位日志。

## 2026-08-27 Location Panel Default Medium

- 修改地点 sheet 的 presentation selection，打开时默认使用 `.medium`，并在每次打开前重置为 `.medium`。
- 保留 `.medium` 折叠、滚动和“重新定位”按钮；未修改定位服务、坐标或反解析链路。
- iOS Debug 真机构建：`BUILD SUCCEEDED`。
- 最新构建已安装到真机，`devicectl` 数据库序号为 `4044`。

## 2026-08-27 Version 1.0.1 Build 4 Verification

- 工程构建配置：`MARKETING_VERSION=1.0.1`、`CURRENT_PROJECT_VERSION=4`。
- 生成包 `/tmp/WorkStampVersion101Build/Build/Products/Debug-iphoneos/DayMark.app` 的 `Info.plist` 已核对为 `CFBundleShortVersionString=1.0.1`、`CFBundleVersion=4`。
