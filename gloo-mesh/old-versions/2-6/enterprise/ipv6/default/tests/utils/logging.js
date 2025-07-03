const debugMode = process.env.RUNNER_DEBUG === '1';
function logDebug(...args) {
  if (debugMode) {
    console.log(...args);
  }
}
module.exports = { logDebug };