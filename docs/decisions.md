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

## 2026-07-02 - Land China Statutory Holiday Exclusion As A Practical Built-In Rule

### Decision

在 `WorkdayCalculator` 中内置一版可离线运行的中国法定节假日排除规则，用于工作天数计算；当前改为直接写死 `2026` 年度放假与调休表，而不是继续用通用推算规则。

### Reason

用户已经明确把“中国节假日排除”视为当前版本设置页里的真实能力，而不是占位开关；继续保留未实现状态会让设置项名不副实，也会影响发布前收口。

### Alternatives Considered

- 接入远程节假日 API：维护方便，但引入网络依赖，不符合当前离线优先的产品方向。
- 继续只做周末排除：实现简单，但无法满足当前核心需求。
- 用通用农历/公历规则推算：实现轻，但很难覆盖中国每年的具体调休安排。

### Impact

- 设置页里的节假日开关现在具备实际效果。
- `2026` 年工作天数计算会按写死的放假与调休规则执行，更接近正式发布要求。
- 后续年份仍需要继续维护本地年度表。

### Follow-up

- 后续继续补 `2027` 及之后年份的本地年度表。
- 真机与单元测试继续覆盖春节、劳动节、国庆等跨周场景。

---

## 2026-07-02 - Freeze The First App Store Messaging Around “现场拍照留痕”

### Decision

首版 App Store 文案和截图叙事统一围绕“现场拍照留痕”展开，突出时间、地点、海拔、工作天数和一拍即存的产品价值，不在首版文案中过度承诺复杂模板、云同步或 AI 能力。

### Reason

当前产品最成熟、最可验证的能力就是现场拍照留痕；把 App Store 表达收敛到这条主线，能降低审核和用户预期偏差，也方便后续逐步扩展功能。

### Alternatives Considered

- 强调“工程 / 打卡 / 考勤”单一场景：会限制产品的可扩展定位。
- 一次性把所有后续规划都写进文案：容易形成能力承诺过多的问题。

### Impact

- 截图文案、描述、关键词和发布清单有了统一口径。
- 后续新增天气、模板系统或 EXIF 增强时，可以按版本节奏逐步追加，不影响首版定位。

### Follow-up

- 在正式出图时保证截图界面、权限文案和实际能力一致。
- 发布前再核一遍隐私政策、截图文案和设置页措辞。

---

## 2026-07-02 - Migrate Reverse Geocoding To MapKit With Fuzzy Address Fallback

### Decision

将 `LocationService` 的地址反解析从 `CLGeocoder` 迁移到 `MapKit` 的 `MKReverseGeocodingRequest`，并在精确地址拿不到时优先回退到“某区域附近”的模糊地址，而不是只展示经纬度。

### Reason

用户当前最看重的是“有坐标就尽量给出一个地址”，哪怕地址不够精确也比空白更适合现场留档；同时 `CLGeocoder` 在新 SDK 下已出现弃用信号，继续投入价值不高。

### Alternatives Considered

- 继续使用 `CLGeocoder`：改动最小，但长期方向不佳，结果样式也更难贴近 Apple 地图生态。
- 接入第三方地图或公开 API：地址可能更细，但会引入额外依赖、联网与合规成本。
- 完全只保留坐标兜底：实现简单，但不符合当前“照片里尽量要有地点文案”的体验目标。

### Impact

- 地址结果优先来自 `MapKit`，更容易与系统照片、地图生态保持一致。
- 当精确反解析失败时，首页和成片仍会尽量展示区域级模糊地址，降低“只有坐标没有地点”的概率。
- 后续如果继续优化地址质量，应优先在 `MapKit` 结果格式化和本地缓存策略上迭代。

### Follow-up

- 真机继续验证地下室、弱网、室内园区等场景下的模糊地址质量。
- 如果 `2027` 以后要继续打磨“地点可信度”，可再评估是否增加 POI 名称开关或更细的地址展示策略。

---

## 2026-07-03 - Reintroduce CLGeocoder As The Base Address Layer While Keeping MapKit POI Enrichment

### Decision

在 `LocationService` 中恢复 `CLGeocoder` 作为第一层基础地址解析，同时保留 `MapKit` 的反解析和附近 POI 检索作为第二层补强；最终策略改为“先保证有一个可读地址，再争取更像园区/商场/写字楼的地点名”。

### Reason

真机体感表明，纯 `MapKit` 方案在当前中国场景里更容易退化成道路、门牌号或过于泛化的结果；而 `CLGeocoder` 虽然在新 SDK 下有弃用警告，但更容易先返回一个用户能接受的基础地址，更符合水印相机“拍完马上能看地点”的产品预期。

### Alternatives Considered

- 继续只用 `MapKit`：方向更顺着新 SDK，但当前地址体感不够稳定。
- 完全回退到 `CLGeocoder`：基础地址更稳，但会丢掉 `MapKit` 对园区、商场、地铁站等 POI 的补强机会。
- 接入第三方中国地图 SDK：潜在效果更好，但当前会引入成本、合规和依赖复杂度。

### Impact

- 地址链路现在是双轨：`CLGeocoder` 负责保底，`MapKit` 只在更优时覆盖。
- 真机弱信号或 POI 稀疏场景下，更容易看到一个可读地址，而不是直接退到坐标。
- 工程会暂时保留 `CLGeocoder` 的弃用警告，这是当前为体验做的有意识取舍。

### Follow-up

- 真机重点验证园区、商场、写字楼、地铁口四类场景的地址展示是否比纯 `MapKit` 更稳定。
- 如果后续 Apple 地图数据继续不满足中国场景，再评估是否需要可选第三方数据源。

---

## 2026-07-06 - Prefer POI-First Address Presentation For On-Site Watermark Readability

### Decision

将地点展示顺序统一为“产业园 / 商场 / 楼宇名在前，具体地址在后”，并在拼装时自动去掉重复的地点名片段。

### Reason

DayMark 的核心场景是现场留痕，不是导航。用户回看照片时，首先想一眼识别“这是哪个园区 / 商场 / 大厦”，其次才是门牌或道路细节；如果把具体地址放前面，地点名会被淹没，可读性和辨识度都更差。

### Alternatives Considered

- 继续保持详细地址优先：更像地图结果，但不符合水印相机的浏览心智。
- 完全只显示 POI 名称：更简洁，但会丢掉必要的地址细节。
- 增加设置开关：更灵活，但当前 MVP 不值得增加额外复杂度。

### Impact

- `CLGeocoder` 保底地址和 `MapKit` 补强地址都会尽量遵循同一展示顺序。
- 园区、商场、楼宇类地点在预览和成片里会更醒目，更接近同类水印相机常见效果。
- 对于只拿到道路 / 门牌号的场景，仍会保留纯地址兜底，不会伪造地点名。

### Follow-up

- 真机验证重复字段清理后，是否仍存在“地点名被包含在详细地址里导致顺序退化”的边角案例。
- 如果后续要支持不同用户偏好，再评估是否把“POI 优先 / 地址优先”做成设置项。

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

---

## 2026-07-02 - Move Frequent Style Controls To The Top Of The Camera Screen

### Decision

将设置、位置、字号、模板这些低频调节项上移到首页顶部，用轻量胶囊按钮承载；底部只保留缩略图、快门和前后摄切换，以及一行简状态。

### Reason

用户收到的反馈是底部按钮过于拥挤，这些项放在底部会破坏相机主操作区的聚焦感。

### Alternatives Considered

- 保持当前底部信息 chip 布局：实现简单，但仍偏工具页。
- 把这些入口全部藏进设置页：页面更干净，但常用调节成本变高。

### Impact

- 首页更接近系统相机的结构分层。
- 位置、字号的快速调节仍然保留，但不会挤压快门区。
- 顶部主卡片不再重复承载设置入口，改为反馈更即时的定位质量状态。

### Follow-up

- 真机验证顶部横向胶囊在小屏设备上的可点击性。

---

## 2026-07-02 - Treat Temporary Location Unknown As Non-Blocking

### Decision

将 `kCLErrorDomain error 0` 这类 `locationUnknown` 临时定位错误视为非阻塞状态，不再弹窗；只有权限、网络或其他明确异常时才提示用户。

### Reason

用户反馈拍照时会看到“定位失败”弹窗，但这类错误通常只是系统在瞬时还没拿到可用坐标，不代表定位功能真的失效。

### Alternatives Considered

- 保持所有定位错误都弹窗：实现简单，但会频繁打断拍照体验。
- 完全隐藏所有定位失败：体验更顺，但会掩盖真正需要处理的权限或网络问题。

### Impact

- 拍照过程中遇到短暂定位抖动时，界面更稳定，不会误报失败。
- 真正需要用户处理的异常仍然会保留提示。

### Follow-up

- 真机验证电梯、地下室、室内弱信号场景下是否仍有误报。

---

## 2026-07-02 - Reshape Home Screen Into Scheme A Camera Layout

### Decision

首页改成更接近系统相机的方案 A：顶部只保留黑色轻工具条，中间尽量让预览铺满，底部采用“相册缩略图 / 快门 / 翻转”的主操作行，并额外提供“地点 / 水印 / 模板”的功能胶囊行；水印低频设置收进底部抽屉。

### Reason

用户明确反馈当前界面整体仍然不合适，希望参考成熟水印相机和系统相机的骨架，而不是继续维持工具页式的信息排布。

### Alternatives Considered

- 延续顶部卡片 + 底部控制块：改动较小，但整体观感仍然偏工具页。
- 把所有水印设置都继续摆在首页：信息更直接，但会持续挤压拍照主交互区。

### Impact

- 首页视觉重心会明显回到预览和快门。
- 水印设置入口仍然保留，但被下沉到不会抢主操作注意力的位置。
- 顶部闪光灯、倒计时先做入口占位，后续再接真实能力。

### Follow-up

- 真机验证底部两层操作在小屏设备上的安全区和误触情况。

---

## 2026-07-02 - Keep Only Location Status On The Preview Layer

### Decision

首页预览层只保留一个轻量的定位状态胶囊，不再常驻展示“相机就绪”；相机未准备好时仅在状态胶囊中短暂体现“准备中”。

### Reason

用户认同顶部应只放操作，不应继续堆叠状态信息；而“相机就绪”在正常场景下属于默认预期，长期占位价值不高。

### Alternatives Considered

- 同时保留“相机就绪”和“定位稳定”：信息更全，但仍然偏工具页。
- 完全不显示状态：界面最干净，但用户无法快速判断定位质量。

### Impact

- 顶部与预览层都会更干净，视觉重心进一步回到相机画面。
- 定位质量仍然可见，且更像拍摄辅助信息而不是系统提示条。

### Follow-up

- 真机验证这个轻状态胶囊在强光、浅色背景下是否足够可读。

---

## 2026-07-02 - Make Flash, Timer, And Location Entry Real Features

### Decision

将顶部闪光灯和倒计时入口接入真实拍照链路；将左下角“地点”从简单提示改为定位信息面板，支持查看地址、经纬度、海拔、精度并手动刷新。

### Reason

用户明确指出“地点”点击没有意义，同时希望闪光灯和倒计时不再只是占位，而是成为可直接使用的拍照能力。

### Alternatives Considered

- 继续保留入口占位：实现最省事，但用户会明显感知为半成品。
- 把地点点击改成普通 toast：反馈更快，但信息承载不足，无法承担拍前确认位置的用途。

### Impact

- 首页工具条和底部功能入口都变成了真正可用的拍摄能力。
- 拍照前可直接确认定位质量，不必再拍完后去系统相册详情页反查。

### Follow-up

- 真机验证前后摄切换后闪光灯按钮的禁用态是否符合预期。

---

## 2026-07-02 - Adopt DayMark Branding And Dedicated Appearance Icons

### Decision

应用对外中文名采用“印记相机”，内部产品名采用 `DayMark`；同时为 iOS 图标补齐独立的亮色、深色和着色模式资源，而不是只复用同一张图。

### Reason

用户已经确认新的品牌命名，并且希望在系统的外观切换和图标着色模式下都保持更完整的视觉表现，而不是只有单一图标。

### Alternatives Considered

- 保持当前 `WorkStamp` 命名：实现最省事，但不符合新的品牌方向。
- 三种模式共用同一张图标：接入快，但在暗黑和着色模式下层次会明显偏弱。

### Impact

- Xcode 构建产物名称会从 `WorkStamp.app` 变为 `DayMark.app`，但 bundle identifier 仍保持不变，真机安装链路不受影响。
- 主屏显示名称会更新为“印记相机”。
- 图标资源维护会多一个小脚本，但后续替换品牌主视觉时会更容易批量生成变体。

### Follow-up

- 真机检查深色桌面、着色模式桌面下的新图标层次是否仍需继续微调。

---

## 2026-07-02 - Make The Workday Template Copy User-Editable Before Building Full Templates

### Decision

在完整多模板系统落地前，先把工作日水印里的 `Bench` 场景词抽成用户可编辑设置，并在设置页和首页底部“模板”入口都提供快速修改能力。

### Reason

用户明确指出“坐班Bench”不应写死，因为实际使用时可能会换成别的场景词。这个诉求比完整的模板切换系统更高频、更直接影响可用性。

### Alternatives Considered

- 继续保留写死 `Bench`：实现最简单，但用户每换一个场景都得改代码。
- 一次性上完整多模板系统：扩展性更强，但当前投入偏大，不符合先打通高频能力的节奏。

### Impact

- 首页预览水印和最终照片水印会同步使用用户自定义的场景词。
- 底部“模板”入口从占位按钮升级成真正可用的快捷配置入口。
- 后续扩展多套模板时，这个可编辑字段可以继续保留为模板实例化参数。

### Follow-up

- 评估是否要把“坐班”前缀也放开成完全可编辑。

---

## 2026-07-02 - Use Monochrome SF Symbols In Preview Watermark And Rename The Last Label To Remark

### Decision

预览水印改成更接近参考图的单色样式：每一行左侧使用白色 SF Symbols，文字保持黑白高级感；最后一行左侧标签不再显示模板词，而是固定显示“备注”。

### Reason

用户希望预览层更像成熟水印相机的展示方式，不要继续强调彩色或过多装饰，同时明确要求把预览中的 `Bench` 标签改成“备注”，但保留原有内容文案。

### Alternatives Considered

- 保持当前纯文字左右分栏：实现简单，但与参考图的识别感仍有差距。
- 预览和成片同时整体重做成图标版：一致性更强，但这轮需求只明确点了预览层，先小步落地更稳。

### Impact

- 预览层的信息识别会更直观，地点、经纬度、海拔等字段一眼就能区分。
- 工作天数内容本身不变，只是左侧标签从模板词切成“备注”。
- 最终照片水印渲染逻辑本轮不变，避免影响现有成片效果。

### Follow-up

- 真机观察预览层图标版是否要进一步同步到最终照片水印。

---

## 2026-07-02 - Force App Icon Cache Refresh With A New Asset Name And Build Number

### Decision

为排查 iOS 主屏未切换 dark icon 的问题，新增一套 `AppIconV2` 图标资源集，并将 `CURRENT_PROJECT_VERSION` 从 `1` 提升到 `2`，强制让系统把这次安装视为新的图标资源组合。

### Reason

已经确认暗黑图标资源声明正确、编译产物 `Assets.car` 里也确实包含 `UIAppearanceDark`，但用户在删除重装且切到深色图标模式后仍未看到生效，因此需要优先排除 SpringBoard / LaunchServices 的图标缓存影响。

### Alternatives Considered

- 继续沿用 `AppIcon` 原资源名反复重装：成本低，但命中系统缓存时很难确认是否真正刷新。
- 直接怀疑 iOS 系统 bug 不再处理：判断太早，缺少一次更强刷新手段。

### Impact

- 工程的主图标资源名会从 `AppIcon` 切到 `AppIconV2`。
- 真机安装包的 build version 会提升到 `2`。
- 若这次仍不生效，基本可以更有把握地归因到当前 iOS 版本的系统行为，而不是工程配置错误。

### Follow-up

- 真机再次检查深色主屏图标是否终于切到 `AppIcon-Dark.png`。

---

## 2026-07-02 - Deepen The Dark Icon Border For Clearer Recognition

### Decision

继续沿用 `AppIconV2` 方案，但将 dark 变体的生成参数进一步压暗，让外轮廓、相机轮廓和底部玻璃条边框更接近黑灰，而不是保留偏白的高光边线。

### Reason

用户已经确认 dark icon 切换功能本身生效，但视觉差异仍不够明显，主要问题就是边框太亮，导致主屏上一眼看不出这是深色版。

### Alternatives Considered

- 只保留镜头发黑：差异有限，主轮廓仍然偏亮。
- 手工单独修一张 dark 图：短期可行，但后续换主视觉时不方便复用。

### Impact

- 深色图标在主屏上会更像独立的一套图，而不是亮色版的轻微变暗。
- 生成脚本后续仍可复用到新的主图标输入上。

### Follow-up

- 真机验证这次 dark icon 是否已经达到“一眼可辨”的程度。

补充：由于用户明确指出上一版仍不够明显，本轮不再仅做压暗，而是切到真正的黑色底座方案，让外围直接成为纯黑系圆角底，优先满足主屏快速识别，而不是保留更多玻璃白边质感。

---

## 2026-07-02 - Restore Full Layout For Dark And Tinted Icons

### Decision

根据用户最新提供的参考图，`Dark` 和 `Tinted` 图标不再沿用“只保留相机主体”的裁切方案，而是回到和亮色图标一致的完整构图：保留整套相机、底部定位/日期玻璃条和整体层次，只替换底座与整体色调。

### Reason

用户给出的目标图已经明确说明，深色和着色模式都应该保持完整图标语言，只是分别切换成黑色底座和统一蓝色着色。此前的“只留相机主体”虽然提升了黑底占比，但已经偏离目标样式。

### Alternatives Considered

- 继续使用主体裁切版 dark icon：黑底更明显，但与参考图和用户预期不一致。
- 只恢复 dark，保留 tinted 的简化版：会让三套图标的家族感断裂。

### Impact

- 三套图标重新回到统一构图，主屏上的品牌识别会更稳定。
- 深色和着色模式仍然保留足够明显的模式差异，只是差异来源改为整体底座与色调，而不是裁切布局。

### Follow-up

- 真机同时检查浅色、深色、着色三种桌面模式下的实际观感，确认 tinted 中部是否还需要进一步压蓝。

---

## 2026-07-02 - Use A User-Provided Dark Icon Master

### Decision

`AppIconV2` 的 dark 变体改为直接使用用户提供的成品图，不再通过脚本从亮色图自动派生。

### Reason

用户已经明确给出满意的暗色效果图，直接接入可以避免继续围绕边框、裁切和整体明度反复微调，也能保证真机效果与目标图一致。

### Alternatives Considered

- 继续用脚本生成 dark icon：维护成本更低，但很难稳定复刻这张成品图的细节。
- 只把参考图当方向继续手调脚本：迭代会更慢，而且仍有偏差风险。

### Impact

- `Dark` 图标后续更新将以这张成品图为基准。
- 脚本仍可继续服务 `Tinted` 或未来的自动派生需求，但当前 dark 不再依赖它。

### Follow-up

- 真机确认系统主屏深色模式已实际读取到这张新 dark 图。

---

## 2026-07-02 - Formalize Documentation Structure For Long-Term Maintenance

### Decision

不对源码目录做大搬家，先以“小步升级”的方式把项目文档体系正式化：补齐 `docs/README.md`、`roadmap.md`、`release.md`、`appstore.md`、`privacy.md`、`ui-guideline.md`，并增加文档资源目录说明。

### Reason

项目已经从单纯打通 MVP，进入持续打磨产品体验和发布准备的阶段。此时最缺的不是更多结构重构，而是产品路线、UI 规范、隐私边界和发布信息的稳定落点。

### Alternatives Considered

- 立即重命名工程、目录和 bundle：长期更整齐，但当前风险高，容易打断真机迭代节奏。
- 继续只维护 `context / architecture / todo`：短期可行，但后续发布、设计和隐私信息会越来越散。

### Impact

- 文档导航和协作成本会明显下降。
- 后续可以围绕正式产品视角推进，而不只是把它当 Demo。
- 当前仍保留 `WorkStamp` 作为源码目录和工程名，避免本轮引入额外配置风险。

### Follow-up

- 后续评估是否在发布前统一工程层命名。
- 将真机测试记录和 App Store 文案持续沉淀到新文档中。

---

## 2026-07-02 - Refine Settings Before Adding More Features

### Decision

在继续扩展定位策略或节假日数据源之前，先把设置页打磨成更正式、可理解的产品界面：统一工作天数相关文案、补实时预览、增加重置确认、改用四宫格位置选择，并在正式版隐藏 debug 提示。

### Reason

用户已经确认现有功能基本可用，当前最直接影响产品质感的是设置页命名和交互仍偏开发态。先把高频设置入口做顺，可以提升后续继续加功能时的整体承接能力。

### Alternatives Considered

- 先做定位等待策略：价值高，但用户当前更明确希望先整理设置体验。
- 先接中国节假日数据源：对工作天数产品化重要，但不如当前设置体验调整直观。

### Impact

- 设置页更接近正式产品，而不是调试面板。
- 快捷水印面板和模板面板的命名也会更统一。
- Release 下不会再显示真机测试提示卡，避免正式版暴露 debug 气质。

### Follow-up

- 真机确认四宫格位置选择和实时预览是否符合预期。
- 后续可继续把模板能力从“名称修改”扩展到真正的多模板系统。

---

## 2026-07-02 - Open Up The Entire Workday Prefix Instead Of Only "Bench"

### Decision

工作天数文案不再只开放 `Bench` 这一段，而是将“第 X 天”前面的整段前缀都作为可编辑内容；`第 X 天` 继续由系统自动生成。

### Reason

用户实际想改的通常不是单个词，而是整条描述方式，例如“坐班 Bench”“巡检”“项目驻场”“实习”等。只开放 `Bench` 会让模板看起来像半成品。

### Alternatives Considered

- 继续只改 `Bench`：实现简单，但表达能力明显不足。
- 直接做完全自由模板字符串：灵活性最高，但对当前设置页来说会把复杂度一下拉高。

### Impact

- 设置页和快捷模板面板会更贴近真实需求。
- 旧配置会通过一次迁移自动补成之前的完整显示样式，避免用户升级后文案突然变化。

### Follow-up

- 真机确认旧数据迁移后的展示是否符合预期。
- 后续若继续扩展，可再升级成占位符模板系统，例如 `{prefix}第{day}天`。

---

## 2026-08-20 - Stabilize Capture Context, Location Freshness, And Workday Semantics

### Decision

本次稳定性修复采用明确的值类型边界和主 actor 状态管理：相机服务在服务层实现单飞与操作 ID，晚到的 AVCapture 回调被忽略；拍照先并行请求一个最长 2 秒的 fresh location，再创建不可变 CaptureContext，水印和照片元数据只从同一上下文读取。定位服务用连续请求 generation、反解析 request ID 和坐标匹配保护快照，所有一次刷新终态（成功、拒绝、错误、超时、取消、不可用）都清理 isRefreshing。无 fresh location 时使用空快照，照片不写入旧位置或合成的海拔/精度/时间。

2026 年工作日表按已确认的官方安排修正：元旦 1 月 1-3 日、春节 2 月 15-23 日、劳动节 5 月 1-5 日、中秋节 9 月 25-27 日、国庆节 10 月 1-7 日及现有清明/端午日期；调休上班日为 1 月 4 日、2 月 14/28 日、5 月 9 日、9 月 20 日、10 月 10 日。调休日期先于周末和节假日排除判断。上下班状态改为“上班前 / 上班 / 下班”三态，设置页说明同步更新。

### Reason

这些边界解决的是结果一致性而非 UI 防抖：重复拍照不能覆盖 continuation，旧地址不能覆盖新坐标，保存的地理元数据不能与预览水印来自不同快照，且原有下班前统一显示“上班”的文案无法表达上班前状态。

### Test infrastructure

应用产物保持 DayMark.app/DayMark，显式保留测试模块名 WorkStamp；Debug/Release 测试宿主均指向 DayMark，新增共享 WorkStamp scheme 并包含单元/UI 目标。Swift Testing 覆盖相机单飞门闩、定位 generation、无效/有效照片位置元数据、2026 年边界和三态上下班时间；UI 测试改为断言拍照和设置控件。

### Verification boundary

普通 generic app build 与 build-for-testing 已完成，未观察到 CameraService、LocationService 或 PhotoLibrarySaver 的并发警告；仍保留用户明确要求暂缓的 iOS 26 CLGeocoder 弃用提示。SWIFT_STRICT_CONCURRENCY=complete 两次尝试均在 SwiftUI 宏插件沙箱失败，无法声称严格构建通过。配置的 iPhone 17 测试在 app 启动时返回 No such process，故没有模拟器通过结论。随后在已配对的 iPhone Air 真机上完成 Debug 构建、安装、启动，`WorkStampTests` 16/16 和 `WorkStampUITests` 1/1 通过；现有 UI 测试只覆盖拍照页控件与设置入口，不替代真实相机拍照、定位刷新和 Photos 写入全链路验收。

### Follow-up fix

真机反馈显示预览有定位，但成片的经纬度、地址和海拔同时变成不可用。原因是拍照时的一次性定位在超时/忙碌/失败后，旧逻辑无条件使用空快照，覆盖了预览中仍有效的缓存定位。修复后在拍照开始时冻结缓存快照：一次性定位失败时，仅当缓存坐标仍在 45 秒内时复用，过期快照才继续降级为空；不为缺失海拔、精度或时间合成伪值。

修复后的 iPhoneOS Debug build 通过，模拟器 `WorkStampTests` 18/18 通过；真机重装和实拍复验待 CoreDevice 恢复 trusted connectivity 后完成。

### Address resolution follow-up

后续真机成片显示经纬度和海拔正常，但地址仍退化为“当前位置附近（经纬度）”。复核确认不是地址格式化本身，而是拍照上下文早于异步逆地理编码完成；因此新增拍照专用定位刷新，在地址解析完成前最多等待 4 秒，并在同一位置复用近期已解析地址。修复版已重新安装到 iPhone Air，用户实拍确认具体地址显示正常。
## 2026-08-24 - Expose App Version In Settings

### Decision

在设置页增加“关于版本”卡片，显示 `CFBundleShortVersionString`、`CFBundleVersion` 以及 Debug / Release 构建渠道；本次功能构建号从 `2` 提升为 `3`。

### Reason

后续需要通过手机上的安装包判断是否已经包含最新代码。版本号和构建号由 Bundle 统一提供，避免在设置页重复维护一套易过期的文本。

### Alternatives Considered

- 只显示应用版本号：无法区分同一 `1.0` 版本下的不同安装包。
- 在页面中硬编码代码提交哈希：容易与实际构建内容不一致，且需要额外的构建注入流程。

### Impact

- 设置页可以直接看到 `1.0 (3)` 和构建渠道。
- 后续代码更新需要同步递增 `CURRENT_PROJECT_VERSION`，再通过设置页核对安装包。

### Follow-up

- iPhone Air 真机 Debug 包 `1.0 (3)` 已完成构建、安装和启动，用户确认设置页版本号显示正常；Release 渠道仍按发布构建时复核。
