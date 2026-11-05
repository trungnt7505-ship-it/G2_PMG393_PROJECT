

const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');


module.exports.sendRelease = async (request, requestId) => {

  if (request.type !== 'release_table' || request.status !== 'open') return;
  const db = getFirestore();
  const [sessionDoc, staffDoc] = await Promise.all([
    db.doc(`sessions/${request.sessionId}`).get(),
    db.doc(`users/${request.createdBy}`).get(),
  ]);
  const session = sessionDoc.data();
  if (!['waiter', 'counter', 'manager'].includes(staffDoc.data()?.role) || !session?.customerId ||
      session.tableId !== request.tableId || !['active', 'billing'].includes(session.status)) return;
  const userRef = db.doc(`users/${session.customerId}`);
  const user = (await userRef.get()).data();
  const tokens = [...new Set(user?.fcmTokens || [])].filter(t => typeof t === 'string' && t);
  if (!tokens.length) throw new Error('Customer has no registered FCM device yet');
  for (let offset = 0; offset < tokens.length; offset += 500) {
    const batch = tokens.slice(offset, offset + 500);
    const result = await getMessaging().sendEachForMulticast({
      tokens: batch,
      notification: {title: `Yêu cầu nhả bàn • ${session.tableName}`, body: request.message || 'Vui lòng liên hệ nhân viên để gia hạn hoặc tính tiền.'},
      data: {sessionId: request.sessionId, requestId: requestId, customerId: session.customerId},
      android: {priority: 'high', ttl: 15 * 60 * 1000, collapseKey: requestId,
        notification: {channelId: 'table_direct_request_sound', sound: 'default', tag: requestId}},
    });
    const transient = result.responses.find(r => r.error && !['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(r.error.code));
    if (transient) throw transient.error;
    const invalid = result.responses.flatMap((response, index) =>
      ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(response.error?.code) ? [batch[index]] : []);
    if (invalid.length) await userRef.update({fcmTokens: FieldValue.arrayRemove(...invalid)});
  }
};
