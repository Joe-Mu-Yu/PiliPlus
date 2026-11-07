# 小窝 CloudBase 协作存储

## 目标与边界

- 两位已认证用户共享一个小窝，数据与照片存放在腾讯云 CloudBase 国内站。
- 保留 `coupleSpace.data.v1` 本地快照，作为离线失败恢复与首次迁移来源。
- 不在客户端保存 CloudBase API Key、腾讯云 Secret 或用户密码；会话令牌仅保存在当前进程内。
- 不创建或保留代替真实用户的正式账号，不提交、推送或发布应用。

## 数据方案

- `couple_spaces` 保存空间及两位成员 UID。
- `couple_space_state` 保存当前页面 JSON 状态和递增 `revision`。
- `couple_space_invites` 保存随机、短时、一次性邀请码，仅能通过安全 RPC 使用。
- `create_couple_space`、`create_couple_space_invite`、`join_couple_space`、`save_couple_space_state` 负责原子业务操作。
- `couple-space` 为私有 PG Storage bucket，object key 为 `<spaceId>/<userId>/<uuid>.<ext>`。

## 冲突与安全

- 保存时提交客户端读取到的 `revision`；不匹配则拒绝写入并重新加载云端版本。
- 表级权限和 RLS 限定为成员读取；邀请与保存只能通过校验 `auth.uid()` 的 RPC。
- 共享空间的两位成员都可以维护页面内容与删除共享照片。
- 未登录、未加入空间时不能读取任何小窝数据或照片。
- 早期细粒度表 `couple_space_moments/comments/entries` 暂不由客户端使用，
  `anon` 与 `authenticated` 权限及策略均已撤销，避免形成旁路写入口。

## 客户端流程

1. 用户名密码登录 CloudBase。
2. 新建空间或用邀请码加入已有空间。
3. 加载云端状态；若存在本地旧数据，允许一次性迁移到云端。
4. 修改内容时先写云端，成功后更新本地快照；失败时保留待同步快照。
5. 照片先上传私有桶，再把 object key 保存到状态；展示时获取短期签名 URL。

## 2026-11 生活化改版

### 调研结论

- Apple 中国区应用元数据与产品官方页显示，小恩爱、恋爱记、Between、SumOne
  的共同高频路径是双人私密表达、共同相册、自动累计相伴天数、纪念日和轻量共同任务。
- 本次不引入定位、虚拟养宠、现金打卡等高成本或与当前产品定位无关的功能；首页只保留两人每天会使用的记录与回看入口。
- 页面视觉采用温暖克制的生活手账层级，而不是将所有功能做成相同权重的卡片。

调研来源（2026-11-07 访问）：[小恩爱 App Store](https://apps.apple.com/cn/app/id524690790)、
[恋爱记 App Store](https://apps.apple.com/cn/app/id590246583)、
[Between 官方产品页](https://between.us/?lang=zh_hans)、
[SumOne App Store](https://apps.apple.com/cn/app/id1469506430)。竞品页面只用于归纳共同使用路径，
未复制其品牌素材、布局或付费玩法。

### 用户故事与验收标准

- 当成员进入首页时，系统应以本地自然日从 `startDate` 实时计算相伴第几天，起始日为第 1 天；跨午夜重新构建页面后数值应增加，未来日期应显示为尚未开始。
- 当成员创建纪念日时，系统应允许选择恋爱、生日、节日或自定义类型，并选择不重复或每年重复；列表应优先显示下一次即将到来的日期，同时正确显示“还有 N 天”“就是今天”或“已过去 N 天”。
- 当成员编辑或删除纪念日时，另一位成员应通过既有 revision 同步看到同一结果；旧版仅含 `title/date` 的项目应无损补齐默认字段。
- 当成员录制心语时，系统应在获得麦克风权限后录制最长 120 秒的 AAC/M4A 文件，停止后先上传私有 `couple-space` bucket，再将 object key、时长、作者和时间写入共享 payload；上传失败不得产生空心语，并应清理临时文件和已上传孤儿对象。
- 当任一成员播放语音心语时，系统应临时签发私有访问 URL，并支持播放、暂停及切换；删除语音心语后应同时删除 CloudBase 对象。
- 当页面处于窄屏时，首页应为单栏；可用宽度不小于 720dp 时应为双栏。文字放大、深色模式、空数据、加载和失败状态均应保持可操作。

### 数据兼容

- `messages` 新增兼容字段：`id`、`type` (`text`/`voice`)、`text`、
  `audioPath`、`audioDurationMs`、`authorId`、`authorName`、`mood`、`date`。
  旧消息缺少 `type` 时按文字心语处理。
- `days` 新增兼容字段：`id`、`type` (`love`/`birthday`/`festival`/
  `custom`) 和 `repeat` (`none`/`yearly`)；旧纪念日按自定义、不重复处理。
- 语音与照片沿用同一个私有 bucket 和成员 RLS，不新增公开 URL、业务表或客户端密钥。
- `couple-space` bucket 保持私有，并将 `audio/mp4`、`audio/aac`、
  `audio/x-m4a` 加入 MIME 白名单；对象路径继续使用
  `<spaceId>/<userId>/<uuid>.<ext>`，由成员 RLS 限制读写。

### 废弃 Firebase

- 主应用公告、位置共享以及 Pure Live 的 Firebase 登录/Firestore 配置同步已经移除；
  小窝共享数据只使用 CloudBase PG 与私有 pgstore bucket。
- Pure Live 的本地文件备份、WebDAV 和局域网同步属于独立的手动备份功能，
  不参与小窝数据同步，也不在应用启动时连接 Firebase。

## 验收

- Dart 格式化、定向 analyze 与仓库回归测试通过。
- SQL migration 通过 CloudBase plan/apply 并复查表、函数、GRANT、RLS。
- 两个真实 CloudBase 用户完成：登录、建空间、邀请码加入、双端读写、冲突提示、照片上传/展示/删除。
- 生成并验签 Release APK；不自动安装或清理用户设备数据。

## 实际验证记录

- 2026-11-06 使用两名临时 CloudBase 应用用户完成国内站真实端到端测试：
  登录、建窝、一次性邀请码加入、双方读写、revision 冲突保护、私有照片上传、
  跨成员签名 URL 与删除均通过。
- 测试后已删除临时小窝、存储对象和两名临时用户；环境仅保留正式 schema、
  私有 bucket、RLS/RPC 以及原有管理员。
