function streamRef(db, issuerToken, streamName) {
  return db.collection(issuerToken).doc(streamName);
}
function statementsRef(db, issuerToken, streamName) {
  return streamRef(db, issuerToken, streamName).collection('statements');
}
function delegateStatementsRef(db, delegateToken, _identityToken) {
  return db.collection(delegateToken).doc('statements').collection('statements');
}
function delegateStreamKey(delegateToken, _identityToken) {
  return delegateToken;
}
const statementPrefix = 'org.nerdster';
const domain = 'nerdster.org';
module.exports = { streamRef, statementsRef, delegateStatementsRef, delegateStreamKey, statementPrefix, domain };
