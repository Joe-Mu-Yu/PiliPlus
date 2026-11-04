# Firebase 个人广播消息

## 当前发送方式

消息通过 GitHub Actions 手动发送到 Firebase Cloud Messaging 主题
`hyperpiliplus_broadcast`。只有在 App 设置中开启“接收个人公告”并允许系统通知的设备才会订阅此主题。

工作流仅使用临时 Google Cloud 访问令牌。不要创建或提交服务账号 JSON 密钥，也不要把 FCM 发送凭据放进 App。

工作流文件必须先进入 GitHub 仓库的默认分支，随后从 **Actions → Firebase personal broadcast → Run workflow** 输入标题和正文。先选择默认的 `validate-only` 检查权限与消息格式；该模式不会投递给设备。确认验证通过后，再显式选择 `send`，它会发给该主题下全部订阅设备。运行成功表示 FCM 接受了发送请求，不保证每台设备已在线或实际显示消息。

## 一次性 Google Cloud 配置

项目为 `hyperpiliplus`，项目编号为 `1043412509094`。在 Google Cloud Console 的 Cloud Shell 中执行以下命令。若其中某个资源已存在，可跳过对应的创建命令。

先在 Cloud Shell 设置后续命令共用的名称：

```sh
PROJECT_ID=hyperpiliplus
PROJECT_NUMBER=1043412509094
FCM_SA_NAME=fcm-topic-sender
FCM_SA="${FCM_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
```

### 1. 启用所需 API 并创建专用服务账号

```sh
gcloud config set project hyperpiliplus

gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  cloudresourcemanager.googleapis.com \
  fcm.googleapis.com

gcloud iam service-accounts create fcm-topic-sender \
  --project="${PROJECT_ID}" \
  --display-name="Hyper-PiliPlus FCM topic sender"

gcloud iam roles create fcmBroadcastSender \
  --project="${PROJECT_ID}" \
  --title="FCM broadcast sender" \
  --description="Send FCM messages and read required project metadata" \
  --permissions=cloudmessaging.messages.create,firebase.clients.get,firebase.clients.list,firebase.links.list,firebase.projects.get,resourcemanager.projects.get,resourcemanager.projects.getIamPolicy,resourcemanager.projects.list,apikeys.keys.get,apikeys.keys.list,apikeys.keys.lookup,serviceusage.operations.get,serviceusage.operations.list,serviceusage.quotas.get,serviceusage.services.get,serviceusage.services.list \
  --stage=GA

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${FCM_SA}" \
  --role="projects/${PROJECT_ID}/roles/fcmBroadcastSender"
```

如果 Google Cloud 要求先关联结算账号，不要为了本功能直接启用付费服务；先停在该页面并确认项目当前结算状态。

### 2. 建立仅信任此 GitHub 仓库发送工作流的身份池

```sh
gcloud iam workload-identity-pools create github-actions \
  --project="${PROJECT_ID}" \
  --location=global \
  --display-name="GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc github \
  --project="${PROJECT_ID}" \
  --location=global \
  --workload-identity-pool=github-actions \
  --display-name="Joe-Mu-Yu PiliPlus broadcast workflow" \
  --issuer-uri="https://token.actions.githubusercontent.com/" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.event_name=assertion.event_name,attribute.workflow_ref=assertion.workflow_ref" \
  --attribute-condition="assertion.repository == 'Joe-Mu-Yu/PiliPlus' && assertion.event_name == 'workflow_dispatch' && assertion.workflow_ref.startsWith('Joe-Mu-Yu/PiliPlus/.github/workflows/firebase-broadcast.yml@')"

gcloud iam service-accounts add-iam-policy-binding \
  "${FCM_SA}" \
  --project="${PROJECT_ID}" \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-actions/attribute.repository/Joe-Mu-Yu/PiliPlus"
```

该条件把外部身份限制为个人仓库中的手动广播工作流。自定义角色允许发送 FCM 消息，并包含 Firebase API 要求的只读项目元数据权限；不包含 Firestore 数据读取或管理权限。

### 3. 在 GitHub 仓库设置两个变量

进入 **Settings → Secrets and variables → Actions → Variables**，新增：

| 变量 | 值 |
| --- | --- |
| `GCP_WIF_PROVIDER` | `projects/1043412509094/locations/global/workloadIdentityPools/github-actions/providers/github` |
| `FCM_SENDER_SERVICE_ACCOUNT` | Cloud Shell 中 `echo "$FCM_SA"` 输出的服务账号邮箱 |

这两个值是资源标识符，不是密钥，因此设置为 Repository variables 即可。无需添加 JSON 密钥。

## 发送与验收

1. 每台 Android 设备在 App 的 **设置 → 广播与位置共享 → 接收个人公告** 开启接收并允许系统通知。
2. 确认本工作流已进入 GitHub 仓库默认分支。
3. 在 GitHub **Actions → Firebase personal broadcast → Run workflow** 输入标题、正文并选择 `validate-only`。成功时可确认云端身份、FCM 发送权限和请求格式正确，但不会有设备收到通知。
4. 只有需要真实验证送达时才选择 `send`；这会投递给主题下的所有订阅设备。前台收到时，App 显示应用内提示；后台时，Android 的 FCM 通知载荷由系统显示。

如果 Google Cloud 拒绝创建 Workload Identity Pool 或服务账号，请把 Cloud Shell 显示的完整错误信息发来；不要改用 App 内的服务账号密钥。
