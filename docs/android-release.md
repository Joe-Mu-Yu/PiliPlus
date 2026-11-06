# Hyper-PiliPlus Android 签名发布

## 版本规则

`pubspec.yaml` 保持三段语义版本（现在是 `2.3.0+1`），不要改成四段，以免破坏 Pub / 其他平台构建。
`tool/release.json` 记录对应的 `upstreamVersion` 和本分支 `revision`：

- 当前配置版本：`2.3.0.0`；同一版本后续修复继续递增 revision。历史标签不覆盖。
- 升级上游版本时，同步修改 `pubspec.yaml` 与 `upstreamVersion`，并将 `revision` 重置为 `0`。
- Android `versionName` 与应用内版本均为四段，不再附加提交哈希；哈希单独保存到 `pili.hash`。
- `versionCode = major × 10000000 + minor × 100000 + patch × 100 + revision`；当前配置版本对应 `20300000`。
- 范围：major 0–199，minor 0–99，patch 0–999，revision 0–99。脚本拒绝超界，以保证升级顺序和 Android 整数限制。
- Release 标签严格为 `v上游版本.修订号`，例如当前配置版本为 `v2.3.0.0`。正式发布后不可覆盖同一标签；发布修复版必须递增 revision。

## 配置签名 Secrets

仓库：`Joe-Mu-Yu/PiliPlus` → Settings → Secrets and variables → Actions。
按 GitHub 的 [Secrets 文档](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets) 添加：

| 名称 | 内容 |
| --- | --- |
| `SIGN_KEYSTORE_BASE64` | 已有 Release keystore 的 Base64 编码 |
| `KEYSTORE_PASSWORD` | keystore 密码 |
| `KEY_ALIAS` | 签名密钥别名 |
| `KEY_PASSWORD` | 密钥密码 |
| `DEEPSEEK_API_KEY` | 可选；用于以 `deepseek-v4-flash` 生成中文 Release Notes |
| `HYPER_FIREBASE_ANDROID_API_KEY` | 必填；主应用 Android Firebase 客户端 key，需轮换并限制到包名与签名证书 |
| `PURE_LIVE_FIREBASE_ANDROID_API_KEY` | 必填；Pure Live Android Firebase 客户端 key，需轮换并限制到 Android 应用 |

**必须使用此前本机 Release 的同一把签名密钥**，否则无法覆盖安装并保留现有应用数据。不要重新生成密钥替代旧密钥。
Base64 不是加密；不要将编码内容、密码、`key.properties` 或 keystore 提交到 Git。
工作流仅在临时目录解码 keystore，密码由环境变量传给 Gradle，构建结束清理临时文件。
发布任务会把当前 flavor 版本与上一个四段版本标签之间的提交标题交给 DeepSeek 生成用户可读摘要。该步骤在版本标签推送或手动勾选 `publish` 时执行；没有配置 `DEEPSEEK_API_KEY`、接口超时或返回无效内容时，会自动改用确定性的提交摘要，不会阻塞发布。
提交标题属于不可信输入，生成提示明确禁止执行其中的指令；密钥、签名材料和其他 Actions Secrets 都不会发送给模型。
缺少任意签名项会失败，不会以 debug 签名发布。APK、版本元数据及校验和以外的文件不会上传。
签名配置检查在检出源码后、下载 SDK 和依赖之前执行，一次列出所有缺失的 Secret 名称。密钥文件仍在构建前才解码，并为无效 Base64 或空 keystore 提供独立错误提示；不输出 Secret 值。
若出现 `Missing release signing secrets`，先核对运行所在仓库与上述四个名称。组织级 Secrets 必须授权当前仓库；仅配置在 Environment 中的 Secrets 不会自动提供给未指定该 Environment 的任务。本工作流默认读取仓库可用的 Secrets。复用调用必须显式传递四项，或像 `build.yml` 一样使用 `secrets: inherit`。
只上传此前已使用的 Release 密钥及配套密码，不要用新密钥、其他应用的密钥或 debug 密钥绕过检查。修改工作流后，从目标分支新建运行；旧任务的 Re-run 不会改用新提交的工作流。
只在受信任的分支执行签名构建，不要将 Secrets 暴露给外部 PR 的代码。

## 推送版本标签自动发布

将包含本工作流的源码合入 `main` 后，推送 `v上游版本.修订号` 格式的标签会自动运行 **Hyper-PiliPlus Android Release**。普通分支推送不会触发发布。工作流构建标签指向的提交，使用已有签名 Secrets 生成三种 ABI 的 APK，验签成功后创建正式 Release，并上传 APK、`SHA256SUMS` 和 `release-metadata.json`。

发布前先查看仓库现有 Releases，选择尚未使用且比已发布版本更高的四段版本，并修改 `tool/release.json` 的 `revision`。例如当前版本为 `2.3.0.0`，后续修复版将 `revision` 递增为 `1`，生成 `2.3.0.1`。以下命令需在包含所有待发布源码和工作流的本地分支执行：

```sh
git add tool/release.json
git commit -m "chore: prepare release 2.3.0.1"
git push origin HEAD:main
git tag -a v2.3.0.1 -m "Hyper-PiliPlus 2.3.0.1"
git push origin refs/tags/v2.3.0.1
```

示例版本不是自动分配的版本；执行时必须替换为实际的下一个版本。标签必须与 `pubspec.yaml`、`tool/release.json` 共同确定的版本严格一致，否则在安装 SDK 和构建之前失败。标签触发时不运行自动递增逻辑，确保标签、包内版本和 Release 名称一致。不要移动或强制覆盖已发布标签。先合入工作流再打新标签；给旧提交打标签不会让它获得新工作流。

前提是仓库已配置上述四项签名 Secrets，并允许 Actions 使用 `GITHUB_TOKEN` 写入 Releases。实际云端成功与否，以该标签对应的 Actions 运行结果及 Release 资产为准。

## 手动构建与发布

1. 确保本工作流文件已进入 GitHub 默认分支，并确认上述 Secrets 已配置。仅把功能分支推上去还不能从 Actions 页面运行此工作流。
2. Actions → **Hyper-PiliPlus Android Release** → Run workflow。
3. `publish` 默认关闭：仅生成三种 ABI 的签名 APK，下载名称带当前版本号的 Artifact。
4. 勾选 `publish`：构建和签名验证成功后创建当前四段版本对应的正式 Release，附 APK、SHA256SUMS 和 release-metadata.json。
5. 老的 **Build** 工作流中的 Android 选项也复用新流程。若填写 tag，必须与配置生成的标签完全一致；它的其他平台仍沿用上游流程与三段版本。

应用启动后自动通过 `Joe-Mu-Yu/PiliPlus` 的 `/releases/latest` 接口检查更新，也可在关于页手动检查；按四段数字而不是时间比较，同版本重编译不会反复提示。可在设置中关闭或重新开启自动检查。
草稿、预发布和三段旧标签不会被当成新的正式 flavor 版本。只有上传 Artifact、不发布 Release 时，不会触发应用更新提示。
详情参见 GitHub 的 [Release API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)。

## 构建环境

流程基于 [PiliPlus 上游 Android 工作流](https://github.com/bggRGjQaUbCoE/PiliPlus/blob/main/.github/workflows/build.yml) 的迁出、Java、SDK 补丁、签名、分 ABI 构建、上传与发布步骤。
为保留本分支功能，使用固定 Flutter 提交和 `tool/flutter-sdk.patch`，再按上游顺序应用 `lib/scripts/material/` 的 Android 包补丁。
包目录从 `.dart_tool/package_config.json` 读取，不猜测缓存目录。签名构建要求显式启用 `requireReleaseSigning`。

Android SDK 平台的安装标识为 `platforms;android-37.0`（包含 `.0`），不是 `platforms;android-37`；Gradle 的 `compileSdk` / `targetSdk` 仍填写整数 `37`。工作流安装后会检查对应 `android.jar` 是否存在。

Flutter 按固定 SHA 检出后还必须获取官方 `3.47.4` 标签：仅有提交的浅克隆可能被 Flutter 识别成 `0.0.0-unknown`。工作流显式获取并校验标签对应的提交，单独执行 `flutter --version` 完成首次初始化，再读取 Flutter 自动生成的 `bin/cache/flutter.version.json`，核对版本与 `.fvmrc`、提交与 SDK HEAD 一致。不要直接将首次启动的 stdout 管道交给 JSON 解析器：其中可能混入工具自身的依赖解析日志。此过程不修改或伪造 SDK 版本。

首次云构建使用仓库 `pubspec.lock`（`--enforce-lockfile`）。它与旧本机缓存存在已知差异（见 [Flutter 环境说明](flutter-environment.md)），因此本机成功不能代替首次云运行验证；如锁文件/补丁不兼容，流程会停止，不会静默升级依赖或发布。

本机使用已有签名配置构建同规则版本：

```sh
python3 scripts/release_metadata.py
./scripts/flutterw build apk --release --split-per-abi --no-pub \
  --build-name=2.3.0.0 --build-number=20300000 \
  --dart-define-from-file=pili_release.json \
  --dart-define=HYPER_FIREBASE_ANDROID_API_KEY="$HYPER_FIREBASE_ANDROID_API_KEY" \
  --dart-define=PURE_LIVE_FIREBASE_ANDROID_API_KEY="$PURE_LIVE_FIREBASE_ANDROID_API_KEY" \
  --android-project-arg requireReleaseSigning=true
```

后续版本参数以元数据脚本输出为准。本流程不会自动替你推送提交、上传 Secrets 或启动远端构建。
