# Project Context

## Project Name

DayMark（印记相机）

## Current Goal

先做一个可在 iPhone 真机上使用的极简水印相机 MVP，支持拍照并写入以下水印信息：

- 当前时间
- 上班 / 下班状态
- 经纬度
- 地址
- 海拔
- 工作第 N 天

## Background

项目目标是提供一个足够简单、打开就能拍的现场记录工具，不追求复杂模板、美颜、滤镜或社交功能。核心价值是把“拍摄时间 + 位置 + 工作进度”稳定写入照片，便于工程、巡检、到场记录等场景留档。

当前对外品牌名已确定为：

- 中文：印记相机
- 英文：DayMark

工程目录和 bundle 仍保留历史命名 `WorkStamp`，后续是否统一到工程层名称，会在准备正式发布前再评估。

## Current Status

### Finished

- [x] 初始化 iOS SwiftUI 工程
- [x] 明确 MVP 功能范围
- [x] 建立首页 / 设置页基础信息架构
- [x] 接入真机相机预览与拍照
- [x] 接入定位、海拔、地址反查
- [x] 接入水印绘制与保存相册
- [x] 接入工作天数与中国法定节假日排除规则的首版实现（当前内置 2026 年年度表）

### In Progress

- [ ] 补齐发布前文案、截图与隐私说明
- [ ] 继续做真机回归和发布前边界验证

## Important Constraints

- 时间限制：优先快速做出可真机验证的最小可用版本
- 平台限制：仅面向 iPhone 真机，当前阶段不要求 iPad 和模拟器体验完整
- 技术限制：优先使用系统原生框架，不引入重依赖
- 安全/隐私限制：相机会请求相机、定位、相册写入权限；默认仅本地处理图片和定位数据，不上传服务器

## MVP Scope

### Home

- 相机预览
- 拍照按钮
- 水印开关
- 水印样式入口
- 设置入口

### Watermark

- 当前时间
- 上班 / 下班状态
- 经纬度
- 地址
- 海拔
- 工作第 N 天
- 中国法定节假日排除

### Settings

- 重置工作第一天
- 手动设置工作第一天日期
- 是否排除周末
- 是否排除中国节假日
- 上班时间
- 下班时间
- 水印位置
- 水印字号

## Important Files

| Path | Purpose |
|---|---|
| `WorkStamp/` | iOS App 源码（当前仍保留历史目录名） |
| `WorkStampTests/` | 单元测试，优先覆盖工作日计算等纯逻辑 |
| `WorkStampUITests/` | UI 测试，后续可补首页与设置流转 |
| `docs/context.md` | 项目目标、范围、限制 |
| `docs/architecture.md` | 架构、模块和权限边界 |
| `docs/decisions.md` | 关键技术决策 |
| `docs/todo.md` | 近期任务与待确认事项 |

## Device / Environment Notes

| Environment | Notes |
|---|---|
| Xcode / SwiftUI | 当前使用原生 SwiftUI 工程骨架 |
| iPhone 真机 | 主验证环境，必须验证相机、定位、海拔、地址反查、相册保存权限 |
| iOS Simulator | 当前阶段不作为核心验证环境，因为模拟器无法真实覆盖相机和现场定位能力 |
