# 2026-11 迁移、安全与 Android 发布稳定化复盘

## 文档状态

- 复盘日期：2026-11-06
- 覆盖阶段：2026-11-03 至 2026-11-06
- 基线提交：`d9b17cb1122849a208d6edf194ea0eb8a932cad3`
- 最终发布：[`v2.3.0.2`](https://github.com/Joe-Mu-Yu/PiliPlus/releases/tag/v2.3.0.2)
- 对应工作流：[Hyper-PiliPlus Android Release](https://github.com/Joe-Mu-Yu/PiliPlus/actions/runs/42223920566)
- 性质：阶段复盘和后续操作依据，不替代 `AGENTS.md`、发布说明或安全响应流程

## 结论

本阶段最终恢复了包含 MIUIX、直播和小窝功能的完整 `2.3.0` 定制版本，并成功发布签名版 `v2.3.0.2`；但过程暴露出四类系统性缺口：交付源身份没有先锁定、客户端配置没有进入完整的密钥审查、CI 可复现性依赖外部镜像、发布验收没有覆盖 Runner 容量和更新通道。

这些问题不能归结为某一次命令写错。决定性原因是“源码、构建、发布、运行”之间缺少可核对的同一性证据，以及安全和 CI 检查只覆盖已知风险，没有覆盖生成配置、历史对象和外部执行环境。

## 影响与边界

### 已观察到的影响

1. 一度从错误 checkout 构建并打开应用，用户看到的版本缺少已经完成的 MIUIX、直播和小窝迁移功能，造成“修复是否丢失”的判断混乱。
2. 四个 Firebase/Google 客户端 API key 曾以字面量出现在公开 Git 历史中，GitHub Secret Scanning 产生四条公开泄露告警。
3. `v2.3.0.0` 因 Pub 镜像归档哈希与锁文件不一致而失败。
4. `v2.3.0.1` 越过依赖阶段后，GitHub-hosted runner 在生成 `app.dill` 时耗尽磁盘空间。
5. 更新检查依赖匿名 GitHub `releases/latest` 接口；仓库为私有时，客户端无法匿名获取最新 Release，因此即使发布成功也不会弹出更新提示。

### 没有证据支持的扩大结论

- 没有证据表明签名 keystore、签名密码、CloudBase 密码或 GitHub Actions Secret 值进入过 Git 历史。
- 没有证据表明暴露的客户端 API key 已被滥用；“尚未发现滥用”不等于 key 可以继续使用。
- 云端构建成功只证明构建、签名、验签和发布链路成功，不证明所有真机 UI、直播平台和双用户小窝路径都已通过人工验收。

## 关键时间线

| 时间（Asia/Shanghai） | 事件 | 结果/证据 |
| --- | --- | --- |
| 2026-11-03 | 加入个人仓库更新检查与 MIUIX 导航相关改动 | 提交 `d88d51e38`、`3802fda1c` |
| 2026-11-04 | 完整 Pure Live 源码回到主线并建立 Android Release 流程 | 提交 `3f1519d23`、`53e7b83a9` |
| 2026-11-06 17:23 | 恢复包含小窝的完整 `2.3.0` 应用 | 提交 `7289f9f29` |
| 2026-11-06 20:04 | 修复离开小窝再进入需要重新登录 | 提交 `835f0642e` |
| 2026-11-06 20:33 | 移除受跟踪文件中的 Firebase API key，改为构建期注入 | 提交 `c82ae4124`；`test/scripts/credential_hygiene_test.py` |
| 2026-11-06 20:57 | Release 依赖源切换为规范的 `pub.dev` 归档 | 提交 `34b5f7c26`；`v2.3.0.1` 越过依赖阶段 |
| 2026-11-06 21:14 | 发布前回收 Runner 中与 Android 无关的预装 SDK 空间 | 提交 `d9b17cb11` |
| 2026-11-06 后续 | `v2.3.0.2` 完成测试、分 ABI 构建、签名、验签和 Release | Actions 运行 `42223920566` 成功；Release 含三个 APK、元数据和 SHA-256 校验文件 |

## 根因与经验

### 1. 错工作区构建：把“代码存在”误当成“正在运行的就是这份代码”

**直接原因**

同一项目同时存在正式目录、Codex worktree 和旧集成目录，构建/启动前没有输出并核对完整的源身份。模拟器中出现的黑屏或旧界面最初被当成页面缺陷排查，延迟了对安装包来源的确认。

**为什么会影响判断**

Flutter 构建成功、APK 安装成功和用户实际看到目标提交是三种不同结论。只报告前两项，无法排除“构建了错误 checkout”“启动了另一个包”“设备保留旧安装”等情况。

**已采取措施**

- 唯一正式开发目录固定为 `/Users/morgan/Space/work/01-project/hyper-pili-plus`。
- 当前正式 `main` 跟踪 `personal/main`，阶段基线为 `d9b17cb11`。
- `AGENTS.md` 要求交付时同时报告源码路径/分支、包名/版本、是否安装与启动。

**以后必须执行**

任何 APK 构建、模拟器测试或发布前，先记录以下凭据；其中任意一项不一致时停止交付，不用 UI 表象猜版本：

```text
源码绝对路径
git remote -v
git status --short --branch
git rev-parse HEAD
包名、versionName、versionCode
目标设备实际安装包与启动状态
```

### 2. API key 公开：审查范围被“真正的服务端 Secret”锚定

**直接原因**

安全审查重点放在 keystore、密码、CloudBase 凭据和 GitHub Secrets，漏掉了 `third_party` 目录与生成的 Firebase 配置。客户端 API key 虽然最终会出现在 APK 中，但仍不应无限制地进入公开仓库和完整历史。

**更深层原因**

- 没有在第一次公开推送前扫描全部受跟踪文件和即将推送的历史。
- 把 `google-services.json` 视作普通生成配置，而不是需要明确决定是否跟踪的安全边界文件。
- 代码审查只看当前 diff，未把标签、旧分支和历史对象纳入暴露面。

**已采取措施**

- 删除并忽略 `android/app/google-services.json`。
- 第一阶段将 Firebase 客户端 key 改为编译期注入，Actions 只从加密 Secrets 读取；
  `2.3.0.3` 又彻底删除了主应用与 Pure Live 的 Firebase 运行时、依赖、
  Firestore 规则、广播工作流和构建参数，后续构建不再需要 Firebase key。
- 重写 `personal/main` 和当时的远端标签历史，并从全新远端镜像扫描所有可达引用。
- 新增 `test/scripts/credential_hygiene_test.py`，禁止受跟踪文件出现 Google API key 字面量，并禁止 `google-services.json` 回到工作树。

**仍未关闭的风险**

历史重写只减少旧值继续从仓库获取的机会，不能使已经看到或缓存的 key 失效。
虽然当前应用已不再使用 Firebase，四个历史暴露 key 仍必须在 Google Cloud/Firebase
控制台撤销或删除。完成前，安全事件状态只能标为“仓库与运行时已净化，旧凭据撤销待完成”。

**经验**

客户端 key 的正确目标不是“保证 APK 中不可提取”，而是最小权限和可撤销：仓库不保存字面量，构建系统按需注入，云端限制调用来源和 API，发现暴露后立即轮换。现有测试是针对已发生模式的回归保护，不是通用 Secret Scanner 的替代品。

### 3. Pub 镜像哈希失败：依赖版本锁定不等于归档来源可复现

**直接原因**

国内 Pub 镜像返回的 `flutter_inappwebview_ios 1.1.2` 归档内容与 lockfile 中的 SHA-256 不一致。继续重试同一镜像或删除锁文件都不会建立可信的可复现性。

**已采取措施**

- `pubspec.lock` 与 Android Release CI 统一使用 `https://pub.dev`。
- 在全新 Pub 缓存中执行 `pub get --enforce-lockfile`。
- 保留原依赖版本，只迁移 hosted URL，不用全量升级掩盖归档问题。
- `test/scripts/signing_workflow_test.py` 固定检查 Release 工作流的 Pub 来源。

**经验**

依赖故障要先区分“版本解析错误”“来源归档变化”和“本机缓存掩盖问题”。本机已有缓存下的成功不能替代首次云构建；锁文件冲突也不能通过删锁或 `pub upgrade` 规避。

### 4. Runner 磁盘耗尽：配置校验成功不等于执行资源足够

**直接原因**

`v2.3.0.1` 已通过依赖和前置测试，但 GitHub-hosted runner 在 AOT 产物写入阶段出现 `No space left on device`。工作流此前没有为固定 Flutter SDK、Android SDK/NDK、Gradle 和分 ABI 产物预留空间预算。

**已采取措施**

- 构建前只删除与本 Android 发布无关的预装 GHC、CodeQL、Boost、.NET 和多版本 NDK。
- 随后安装项目固定的 NDK `28.2.13676358`，避免删错实际依赖。
- 自动化测试限定清理目标，防止把广泛 `rm` 变成不可审查的空间修复。
- `v2.3.0.2` 已实际通过云端构建和发布，证明这项改动解决了本次 Runner 容量故障。

**经验**

CI 的验收必须到“真实云端运行结果”，`actionlint` 和本机构建只能证明语法或局部流程。空间清理必须精确列出可再生目标；不要清空整个工具链，也不要把旧 APK 当成本次产物。

### 5. 更新弹窗缺失：发布成功与客户端可发现发布是两条链路

**直接原因**

应用通过匿名 GitHub REST API 的 `releases/latest` 查询更新。仓库为私有时匿名请求不可用；Debug 模式、自动检查被关闭、Release 为草稿/预发布或版本未变大时也不会弹窗。

**已确认事实**

- `v2.3.0.2` 是正式 Release，不是 draft 或 prerelease。
- 当前版本比较使用四段数字。
- 截止本次复盘时仓库为公开，因此“私有仓库匿名 404”不再是当前状态，但仓库可见性再次变化时问题会复现。

**经验与后续架构方向**

源码托管和应用更新通道不应被迫具有相同可见性。若以后保持源码私有，应使用单独的公开 Release 仓库，或使用 CloudBase/COS 提供版本 JSON 与 APK；不能把 GitHub Token 内置到客户端来访问私有 Release。

## 已落地的永久防线

| 风险 | 防线 | 所有者位置 | 证据等级 |
| --- | --- | --- | --- |
| 构建错 checkout | 交付凭据要求：路径、分支/提交、包名/版本、安装/启动状态 | `AGENTS.md` | 流程规则，待后续任务持续观察 |
| Google API key 再次进入源码 | 字面量扫描；禁止 `google-services.json` | `test/scripts/credential_hygiene_test.py` | 自动化回归已通过 |
| Pub 镜像归档不一致 | Release 使用 `pub.dev`；强制 lockfile | `.github/workflows/android-release.yml`、`pubspec.lock` | 全新缓存与云端运行通过 |
| Runner 磁盘耗尽 | 精确回收无关预装 SDK；固定 NDK | `.github/workflows/android-release.yml` | `v2.3.0.2` 云端运行通过 |
| 标签、配置、包内版本漂移 | 四段版本元数据与工作流前置校验 | `scripts/release_metadata.py`、发布测试 | 自动化回归与正式 Release 通过 |
| 发布了但客户端不可发现 | 记录匿名 API、仓库可见性和正式 Release 条件 | `docs/android-release.md` | 条件性支持；仍与可见性耦合 |

## 发布前最小检查表

以下检查只补充高风险断点，不替代 `AGENTS.md` 中的完整构建和验签流程。

### 源身份

- [ ] 当前目录是正式项目绝对路径，不是废弃或临时 worktree。
- [ ] `git status --short --branch`、远端、HEAD 和目标分支已记录。
- [ ] 构建配置生成的包名和四段版本与目标 Release 一致。

### 安全

- [ ] 对全部受跟踪文件运行凭据卫生测试。
- [ ] 新增的生成配置、`third_party`、示例文件和日志已纳入审查。
- [ ] 若发现暴露，先撤销/轮换，再净化当前树与可达历史；不能只删当前文件。
- [ ] 客户端 API key 已设置应用和 API 范围限制。

### 可复现构建

- [ ] 固定 Flutter 提交和 SDK 补丁校验通过。
- [ ] 全新环境使用 `pub get --enforce-lockfile`，不依赖本机旧缓存。
- [ ] CI 依赖源、Android SDK 和 NDK 与项目说明一致。
- [ ] Runner 有足够空间；清理动作只针对明确可再生且与发布无关的目标。

### 交付

- [ ] 区分并分别记录：代码检查、本地构建、云端构建、签名验签、Release 创建、设备安装、真实用户路径。
- [ ] Release 不是草稿或预发布，包含三个 ABI APK、元数据和校验文件。
- [ ] 更新查询通道对客户端可访问，版本高于当前安装包。
- [ ] 未执行的真机/双用户/外部平台验证明确列为未验证，不能由 CI 成功代替。

## 遗留事项和关闭条件

### P0：轮换并限制历史暴露的四个客户端 key

关闭条件：旧 key 在 Google Cloud/Firebase 控制台撤销或删除；GitHub Secret
Scanning 告警关闭；仓库的 Firebase 退役测试、凭据卫生测试以及无 Firebase 构建通过。

### P1：解耦源码可见性与更新分发

关闭条件：确定长期策略——保持仓库公开，或迁移到独立公开 Release/CloudBase/COS 更新源；私有源码方案必须在无客户端 GitHub Token 的条件下完成真实更新检查。

### P1：补充发布源身份的自动校验

目前“路径/远端/HEAD/包名/版本”主要靠流程约束。若后续再次出现错 checkout 或错安装包，应把这些信息写入统一的发布预检脚本和 Release 元数据，避免继续增加口头规则。

## 后续观察指标

在后续三个 Android 发布或相关长任务中观察：

1. 是否再次发生构建源、安装包或模拟器目标混淆。
2. 凭据测试是否在推送前阻止新的字面量；是否仍有 Secret Scanning 告警。
3. 从 CI 首个真实错误到定位根因，是否不再经过无证据的重复重跑。
4. 最终回报是否能明确区分“检查通过”“构建成功”“Release 成功”和“真机功能通过”。
5. 更新提示是否在目标仓库可见性和正式 Release 条件下稳定出现。

若这些指标没有改善，应收窄或自动化现有规则，而不是继续堆叠更多说明文字。

## 证据状态与资料

### 已验证

- 本仓库提交、标签、自动化测试和工作流配置。
- GitHub Actions 运行 `42223920566` 与 `v2.3.0.2` Release 资产。
- 远端历史净化后的可达引用扫描结果。

### 条件性支持

- 更新提示恢复依赖仓库继续公开、客户端开启自动检查、运行 Release 构建且版本更高；任一条件变化都可能不弹窗。
- Runner 空间清理已解决本次故障，但 GitHub-hosted runner 镜像以后可能变化，仍需以每次真实运行结果为准。

### 待验证

- 四个历史暴露 key 是否已在 Google Cloud/Firebase 控制台完成轮换、撤销和调用限制。
- `v2.3.0.2` 在用户真机上的完整直播、小窝双用户和更新弹窗路径。

### 本轮核对的官方资料

- GitHub Docs（持续更新），[Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)：支持“重写历史后仍需撤销/轮换 Secret，并处理克隆和缓存”的响应原则。
- GitHub Docs（持续更新），[GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)：Runner 镜像和能力属于外部执行环境，应以实际运行核验。
- GitHub Docs（持续更新），[Get the latest release](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)：说明客户端查询正式 latest Release 的接口边界。

这些外部资料只支持通用处理原则；本项目措施是否有效，以仓库自动化、云端运行和真实设备结果为准。
