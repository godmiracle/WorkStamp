# True Device Testing

DayMark（印记相机）当前以 iPhone 真机作为核心验收环境。本文件用于沉淀真机测试范围、步骤和记录模板。

## Test Environment

- Product Name: `DayMark`
- Display Name: `印记相机`
- Bundle Identifier: `com.godmiracle.WorkStamp`
- Current Marketing Version: `1.0`
- Current Build: `2`

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
