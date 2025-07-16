const jsYaml = require('js-yaml');
const deepObjectDiff = require('deep-object-diff');
const chaiExec = require("@jsdevtools/chai-exec");
const chai = require("chai");
const expect = chai.expect;
const should = chai.should();
chai.use(chaiExec);
const utils = require('./utils');
const { debugLog } = require('./utils/logging');
chai.config.truncateThreshold = 4000; // length threshold for actual and expected values in assertion errors

global = {
  checkKubernetesObject: async ({ context, namespace, kind, k8sObj, yaml }) => {
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "kubectl " + _context + " -n " + namespace + " get " + kind + " " + k8sObj + " -o json";
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);
    let json = jsYaml.load(yaml)

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.should.exit.with.code(0);
    cli.stderr.should.be.empty;
    let data = JSON.parse(cli.stdout);
    debugLog(`Parsed data from CLI: ${JSON.stringify(data)}`);

    let diff = deepObjectDiff.detailedDiff(json, data);
    debugLog(`Diff between expected and actual object: ${JSON.stringify(diff)}`);

    let expectedObject = false;
    if (Object.keys(diff.updated).length === 0 && Object.keys(diff.deleted).length === 0) {
      expectedObject = true;
    }
    debugLog(`Expected object found: ${expectedObject}`);
    expect(expectedObject, "The following object can't be found or is not as expected:\n" + yaml).to.be.true;
  },

  checkDeployment: async ({ context, namespace, k8sObj }) => {
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "kubectl " + _context + " -n " + namespace + " get deploy " + k8sObj + " -o jsonpath='{.status}'";
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    let readyReplicas = JSON.parse(cli.stdout.slice(1, -1)).readyReplicas || 0;
    let replicas = JSON.parse(cli.stdout.slice(1, -1)).replicas;
    debugLog(`Ready replicas: ${readyReplicas}, Total replicas: ${replicas}`);

    if (readyReplicas != replicas) {
      debugLog(`Deployment ${k8sObj} in ${context} not ready, retrying...`);
      await utils.sleep(1000);
    }
    cli.should.exit.with.code(0);
    readyReplicas.should.equal(replicas);
  },

  checkDeploymentHasPod: async ({ context, namespace, deployment }) => {
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "kubectl " + _context + " -n " + namespace + " get deploy " + deployment + " -o name'";
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    cli.stdout.should.not.be.empty;
    cli.stdout.should.contain(deployment);
  },

  checkStatefulSetHasRunningReplica: async ({ context, namespace, statefulSet }) => {
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "kubectl " + _context + " -n " + namespace + " get sts " + statefulSet + " -o jsonpath='{.status}'";
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    let readyReplicas = JSON.parse(cli.stdout.slice(1, -1)).readyReplicas || 0;
    debugLog(`StatefulSet ${statefulSet} - Ready replicas: ${readyReplicas}`);

    if (readyReplicas < 1) {
      debugLog(`StatefulSet ${statefulSet} in ${context} has no ready replicas, retrying...`);
      await utils.sleep(1000);
    }
    cli.should.exit.with.code(0);
    readyReplicas.should.be.at.least(1);
  },

  checkDeploymentsWithLabels: async ({ context, namespace, labels, instances }) => {
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "kubectl " + _context + " -n " + namespace + " get deploy -l " + labels + " -o jsonpath='{.items}'";
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    let deployments = JSON.parse(cli.stdout.slice(1, -1));
    debugLog(`Found deployments: ${JSON.stringify(deployments)}`);

    expect(deployments).to.have.lengthOf(instances);
    deployments.forEach((deployment) => {
      let readyReplicas = deployment.status.readyReplicas || 0;
      let replicas = deployment.status.replicas;
      debugLog(`Deployment ${deployment.metadata.name} - Ready replicas: ${readyReplicas}, Total replicas: ${replicas}`);

      if (readyReplicas != replicas) {
        debugLog(`Deployment ${deployment.metadata.name} in ${context} not ready, retrying...`);
        utils.sleep(1000);
      }
      cli.should.exit.with.code(0);
      readyReplicas.should.equal(replicas);
    });
  },

  checkPodRestartCountIs0: ({ context, namespace, k8sLabel }) => {
    // covers both namespace scoped and cluster scoped objects
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "kubectl " + _context + " get pods -l " + k8sLabel + " -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}'";
    if (namespace) {
      command = "kubectl " + _context + " -n " + namespace + " get pods -l " + k8sLabel + " -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}'";
    }
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    cli.should.exit.with.code(0);
    const restartCount = +cli.stdout.replace(/\'/g, '');
    restartCount.should.equal(0);
  },

  checkPodContainerCount: ({ context, namespace, k8sLabel, expectedContainers }) => {
    // covers both namespace scoped and cluster scoped objects
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "sh -c 'kubectl " + _context + " get pods -l " + k8sLabel + " -o json | jq -r \".items[] | \\\"\\(.metadata.name) \\(.spec.containers | length)\\\"\"'";
    if (namespace) {
      command = "sh -c 'kubectl " + _context + " -n " + namespace + " get pods -l " + k8sLabel + " -o json | jq -r \".items[] | \\\"\\(.metadata.name) \\(.spec.containers | length)\\\"\"'";
    }
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    cli.should.exit.with.code(0);
    const pods = cli.stdout.trim().split("\n");
    const podCount = pods.length;
    const podsWithMatchingContainerCount = pods.filter(line => line.endsWith(` ${expectedContainers}`)).length;
    podsWithMatchingContainerCount.should.equal(podCount);
  },

  checkPodForAnnotation: ({ context, namespace, k8sLabel, expectedAnnotationKey, expectedAnnotationValue }) => {
    // covers both namespace scoped and cluster scoped objects
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "kubectl " + _context + " get pods -l " + k8sLabel + " -ojsonpath='{range .items[*]}{.metadata.name}{\": \"}{.metadata.annotations." + expectedAnnotationKey.replace(/\./g, "\\.") + "}{\"\\n\"}{end}'";
    if (namespace) {
      command = "kubectl " + _context + " -n " + namespace + " get pods -l " + k8sLabel + " -ojsonpath='{range .items[*]}{.metadata.name}{\": \"}{.metadata.annotations." + expectedAnnotationKey.replace(/\./g, "\\.") + "}{\"\\n\"}{end}'";
    }
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    cli.should.exit.with.code(0);
    const pods = cli.stdout.replace(/^'|'$/g, "").trim().split("\n");
    const podCount = pods.length;
    const podsWithMatchingAnnotationCount = pods.filter(line => line.endsWith(`: ${expectedAnnotationValue}`)).length;
    podsWithMatchingAnnotationCount.should.equal(podCount);
  },

  checkStatefulSet: async ({ context, namespace, k8sObj }) => {
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "kubectl " + _context + " -n " + namespace + " get sts " + k8sObj + " -o jsonpath='{.status}'";
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    let readyReplicas = JSON.parse(cli.stdout.slice(1, -1)).readyReplicas || 0;
    let replicas = JSON.parse(cli.stdout.slice(1, -1)).replicas;
    debugLog(`StatefulSet ${k8sObj} - Ready replicas: ${readyReplicas}, Total replicas: ${replicas}`);

    if (readyReplicas != replicas) {
      debugLog(`StatefulSet ${k8sObj} in ${context} not ready, retrying...`);
      await utils.sleep(1000);
    }
    cli.should.exit.with.code(0);
    readyReplicas.should.equal(replicas);
  },

  checkDaemonSet: async ({ context, namespace, k8sObj }) => {
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "kubectl " + _context + " -n " + namespace + " get ds " + k8sObj + " -o jsonpath='{.status}'";
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    let readyReplicas = JSON.parse(cli.stdout.slice(1, -1)).numberReady || 0;
    let replicas = JSON.parse(cli.stdout.slice(1, -1)).desiredNumberScheduled;
    debugLog(`DaemonSet ${k8sObj} - Ready replicas: ${readyReplicas}, Total replicas: ${replicas}`);

    if (readyReplicas != replicas) {
      debugLog(`DaemonSet ${k8sObj} in ${context} not ready, retrying...`);
      await utils.sleep(1000);
    }
    cli.should.exit.with.code(0);
    readyReplicas.should.equal(replicas);
  },

  k8sObjectIsPresent: ({ context, namespace, k8sType, k8sObj }) => {
    // covers both namespace scoped and cluster scoped objects
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    let command = "kubectl " + _context + " get " + k8sType + " " + k8sObj + " -o name";
    if (namespace) {
      command = "kubectl " + _context + " -n " + namespace + " get " + k8sType + " " + k8sObj + " -o name";
    }
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    cli.should.exit.with.code(0);
  },

  genericCommand: async ({ command, responseContains = "" }) => {
    debugLog(`Executing generic command: ${command}`);
    let cli = chaiExec(command);

    if (cli.stderr && cli.stderr != "") {
      debugLog(`Command ${command} not successful: ${cli.stderr}`);
      await utils.sleep(1000);
    }

    debugLog(`Command output (stdout): ${cli.stdout}`);
    debugLog(`Command error (stderr): ${cli.stderr}`);

    cli.stderr.should.be.empty;
    cli.should.exit.with.code(0);
    if (responseContains != "") {
      debugLog(`Checking if stdout contains: ${responseContains}`);
      cli.stdout.should.contain(responseContains);
    }
  },

  getOutputForCommand: ({ command }) => {
    debugLog(`Executing command: ${command}`);
    let cli = chaiExec(command);
    debugLog(`Command output (stdout): ${cli.stdout}`);
    return cli.stdout;
  },
  curlInPod: ({ curlCommand, podName, namespace, context }) => {
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    debugLog(`Executing curl command: ${curlCommand} on pod: ${podName} in namespace: ${namespace}`);
    let execCommand = `kubectl ${_context} -n ${namespace} debug -i -q ${podName} --image=radial/busyboxplus:curl -- ${curlCommand}`;
    const cli = chaiExec(execCommand);
    debugLog(`Curl command output (stdout): ${cli.stdout}`);
    return cli.stdout;
  },
  curlInDeployment: async ({ curlCommand, deploymentName, namespace, context }) => {
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }
    debugLog(`Executing curl command: ${curlCommand} on deployment: ${deploymentName} in namespace: ${namespace} and context: ${_context}`);
    let getPodCommand = `kubectl ${_context} -n ${namespace} get pods -l app=${deploymentName} -o jsonpath='{.items[0].metadata.name}'`;
    let podName = chaiExec(getPodCommand).stdout.trim();
    if (podName === "") {
      getPodCommand = `kubectl ${_context} -n ${namespace} get pods -l app.kubernetes.io/name=${deploymentName} -o jsonpath='{.items[0].metadata.name}'`;
      podName = chaiExec(getPodCommand).stdout.trim();
    }
    debugLog(`Pod selected for curl command: ${podName}`);
    let execCommand = `kubectl ${_context} -n ${namespace} debug ${podName} -i --image=curlimages/curl --quiet -- ${curlCommand}`;
    debugLog(`Executing debug command: ${execCommand}`);
    const cli = chaiExec(execCommand);
    debugLog(`Curl command output (stdout): ${cli.stdout}`);
    return cli.stdout;
  },

  curlWithPortForward: async ({ resource, resourceType = 'svc', targetPort, localPort, namespace, context, curlCommand, timeoutMs = 10000 }) => {
    let _context = "";
    if (context) {
      _context = `--context ${context}`;
    }

    // Start port-forwarding in the background
    debugLog(`Setting up port-forward from local port ${localPort} to ${resourceType}/${resource} port ${targetPort} in namespace ${namespace}`);
    const portForwardCommand = `kubectl ${_context} -n ${namespace} port-forward ${resourceType}/${resource} ${localPort}:${targetPort}`;

    // Use spawn to start the process in background mode
    const { spawn } = require('child_process');
    const portForward = spawn('sh', ['-c', portForwardCommand], {
      detached: true,
      stdio: ['ignore', 'pipe', 'pipe']
    });

    // Set up stdout and stderr handling for debugging
    let portForwardOutput = '';
    portForward.stdout.on('data', (data) => {
      portForwardOutput += data.toString();
    });

    let portForwardError = '';
    portForward.stderr.on('data', (data) => {
      portForwardError += data.toString();
    });

    // Wait for port-forward to be established
    debugLog(`Waiting for port-forward to be established...`);
    await new Promise(resolve => setTimeout(resolve, 2000));

    try {
      // Execute curl command to the forwarded port
      const modifiedCurlCommand = curlCommand.replace(/localhost:(\d+)/, `localhost:${localPort}`);
      debugLog(`Executing curl command: ${modifiedCurlCommand}`);

      // Set a timeout for the curl command
      const execWithTimeout = new Promise((resolve, reject) => {
        const cli = chaiExec(modifiedCurlCommand);
        resolve(cli);

        setTimeout(() => {
          reject(new Error(`Curl command timed out after ${timeoutMs}ms`));
        }, timeoutMs);
      });

      const cli = await execWithTimeout;
      debugLog(`Curl command output (stdout): ${cli.stdout}`);
      debugLog(`Curl command error (stderr): ${cli.stderr}`);

      return cli.stdout;
    } catch (error) {
      debugLog(`Error during curl execution: ${error.message}`);
      throw error;
    } finally {
      // Cleanup: kill the port-forward process
      debugLog(`Cleaning up port-forward process (PID: ${portForward.pid})`);
      if (portForward.pid) {
        process.kill(-portForward.pid, 'SIGTERM');
      }

      debugLog(`Port-forward stdout: ${portForwardOutput}`);
      if (portForwardError) {
        debugLog(`Port-forward stderr: ${portForwardError}`);
      }
    }
  },
};

module.exports = global;

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0 && this.currentTest.currentRetry() % 5 === 0) {
    debugLog(`Test "${this.currentTest.fullTitle()}" retry: ${this.currentTest.currentRetry()}`);
  }
  utils.waitOnFailedTest(done, this.currentTest.currentRetry())
});
