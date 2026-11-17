import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { before, beforeEach, after, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc, writeBatch, serverTimestamp, Timestamp } from 'firebase/firestore';

const projectId = 'demo-message-board';
const seeded = 'RULES000000000000001';
const newId = 'RULES000000000000002';
let env;

const profile = (uid, overrides = {}) => ({
  uid, firstName: 'Test', lastName: uid, role: 'member',
  registrationDateTime: serverTimestamp(), ...overrides,
});

const message = (uid, overrides = {}) => ({
  authorUid: uid, authorName: 'Test ' + uid, text: 'Hello from the test board',
  createdAt: serverTimestamp(), editedAt: null, ...overrides,
});

function create(db, uid, overrides, id = newId) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'messages', id), message(uid, overrides));
  batch.set(doc(db, 'users', uid, 'postReceipts', id), { createdAt: serverTimestamp() });
  return batch.commit();
}

const as = (uid) => env.authenticatedContext(uid).firestore();
const target = (db) => doc(db, 'messages', seeded);

before(async () => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
  env = await initializeTestEnvironment({
    projectId, firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all(['alice', 'bob'].map((uid) => setDoc(doc(db, 'users', uid), profile(uid))));
    await setDoc(target(db), message('alice'));
    await setDoc(doc(db, 'users', 'alice', 'postReceipts', seeded), { createdAt: serverTimestamp() });
  });
});
after(async () => env?.cleanup());

test('R01 signed-out document and collection reads denied', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(target(db)));
  await assertFails(getDocs(collection(db, 'messages')));
});
test('R02 cross-user edit denied and original message preserved', async () => {
  await assertFails(updateDoc(target(as('bob')), { text: 'Changed', editedAt: serverTimestamp() }));
  assert.equal((await getDoc(target(as('alice')))).data().text, message('alice').text);
});
test('R03 cross-user delete denied and message survives', async () => {
  await assertFails(deleteDoc(target(as('bob'))));
  assert.equal((await getDoc(target(as('alice')))).exists(), true);
});
test('R04 forged author UID and display name denied', async () => {
  await assertFails(create(as('bob'), 'bob', { authorUid: 'alice' }));
  await assertFails(create(as('bob'), 'bob', { authorName: 'Test alice' }));
});
test('R05 member creates message with paired receipt and server timestamp', async () => {
  const db = as('bob');
  await assertSucceeds(create(db, 'bob'));
  const item = (await getDoc(doc(db, 'messages', newId))).data();
  assert.equal(item.authorUid, 'bob');
  assert.ok(item.createdAt instanceof Timestamp);
  assert.equal(item.editedAt, null);
});
test('R06 authenticated user can read another member’s message', async () => {
  const result = await assertSucceeds(getDocs(collection(as('bob'), 'messages')));
  assert.equal(result.size, 1);
});
test('R07 owner updates text and edit timestamp only', async () => {
  const ref = target(as('alice'));
  const old = (await getDoc(ref)).data();
  await assertSucceeds(updateDoc(ref, { text: 'Revised', editedAt: serverTimestamp() }));
  const updated = (await getDoc(ref)).data();
  assert.equal(updated.text, 'Revised');
  assert.ok(updated.editedAt instanceof Timestamp);
  assert.ok(updated.createdAt.isEqual(old.createdAt));
});
test('R08 owner deletes their message and receipt prevents resurrection', async () => {
  const db = as('alice');
  await assertSucceeds(deleteDoc(target(db)));
  assert.equal((await getDoc(target(db))).exists(), false);
  await assertFails(create(db, 'alice', {}, seeded));
});
test('R09 owner cannot change ownership, author label, or creation time', async () => {
  const ref = target(as('alice'));
  for (const fields of [{ authorUid: 'bob' }, { authorName: 'New label' }, { createdAt: serverTimestamp() }]) {
    await assertFails(updateDoc(ref, { ...fields, editedAt: serverTimestamp() }));
  }
});
test('R10 private profiles and receipts cannot be read or written by another member', async () => {
  const db = as('bob');
  await assertFails(getDoc(doc(db, 'users', 'alice')));
  await assertFails(updateDoc(doc(db, 'users', 'alice'), { firstName: 'Unauthorized' }));
  await assertFails(getDoc(doc(db, 'users', 'alice', 'postReceipts', seeded)));
});
test('R11 own five-field profile once, server time, and member role only', async () => {
  const db = as('carol');
  const ref = doc(db, 'users', 'carol');
  await assertFails(setDoc(ref, profile('carol', { role: 'admin' })));
  await assertSucceeds(setDoc(ref, profile('carol')));
  const value = (await getDoc(ref)).data();
  assert.deepEqual(Object.keys(value).sort(), ['firstName', 'lastName', 'registrationDateTime', 'role', 'uid']);
  assert.ok(value.registrationDateTime instanceof Timestamp);
  await assertFails(setDoc(ref, profile('carol')));
});
test('R12 malformed data, signed-out writes, and unpaired writes denied', async () => {
  const db = as('bob');
  for (const fields of [{ text: ' ' }, { text: 'x'.repeat(501) }, { text: 1 }, { extra: true }, { editedAt: serverTimestamp() }]) {
    await assertFails(create(db, 'bob', fields));
  }
  await assertFails(setDoc(doc(db, 'messages', newId), message('bob')));
  await assertFails(setDoc(doc(db, 'users', 'bob', 'postReceipts', newId), { createdAt: serverTimestamp() }));
  await assertFails(create(env.unauthenticatedContext().firestore(), 'bob'));
});
