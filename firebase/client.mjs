import { randomBytes } from 'node:crypto';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, signInWithEmailAndPassword, createUserWithEmailAndPassword } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, doc, getDoc, getDocFromServer, runTransaction, serverTimestamp } from 'firebase/firestore';

export const demoProject = 'demo-message-board';
export const demoPassword = process.env.DEMO_PASSWORD ?? ('Local' + randomBytes(12).toString('hex'));

export function localClient(label) {
  const app = initializeApp({ projectId: demoProject, apiKey: 'demo-api-key' }, label);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1', 8180);
  return { auth, db, close: () => deleteApp(app) };
}

export async function account(client, email, firstName, lastName) {
  let credential;
  try {
    credential = await createUserWithEmailAndPassword(client.auth, email, demoPassword);
  } catch (error) {
    if (error.code !== 'auth/email-already-in-use') throw error;
    credential = await signInWithEmailAndPassword(client.auth, email, demoPassword);
  }
  const uid = credential.user.uid;
  const profile = doc(client.db, 'users', uid);
  await runTransaction(client.db, async (transaction) => {
    if ((await transaction.get(profile)).exists()) return;
    transaction.set(profile, { uid, firstName, lastName, role: 'member', registrationDateTime: serverTimestamp() });
  });
  return (await getDoc(profile)).data();
}

export function post(client, user, id, text) {
  const message = doc(client.db, 'messages', id);
  const receipt = doc(client.db, 'users', user.uid, 'postReceipts', id);
  return runTransaction(client.db, async (transaction) => {
    if ((await transaction.get(receipt)).exists()) return;
    transaction.set(message, {
      text, authorUid: user.uid, authorName: user.firstName + ' ' + user.lastName,
      createdAt: serverTimestamp(), editedAt: null,
    });
    transaction.set(receipt, { createdAt: serverTimestamp() });
  }, { maxAttempts: 3 }).catch(async (error) => {
    if (!['permission-denied', 'already-exists', 'aborted'].includes(error.code) ||
        !(await getDocFromServer(receipt)).exists()) throw error;
  });
}
