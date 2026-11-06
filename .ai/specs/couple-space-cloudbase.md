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
