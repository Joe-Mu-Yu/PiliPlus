# Pure Live 迁移审计（第一轮）

日期：2026-10-20；基线：`Joe-Mu-Yu/pure_live`，本地审计快照 `/tmp/pure_live_plan_audit`。

## 已核实

- 来源许可证文件为 AGPL-3.0；当前 PiliPlus 根目录许可证为 GPL-3.0。GNU AGPLv3 §13 对与 GPLv3 代码组合有明确兼容条款，但分发整合作品仍需按适用条款履行源码、许可和通知要求。本报告不构成法律意见；迁移时保留来源版权/许可证信息并复核打包分发方式。
- 来源 `pubspec.yaml` 的录制子系统使用 `ffmpeg_kit_extended_flutter: 0.6.2`；当前 PiliPlus 的 `pubspec.yaml` **没有**该包。先前“当前包已有 FFmpeg 扩展依赖”的判断是错误的，已纠正。不能仅因系统有 `media_kit` 就认定拥有 FFmpeg 录制能力。
- 来源 `lib/core/sites.dart` 声明 22 个平台 ID：Weibo、Niconico、Bilibili、Douyu、Huya、Douyin、Kuaishou、CC、IPTV、Twitch、SOOP、YY、AcFun、Picarto、Twitcasting、Missevan、Inke、Kilakila、Huajiao、OpenREC、TtingLive、Xiaohongshu。此为站点注册清单，不代表每个平台都支持关注管理或录制。
- 来源录制目录约 51 个 Dart 文件，包含 FFmpeg 命令/会话、FLV relay、后台服务、任务状态与持久化、重连/续录、设置及文件管理，属于完整子系统而非单页面。
- 当前 PiliPlus 导航枚举只有 Home、Dynamics、Mine；用户配置以枚举 index 存储，因此中间插入枚举值会导致旧配置索引错位。新增值应追加在末尾，并对非法旧 index 做健壮回退/迁移测试。
- 当前 PiliPlus 有 Bilibili `lib/pages/live_follow/` 页面，但无通用跨平台收藏 adapter，也无录制服务。PiliPlus Android manifest/原生层的现有服务不能直接替代录制前台服务。

## 依赖/实施影响

- 录制迁移至少需要审查 FFmpeg 扩展包版本、原生二进制 ABI/许可、Android 前台服务类型与通知权限，并与项目现有 Android 原生导航服务协调；不得直接改动或复用导航服务语义。
- 关注功能可先接入 PiliPlus 已有 Bilibili live follow 数据，再逐个审计其余站点的收藏来源和房间状态接口。首轮宜采用平台能力矩阵，不能将 22 个注册站点统称为“全平台关注/录制支持”。
- 来源使用 Hive、Dio/cookie jar、Drift、FFmpeg 扩展等多项依赖；应只迁移所需依赖，不能整体复制来源 `pubspec.yaml` 或覆盖当前 lockfile。

## 尚未完成的核验

- 静态源码核对：注册表包含 22 个站点；这些站点的 adapter 文件均声明 `LiveSiteRecordRoomResolver`。这只证明来源代码有“录制前房间信息解析”契约，不代表每个平台的 FFmpeg 输入、认证、后台行为或文件产物已验证可用。
- 显式链接解析器文件（源码中可定位到独立 `*_link.dart`）目前见于 Huajiao、Kilakila、Niconico、Openrec、TTing/FlexTV、Weibo、Xiaohongshu；其余平台可能在 adapter/API 中解析，需逐一追踪，不能据此标为不支持。
- 源码 `LiveSite` 提供统一房间详情、搜索、状态、清晰度和播放地址接口；接口默认实现可能返回空值/未知状态。各 adapter 的请求协议、登录 Cookie/token、直播流封装及 `getLiveStatus` 实现并不一致，尚未完成逐个平台调用链与合法使用条件审计。
- 当前只有源码静态审计，没有对 22 个平台进行网络请求、登录态或真实录制测试。逐站可用性结论均为“待验证”，不能用接口声明代替验证。
- AGPL 与所有来源第三方依赖的具体声明/二进制分发要求须在锁定迁移代码与依赖后复核。
- Android 目标版本上的长时后台录制、进程回收、通知权限与 SAF/MediaStore 输出必须在真实设备验证。

## 平台登记矩阵（来源代码静态观察）

“录制解析接口”只表示站点 adapter 声明了严格录制详情解析接口；“独立链接解析器”仅表示有单独 `*_link.dart` 文件。登录要求、协议与运行结果未通过网络/设备实测，因此明确记为待审计，而不是默认匿名可用或录制成功。

| 平台 ID | 独立链接解析器 | 录制解析接口 | 登录/流协议/真实录制 |
|---|---|---|---|
| weibo | 有 | 有 | 待逐站审计与实测 |
| niconico | 有 | 有 | 待逐站审计与实测 |
| bilibili | 未见独立文件 | 有 | 待逐站审计与实测；PiliPlus 既有 B 站直播能力不能直接证明 Pure Live 录制闭环 |
| douyu | 未见独立文件 | 有 | 待逐站审计与实测 |
| huya | 未见独立文件 | 有 | 待逐站审计与实测 |
| douyin | 未见独立文件 | 有 | 待逐站审计与实测 |
| kuaishou | 未见独立文件 | 有 | 待逐站审计与实测 |
| cc | 未见独立文件 | 有 | 待逐站审计与实测 |
| iptv | 未见独立文件 | 有 | 待逐站审计与实测；来源还存在用户自定义播放列表场景 |
| twitch | 未见独立文件 | 有 | 待逐站审计与实测 |
| soop | 未见独立文件 | 有 | 待逐站审计与实测 |
| yy | 未见独立文件 | 有 | 待逐站审计与实测 |
| acfun | 未见独立文件 | 有 | 待逐站审计与实测 |
| picarto | 未见独立文件 | 有 | 待逐站审计与实测 |
| twitcasting | 未见独立文件 | 有 | 待逐站审计与实测 |
| missevan | 未见独立文件 | 有 | 待逐站审计与实测 |
| inke | 未见独立文件 | 有 | 待逐站审计与实测 |
| kilakila | 有 | 有 | 待逐站审计与实测；链接解析使用 `pointycastle` 加密逻辑，带来依赖冲突 |
| huajiao | 有 | 有 | 待逐站审计与实测 |
| openrec | 有 | 有 | 待逐站审计与实测 |
| ttinglive | 有 | 有 | 待逐站审计与实测 |
| xiaohongshu | 有 | 有 | 待逐站审计与实测；短链解析有受限重定向会话 |

## 依赖路线决定

曾尝试把 `pure_live` 整个 Flutter 应用作为 Git package 引入；其 `pointycastle ^4.0.0` 与 PiliPlus 的 `encrypt ^5.0.3`（要求 `pointycastle ^3.6.2`）约束冲突，且两边偏好不同的 WebDAV、窗口和 UI 依赖来源。未保留这次试验产生的 overrides/vendor，不升级加密依赖绕过冲突。后续采用选择性移植并按功能闭包锁定依赖，除非先完成兼容性与回归验证。

## 许可边界确认

用户已明确接受按 AGPL 兼容方式继续迁移。来源 commit 的 `LICENSE` 标记 AGPL-3.0；GNU AGPLv3 第 13 节对与 GPLv3 程序组合的额外网络交互条款作出规定。实施需保留来源版权/许可与第三方通知，并在发布前复核组合分发、源码提供及网络交互义务；本记录不是法律意见。
