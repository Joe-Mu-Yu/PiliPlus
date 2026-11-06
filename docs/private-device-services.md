# 个人公告与设备位置

## Firebase 一次性设置

工程使用独立 Firebase 项目 `hyperpiliplus`，不复用 Pure Live 的 Firebase 项目。

1. 在 Firebase Authentication 的登录提供商中启用 **匿名**。
2. 创建 Cloud Firestore 数据库，选择 **生产模式**。
3. 在工程根目录安装并登录 Firebase CLI，然后执行：

   ```sh
   firebase deploy --only firestore:rules --project hyperpiliplus
   ```

   此命令会发布仓库中的 `firestore.rules`。本工程不会自动部署规则。
4. Android Firebase 应用包名必须是 `com.aritxonly.hyperpiliplus`。轮换并限制 Android API key 后，通过构建参数注入，不要把 `google-services.json` 或 key 提交到 Git：

   ```sh
   ./scripts/flutterw build apk \
     --dart-define=HYPER_FIREBASE_ANDROID_API_KEY="$HYPER_FIREBASE_ANDROID_API_KEY" \
     --dart-define=PURE_LIVE_FIREBASE_ANDROID_API_KEY="$PURE_LIVE_FIREBASE_ANDROID_API_KEY"
   ```

   本地变量值、CI Secrets 和生成的配置文件都不得提交。其他平台分别使用 `PURE_LIVE_FIREBASE_APPLE_API_KEY` 与 `PURE_LIVE_FIREBASE_WINDOWS_API_KEY`。

## 发送公告

在 Firebase Console → **Messaging** → **Create your first campaign / Notifications** 创建通知，目标选择 **Topic**，topic 填 `hyperpiliplus_broadcast`。设备只有在应用的“设置 → 隐私设置 → 广播与位置共享”中开启接收公告并允许系统通知后才会订阅。

应用在前台时显示站内提示；在后台时由 Android 显示通知。点击后台通知会打开应用并提示消息内容。系统省电策略、网络状态及强行停止应用可能影响送达时间。

## 查看位置

在 Firebase Console → **Firestore Database → Data → `device_locations`** 查看各设备的最新记录。每个匿名安装身份只有一个文档，包含设备别名、纬度、经度、精度和更新时间。把 `latitude`、`longitude` 复制到地图搜索框，或使用 `https://maps.google.com/?q=纬度,经度` 打开地图。

应用默认不共享位置。开启前会说明数据内容；定位只在应用前台并取得使用期间定位授权后更新。关闭开关会停止采集并删除该 UID 的最新文档。若卸载应用或清除其数据，设备无法发送删除请求，最后一条记录可能留在 Firestore，需要在控制台手动删除。

Firestore 规则禁止客户端读取位置文档，并只允许已认证设备写入/删除自己的 UID 文档。项目所有者仍可从 Firebase Console 管理这些数据。Firebase 客户端 API key 最终会存在于安装包中，不能当作服务端秘密；必须在 Google Cloud Console 限制到对应 Android 包名与签名证书，并限制可调用 API。仓库仍不保存这些 key，也绝不能保存服务账号私钥或 Admin SDK 凭证。
