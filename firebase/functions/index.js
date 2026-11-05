const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {initializeApp} = require('firebase-admin/app');
initializeApp();
const {sendRelease} = require('./send-release');
exports.notifyTableRelease = onDocumentCreated({document: 'requests/{requestId}', region: 'asia-southeast1'}, event => sendRelease(event.data.data(), event.params.requestId));
