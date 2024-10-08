const jsYaml = require('js-yaml');
const deepObjectDiff = require('deep-object-diff');
const chaiExec = require("@jsdevtools/chai-exec");
const chai = require("chai");
const expect = chai.expect;
const should = chai.should();
chai.use(chaiExec);
const utils = require('./utils');
chai.config.truncateThreshold = 4000; // length threshold for actual and expected values in assertion errors

global = {
  checkKubernetesObject: async ({ context, namespace, kind, k8sObj, yaml }) => {
    let command = "kubectl --context " + context + " -n " + namespace + " get " + kind + " " + k8sObj + " -o json";
    let cli = chaiExec(command);
    let json = jsYaml.load(yaml)

    cli.should.exit.with.code(0);
    cli.stderr.should.be.empty;
    let data = JSON.parse(cli.stdout);
    let diff = deepObjectDiff.detailedDiff(json, data);
    let expectedObject = false;
    console.log(Object.keys(diff.deleted).length);
    if (Object.keys(diff.updated).length === 0 && Object.keys(diff.deleted).length === 0) {
      expectedObject = true;
    }
    expect(expectedObject, "The following object can't be found or is not as expected:\n" + yaml).to.be.true;
  },
  checkDeployment: async ({ context, namespace, k8sObj }) => {
    let command = "kubectl --context " + context + " -n " + namespace + " get deploy " + k8sObj + " -o jsonpath='{.status}'";
    let cli = chaiExec(command);
    cli.stderr.should.be.empty;
    let readyReplicas = JSON.parse(cli.stdout.slice(1, -1)).readyReplicas || 0;
    let replicas = JSON.parse(cli.stdout.slice(1, -1)).replicas;
    if (readyReplicas != replicas) {
      console.log("    ----> " + k8sObj + " in " + context + " not ready...");
      await utils.sleep(1000);
    }
    cli.should.exit.with.code(0);
    readyReplicas.should.equal(replicas);
  },
  checkDeploymentHasPod: async ({ context, namespace, deployment }) => {
    let command = "kubectl --context " + context + " -n " + namespace + " get deploy " + deployment + " -o name'";
    let cli = chaiExec(command);
    cli.stderr.should.be.empty;
    cli.stdout.should.not.be.empty;
    cli.stdout.should.contain(deployment);
  },
  checkDeploymentsWithLabels: async ({ context, namespace, labels, instances }) => {
    let command = "kubectl --context " + context + " -n " + namespace + " get deploy -l " + labels + " -o jsonpath='{.items}'";
    let cli = chaiExec(command);
    cli.stderr.should.be.empty;
    let deployments = JSON.parse(cli.stdout.slice(1, -1));
    expect(deployments).to.have.lengthOf(instances);
    deployments.forEach((deployment) => {
      let readyReplicas = deployment.status.readyReplicas || 0;
      let replicas = deployment.status.replicas;
      if (readyReplicas != replicas) {
        console.log("    ----> " + deployment.metadata.name + " in " + context + " not ready...");
        utils.sleep(1000);
      }
      cli.should.exit.with.code(0);
      readyReplicas.should.equal(replicas);
    });
  },
  checkStatefulSet: async ({ context, namespace, k8sObj }) => {
    let command = "kubectl --context " + context + " -n " + namespace + " get sts " + k8sObj + " -o jsonpath='{.status}'";
    let cli = chaiExec(command);
    cli.stderr.should.be.empty;
    let readyReplicas = JSON.parse(cli.stdout.slice(1, -1)).readyReplicas || 0;
    let replicas = JSON.parse(cli.stdout.slice(1, -1)).replicas;
    if (readyReplicas != replicas) {
      console.log("    ----> " + k8sObj + " in " + context + " not ready...");
      await utils.sleep(1000);
    }
    cli.should.exit.with.code(0);
    readyReplicas.should.equal(replicas);
  },
  checkDaemonSet: async ({ context, namespace, k8sObj }) => {
    let command = "kubectl --context " + context + " -n " + namespace + " get ds " + k8sObj + " -o jsonpath='{.status}'";
    let cli = chaiExec(command);
    cli.stderr.should.be.empty;
    let readyReplicas = JSON.parse(cli.stdout.slice(1, -1)).numberReady || 0;
    let replicas = JSON.parse(cli.stdout.slice(1, -1)).desiredNumberScheduled;
    if (readyReplicas != replicas) {
      console.log("    ----> " + k8sObj + " in " + context + " not ready...");
      await utils.sleep(1000);
    }
    cli.should.exit.with.code(0);
    readyReplicas.should.equal(replicas);
  },
  k8sObjectIsPresent: ({ context, namespace, k8sType, k8sObj }) => {
    let command = "kubectl --context " + context + " -n " + namespace + " get " + k8sType + " " + k8sObj + " -o name";
    let cli = chaiExec(command);

    cli.stderr.should.be.empty;
    cli.should.exit.with.code(0);
  },
  genericCommand: async ({ command, responseContains = "" }) => {
    let cli = chaiExec(command);
    if (cli.stderr && cli.stderr != "") {
      console.log("    ----> " + command + " not succesful: " + cli.stderr);
      await utils.sleep(1000);
    }
    cli.stderr.should.be.empty;
    cli.should.exit.with.code(0);
    if (responseContains != "") {
      cli.stdout.should.contain(responseContains);
    }
  },
  getOutputForCommand: ({ command }) => {
    let cli = chaiExec(command);
    return cli.stdout;
  },
  curlInPod: ({ curlCommand, podName, namespace }) => {
    return global.getOutputForCommand({ command: `kubectl -n ${namespace} debug -i -q ${podName} --image=curlimages/curl -- sh -c \'${curlCommand}\'` }).replaceAll("'", "");
  },
};

module.exports = global;

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0 && this.currentTest.currentRetry() % 5 === 0) {
    console.log(`Test "${this.currentTest.fullTitle()}" retry: ${this.currentTest.currentRetry()}`);
  }
  utils.waitOnFailedTest(done, this.currentTest.currentRetry())
});
