# DayMark / 印记相机

一个面向 iPhone 真机使用的极简水印相机项目，主打“打开就拍、现场留档、信息可信”。

## 产品目标

- 拍照时将时间、上班/下班状态、经纬度、地点、海拔、工作第 N 天写入照片
- 保持操作足够轻，不做复杂滤镜、美颜或社交能力
- 优先围绕真实现场记录、工程到场、巡检打卡等场景优化

## 当前状态

- 已打通真机相机预览、拍照、水印绘制、相册保存
- 已接入定位、海拔、地址反查和照片元数据写入
- 已完成第一轮首页与设置页相机化视觉调整
- 已接入亮色 / 暗色 / 着色模式应用图标

## 项目结构

```txt
.
├── AGENTS.md
├── README.md
├── WorkStamp/
├── WorkStampTests/
├── WorkStampUITests/
├── docs/
│   ├── README.md
│   ├── architecture.md
│   ├── appstore.md
│   ├── changelog.md
│   ├── context.md
│   ├── decisions.md
│   ├── privacy.md
│   ├── prompts.md
│   ├── release.md
│   ├── roadmap.md
│   ├── todo.md
│   ├── ui-guideline.md
│   ├── assets/
│   ├── design/
│   ├── screenshots/
│   └── sessions/
└── scripts/
```

## 核心文档

- [文档导航](docs/README.md)
- [项目背景](docs/context.md)
- [架构设计](docs/architecture.md)
- [技术决策](docs/decisions.md)
- [开发任务](docs/todo.md)
- [产品路线图](docs/roadmap.md)
- [UI 设计规范](docs/ui-guideline.md)
- [隐私说明](docs/privacy.md)
- [发布检查](docs/release.md)
- [App Store 文案](docs/appstore.md)

## 开发原则

- 先真机可用，再追求功能堆叠
- 优先使用系统原生框架，不引入重依赖
- 除代码外，同步维护路线图、决策、待办和会话日志
- 拍照、定位和水印链路默认只在本地完成，不上传服务器

## 建议开发流程

1. 阅读 `README.md`、`AGENTS.md` 与 `docs/README.md`
2. 确认 `docs/todo.md` 和当日 `docs/sessions/YYYY-MM-DD.md`
3. 开发和真机验证
4. 更新 `docs/changelog.md`
5. 记录必要决策到 `docs/decisions.md`

## 当前命名说明

- 产品名：`DayMark`
- 中文名：`印记相机`
- 工程源码目录与 bundle 仍保留历史命名 `WorkStamp`

当前先统一产品层命名；若后续准备正式发布，可再评估是否一次性统一工程名、仓库名和 bundle 相关标识。
