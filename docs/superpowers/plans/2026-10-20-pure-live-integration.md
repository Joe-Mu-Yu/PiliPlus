# Pure Live 关注与录制中心整合实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 PiliPlus 主导航接入重设计后的 Pure Live 关注与录制中心功能，按 Apple HIG 原则优化体验并保持 Android 适配。

**Architecture:** 先做只读来源/许可/平台能力审计，再分为导航与关注、录制 MVP、录制增强几个可独立验收阶段。关注平台适配与录制引擎均与页面分离；支持通过直播间链接新增跨平台收藏，并按审计结果扩展平台，不假设所有 Pure Live 平台均可录制。

**Recorder migration constraint:** 直接迁移 Pure Live 原项目的录制实现与其必要依赖闭包；只改 PiliPlus 集成所必需的导入、服务注入、存储/设置和 Android 桥接。不得另行编写等价录制引擎/任务仓储来替代原实现。

**Tech Stack:** Flutter/Dart、GetX、现有 `NavigationBarType` 主导航、Android Kotlin 原生桥接（仅在后台录制确有需要时新增）。

**Spec:** `docs/superpowers/specs/2026-10-20-pure-live-follow-recorder-integration-design.md`

## Global Constraints

- 保留现有导航项、用户导航配置、侧栏/底栏路径及 Bilibili 关注能力和数据。
- Pure Live 代码、第三方依赖及许可证义务须在迁移前逐项核查。
- 不将可播放推断为可录制；每个平台的协议、登录态、后台行为单独验证。
- Apple HIG 仅作设计参考；遵守 PiliPlus 主题和 Android 合适交互，不宣称 Apple 平台合规。
- 遵守仓库 `AGENTS.md`；保留既有工作区改动，使用 `./scripts/flutterw`，不擅自提交、推送或发布。

## Review Focus

- 用户自定义导航里缺少新增目的地或索引过期：测试设置迁移、底栏/侧栏一致性。
- 多平台刷新部分失败：测试单平台错误不清空其他平台数据。
- Bilibili 旧关注数据与新模型迁移：测试升级后原列表仍可访问且无重复收藏。
- 后台录制被系统限制或权限拒绝：测试明确状态/通知，不显示虚假的“录制中”。
- 网络中断、磁盘满或目录不可写：测试任务终态、临时文件处理和错误提示。

---

## Task 1: 来源、许可证与平台能力审计（无产品代码）

**Files:**
- Read: `lib/models/common/nav_bar_config.dart`
- Read: `lib/pages/main/controller.dart`
- Read: `lib/pages/main/view.dart`
- Read: `/tmp/pure_live_plan_audit/lib/modules/favorite/`
- Read: `/tmp/pure_live_plan_audit/lib/recorder/`
- Read: both repositories' license and dependency manifests
- Create: `docs/superpowers/specs/2026-10-20-pure-live-platform-audit.md`

**Interfaces:**
- Produces: 平台能力矩阵、来源 commit、许可证/依赖清单、首批支持/录制平台范围；不新增运行时接口。

- [x] 核对来源仓库/commit 与根许可证；逐项依赖许可审查仍待结合迁移代码和最终依赖完成。
- [ ] 完成 22 个平台的链接识别/解析、房态 API、登录态、跳转、流协议、headers/cookies 与录制实测矩阵；当前仅完成静态入口盘点，未核验项明确标记待办。
- [x] 对照当前导航枚举和配置索引，确认新枚举必须追加末尾；Bilibili 旧关注页可复用。
- [x] 写入审计报告及依赖路线；本轮不替换用户指定的来源仓库/commit。

## Task 2: 导航目的地与关注页面骨架

**Files:**
- Modify: `lib/models/common/nav_bar_config.dart`
- Modify: `lib/pages/main/controller.dart`
- Modify: `lib/pages/main/view.dart`
- Create: `lib/pages/pure_live_follow/view.dart`
- Test: navigation configuration and main navigation widget tests (paths to be finalized after repository test-pattern audit)

**Interfaces:**
- Consumes: Task 1 的兼容策略与首批平台范围。
- Produces: 两个稳定导航目的地；关注页可加载状态及空态；录制入口先仅在录制服务未实现时提供明确未就绪页，不呈现假功能。

- [x] 为新增目的地编写序列化索引兼容测试，确认旧目的地 index 不变。
- [x] 观察测试先失败，再追加导航类型、图标/标签与页面分发。
- [x] 关注入口与录制中心导航目的地已接入；关注页仍复用旧 Bilibili 页面、录制页仍是临时占位，二者均不得视为功能迁移完成。
- [x] 全套 Flutter 测试覆盖主导航枚举兼容，78 项通过；目标分析无问题。

## Task 3: 跨平台收藏域与首批适配

**Files:**
- Create: `lib/models/common/live_favorite.dart`
- Create: `lib/services/live_favorite_repository.dart`
- Create: `lib/services/live_platform_adapter.dart`
- Create: `lib/pages/pure_live_follow/controller.dart`
- Modify: `lib/pages/pure_live_follow/view.dart`
- Test: repository, adapter, migration, filtering and refresh tests under `test/`

**Interfaces:**
- `LiveFavorite`：平台 ID、平台房间/用户 ID、显示信息、标签。
- `LivePlatformAdapter`：列出收藏、查询房间状态、打开房间；确切 Dart 类型由 Task 1 的平台审计决定。
- `LiveFavoriteRepository`：读取/保存收藏并按平台筛选。
- `LiveRoomLinkResolver`：解析受支持平台的直播间 URL 为已验证房间详情；未知域名/缺失 ID 不得创建伪收藏。

- [ ] 添加复合身份、标签、状态分组及平台隔离的失败用例。
- [ ] 对现有 Bilibili 收藏建立兼容读取/迁移测试，确认不丢失、不重复后实现适配。
- [ ] 只实现 Task 1 明确推荐的首批 adapter；其他平台显示未支持而非虚报成功。
- [ ] 提供粘贴直播间链接的新增流程；先验证平台与房间详情成功，再持久化收藏；未知链接和离线/无效房间显示原因且不写入。
- [ ] 加入筛选、刷新、错误隔离及滚动/页面状态测试。

## Task 4: 录制 MVP 可行性与 Android 生命周期技术验证

**Files:**
- Create: `docs/superpowers/specs/2026-10-20-pure-live-recorder-mvp.md`
- Potentially Create: isolated, disposable prototype outside shipped app code
- Test: protocol-level fixture tests for selected platform, if permitted by source and platform terms

**Interfaces:**
- Consumes: Task 1 的录制平台审计。
- Produces: 一个平台的可行性结论及独立录制子系统规格；不把原型视作可发布功能。

- [x] 按用户要求将抖音设为首个候选平台；平台条款/授权仍待核验，未将用户排序要求当作平台许可。
- [x] 用户声明已获官方授权，授权范围仅为直播录制；未独立审阅许可文件，故实现范围严格限于直播录制。
- [ ] 核验授权范围内可用的抖音接口、登录态/流地址前提；不绕过访问控制。
- [ ] 验证流捕获、文件封装/收尾、网络中断处理和 Android 后台限制；不可验证项明示。
- [ ] 仅在可行性及许可边界明确后写录制 MVP 规格；若不可行，停止该平台实施并报告替代选择。

## Task 5: 录制领域与手动单任务 MVP

**Files:**
- Migrate directly from `/tmp/pure_live_plan_audit/lib/recorder/` into the PiliPlus source tree, retaining original implementation structure and attribution.
- Adapt only source imports, required Pure Live runtime dependencies/services/settings, and Android foreground-service bridge/manifest integration.
- Replace the recorder placeholder page with the migrated original recording-center UI, adapted to PiliPlus navigation/theme.
- Migrate and adapt upstream recorder tests/fixtures where applicable; add focused host-integration regression tests.

**Interfaces:**
- `RecordTask`: stable ID, source identity, state, timestamps, output path, failure detail.
- `RecorderService`: start, stop, observe task state; selected platform implementation injected behind interface.
- `RecordTaskStore`: save, load and update task records.

- [ ] 迁移原项目的任务状态、恢复、失败处理、停止幂等和任务持久化逻辑及原有测试；不另造平行模型。
- [ ] 接入原项目的 Douyin stream resolver 与 FFmpeg 录制链；保留原有源代码逻辑，仅改 PiliPlus 集成点。
- [ ] 迁移原 Android 后台服务/通知实现并适配现有原生服务；系统拒绝时保留原有清晰失败状态。
- [ ] 迁移原录制中心任务列表、开始/停止、完成/失败详情与文件入口，并按 PiliPlus 主题适配。
- [ ] 在目标设备执行后台、锁屏、断网和文件可播放性验证；模拟器结果单独标记。

## Task 6: 录制增强（另行排期，MVP 验收后）

**Files:**
- Modify: `lib/recorder/services/recorder_service.dart`
- Create: `lib/recorder/services/record_queue.dart`
- Create: `lib/recorder/services/reconnect_policy.dart`
- Modify: `lib/pages/recorder_center/view.dart`
- Test: queue, reconnect, restore, disk-full and concurrency tests under `test/`

**Interfaces:**
- Consumes: Task 5 的 `RecorderService` 与 `RecordTaskStore`。
- Produces: 有界队列、受控并发、重连/恢复策略及设置入口。

- [ ] 为队列上限、并发上限、取消和失败隔离编写测试。
- [ ] 为断流、进程恢复、磁盘满/不可写和重复任务编写测试。
- [ ] 实现增强能力及相关设置；每个平台单独声明支持矩阵。

## Task 7: 最终视觉、回归与 APK 验证

**Files:**
- Modify: affected navigation/follow/recorder UI only
- Test: affected Flutter tests and existing test suite
- Build: signed per-ABI release APKs per repository instructions

**Interfaces:**
- Consumes: Tasks 2–6 已验收功能。
- Produces: 通过验证的签名 APK 和明确的设备验证限制。

- [ ] 检查窄屏、主题、文字缩放、侧栏/底栏、空/错/权限状态和非颜色状态编码。
- [ ] 运行格式化、定向 analyze、测试、`git diff --check`；报告实际结果。
- [ ] 按 `AGENTS.md` 生成版本元数据并构建签名 Release APK，核对包名、版本、签名和文件哈希。
- [ ] 不自动安装设备；交付 APK 绝对路径并列明未验证的真机/后台场景。

## 2026-11-05：直播刷新与多线路修复发布

用户授权本轮修复截图中的抖音刷新失败，对照原 Pure Live 保留多线路，在模拟器通过后提交、推送、云端编译并发布正式 Release。仅操作模拟器，不覆盖已连接的实体手机。

- [x] Android 签名诊断包可解析示例抖音离线房间；macOS 真实网络验证离线房间及三个直播间，每清晰度返回两条线路。截图中的连接失败尚未复现，不能宣称其特定网络根因已修复。回归复现连续三次刷新令并发升至 12，参照原项目刷新锁合并重复请求，保留平台错误隔离。
- [x] 对照 `Joe-Mu-Yu/pure_live` 核对完整线路列表；修复普通平台切线重新请求后 CDN 顺序改变导致选择错误，继续为签名恢复平台重新解析，不伪造 CDN 或流地址。
- [ ] 运行相关分析、Flutter 回归及版本脚本测试；签名构建后在模拟器实际测试刷新、播放与线路选择。
- [ ] 使用未占用的新版本标签，推送 `personal/main`；云端构建成功且产物版本/签名/源码通过验证后发布。

基线：工作区与远端 main 为 `9a8f92495bffeaf9c6ae1373cc0b236f847adf15`，正式版为 `v2.1.4.0`。旧 `v2.1.4.3` Release 已删除但 Git 标签仍存在，不能覆盖。SDK 预检通过（Flutter 3.47.4 / Dart 3.13.3）。macOS 真实网络可解析示例抖音离线房间，尚不能据此证明 Android 正常；模拟器已有旧实验版 2.1.4.1，其旧链接刷新错误不作为本次修复通过证据。

代码验证：全套 Flutter 测试 157 项通过；Python 发布脚本测试 20 项通过；定向分析无 error/warning，播放页既有 7 条 info 未作无关修改。修复前重复刷新回归失败（峰值 12，预期 ≤4）；切线回归失败（再次请求造成目标线路与实际 URL 不一致），修复后均通过。下一步为签名 APK 的模拟器完整页面与真实播放验证，通过后才推送发布 `v2.1.4.4`。

模拟器实测发现另一根因：导入的 Pure Live v3 备份有抖音收藏 `roomId` 是 `MS4...` 账号标识，迁移工具把它拼成 `live.douyin.com/MS4...`。新版本刷新其余抖音房间成功，但此条无法通过房间解析，导致页面一直显示“部分平台刷新失败”。这不是连接超时，不能把账号 ID 猜成直播间 ID。现在将这类记录标记“链接需要更新”，不删除旧收藏；用户可手动输入新的直播间链接，经真实解析验证后保留标签并替换。新增复现失败的 controller/UI 回归，修复后通过；全套测试 161 项通过。之前 157 项仅为修补迁移前的结果。下一步重编最终签名包，在模拟器复测并核对云端发布。
