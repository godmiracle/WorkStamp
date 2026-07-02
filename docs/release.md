# Release Checklist

用于 TestFlight 或 App Store 发布前的统一检查。

## Version Record

| Version | Build | Date | Status | Notes |
|---|---|---|---|---|
| 1.0 | 2 | TBD | Draft | 当前开发中版本，对应印记相机 / DayMark 第一阶段真机版本 |

## Pre-Release Checklist

### Product

- [ ] 核心拍照链路真机可用
- [ ] 水印内容与最终照片一致
- [ ] 工作第 N 天计算规则已确认
- [ ] 中国法定节假日排除规则已确认
- [ ] 关键文案已校对
- [ ] 自定义模板文案流程已验证

### Device Verification

- [ ] 后置拍照验证
- [ ] 前置拍照验证
- [ ] 最近照片缩略图入口验证
- [ ] 定位授权允许场景验证
- [ ] 定位拒绝场景验证
- [ ] 相册写入授权验证
- [ ] 深色模式图标验证
- [ ] 图标着色模式验证
- [ ] 小屏 iPhone 安全区验证

### Privacy & Compliance

- [ ] 相机权限说明已检查
- [ ] 定位权限说明已检查
- [ ] 相册权限说明已检查
- [ ] `privacy.md` 已同步更新
- [ ] 不存在未说明的数据上传行为
- [ ] 照片元数据中的位置行为已向用户边界说明

### App Store Prep

- [ ] App 名称确认
- [ ] 副标题确认
- [ ] 关键词确认
- [ ] 描述确认
- [ ] 更新日志确认
- [ ] 首版 5 张截图准备完成
- [ ] 截图文案与实际界面一致

### Build & Release

- [ ] Version 更新
- [ ] Build 更新
- [ ] Release Notes 准备完成
- [ ] Archive 成功
- [ ] TestFlight / App Store Connect 上传成功

## Current Project Snapshot

- Marketing Version: `1.0`
- Build: `2`
- Display Name: `印记相机`
- Product Name: `DayMark`
- Bundle Identifier: `com.godmiracle.WorkStamp`

## Release Notes Template

```md
版本：
构建号：
发布日期：

本次更新：
- ...

已知问题：
- ...
```
