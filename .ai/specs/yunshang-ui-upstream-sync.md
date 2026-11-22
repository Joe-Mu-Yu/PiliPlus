# 云上视觉、非影视播放器与 PiliPlus 2.2.1 功能同步

## Why

当前分支已经完成全局 MIUIX 组件基线，但页面层级、视频卡、视频详情与播放器控制层仍以零散 Material 布局为主；同时当前分支相对 `bggRGjQaUbCoE/PiliPlus` 的共同基线缺少 46 个上游提交。目标不是复制 HarmonyOS 代码或整仓覆盖定制分支，而是在保留现有 MIUIX、原生悬浮底栏、AVBox 影视、Pure Live、录制、CloudBase 与发布链的前提下，同步上游用户功能，并把高频界面和非影视播放器统一为 `yunshang-bili` 所体现的沉浸式圆角/胶囊语言。

## What

- 语义同步 `refs/remotes/bgg-upstream/main` 的 46 个提交（共同基线 `737163c53d1e00794388723c39327dc7fac1dbf8`，目标 `217fb54f51f6764176319bbdedab2a7522d75401`），逐项记录已具备、手工移植或有依据地跳过。
- 新增低开销的沉浸页面表面、可按压圆角媒体卡、分段胶囊与播放器 HUD 表面，优先接入首页、推荐视频卡、视频详情和 `PLVideoPlayer`。
- 非影视播放器只改控制层、提示、菜单、进度和显隐动画；不换解码内核，不改变点击、双击、长按、拖动、弹幕、倍速、清晰度、字幕、投屏或横竖屏语义。
- “影视除外”明确排除 `lib/pages/movies/`、`android/.../AvboxBridge.kt` 和 `third_party/avbox/`。B 站 UGC/PGC、直播与 Pure Live 仍使用同一套 `PLVideoPlayer`，因此共享其控制层视觉；不会修改 AVBox Media3 播放器。
- 所有新增动画尊重 `MediaQuery.disableAnimations`，常态控制在 120–300ms；不新增实时背景模糊、常驻 Shader、逐帧截图或全屏高成本透明合成。

## Context

**Relevant files:**

- `lib/utils/theme_utils.dart`, `lib/common/style.dart` — 已完成的 MIUIX 主题、色彩、字重与尺寸真源。
- `lib/pages/home/view.dart`, `lib/common/widgets/video_card/` — 首页与视频卡入口。
- `lib/pages/video/view.dart`, `lib/pages/video/introduction/` — 竖屏/横屏视频详情、简介与评论布局。
- `lib/plugin/pl_player/view/view.dart`, `lib/plugin/pl_player/widgets/` — PiliPlus、直播与 Pure Live 共用播放器控制层。
- `lib/pages/movies/`, `android/app/src/main/kotlin/com/example/piliplus/AvboxBridge.kt`, `third_party/avbox/` — 明确排除的影视播放路径。
- `lib/pages/reply/`, `lib/pages/download/`, `lib/pages/live_room/`, `lib/pages/audio/`, `lib/pages/setting/` — 上游功能同步的高冲突区域。
- `/tmp/hyper-yunshang-ref.WQVsIj/` — `chunwcc/yunshang-bili` 的只读设计参考，基准提交 `33487c13e7b04f5610cea0156bcc43795059ef95`。

**Patterns to follow:**

- 颜色只使用场景对应的 `ColorScheme`，默认字重继续由用户设置（默认 350）决定。
- 共享转场继续使用 `video_card_transition.dart`，预测返回、快速返回和取消手势合同不变。
- 弹层继续通过现有原生底栏遮挡管理；播放器继续由 `PlPlayerController` 管理生命周期与手势。
- 生成的 gRPC 文件只从可追溯上游提交同步；不得手改生成内容来掩盖协议差异。
- 上游依赖提交先按功能必要性拆解；固定 Flutter 3.47.4 / Dart 3.13.3，不采用上游 Flutter 3.47.9 SDK 更新。

## Constraints

**Must:**

- 保留当前工作区全部 MIUIX 改动和新增测试，保留 `.workbuddy/` 原样。
- 对每个上游提交给出源提交、采纳方式和验证证据；冲突按语义处理，不整文件选择上游版本。
- 首页和卡片在浅色、深色、纯黑、窄屏、大字体下仍可读，触控目标至少 40dp。
- 播放器控制层在 240–1024dp 宽度和 1.0/1.8 文本缩放下无溢出；横屏安全区与弹层遮挡不回归。
- 修复行为缺陷时添加针对性测试；最终运行改动文件 analyze、全量 Flutter/Python 测试、`git diff --check` 和签名 Release APK 构建/验签。

**Must not:**

- 不覆盖 AVBox 影视播放器，不把 AVBox URL/解码恢复链迁入 `PLVideoPlayer`。
- 不升级项目固定 Flutter SDK，不通过全量 `pub upgrade`、删锁文件或取消严格依赖检查绕过问题。
- 不照搬 HarmonyOS 系统材质 API、许可不清楚的组件源码、参考项目素材或大面积 `backdropBlur`。
- 不删除本分支的 MIUIX、影视、Pure Live、录制、CloudBase、原生选择工具栏或发布功能。
- 不提交、不推送、不打标签、不发布、不安装设备；这些动作不在本轮授权内。

**Out of scope:**

- AVBox 的 UI、Media3 内核与内容源。
- 后端/API 行为重设计、账号数据迁移、播放器解码器替换。
- 为视觉近似引入新的图片素材、字体或重量级动画依赖。

## 设计映射矩阵

| 参考元素 | 参考证据 | 当前落点 | 低开销实现 | 验证 |
| --- | --- | --- | --- | --- |
| 深色环境背景与内容聚焦 | `home-portrait.jpg`, `HomePage.ets` | `pages/home/view.dart`、视频详情根表面 | 新建静态 `ColorScheme` 径向/线性渐变环境表面；不模糊、不逐帧采样，浅色与纯黑有独立透明度 | Golden/Widget：主题切换、reduced motion 无持续 ticker |
| 浮动圆角页头与搜索动作 | `HdsGlassBar.ets`, `HdsMiniBarButton.ets` | 首页搜索、历史/消息/头像 | 使用现有 MIUIX 表面、16–24 圆角、细边框与 40/44dp 命中；保留原生底栏 | Widget：搜索、消息、头像入口各触发一次 |
| 紧凑圆角媒体卡 | `VideoCardComponent.ets`, 首页截图 | `video_card_v.dart`, `video_card_h.dart` | 16dp 圆角、1dp 低对比边框、媒体裁切、底部元数据/推荐胶囊；按压缩放 0.985，120ms，reduced motion 为 1.0 | Widget：命中、长按、按压恢复、文本缩放无溢出 |
| 详情/评论胶囊切换 | `player-portrait.jpg`, `VideoPlayerPage.ets` | `pages/video/view.dart::buildTabBar` | TabBar 使用圆角轨道和选中胶囊，发弹幕/弹幕开关合为独立操作胶囊；保留计数和滚动回顶 | Widget：切换、重复点击回顶、评论计数、语义 |
| 大圆角信息分组 | 播放器竖屏截图 | UGC/PGC 简介、相关视频、评论容器 | 仅在高层分组使用 `surfaceContainerLow/Lowest` + 20–24dp 圆角；不为每行新增合成层 | 窄屏/大字体布局测试，Hero 目标色一致 |
| 横屏左视频右评论 | `player-landscape.jpg`, `LivePlayerPage.ets` | 当前宽屏视频详情布局 | 保留现有响应式结构，统一右栏圆角与胶囊筛选；不重排播放器生命周期 | 600/1024dp Widget 布局与返回行为 |
| 控件淡入位移 | `AnimationUtil.ts`, `VideoControls.ets` | `app_bar_ani.dart` | 220ms easeOutCubic 的淡入+小位移；reduced motion 直接显示/隐藏；避免整屏模糊 | 动画时钟测试、无残留 ticker |
| 播放器顶部/底部控制组 | `VideoControls.ets` | `bottom_control.dart`, `compact_player_controls.dart`, HeaderControl | 半透明黑色胶囊、细边框、分组按钮与可伸缩进度；保证 40dp 命中，菜单样式统一 | 240–1024dp、1.0/1.8 文本缩放测试 |
| 音量/亮度/进度/倍速提示胶囊 | `VideoControls.ets` | `pl_player/view/view.dart` | 统一 `PlayerHudPill`，图标+数值，150–200ms opacity/scale；reduced motion 零时长 | Widget：每种 HUD、忽略指针、语义文本 |
| 轻量弹簧与按压反馈 | `HdsMaterialPill.ets`, `AnimationUtil.ts` | 通用卡片、胶囊按钮 | 仅局部 `AnimatedScale`/显式曲线，不采用参考项目 0.9 缩放或 600–1500ms 动画 | Pointer cancel/up 后恢复，禁用动画无缩放 |

## 上游 46 提交同步矩阵

状态定义：`移植`=本轮手工语义同步；`已有`=当前分支有等价实现并补证据；`基础设施跳过`=没有独立用户功能且与固定 SDK/依赖合同冲突。最终实施时把“待核对”全部归类并记录验证。

| 提交 | 功能 | 初始处理 | 冲突/验证重点 |
| --- | --- | --- | --- |
| `33f32db2a` | 长图拖动关闭修复 | 待核对/移植 | 图片查看器手势回归 |
| `74764f2f3` | #2702 修复 | 待核对 | 以提交 diff 确认用户路径 |
| `56d5ff5de` | lint | 基础设施候选 | 不做无关格式化 |
| `d0e03529b` | 直播横屏移除底部安全区 | 待核对/移植 | 横屏、挖孔与系统栏 |
| `39587f88c` | 打开音频媒体修复 | 待核对/移植 | 音频路由、恢复播放 |
| `453dcb750` | 音频会话修复 | 待核对/移植 | Android/iOS 音频焦点 |
| `f67a90291` | 离线字幕/观点 | 移植 | 离线模型、播放器面板 |
| `8006ace0a` | DLNA 旧乐播控制 URL 规范化 | 移植 | URL 单测 |
| `0005b8433` | 楼中楼线程回复 | 移植 | 回复树、定位、分页 |
| `844001deb` | 分集滚动偏移修复 | 移植 | 分集初始定位 |
| `35dd49785` | #3504 修复 | 待核对 | 以提交 diff 确认 |
| `bcc784385` | 下载队列条目更新 | 移植 | 队列状态刷新 |
| `b94e1fc05` | 依赖升级 | 按功能拆解 | 不升级固定 SDK，不全量改锁 |
| `934a7ada3` | 本地字幕更新修复 | 移植 | 字幕替换/持久化 |
| `a32f1cc2c` | 本地字幕读取修复 | 移植 | 离线重启恢复 |
| `8ba530518` | 观点显示遵从设置 | 移植 | 设置开关 |
| `ef30e2482` | seek 修复 | 移植 | 拖动、取消、离线播放器 |
| `61409bb74` | 跳到目标观点 | 移植 | 章节跳转与播放状态 |
| `4fce4bb5a` | 推荐源选择与说明 | 移植 | 设置弹窗、持久化、源切换 |
| `a76861a20` | UI 优化 | 语义筛选 | 与本轮设计/MIUIX 合并，不整文件覆盖 |
| `090e5925d` | 专栏 Opus 修复 | 移植 | 图文加载 |
| `dc829bf26` | #3522 修复 | 待核对 | 以提交 diff 确认 |
| `24f798d0d` | 动态折叠动作 | 移植 | 折叠项渲染/交互 |
| `86f4759d4` | 窗口偏移计算 | 最终被回滚 | 与 `96c1c519d` 成对处理 |
| `f52160af0` | gRPC proto 更新 | 移植 | 生成文件来源与编译 |
| `c9fef1a66` | 下载分集索引修复 | 移植 | PGC/UGC 下载 |
| `b5e138398` | 清晰度更新后刷新下载条目 | 移植 | 下载列表状态 |
| `07c48d0c3` | 匿名 buvid 修复 | 移植 | 未登录请求 |
| `c520a3fe1` | 离线音量 | 移植 | 持久化与范围 |
| `2dd24225b` | 更新离线 UGC 季信息 | 移植 | 兼容旧缓存 |
| `bd93f4792` | 直播 trace | 移植 | 请求参数/日志隐私 |
| `cab0114a2` | MPRIS 优化 | 移植 | 桌面媒体会话 |
| `f61cdab35` | 回复树显示切换 | 移植 | 设置/视图切换 |
| `3bfb84e37` | DASH 处理优化 | 移植 | 画质、音轨、解码回归 |
| `87dd54b8d` | 专栏列表倒序 | 移植 | 排序入口与状态 |
| `6a1090102` | 粉丝勋章管理 | 移植 | 直播入口、佩戴/卸下 |
| `de3558cf7` | 移除调试日志 | 基础设施候选 | 不扩大改动 |
| `f284577b5` | Linux 构建修复 | 条件移植 | 保持多平台编译 |
| `724f24517` | 依赖升级 | 按功能拆解 | 锁文件与 Flutter 3.47.4 |
| `915276c87` | 上游补丁更新 | 基础设施跳过 | 本项目独立 SDK patch 合同 |
| `68fbb1ff5` | 减少重建 | 移植 | Widget 生命周期、性能 |
| `9999f21d4` | 自动佩戴勋章修复 | 移植 | 开关与登录状态 |
| `94cd406a3` | 依赖升级 | 按功能拆解 | 只采纳必要兼容版本 |
| `96c1c519d` | 回滚窗口偏移修复 | 与 `86f4759d4` 抵消 | 最终行为保持当前稳定实现 |
| `de85b2d8d` | 回滚桌面最小窗口修复 | 待核对 | 当前是否包含被回滚提交 |
| `217fb54f5` | Release 2.2.1 | 元数据不照搬 | 功能完成度核对，保留四段版本体系 |


## 上游同步实测结论（本轮）

机械合并 `bgg-upstream/main` 已在隔离 worktree 中实测：68 个文件冲突、501 个 `analyze` 错误，
主要来自本分支对 `pl_player`（`PlayOwner`/`PlaybackState` 重构、紧凑单行控制条）、
`pages/download`（目录重构）、`pages/live_room`（控制器拆分）、`utils/desktop`（改 window_manager）、
`grpc` 生成文件与 `page_utils` 跳转合同的定向改写。因此**不采用整分支合并**，
改为逐项审计后只移植无架构耦合的修复。

本轮已移植并验证：

| 上游提交 | 内容 | 落点 | 验证 |
| --- | --- | --- | --- |
| `8006ace0a` | DLNA 旧乐播 `controlURL` 规范化 | 新增 `lib/utils/dlna_utils.dart`，接入 `lib/pages/dlna/view.dart` | `test/utils/dlna_utils_test.dart` 4/4 |
| `8006ace0a` 依赖部分 | `dlna_dart` 0.1.1 → 0.1.2（`controlURL` 改 `Uri.resolve`、SOAP 转义修正） | `pubspec.yaml`/`pubspec.lock` | 同上用例覆盖 |
| `d0e03529b` | 直播横屏全屏移除底部安全区边距 | `lib/pages/live_room/view.dart` | 静态检查 + 布局审阅（未真机） |

本轮**未移植**并记录原因：

- `6a1090102` 粉丝勋章管理、`bd93f4792` 直播 trace、`0005b8433` 楼中楼线程回复、`f61cdab35` 回复树开关、
  `f67a90291`/`934a7ada3`/`a32f1cc2c` 离线字幕与观点、`c520a3fe1` 离线音量、`2dd24225b` 离线季信息、
  `87dd54b8d` 专栏倒序、`4fce4bb5a` 推荐源弹窗、`61409bb74` 跳转目标观点：均依赖上游对本分支同名文件的
  大范围重构（`live_room/controller.dart` 已拆分为 `controller_mixin/*`、`download_service` 签名已改、
  `rcmd_source.dart` 在本分支已不存在）。直接 cherry-pick 会覆盖已有的 MIUIX、录制、Pure Live 与下载重构，
  需要单独一轮按功能重新实现，不在本轮视觉改造范围内。
- `b94e1fc05`/`724f24517`/`94cd406a3`/`cab0114a2` 依赖升级：项目固定 Flutter 3.47.4 且锁文件严格校验，
  只采纳了 DLNA 这一个与本轮修复直接相关的升级。
- `915276c87` 上游 SDK 补丁更新：与本项目 `tool/flutter-sdk.patch` 独立合同冲突，跳过。

## 视觉令牌映射（与参考工程对照）

| 参考取值（`chunwcc/yunshang-bili`） | 本项目落点 | 说明 |
| --- | --- | --- |
| 视频卡 r24 / 信息区 16 / 底栏胶囊 28 | `ImmersiveTokens.cardRadius=16`、`groupRadius=22`、`pillRadius=999` | 按触摸密度折中，不照抄 24 |
| 按压缩放 0.90–0.97 | `ImmersiveTokens.pressedScale=.985` | 保持文字可读，不取 0.9 |
| 卷帘/滑入 220–300ms 弹簧 | `chromeDuration=220ms`、`hudDuration=160ms`、`pressDuration=120ms` | 全部经 `disableAnimations` 门控 |
| HUD 长按 260ms 弹入、退场 180ms | `PlayerHudPill` 统一 160ms opacity+scale | 参考工程 `VideoControls` 缺 reduced-motion 门控，本项目补齐 |
| 实时 `blur(20px)` 玻璃、逐帧采样 | **不采用** | 项目红线：无实时模糊/常驻 Shader |

## Tasks

### T1: 上游语义同步基线

**Do:** 在隔离临时 worktree 复制当前未提交基线，逐提交审计/移植上游 46 个提交；将最终功能补丁应用回当前工作区，保留定制模块。把矩阵中所有“待核对”更新为明确结论。

**Files:** 按上游提交涉及文件；重点 `lib/pages/reply/`, `lib/pages/download/`, `lib/pages/live_room/`, `lib/pages/audio/`, `lib/models/`, `lib/grpc/`, `pubspec.*`

**Verify:** 每个功能域运行针对性 analyze/测试；`git diff --check`；固定 SDK 检查通过。

### T2: 低开销沉浸式 UI 原语与首页/视频卡

**Do:** 新增环境表面、按压表面和胶囊组件；接入首页顶部区域、纵向/横向视频卡，统一 16–24dp 圆角、元数据胶囊、细边框与按压反馈。使用现有封面与主题颜色，不复制参考素材。

**Files:** `lib/common/widgets/immersive/`, `lib/pages/home/view.dart`, `lib/common/widgets/video_card/video_card_v.dart`, `lib/common/widgets/video_card/video_card_h.dart`

**Verify:** 新增 Widget 测试覆盖明暗主题、reduced motion、点击/长按、pointer cancel 和大字体无溢出；指定文件 analyze。

### T3: 视频详情与响应式信息层级

**Do:** 把详情/评论/播放列表切换、发弹幕和弹幕开关改为分组胶囊；为高层信息区和横屏评论栏统一圆角表面，同时保持两层滚动书签、Hero 目标色、PGC/UGC 行为和预测返回。

**Files:** `lib/pages/video/view.dart`, `lib/pages/video/introduction/`, `lib/pages/video/reply/`, `lib/common/widgets/video_card/video_card_transition.dart`（仅在确需兼容时）

**Verify:** Tab 切换与回顶、滚动位置恢复、快速返回/取消、窄屏/大字体与横屏布局测试。

### T4: 非影视播放器控制层与动画

**Do:** 新增统一播放器 HUD 胶囊和控制层表面；将顶部/底部显隐改为 220ms 淡入+短位移，统一音量/亮度/seek/倍速提示、菜单和按压反馈。保持 `PlPlayerController`、media_kit、手势和所有播放能力不变；AVBox 路径不引用新组件。

**Files:** `lib/plugin/pl_player/view/view.dart`, `lib/plugin/pl_player/widgets/app_bar_ani.dart`, `bottom_control.dart`, `compact_player_controls.dart`, `common_btn.dart`, `lib/pages/video/widgets/header_control.dart`

**Verify:** 控件显隐/reduced motion、HUD、240–1024dp、1.0/1.8 文本缩放、拖动 seek、全屏安全区和弹层顺序测试。

### T5: 性能收口与完整交付

**Do:** 审计新增动画的重建边界和 RepaintBoundary，按项目流程格式化、analyze、全量测试，最终源码重新生成发布元数据，构建三 ABI 签名 Release APK并核对签名、包名、版本、时间与哈希。只交付，不安装。

**Verify:** `./scripts/flutterw --check-sdk`；改动文件 `dart format`；`./scripts/flutterw analyze --no-pub ...`；`./scripts/flutterw test --no-pub`；Python 测试；`git diff --check`；`apksigner verify`；`aapt dump badging`。

## Done

- [x] 上游同步改为逐项审计移植：本轮移植 DLNA 规范化与直播横屏安全区，其余提交已记录不移植原因（见“上游同步实测结论”）。
- [ ] 剩余上游用户功能（粉丝勋章、楼中楼、离线字幕/观点、推荐源弹窗等）需单独一轮按功能重新实现。
- [x] 首页、视频卡、视频详情与非影视播放器具有统一的 MIUIX + 云上沉浸式圆角/胶囊语言（`lib/common/widgets/immersive/`、`player_hud_pill.dart`）。
- [ ] AVBox 影视代码与播放行为未改变；UGC/PGC/直播/Pure Live 的原有交互能力不丢失。
- [x] `disableAnimations` 下无位移/缩放/持续 ticker；常态没有新增实时 blur、常驻 Shader 或逐帧采样（已有 Widget 测试断言）。
- [x] 针对性测试（沉浸组件 7 项、播放控制 17 项、转场 16 项、DLNA 4 项）、全量 Flutter 226 项、Python 36 项、改动文件 `analyze` 与 `git diff --check` 全部通过。
- [ ] 最终源码的三 ABI 签名 Release APK 已生成并核验；真机未验证项明确列出。

## 本轮追加：Mochi 动效与首页信息架构

用户授权：参考 `feice11/mochi-compose` 的动效语言重做首页；首页展示大卡轮播与推荐流，移除继续观看；首页频道选择收纳进顶部三点菜单，不增加消息入口。保留当前分支真实存在的“热门”频道，共六个频道。

实施映射：只移植弹簧空间动效、按压压缩回弹、内容淡入的交互原则，不引入 Kotlin Compose 依赖或复制参考实现；复用现有推荐模型、视频卡、频道配置、MIUIX/原生底栏和搜索入口。轮播精选项从推荐列表选取并从下方列表去重。减少动态效果时停用运动动画。

验收：频道菜单可切换六项；推荐页轮播点击使用现有视频详情路径；无继续观看区域；列表首屏不重复显示精选项；常规交互、返回/刷新及桌面/侧栏导航保持可用。根因已确认是本机 `PUB_HOSTED_URL` 镜像与锁文件按 `pub.dev` 保存的归档哈希不一致；指定官方源后 `pub get --enforce-lockfile` 成功，锁文件未改。`prepare_android_ci.py` 已改为逐 hunk 检查，已存在的下游补丁跳过，其余补丁仅在 `git apply --check` 通过后应用；以严格锁文件依赖实测通过。最终源码相关 analyze、全量 Flutter 测试（228 项通过、1 项 CloudBase 测试因无凭据 skip）、Python 36 项、`git diff --check` 均通过。版本 `2.4.0.14`（20400014）三 ABI Release APK 已签名构建并通过验签及包名/版本核对；未安装/未做真机交互验证。

## 本轮交互修订：悬浮频道入口与自动轮播

频道入口仅显示悬浮三点按钮，移除并不显示搜索入口；按钮停在页面右下方内容层，底色透明度在浮动导航栏模式下与底栏一致为 0.4，菜单展开后列出六频道。大卡 5 秒自动切换；用户拖动暂停、滑动结束后恢复，后台/停用 ticker 时暂停，`disableAnimations` 时关闭自动轮播及过渡动画。三点菜单弹出使用约 240ms easeOutBack，按压反馈使用项目 PressScaleListener 的 easeOutBack（120ms）；均在现有 120–300ms 交互预算内。

本轮最终验证：轮播 Widget 测试 2 项、全量 Flutter 230 项通过且 1 项 CloudBase 测试因无凭据 skip、Python 36 项、改动文件 analyze 与 `git diff --check` 通过。版本 `2.4.0.14` 三 ABI APK 已重新签名构建并验签、核对包名/版本。未安装或进行真机 UI 验证。

## 本轮追加：动态/直播悬浮分类菜单与搜索圆钮

动态页移除常驻五频道胶囊，五类入口迁入顶部悬浮三点按钮；加号独立悬浮，按钮与菜单在浮动底栏模式下采用同样 0.4 surface alpha。直播页将推荐/分区及可用二级标签移入置于直播内容顶部的悬浮三点菜单，旧文字胶囊不再占据内容区，菜单仍调用原控制器筛选逻辑。搜索圆钮移除描边与 InkWell 波纹，原生玻璃层关闭重复搜索圆钮并取消其投影；Flutter 搜索入口保留。

验证：三个目标 Dart 文件 analyze 通过；全量 Flutter 230 项通过、1 项 CloudBase 测试缺凭据跳过；Python 36 项通过；diff check 通过；三 ABI 签名 Release 构建及验签、包名/版本校验通过。未进行真机视觉验证。
