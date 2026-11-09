# 家庭安全按需位置共享

## Why

家长希望在明确授权的情况下了解未成年家庭成员是否安全到达。该能力涉及未成年人和行踪轨迹，不能作为普通“未成年人模式”开关实现，必须与 B 站账号、内容功能和连续追踪隔离。

## What

交付 Android 优先的家庭安全 MVP：使用现有国内 CloudBase 独立账号，被照护端主动创建家庭并生成一次性邀请码，照护端加入后可以请求报平安；被照护端明确点击后才采集并共享一次位置。云端只保留一条最新位置、24 小时自动失效，查看位置有审计，任一方可以立即撤销或删除全部家庭安全数据。

## Context

**Relevant files:**

- `lib/pages/couple_space/cloudbase_repository.dart` — 已验证的 CloudBase Auth、令牌刷新和 RPC HTTP 通道。
- `cloudbase/migrations/` — CloudBase PG 版本化迁移真源。
- `lib/pages/mine/controller.dart`、`lib/router/app_pages.dart` — 用户入口与 GetX 路由。
- `android/app/src/main/kotlin/com/example/piliplus/MainActivity.kt` — Android MethodChannel 生命周期入口。
- `android/app/src/main/AndroidManifest.xml` — 前台单次定位权限。

**Patterns to follow:**

- 复用 `couple_space` 的 CloudBase 登录会话与 `SECURITY DEFINER` RPC 边界，不在客户端保存 API Key。
- 数据库表默认不向 `anon`、`authenticated` 开放直读写；所有敏感操作通过校验 `auth.uid()` 的 RPC。
- Flutter 页面沿用项目 Material/MIUI 主题、动态 `ColorScheme`、GetX 路由与默认字重，不硬编码近似颜色。

**Key decisions already made:**

- 国内 CloudBase 环境 `urban-iguana-d9g3i6yg86c256bd4`；独立家庭表，不复用“小窝”成员关系。
- 首版只做用户触发的单次前台定位，不申请后台定位，不做轨迹或静默采集。
- 首版不嵌入地图 SDK；通过系统 `geo:` URI 交给用户已有地图应用。
- 邀请码证明双方设备完成共享确认，但不声称完成法定监护关系认证。

## Design specification

- **Scene:** Operate。
- **Purpose:** 让双方清楚知道当前绑定、待处理请求、最后位置和谁查看过，优先降低误解与滥用风险。
- **Aesthetic direction:** Industrial/utilitarian，强调状态、时间和可撤销操作，不做娱乐化装饰。
- **Color palette:** 完全复用项目 `ColorScheme` 的 `surfaceContainerLowest`、`surfaceContainer`、`primaryContainer`、`errorContainer` 与对应前景色；动态主题是项目约束，因此不新增固定十六进制色。
- **Typography:** 复用项目主题字体与用户选择的默认 350 字重；标题使用主题现有层级，不覆盖字体家族。
- **Layout:** 手机单栏、最大正文宽度 720dp；4/8/12/16/24/32 间距尺度；窄屏按钮纵向，大屏操作区最多两列。所有状态覆盖加载、空、拒绝、过期、离线和错误。

## Constraints

**Must:**

- 被照护端先创建，照护端只能凭短时一次性邀请码加入。
- 定位前显示用途并由被照护端当次确认；拒绝权限不影响播放器功能。
- 位置超过 24 小时不得返回给照护端；撤销时立即删除当前位置。
- 位置读取只能走服务端函数并记录访问事件。
- 任一方可撤销关系并删除该模块全部数据。
- 停止共享后保留一个无位置的已停止状态，使任一方仍可执行“永久删除”；删除后才能重新建立家庭。

**Must not:**

- 不申请 `ACCESS_BACKGROUND_LOCATION`，不启动定位前台服务。
- 不保存连续轨迹，不自动轮询采集，不把坐标写入普通日志。
- 不使用 B 站 UID/Cookie 建立家庭关系。
- 不自动提交、推送、发布或安装 APK。

**Out of scope:**

- 法定监护关系实名认证、短信注册、SOS、电子围栏、后台持续共享、iOS 原生定位和地图内嵌展示。

## Tasks

### T1: 隔离的家庭安全数据库边界

**Do:** 新建家庭、邀请码、报平安请求、最新位置和审计事件表；创建绑定、请求、回应、查看、撤销和删除 RPC；关闭客户端直接表访问。

**Files:** `cloudbase/migrations/20261108142407_family_safety_mvp.sql`

**Verify:** CloudBase migration plan/apply；复查表、函数、GRANT、RLS 与远端迁移记录。

### T2: CloudBase 客户端合同

**Do:** 暴露复用现有登录会话的受控 RPC 调用；实现家庭安全模型、仓库和 HTTP 合同测试。

**Files:** `lib/pages/couple_space/cloudbase_repository.dart`, `lib/pages/family_safety/model.dart`, `lib/pages/family_safety/cloudbase_repository.dart`, `test/pages/family_safety_cloudbase_repository_test.dart`

**Verify:** 定向 Dart analyze 和仓库测试。

### T3: Android 单次前台定位

**Do:** 增加粗略/精确前台权限、Android 当前定位 MethodChannel 与 Flutter 服务；处理定位关闭、权限拒绝、超时和不支持平台。

**Files:** `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/example/piliplus/FamilyLocation.kt`, `android/app/src/main/kotlin/com/example/piliplus/MainActivity.kt`, `lib/pages/family_safety/location_service.dart`, `test/pages/family_safety_location_service_test.dart`

**Verify:** Kotlin/Flutter 构建、MethodChannel 单测；确认清单不存在后台定位权限。

### T4: 家庭安全用户路径

**Do:** 增加登录、创建/加入、请求、明确分享/拒绝、位置状态、系统地图、审计、撤销与删除页面；从“我的”进入。

**Files:** `lib/pages/family_safety/view.dart`, `lib/router/app_pages.dart`, `lib/pages/mine/controller.dart`, `test/pages/family_safety_view_test.dart`

**Verify:** Widget 测试覆盖未登录、未绑定、双方角色、过期位置和权限拒绝；定向 analyze。

### T5: 整体交付验证

**Do:** 完成安全复查、全量测试、签名 Release APK 构建与验签。

**Verify:** `./scripts/flutterw --check-sdk`、指定文件格式化/analyze、`./scripts/flutterw test --no-pub`、`git diff --check`、签名/包名/版本检查。

## Done

- [x] 数据库迁移已登记，敏感表没有客户端直读写旁路。
- [x] 双方确认绑定、请求、分享、查看审计、撤销与删除合同有自动化测试。
- [x] Android 只在用户点击时读取一次位置，拒绝或关闭定位均有明确状态。
- [x] 页面入口、窄屏和大字体保持可操作。
- [x] 签名 Release APK 已生成并验签；模拟器已完成双端真实账号与原生定位闭环，真机位置仍待用户验证。
