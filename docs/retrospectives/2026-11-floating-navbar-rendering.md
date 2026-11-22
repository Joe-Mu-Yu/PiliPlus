# 2026-11 悬浮底栏灰带与下移问题复盘

## 文档状态

- 复盘日期：2026-11-21
- 覆盖阶段：2026-11-21 悬浮底栏搜索按钮重做与底部渲染修复
- 基线提交：`b3f3e8ba5`
- 涉及文件：
  - `android/app/src/main/kotlin/com/example/piliplus/MiuixLiquidGlassNavigationBar.kt`
  - `android/app/src/main/kotlin/com/example/piliplus/DeadlinerNavigationOverlayContent.kt`
  - `android/app/src/main/kotlin/com/example/piliplus/FlutterSurfaceBackdropSampler.kt`
- 性质：问题档案与操作依据，不替代 `AGENTS.md` 或发布说明

## 结论

本轮暴露了两类反复出现的缺陷，它们的共同点是**表现直观、根因不直观**，导致用“看起来相关”的手段反复试错却越改越偏：

1. **悬浮底栏下移/上浮**：不是 padding 写错，而是**透明采样图参与了父布局测量**，把承载底栏的 Box 撑高，底栏随之被推离屏幕底部。
2. **底栏与搜索框的灰带、黑色阴影**：不是布局问题，而是**玻璃材质的三处装饰参数**在浅色/深色背景上产生的暗边：`dropShadow` 黑色投影、`BloomStroke` 高光描边的内侧模糊、以及采样图透明度为 0 被渲染器剔除。

两类问题的共同教训：**先隔离变量定位“是哪一层画的”，再改参数**；不要在同一轮里同时调整布局与材质。

## 一、底栏下移问题（每次必现）

### 现象

每次改动底栏后，悬浮胶囊和搜索按钮都会被抬高，离屏幕底部出现明显空白；调整 `padding` 只能轻微变化，无法真正贴底。曾观测到胶囊底部距屏幕底约 64dp，最严重一次达到 130dp。

### 根因

底栏外层结构是 `Box { Image(采样图) + Row(底栏) }`，Box 高度取**所有子项的最大高度**。

采样图用于玻璃折射，其尺寸是“底栏 bounds + 上下各 48dp bleed”，即比底栏本身高约 96dp。当它用 `.size()` 参与布局时，Box 被撑高 96dp；而 `Row` 默认顶部对齐，于是底栏被顶到 Box 顶部，凭空上移约 96dp。

**关键点：`padding` 只能影响 Row 内部，改变不了 Box 被采样图撑高这一事实。** 这就是“怎么调 padding 都贴不到底”的原因。

### 解决方案

让采样图**不参与父布局测量**，Box 高度只由底栏 Row 决定：

```kotlin
Box(Modifier.fillMaxWidth()) {
    // 1. Row 放最前面，由它单独决定 Box 高度
    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp) /* … */) { /* 胶囊 + 搜索圆 */ }

    // 2. 采样图放后面，用 matchParentSize 跟随 Box 尺寸
    backdropSnapshot?.let { snapshot ->
        Image(
            bitmap = snapshot.bitmap.asImageBitmap(),
            contentScale = ContentScale.FillBounds,
            modifier = Modifier
                .matchParentSize()
                .graphicsLayer {
                    clip = false                       // 允许绘制越界（crop 比 Box 大）
                    transformOrigin = TransformOrigin(0f, 0f)
                    scaleX = snapshot.sourceWidthPx / size.width   // 还原真实尺寸
                    scaleY = snapshot.sourceHeightPx / size.height
                    translationX = snapshot.sourceLeftInWindowPx - rootPositionInWindow.x
                    translationY = snapshot.sourceTopInWindowPx  - rootPositionInWindow.y
                }
                .alpha(0.001f)                          // 关键：不能用 0f，见下节
                .layerBackdrop(backdrop),
        )
    }
}
```

要点：

- `matchParentSize()` 让采样图尺寸恒等于 Box，**永远不会再撑高布局**。
- 用 `graphicsLayer` 的 `scale`/`translation` 把下采样裁剪图还原到真实窗口位置，`layerBackdrop` 照常工作。
- `transformOrigin = (0,0)` 保证平移是纯窗口偏移，不是中心轴缩放。
- `clip = false` 让比 Box 更大的 crop 能正常绘制。

### 排查方法（下次直接照做）

1. 不要先调 `padding`。先确认 **Box 高度是否等于 Row 高度**：
   - 在 Box 的 `onGloballyPositioned` 里比对 `coordinates.size.height` 与 Row 的高度。
   - 若 Box 明显更高，就是有透明子项参与了测量。
2. 逐项移除 Box 内的子项（尤其是采样图、调试面板、Spacer），观察底栏位置是否跳变，即可锁定元凶。
3. 定稿后统一用“采样图 `matchParentSize`”模式，可长期避免复发。

## 二、灰带与黑色阴影问题

### 现象

- 底栏下沿出现一条 2dp 左右、横贯整宽的 `#666666` 灰带。
- 浅色页面上表现为胶囊底部略暗（如 241 vs 周围 255）。
- 搜索圆底部也出现阴影。
- 曾出现整块 `102,102,102` 的均匀灰色区域。

### 根因：三个独立原因叠加

#### 1. 采样图 `alpha(0f)` 被渲染器剔除

采样图需要“不可见但仍参与 `layerBackdrop` 记录”。用 `.alpha(0f)` 时，**部分 HyperOS 渲染器会直接剔除该图层**（layer culling），导致玻璃拿不到背景像素，底边渲染为均匀灰色。

**修复**：改用极小非零透明度。

```kotlin
.alpha(0.001f)   // 不能是 0f
```

上游 `hyper/main` 的实现同样使用 `BACKDROP_SOURCE_ALPHA = 0.001f`，并在注释中明确记录了这一现象。

#### 2. 胶囊 `dropShadow` 形成淡灰晕

```kotlin
.dropShadow(shape = pillShape, shadow = Shadow(radius = 10.dp, color = Color.Black, alpha = 0.1f))
```

黑色投影在玻璃下方形成柔和灰晕。在半透明玻璃上尤其明显，就是“浅浅的淡灰带”。

**修复**：移除 `dropShadow`，改用 1dp 细边框维持边缘轮廓。

```kotlin
.border(
    width = 1.dp,
    color = if (isDark) Color.White.copy(alpha = 0.10f) else Color.Black.copy(alpha = 0.06f),
    shape = pillShape,
)
```

#### 3. `BloomStroke` 高光描边的内侧模糊

`iosIndicatorSpecular` 使用 `BloomStroke(innerBlurRadius = 2.dp)`，且二次光源 z 为负（位于表面下方）：

```kotlin
secondaryLight = LightSource(position = LightPosition(0.5f, 0.8f, -0.5f), intensity = 0.4f)
```

内侧模糊与负 z 光源叠加，在胶囊和搜索圆的**下沿内侧**产生 2dp 暗线。

**修复**：移除 `highlight`（改为 `{ null }`），并把二次光源 z 调正、强度降低：

```kotlin
secondaryLight = LightSource(position = LightPosition(0.5f, 0.8f, 0.5f), intensity = 0.25f)
```

### 排查矩阵（本次实测结论）

| 假设 | 实验 | 结果 |
| --- | --- | --- |
| `lens` 折射导致 | 移除 `lens` | 灰带仍在，排除 |
| `vibrancy` 压暗 | 移除 `vibrancy` | 灰带仍在，排除 |
| 布局/padding 导致 | 多种 padding 组合 | 灰带位置不变，排除 |
| 采样图被剔除 | `alpha(0f)` → `0.001f` | 灰带从 48 行降至 6 行，部分改善 |
| `dropShadow` 灰晕 | 移除投影 | 胶囊底部淡灰消失 |
| `highlight` 内模糊 | 移除 `highlight` | **灰带完全消失** |

### 排查方法（下次直接照做）

1. **先分离图层**：临时把目标区域涂成醒目色（如洋红 `0xFFFF00FF`）用 `drawBehind`，看它是否被灰带覆盖，判断灰带在目标层之上还是之下。
2. **逐个关闭材质特性**：按 `lens` → `vibrancy` → `blur` → `highlight` → `dropShadow` 顺序单独关闭并截图对比，一次只动一个。
3. **量化验证**：不要靠肉眼。扫描目标行的像素，统计目标颜色（如 `(102,102,102)`）占比，前后对比行数。
4. **注意 `alpha` 语义**：任何“不可见但仍需参与合成”的图层，一律用 `0.001f` 而不是 `0f`。

## 三、操作清单

### 改动底栏布局时

- [ ] 采样图必须 `matchParentSize()`，不得用 `.size()`
- [ ] Box 高度只由 Row 决定，不引入其它占位子项
- [ ] 需要呼吸间距时，用 Row 内部 `padding(bottom)`，并确认该区域不会露出页面深色底

### 改动玻璃材质时

- [ ] 采样图透明度为 `0.001f`
- [ ] 不使用黑色 `dropShadow`；需要轮廓用 1dp 细边框
- [ ] 不使用带 `innerBlurRadius` 的 `highlight`；如需要高光，避免底边
- [ ] 光源 z 值不为负

### 验证时

- [ ] 至少在**纯白**和**深色**两种页面各截一次图
- [ ] 像素级检查底部区域是否存在成片均匀色带
- [ ] 对比改动前后同一位置的亮度统计

## 四、遗留与后续

- 上游 `hyper/main` 采用 `FlutterBackdropLayer` + `FloatingNavigationEdgeMask` + `navigationBarsPadding()` 的完整架构，用纯色边缘遮罩统一处理底栏下方区域。当前实现是等价的最小修复，尚未迁移到该架构；若后续底部问题复发，优先考虑该方案。
- 本轮验证覆盖浅色与深色页面；极窄屏、大字体和横屏下的底栏表现未单独回归。
- 本轮改动未提交、未推送、未发布。
