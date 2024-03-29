global = {
  sleep: ms => new Promise(resolve => setTimeout(resolve, ms)),
  waitOnFailedTest: (done, currentRetry) => {
    if(currentRetry > 0){
      console.log("Test failed. Retrying again in 1 second...");
      setTimeout(done, 1000);
    } else {
      done();
    }
  }
};

module.exports = global;