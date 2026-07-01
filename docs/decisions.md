# Decision Log

记录重要技术决策，避免以后忘记“为什么这么做”。

## Template

```md
## YYYY-MM-DD - Decision Title

### Decision

做了什么决定？

### Reason

为什么这么决定？

### Alternatives Considered

- 方案 A：
- 方案 B：

### Impact

影响范围是什么？

### Follow-up

后续需要注意什么？
```

---

## 2026-06-26 - Initialize AI Native Project Template

### Decision

采用 `README.md + AGENTS.md + docs/` 的结构管理项目上下文、AI 指令、技术决策和待办事项。

### Reason

多设备开发和 AI 辅助开发容易丢失上下文，需要把关键沟通和决策沉淀到仓库中。

### Alternatives Considered

- 只依赖 Codex 聊天记录：跨设备和长期维护不稳定。
- 只写 README：无法保留细节决策和开发会话。

### Impact

后续所有项目都可以从该模板初始化。

### Follow-up

实际项目创建后，需要及时填写 `docs/context.md` 和 `docs/architecture.md`。

---

## 2026-07-01 - Define WorkStamp MVP Around True Device Capture

### Decision

将 WorkStamp 定义为一个原生 iPhone 水印相机 MVP，第一阶段只做拍照现场记录所需的最小功能：时间、经纬度、地址、海拔、工作第 N 天，以及基础水印位置/字号设置。

### Reason

目标是尽快形成可真机验证的可用版本，避免在模板、滤镜、账户、云同步等非核心功能上分散精力。

### Alternatives Considered

- 先做复杂模板系统：会拖慢首个可用版本落地。
- 先做多端或后端同步：当前没有明确需求，增加不必要复杂度。

### Impact

- 首页、设置页、工作日计算和权限处理将围绕“真机拍照场景”设计。
- 后续模块优先级明确为相机、定位、水印渲染，而不是运营类能力。

### Follow-up

- 接入 `AVFoundation` 真机预览与拍照。
- 接入定位、地址反查、海拔。
- 完成照片水印渲染和相册保存。

---

## 2026-07-01 - Treat The First Capture Day As Work Day 1

### Decision

工作第 N 天的计算规则采用“工作第一天固定为第 1 天，之后再按设置决定是否跳过周末和中国节假日”。

### Reason

用户明确提出“拍照的第一天是工作第一天”，这意味着首日不应因为它恰好落在周末或节假日而被算作无效起点。

### Alternatives Considered

- 严格按工作日规则连首日一起过滤：会让“第一天拍照就是第一天”的认知落空。
- 完全按自然日递增：无法满足排除周末和节假日的需求。

### Impact

- `WorkdayCalculator` 需要把起始日固定计为第 1 天。
- 文案和设置说明需要避免让用户误以为起始日也会被过滤。

### Follow-up

- 为该规则补单元测试。
- 后续在设置页增加说明文字。

---

## 2026-07-01 - Prioritize True Device Testing Over Simulator Validation

### Decision

当前阶段以 iPhone 真机作为主验证环境，不把模拟器作为相机、定位和水印拍照能力的验收标准。

### Reason

相机预览、拍照、真实定位、海拔和相册写入都与真机权限和硬件状态强相关，模拟器无法完整覆盖。

### Alternatives Considered

- 主要依赖模拟器开发：开发快，但会掩盖真实权限和硬件行为问题。
- 同时铺开真机和模拟器等价支持：对 MVP 来说投入过高。

### Impact

- 需要尽早补齐权限文案和真机测试清单。
- UI 骨架可以在模拟器预览，但功能交付以真机联调为准。

### Follow-up

- 补充真机测试步骤文档。
- 真机接入后记录设备行为差异。

---

## 2026-07-01 - Keep Capture Pipeline Fully Local On Device

### Decision

相机拍照、水印渲染、定位取值和相册保存全部在本地完成，不引入后端或上传链路。

### Reason

这是最快打通 MVP 的方式，也更符合现场记录工具对隐私和可离线使用的预期。

### Alternatives Considered

- 拍照后上传服务器处理水印：实现更重，也会引入隐私和网络依赖。
- 第三方相机 SDK：当前需求简单，没有必要增加依赖和维护成本。

### Impact

- 需要在端内处理相机权限、定位权限和相册写入权限。
- 真机上即可完成端到端验证，不依赖后端环境。

### Follow-up

- 真机验证不同权限拒绝场景的降级表现。

---

## 2026-07-01 - Persist Capture Metadata Into Photos Assets

### Decision

保存带水印照片时，除了写入最终图片像素，还同步把拍摄时间和定位坐标写入 `PHAsset` 的系统元数据。

### Reason

用户希望在 iPhone 照片 App 中看到系统位置标题，并在下拉详情里显示地图；仅保存 `UIImage` 像素无法触发这套系统位置展示。

### Alternatives Considered

- 只把地址作为水印文字写进图片：用户肉眼可见，但系统照片详情页无法识别成位置。
- 后续再补 EXIF 二次写入：复杂度更高，对当前 MVP 不必要。

### Impact

- 相册中的 WorkStamp 照片会更接近系统相机照片的浏览体验。
- 若拍照瞬间还没有定位坐标，照片仍能保存，但系统位置标题与地图可能不会出现。

### Follow-up

- 真机验证照片详情页的位置标题、地图和时间是否正常展示。

---

## 2026-07-01 - Move The MVP UI To A Camera-First Layout

### Decision

首页从滚动卡片式工具页调整为沉浸式相机主界面，保留拍照、设置和水印预览为核心操作；设置页改为统一的液态玻璃卡片布局。

### Reason

现有功能已经打通，但旧界面更像调试页，不像可长期使用的水印相机产品；用户也明确反馈“看起来有点简陋”。

### Alternatives Considered

- 继续沿用 `ScrollView + Form`：改动小，但产品感不足。
- 一次性重做复杂模板系统：投入过大，不符合当前 MVP 节奏。

### Impact

- 首页会更强调预览、拍照和现场使用效率。
- 设置页和首页视觉语言统一，更适合后续继续迭代水印模板。

### Follow-up

- 真机验证底部控制区在不同尺寸 iPhone 上的可触达性。

---

## 2026-07-01 - Separate Preview Watermark From Final Photo Watermark

### Decision

预览界面保留轻量逐行透明遮罩辅助阅读，但最终保存到照片的水印去掉背景遮罩，只保留白字和阴影直接压在画面上。

### Reason

用户希望预览时信息更紧凑，同时成片要更接近现场水印相机常见的“文字直接订在照片上”的效果。

### Alternatives Considered

- 预览和成片完全共用同一种遮罩样式：实现简单，但成片会显得太重。
- 预览和成片都完全无遮罩：在实时预览里可读性会下降。

### Impact

- 首页预览和最终照片会采用不同的视觉策略，但信息内容保持一致。
- 后续若继续迭代样式，需要同时关注预览可读性和成片观感。

### Follow-up

- 真机拍一张样片，验证无底遮罩白字在浅色背景上的可读性。

---

## 2026-07-01 - Align Preview Watermark With Final Photo Output

### Decision

将首页预览水印也调整为和最终成片一致的白字直出效果，不再保留预览专用的透明底遮罩。

### Reason

用户明确希望拍照预览和最终成像尽量一致，这样才能做到更接近“所见即所得”。

### Alternatives Considered

- 继续保留预览透明底遮罩：可读性高，但与成片视觉不一致。
- 只在部分行保留遮罩：视觉会变得不统一。

### Impact

- 预览与成片样式统一，用户更容易判断最终照片效果。
- 在复杂背景上，预览可读性将更依赖文字阴影强度。

### Follow-up

- 真机验证高亮背景下预览白字是否仍足够清楚。

---

## 2026-07-01 - Add In-App Recent Capture Preview

### Decision

首页底部增加类似系统相机的“最近一张照片”缩略图入口，拍照保存成功后直接在应用内提供大图预览。

### Reason

用户不希望每次拍完还要切到系统相册确认效果，希望在 WorkStamp 内完成快速回看。

### Alternatives Considered

- 仅保存到系统相册，不做应用内回看：实现简单，但使用链路断开。
- 每次拍完自动强制进入预览：会打断连续拍摄节奏。

### Impact

- 拍照后的确认路径更接近系统相机体验。
- 当前缩略图只覆盖本次 App 会话中的最近一张照片，后续可再考虑冷启动恢复。

### Follow-up

- 真机验证连续拍摄时缩略图刷新是否稳定。

---

## 2026-07-01 - Move Bottom Controls Closer To Native Camera Patterns

### Decision

底部控制区调整为更接近系统相机的三段式结构：左侧最近照片，中间快门，右侧前后摄切换；将原先偏设置说明式的控件改为更紧凑的状态胶囊。

### Reason

用户希望底部交互更像相机而不是工具页，同时明确提出需要前后置切换。

### Alternatives Considered

- 继续保留说明文字和开关行：信息完整，但相机感不强。
- 把所有状态都塞进顶部：会削弱底部主交互的直觉性。

### Impact

- 首页更接近系统相机的操作心智。
- 需要保证前后摄切换不会影响现有拍照和保存链路。

### Follow-up

- 真机验证前后摄切换后拍照、缩略图和水印是否都正常。

---

## 2026-07-01 - Use Cached Non-Blocking Location Quality Tiers

### Decision

定位链路改为持续缓存最近的优质坐标，不阻塞拍照；地址只在定位精度达标时反查，并在 UI 上显示“定位稳定 / 一般 / 定位中”。

### Reason

用户明确表示拍照前硬等 1 到 2 秒体验太差，同时反馈当前地址结果不够准，需要在不阻塞快门的前提下提高定位可用性。

### Alternatives Considered

- 拍照前强制等待稳定定位：定位可能更准，但拍照体验明显变差。
- 继续拿到最新点就直接用：实现简单，但室内或弱信号场景下地址容易飘。

### Impact

- 拍照仍然是即时的，但会更倾向使用缓存中的优质点。
- 地址反查会更保守，避免拿低质量坐标频繁更新错误地址。

### Follow-up

- 真机验证办公楼、园区、室内等场景下地址是否明显稳定。
