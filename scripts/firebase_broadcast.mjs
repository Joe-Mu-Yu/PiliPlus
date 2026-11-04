import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const PROJECT_ID = 'hyperpiliplus';
const TOPIC = 'hyperpiliplus_broadcast';
const MAX_PAYLOAD_BYTES = 4096;

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`缺少必填配置：${name}`);
  }
  return value;
}

export function buildPayload(title, body, validateOnly = false) {
  const payload = {
    message: {
      topic: TOPIC,
      notification: { title, body },
    },
  };
  if (validateOnly) payload.validate_only = true;

  const serialized = JSON.stringify(payload);
  const payloadBytes = Buffer.byteLength(serialized, 'utf8');
  if (payloadBytes > MAX_PAYLOAD_BYTES) {
    throw new Error(
      `消息内容过长（${payloadBytes} 字节）；FCM 单条消息上限为 ${MAX_PAYLOAD_BYTES} 字节。`,
    );
  }

  return { payload, serialized, payloadBytes };
}

export async function postMessage({
  accessToken,
  title,
  body,
  validateOnly = false,
  fetchImpl = fetch,
}) {
  const { payload, serialized, payloadBytes } = buildPayload(
    title,
    body,
    validateOnly,
  );
  const response = await fetchImpl(
    `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json; charset=utf-8',
      },
      body: serialized,
      signal: AbortSignal.timeout(15000),
    },
  );
  const responseText = await response.text();
  let result;
  try {
    result = responseText ? JSON.parse(responseText) : {};
  } catch {
    result = {};
  }

  if (!response.ok) {
    const detail =
      result.error?.message ?? `FCM 返回 HTTP ${response.status}`;
    throw new Error(`${validateOnly ? '验证' : '发送'}失败：${detail}`);
  }

  return { result, payloadBytes };
}

async function main() {
  const title = required('FCM_TITLE');
  const body = required('FCM_BODY');
  const validateOnly = process.argv.includes('--validate-only');
  const { payloadBytes } = buildPayload(title, body, validateOnly);

  if (process.argv.includes('--dry-run')) {
    console.log(
      `本地 dry-run 通过：项目 ${PROJECT_ID}，主题 ${TOPIC}，载荷 ${payloadBytes} 字节；未连接 Firebase，也没有发送消息。`,
    );
    return;
  }

  const accessToken = required('FCM_ACCESS_TOKEN');
  const { result } = await postMessage({
    accessToken,
    title,
    body,
    validateOnly,
  });

  if (validateOnly) {
    console.log('FCM 无投递验证通过：请求未发送给任何设备。');
  } else {
    console.log(`FCM 已接受发送请求：${result.name ?? '成功'}`);
    console.log(
      '此结果表示 FCM 接受了主题消息，不表示每台设备均已实际显示。',
    );
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
