function streamRef(db, issuerToken, streamName) {
  return db.collection(issuerToken).doc(streamName);
}
function statementsRef(db, issuerToken, streamName) {
  return streamRef(db, issuerToken, streamName).collection('statements');
}
module.exports = { streamRef, statementsRef };
