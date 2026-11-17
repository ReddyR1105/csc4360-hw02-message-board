import assert from 'node:assert/strict';
import { test } from 'node:test';
import { signOut } from 'firebase/auth';
import {
  collection, deleteDoc, doc, getDocFromServer,
  getDocsFromServer, onSnapshot, orderBy, query, serverTimestamp, updateDoc,
} from 'firebase/firestore';
import { account, localClient, post, demoProject } from '../client.mjs';

function observe(board, ids, expected, action) {
  return new Promise((resolve, reject) => {
    let observed = '';
    const timer = setTimeout(() => finish(new Error(
      'Expected ' + expected + ' but last board snapshot was ' + observed,
    )), 12000);
    const stop = onSnapshot(board, (snapshot) => {
      observed = snapshot.docs.filter((item) => ids.includes(item.id)).map((item) => item.data().text).join('|');
      if (observed === expected) finish();
    }, finish);
    function finish(error) {
      clearTimeout(timer);
      stop();
      if (error) reject(error);
      else resolve();
    }
    Promise.resolve().then(action).catch(finish);
  });
}

test('I01 Auth emulator plus two authenticated Firestore clients, ordering and live CRUD', async () => {
  const a = localClient('integration-a');
  const b = localClient('integration-b');
  const suffix = Date.now().toString(36);
  const first = 'A' + suffix.padStart(19, '0');
  const second = 'B' + suffix.padStart(19, '0');
  const firstRef = doc(a.db, 'messages', first);
  const secondRef = doc(b.db, 'messages', second);
  const board = query(collection(b.db, 'messages'), orderBy('createdAt', 'desc'));
  try {
    const owner = await account(a, 'owner-' + suffix + '@example.test', 'Avery', 'Hill');
    const reader = await account(b, 'reader-' + suffix + '@example.test', 'Blake', 'Price');
    assert.equal(a.db.app.options.projectId, demoProject);
    assert.equal(a.auth.emulatorConfig.host, '127.0.0.1');
    assert.equal(owner.uid, a.auth.currentUser.uid);
    assert.ok(owner.registrationDateTime.toMillis() > 0);
    assert.notEqual(owner.uid, reader.uid);

    await observe(board, [first, second], 'Original', () => post(a, owner, first, 'Original'));
    await observe(board, [first, second], 'Newer|Original', () => post(b, reader, second, 'Newer'));
    await observe(board, [first, second], 'Newer|Edited', () => updateDoc(firstRef, { text: 'Edited', editedAt: serverTimestamp() }));
    await observe(board, [first, second], 'Newer', () => deleteDoc(firstRef));
    assert.equal((await getDocFromServer(secondRef)).data().text, 'Newer');
    await deleteDoc(secondRef);
    await signOut(b.auth);
    await assert.rejects(getDocsFromServer(collection(b.db, 'messages')), { code: 'permission-denied' });
  } finally {
    await Promise.all([a.close(), b.close()]);
  }
});

test('I02 repeated concurrent submissions use one document and retain receipt after delete', async () => {
  const a = localClient('integration-retry');
  const suffix = Date.now().toString(36);
  const id = 'C' + suffix.padStart(19, '0');
  const message = doc(a.db, 'messages', id);
  try {
    const owner = await account(a, 'retry-' + suffix + '@example.test', 'Cameron', 'West');
    await Promise.all([post(a, owner, id, 'Retry the same post'), post(a, owner, id, 'Retry the same post')]);
    await post(a, owner, id, 'Retry the same post');
    const all = await getDocsFromServer(collection(a.db, 'messages'));
    assert.equal(all.docs.filter((item) => item.id === id).length, 1);
    const saved = (await getDocFromServer(message)).data();
    assert.equal(saved.text, 'Retry the same post');
    await deleteDoc(message);
    await post(a, owner, id, 'Retry the same post');
    assert.equal((await getDocFromServer(message)).exists(), false);
  } finally {
    await a.close();
  }
});
