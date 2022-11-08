const chaiExec = require("@jsdevtools/chai-exec");
const chai = require("chai");
const should = chai.should();
chai.use(chaiExec);
const utils = require('./utils');

global = {
  checkDeployment: async ({ context, namespace, k8sObj }) => {
    let command = "kubectl --context " + context + " -n " + namespace + " get deploy " + k8sObj + " -o jsonpath='{.status.availableReplicas}'";
    let cli = chaiExec(command);

    cli.stderr.should.be.empty;
    let availableReplicas = cli.stdout;
    if (!availableReplicas.includes("1")) {
      console.log("    ----> " + k8sObj + " in " + context + " not ready...");
      await utils.sleep(1000);
    }
    cli.should.exit.with.code(0);
    availableReplicas.should.equal("'1'");
  },
  k8sObjectIsPresent: ({ context, namespace, k8sType, k8sObj }) => {
    let command = "kubectl --context " + context + " -n " + namespace + " get " + k8sType + " " + k8sObj + " -o name";
    let cli = chaiExec(command);

    cli.stderr.should.be.empty;
    cli.should.exit.with.code(0);
  },
  genericCommand: async ({ command, responseContains="" }) => {
    let cli = chaiExec(command);
    if (cli.stderr && cli.stderr != "") {
      console.log("    ----> " + command + " not succesful...");
      await utils.sleep(1000);
    }
    cli.stderr.should.be.empty;
    cli.should.exit.with.code(0);
    if(responseContains!=""){
      cli.stdout.should.contain(responseContains);
    }
  },
  getOutputForCommand: ({ command }) => {
    let cli = chaiExec(command);
    return cli.stdout;
  },
};

module.exports = global;

afterEach(function(done) { utils.waitOnFailedTest(done, this.currentTest.currentRetry())});