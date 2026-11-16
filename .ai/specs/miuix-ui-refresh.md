# MIUIX 全局 UI、交互与动效刷新

## Why

当前 Android 悬浮底栏使用 MIUIX，但 Flutter 主界面没有安装 `MiuixTheme`，只有少量圆角和 Switch 接入了 MIUIX；其余按钮、表单、菜单、弹层、选择控件和加载状态仍由零散的 Material 默认值决定，明暗色、触控面积、动效和反馈不一致。

## What

在不把 Flutter 页面重写为 Compose、不破坏播放器和现有业务路径的前提下，为整个 App 建立一个可验证的 MIUIX 适配层：

- 所有页面共享同一套 MIUIX 颜色、字体、圆角、尺寸和状态色语义。
- 能由 `ThemeData` 继承的 Material 控件统一视觉令牌；不能仅靠主题实现的 Checkbox、Radio、Slider、Switch、IconButton 使用项目级 MIUIX 包装。
- 常用选择行整行可点、控件状态与行点击一致，并保留键盘、语义、禁用态、触觉和既有回调。
- 动画尊重系统 `disableAnimations`，保留用户选择的页面转场、预测返回和共享转场；不新增全屏模糊、逐帧截图或常驻 Shader。

“一致”指组件视觉令牌、交互状态和动效语义等价，而不是把 465 个 Flutter 页面改写为 Compose。Compose MIUIX 当天 `main`（`ac0af4671bc9e4489d0960685a46a5b1ffd557da`，2026-11-16）包含尚未正式发布的 Glass 组件；生产基线分为：原生 Android `v0.9.4`、Flutter 稳定移植 `flutter_miuix 1.3.0`、未发布 Glass 仅参考行为与性能约束。

## Context

**Relevant files:**

- `lib/utils/theme_utils.dart` — Material 与 MIUIX 的颜色、排版和组件主题真源。
- `lib/main.dart` — 根部主题、MediaQuery、SmartDialog 与原生底栏遮挡入口。
- `lib/common/widgets/miuix_*.dart` — 不能只靠 `ThemeData` 对齐的项目级控件。
- `lib/common/widgets/button/icon_button.dart`、`lib/common/widgets/radio_widget.dart` — 已被多页面复用的交互入口。
- `lib/common/widgets/scaffold/mini_scaffold.dart`、`lib/common/widgets/floating_navigation_bar.dart` — Sheet 与 Flutter 导航动效。
- `lib/common/widgets/loading_widget/`、`lib/common/widgets/custom_toast.dart` — 全局加载和反馈表面。
- `android/app/build.gradle.kts` 与原生导航实现 — 已发布 MIUIX Android 基线，除非有正式版本不切未发布快照。

**Reference evidence:**

- 官方 Compose 源码：`compose-miuix-ui/miuix` 的 `Button.kt`、`IconButton.kt`、`Checkbox.kt`、`RadioButton.kt`、`Slider.kt`、`TextField.kt`、`Card.kt`、`DialogContentLayout.kt`、`BottomSheetContentLayout.kt`、`NavigationBar.kt`、`NavigationRail.kt`、`Badge.kt`。
- 关键默认值：Button 58×40/圆角 16，IconButton 40，Checkbox/Radio 26，Slider 高 28，Card 16，TextField 16，Dialog 32/最大宽 420，BottomSheet 28/最大宽 640，列表内容水平边距 16。

## Constraints

**Must:**

- 保留用户精确字重（默认 350）和自定义字体，不回退 MIUIX 默认 w400。
- 保留现有主题种子色、纯黑主题、浅色/深色和系统模式。
- 保留 Slider 的 `divisions`、数值气泡、开始/结束回调、禁用态及语义；Material `divisions` 映射为 MIUIX `steps = divisions - 1`，MIUIX 不支持的数值气泡、辅助轨道和交互限制使用已主题化 Material 回退。
- 触控目标不小于 40dp；独立选择控件使用 48dp 命中区，视觉尺寸仍按 MIUIX 26dp。
- 保留原生底栏弹层遮挡、预测返回、共享转场、播放器手势和滚动恢复合同。

**Must not:**

- 不把未发布的 Compose `main` 快照直接作为生产 Maven 依赖。
- 不把 Glass/Blur 铺到列表、卡片或页面背景；Glass 只允许用于有正确背景采样的高层级 Chrome。
- 不以全量替换文件、依赖升级或无关格式化掩盖兼容问题。
- 不改变用户当前页面转场设置，不自动安装 APK 到设备。

## Component matrix

| 类别 | 当前处理 | 验收 |
| --- | --- | --- |
| 颜色、排版 | `ColorScheme` 映射 `MiuixColors`，根部安装 `MiuixTheme` | 明暗主题和精确字重一致 |
| Card/Dialog/Sheet/Menu | 全局 Theme 令牌 | 16/32/28/16 圆角，弹层宽度与遮挡正确 |
| Button/IconButton/FAB | 全局 Theme；共用 helper 用 MIUIX 实现 | 40dp 以上触控、状态色一致 |
| TextField/Search | 16 圆角、填充表面、2dp 聚焦边框 | 点击区域、焦点和键盘行为保留 |
| List/Tab/Divider/Snackbar | 全局 Theme 令牌 | 行间距、选中态、反馈表面一致 |
| NavigationBar/Rail/Drawer | 原生底栏保留；Flutter 回退统一 MIUIX 令牌 | 64/80/240 尺寸、状态色和选中表面一致 |
| Badge | 全局 Theme 令牌 | 6dp 圆点、16dp 内容徽标及 error/onError 配色 |
| Chip/SegmentedButton | MIUIX 无稳定同名组件，使用主题化 Material 回退 | 统一 16 圆角、40dp 高度、状态色和触控区 |
| Checkbox/Radio/Switch | 项目包装 + 显式迁移 | 26dp 视觉、48dp 命中、整行点击、触觉和语义 |
| Slider | 兼容包装；高级 Material 特性保留主题化回退 | 步进、开始/结束回调、辅助功能不丢失 |
| Progress/Toast | MIUIX 形态和表面 | reduced motion 下不持续做无意义重绘 |
| Glass | 仅高层级 Chrome；本轮不扩大 | 无新增全屏 blur/shader 开销 |

## Tasks

### T1: 全局主题桥接

**Do:** 将 Material `ColorScheme` 映射到 `MiuixColors`，生成保留用户字重/字体的 `MiuixTextStyles`，在根部安装 `MiuixTheme`；补齐 Card、Dialog、Sheet、Menu、Button、IconButton、Input、ListTile、Checkbox、Radio、Slider、Tab、FAB、Divider、Snackbar、Progress、NavigationBar/Rail/Drawer、Badge、Chip、SegmentedButton 等回退主题。

**Files:** `lib/utils/theme_utils.dart`, `lib/main.dart`, `lib/common/style.dart`, `pubspec.yaml`, `pubspec.lock`

**Verify:** 主题映射 Widget/单元测试；指定文件 analyze。

### T2: 高交互组件迁移

**Do:** 新增 MIUIX Checkbox、Slider 与选择列表兼容包装；把共用 Radio、IconButton、Switch 接到根主题；迁移全部直接 Checkbox、横向 Slider、Switch/Checkbox/RadioListTile 和 ProgressIndicator，保留数值气泡、辅助轨道、交互限制等高级 Slider 能力的主题化 Material 回退。

**Files:** `lib/common/widgets/miuix_checkbox.dart`, `lib/common/widgets/miuix_slider.dart`, `lib/common/widgets/miuix_switch.dart`, `lib/common/widgets/radio_widget.dart`, `lib/common/widgets/button/icon_button.dart` 及直接使用页面

**Verify:** 48dp 命中、整行单选、Slider 步进和回调 Widget 测试；相关页面 analyze。

### T3: 反馈、动效与开销

**Do:** 统一 Toast、加载与刷新表面；Sheet、顶部/底部 Chrome 和 Flutter 导航在 `disableAnimations` 时停用过渡，常态缩短冗长动画；骨架屏缓存子树并只重绘 Shader 层，不触碰用户页面转场与视频共享转场。

**Files:** `lib/common/widgets/custom_toast.dart`, `lib/common/widgets/loading_widget/`, `lib/common/widgets/scaffold/mini_scaffold.dart`, `lib/common/widgets/floating_navigation_bar.dart`

**Verify:** reduced-motion Widget 测试；动画控制器无泄漏；`git diff --check`。

### T4: 全量回归与签名包

**Do:** 运行静态检查、Flutter/Python 测试，生成分 ABI 签名 Release APK，核对签名、包名、版本与产物哈希；在可用 Android 运行实例上后台烟测主题、选择控件、弹层和导航。

**Verify:** 项目规定的测试、构建、`apksigner`、`aapt dump badging` 和实际交互记录。

## Done

- [x] 根部 Material 与 MIUIX 主题使用同一配色、字体和精确字重。
- [x] 主题可覆盖组件使用统一令牌；高交互组件完成显式迁移且无回调回归。
- [x] reduced motion 生效，无新增全屏实时模糊或常驻 Glass 开销。
- [x] `./scripts/flutterw test --no-pub`、脚本测试和 `git diff --check` 通过。
- [x] 分 ABI 签名 Release APK 构建成功并核对包名、版本、签名（2026-11-16，三 ABI apksigner Verifies，包 com.aritxonly.hyperpiliplus / 2.4.0.2 / 20400002）。
- [x] 真机冒烟：明暗主题下首页/播放器/胶囊控件正常、无崩溃；云端验证未做，真机完整回归仍需用户自行确认。
