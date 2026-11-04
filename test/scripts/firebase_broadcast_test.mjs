import assert from 'node:assert/strict';
import test from 'node:test';

import { buildPayload, postMessage } from '../../scripts/firebase_broadcast.mjs';

test('validate-only sets the FCM no-delivery flag and uses the broadcast topic', async () => {
  let request;
  const result = await postMessage({
    accessToken: 'test-token',
    title: '链路检查',
    body: '不会投递到设备',
    validateOnly: true,
    fetchImpl: async (url, options) => {
      request = { url, options };
      return { ok: true, text: async () => '{}' };
    },
  });

  assert.equal(
    request.url,
    'https://fcm.googleapis.com/v1/projects/hyperpiliplus/messages:send',
  );
  assert.equal(JSON.parse(request.options.body).validate_only, true);
  assert.deepEqual(JSON.parse(request.options.body).message, {
    topic: 'hyperpiliplus_broadcast',
    notification: { title: '链路检查', body: '不会投递到设备' },
  });
  assert.ok(result.payloadBytes > 0);
});

test('normal send does not set validate_only', () => {
  const { payload } = buildPayload('公告', '消息正文');
  assert.equal(Object.hasOwn(payload, 'validate_only'), false);
});

test('oversized messages are rejected before an HTTP request', () => {
  assert.throws(
    () => buildPayload('公告', '字'.repeat(4096)),
    /消息内容过长/,
  );
});
