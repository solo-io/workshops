const helpers = require('./tests/chai-exec');

describe("kebpf is running", () => {
  const deployments = ["kebpf"];
  deployments.forEach(deployment => {
    it(deployments + ' pods are ready', () => helpers.checkDeployment({ context: "ebpf", namespace: "default", k8sObj: deployment }));
  });
});