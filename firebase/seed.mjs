import { localClient, account, post } from './client.mjs';

if ((process.env.DEMO_PASSWORD ?? '').length < 8) throw new Error('Set a disposable DEMO_PASSWORD of at least eight characters.');

const alice = localClient('seed-maya');
const bob = localClient('seed-jordan');
try {
  const maya = await account(alice, 'maya@example.test', 'Maya', 'Chen');
  const jordan = await account(bob, 'jordan@example.test', 'Jordan', 'Reed');
  await post(alice, maya, 'SEED0000000000000001', 'I’m hosting a study session at the library Thursday at 4.');
  await post(bob, jordan, 'SEED0000000000000002', 'The Flutter review notes are ready. Bring your questions!');
  console.log('Seeded two test profiles and two messages in demo-message-board at 127.0.0.1.');
} finally {
  await Promise.all([alice.close(), bob.close()]);
}
