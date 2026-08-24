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
