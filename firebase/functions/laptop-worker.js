const path = require('node:path');
const {initializeApp, applicationDefault} = require('firebase-admin/app');
const fs = require('node:fs');
const os = require('node:os');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const auth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));
const projectId = 'cafe-73637';
const scopes = ['https://www.googleapis.com/auth/cloud-platform'];
const account = auth.getGlobalDefaultAccount();
if (!account) throw new Error('Sign in first with firebase login');
const credential = {
  async getAccessToken() {
    const token = await auth.getAccessToken(account.tokens.refresh_token, scopes);
    return {access_token: token.access_token, expires_in: 3600};
  },
};
const api = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/api.js'));
const credentialDir = fs.mkdtempSync(path.join(os.tmpdir(), 'cafe-push-'));
const credentialPath = path.join(credentialDir, 'adc.json');
fs.writeFileSync(credentialPath, JSON.stringify({type: 'authorized_user', client_id: api.clientId(), client_secret: api.clientSecret(), refresh_token: account.tokens.refresh_token}), {mode: 0o600});
process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
process.on('exit', () => {
  fs.unlinkSync(credentialPath);
  fs.rmdirSync(credentialDir);
});
initializeApp({projectId, credential: applicationDefault()});
const db = getFirestore();
const {sendRelease} = require('./send-release');
const queue = new Map();
let busy = false;
let unsubscribe;
let timer;
async function drain() {
  if (busy) return;
  busy = true;
  try {
    for (const [id, request] of queue) {
      const created = request.createdAt?.toMillis?.();
      if (request.status !== 'open' || !created || Date.now() - created > 15 * 60 * 1000) {
        queue.delete(id);
        continue;
      }
      const delivery = db.doc(`_notificationDeliveries/${id}`);
      const claimed = await db.runTransaction(async tx => {
        const data = (await tx.get(delivery)).data();
        if (data?.sent || (data?.leaseUntil?.toMillis() || 0) > Date.now()) return false;
        tx.set(delivery, {sent: false, leaseUntil: Timestamp.fromMillis(Date.now() + 120000)}, {merge: true});
        return true;
      });
      if (!claimed) continue;
      try {
        // Re-read so a closed request is not sent from an outdated snapshot.
        const fresh = (await db.doc(`requests/${id}`).get()).data();
        if (fresh?.status === 'open') await sendRelease(fresh, id);
        await delivery.set({sent: true, sentAt: Timestamp.now()});
        queue.delete(id);
        console.log(`Handled release request ${id}`);
      } catch (error) {
        await delivery.set({sent: false, leaseUntil: Timestamp.fromMillis(Date.now() + 30000)}, {merge: true});
        console.error(`Request ${id}: ${error.message}`);
      }
    }
  } catch (error) {
    console.error(`Worker: ${error.message}`);
  } finally {
    busy = false;
  }
}
async function main() {
  await db.collection('requests').limit(1).get();
  if (process.argv.includes('--check')) {
    // Validation only. No push is delivered.
    const token = await credential.getAccessToken();
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: 'POST', headers: {Authorization: `Bearer ${token.access_token}`, 'Content-Type': 'application/json'},
      body: JSON.stringify({validate_only: true, message: {topic: 'cafe-backend-validation', notification: {title: 'Validation'}}}),
    });
    if (!response.ok) throw new Error(`FCM validation failed (${response.status}): ${await response.text()}`);
    console.log('Firestore and FCM credentials OK. No notification sent.');
    await db.terminate();
    return;
  }
  unsubscribe = db.collection('requests').where('type', '==', 'release_table').onSnapshot(snapshot => {
    for (const change of snapshot.docChanges()) {
      if (change.type === 'removed') queue.delete(change.doc.id);
      else queue.set(change.doc.id, change.doc.data());
    }
    void drain();
  }, error => {
    console.error(`Firestore listener stopped: ${error.message}. Restart the backend.`);
    process.exitCode = 1;
    clearInterval(timer);
    void db.terminate();
  });
  timer = setInterval(() => void drain(), 15000);
  console.log(`Cafe push backend running for ${projectId}. Keep this terminal open. Ctrl+C to stop.`);
}
process.on('SIGINT', () => {
  unsubscribe?.();
  clearInterval(timer);
  void db.terminate().finally(() => process.exit());
});
main().catch(error => {console.error(error.message); process.exit(1);});

