# 私有广播消息与自愿位置共享

## 目标

- 管理员可以向已启用通知的 Hyper-PiliPlus 安装实例发送公告。
- 每个安装实例只有在使用者主动启用位置共享并授予系统定位权限后，才上报位置。
- 管理员可以查看已授权实例的最新位置和更新时间。

## 范围与隐私边界

- 首期只覆盖 Android；消息到达受网络、系统通知授权、设备省电策略和应用强制停止状态影响，不承诺所有设备即时送达。
- 广播使用 Firebase Cloud Messaging (FCM) 的固定 topic；从 Firebase Console 的 Notifications Composer 发送。应用前台显示站内提示，后台显示系统通知。
- 位置共享默认关闭，先只在应用前台运行时更新；不申请后台定位权限，不保留历史轨迹。
- 用户关闭共享时停止定位并删除该安装实例保存的最新位置；用户拒绝定位权限时，其他功能照常可用。
- 用 Firebase Anonymous Auth UID 区分安装实例，不读取 IMEI、广告 ID 或其他硬件标识；提供用户可编辑的设备别名。
- Firestore 每个安装实例只保存一条最新记录；客户端规则限制只能写入自己的文档。管理员通过其 Firebase 项目控制台查看。
- 不把服务帐号私钥、FCM 服务端凭证或任何 Admin SDK 凭证放入 App、仓库或 APK。

## 架构决定

- 使用一个由 Joe-Mu-Yu 控制的独立 Firebase 项目，承载 FCM、Firebase Anonymous Auth 和 Cloud Firestore。
- 不复用 `third_party/pure_live` 中现有的 Firebase 项目配置 (`pure-live-26c7f`)：其用途属于第三方直播模块，当前没有证据证明用户拥有该项目或其数据管理权。
- 不额外部署自建服务器或 Firebase Cloud Functions。公告由 Firebase Console 发送至 topic；设备位置只写入 Firestore 自己的 UID 文档，管理员用 Firebase Console 查看。
- 控制台里的集合和字段只存设备别名、经纬度、精度、更新时间与必要的共享状态。首期不保存历史位置。

## 验收

- 首次启用通知时请求 Android 通知权限；通过后订阅固定广播 topic。权限拒绝或关闭通知时界面显示当前状态，不影响应用其他功能。
- 在 Firebase Console 向广播 topic 发送一条测试消息：前台收到站内提示；后台收到系统通知；点击后打开应用并展示消息内容。
- 设置中位置共享默认关闭。打开时先展示用途说明，再请求定位权限；仅在两者都允许时上报。
- 使用模拟器定位验证：Firestore 只出现当前 UID 的单条最新记录；更新时间及经纬度匹配模拟器位置。
- 关闭共享或撤销权限后不再上报，且当前 UID 的位置记录被删除；其他 UID 记录不受影响。
- Firestore Rules Emulator 覆盖未认证、跨 UID 读写、本人写入/删除和管理员控制台访问边界。
- 构建签名 Release APK；在模拟器中分别验证授权、拒绝、关闭、前后台消息、无网络恢复等路径。

## 外部前置条件

实现前需在用户控制的 Firebase 项目中启用 Cloud Messaging、Anonymous Authentication 与 Firestore，并生成本项目 Android app 的 Firebase 配置。部署 Firestore Rules 需要项目所有者权限。当前仓库没有这些外部资源的授权或凭证，不能把第三方直播模块的 Firebase 配置用于位置数据。

## 实施顺序

1. 创建/确认独立 Firebase 项目和 Android app 配置，验证 Firestore 与 FCM 可用。
2. 加入客户端初始化、通知权限、topic 订阅、前台/后台消息处理与公告提示。
3. 加入自愿共享设置、前台定位、匿名安装身份、最新位置写入与撤回删除。
4. 添加最小权限 Firestore Rules 及 Rules Emulator 回归覆盖。
5. 完成 Firebase Console 操作说明、签名构建、模拟器端到端验证。
