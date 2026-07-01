# Architecture

## Overview

WorkStamp 采用单端本地架构，优先保证真机可拍、可写水印、可保存，不依赖后端服务。

```txt
User
  ↓
iPhone App (SwiftUI)
  ↓
Camera / Location / Photo Library / Geocoder
  ↓
Local Settings + Local Watermark Rendering
```

## Modules

| Module | Responsibility | Notes |
|---|---|---|
| `ContentView` | 首页容器、相机区域入口、设置入口 | 当前阶段先搭界面骨架 |
| `SettingsView` | 工作日规则和水印样式设置 | 使用本地存储持久化 |
| `WorkdayCalculator` | 计算工作第 N 天 | 纯逻辑，优先单测覆盖 |
| `AppSettings` | 设置键、展示枚举、默认值 | 基于 `@AppStorage` |
| `CameraService` / `CameraPreviewView` | 相机预览、拍照输出 | 基于 `AVFoundation` 真机会话 |
| `LocationService` | 经纬度、海拔、地址反查 | 基于 `CoreLocation` + `CLGeocoder` |
| `WatermarkRenderer` | 将文字绘制到拍摄图片 | 使用 UIKit 绘制后再保存 |
| `PhotoLibrarySaver` | 写入系统相册 | 基于 `Photos` add-only 权限 |

## Data Flow

1. 用户打开首页，App 初始化设置并准备相机与定位权限状态。
2. 真机预览启动后，页面实时显示预估水印信息。
3. 用户拍照时，相机会输出原始照片，定位服务提供当前经纬度、海拔和地址快照。
4. 水印渲染模块将文本绘制到图片，再保存到相册。
5. 用户在设置页修改规则后，首页预览立即刷新。

## Local Storage

本地仅存储轻量设置项：

- 工作第一天时间戳
- 是否排除周末
- 是否排除中国节假日
- 水印位置
- 水印字号

当前不保存用户账号、远端配置或历史记录数据库。

## External Dependencies

| Dependency | Usage | Risk |
|---|---|---|
| `SwiftUI` | 页面与状态管理 | 低 |
| `AVFoundation` | 相机预览与拍照 | 真机权限与会话管理复杂度中等 |
| `CoreLocation` | 经纬度、海拔 | 定位精度与授权状态存在波动 |
| `Contacts / CLGeocoder` | 地址反查 | 地址解析速度和完整性不稳定 |
| `Photos` | 保存带水印照片 | 需要相册写入权限 |

## Security & Privacy

- 是否处理用户隐私数据：是，包含地理位置、海拔、拍摄时间
- 是否需要系统权限：需要，相机、定位、相册写入
- 是否需要网络传输：MVP 默认不需要；若系统地址反查发生系统级联网行为，不由 App 自建后端承载
- 是否需要加密/脱敏：当前版本默认不做远程传输，但要明确提示用户照片中会写入敏感位置信息

## True Device Testing Strategy

- 核心能力只在 iPhone 真机验收：
  - 相机预览
  - 拍照成像
  - 定位精度
  - 海拔采集
  - 地址反查
  - 相册保存
- 模拟器只可用于基础 UI 开发，不作为功能完成判定标准。
- 若真机未授权定位或相机，首页应降级显示状态提示，而不是崩溃或阻塞设置页。

## Future Architecture Ideas

- [ ] 将节假日规则抽象为可替换数据源，支持本地静态表或后续远程更新
- [ ] 把水印模板拆成独立样式对象，支持多套布局
- [ ] 增加拍后预览页，允许确认后再保存
