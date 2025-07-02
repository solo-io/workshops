const BasePage = require("../base");

class GraphPage extends BasePage {
  constructor(page) {
    super(page)

    // Selectors
    this.clusterDropdownButton = '[data-testid="cluster-dropdown"] button';
    this.selectCheckbox = (value) => `input[type="checkbox"][value="${value}"]`;
    this.namespaceDropdownButton = '[data-testid="namespace-dropdown"] button';
    this.fullscreenButton = '[data-testid="graph-fullscreen-button"]';
    this.centerButton = '[data-testid="graph-center-button"]';
    this.canvasSelector = '[data-testid="graph-screenshot-container"]';
    this.layoutSettingsButton = '[data-testid="graph-layout-settings-button"]';
    this.ciliumNodesButton = '[data-testid="graph-cilium-toggle"]';
    this.disableCiliumNodesButton = '[data-testid="graph-cilium-toggle"][aria-checked="true"]';
    this.enableCiliumNodesButton = '[data-testid="graph-cilium-toggle"][aria-checked="false"]';

  }

  async selectClusters(clusters) {
    await this.page.waitForSelector(this.clusterDropdownButton, { visible: true });
    await this.page.click(this.clusterDropdownButton);
    for (const cluster of clusters) {
      await this.page.waitForSelector(this.selectCheckbox(cluster), { visible: true });
      await this.page.click(this.selectCheckbox(cluster));
      await new Promise(resolve => setTimeout(resolve, 50));
    }
  }

  async selectNamespaces(namespaces) {
    await this.page.click(this.namespaceDropdownButton);
    for (const namespace of namespaces) {
      await this.page.waitForSelector(this.selectCheckbox(namespace), { visible: true });
      await this.page.click(this.selectCheckbox(namespace));
      await new Promise(resolve => setTimeout(resolve, 50));
    }
  }

  async toggleLayoutSettings() {
    await this.page.waitForSelector(this.layoutSettingsButton, { visible: true, timeout: 5000 });
    await this.page.click(this.layoutSettingsButton);
    // Toggle Layout settings takes a while to open, subsequent actions will fail if we don't wait
    await new Promise(resolve => setTimeout(resolve, 1000));
  }

  async enableCiliumNodes() {
    const ciliumNodesButtonExists = await this.page.$(this.ciliumNodesButton) !== null;
    if (ciliumNodesButtonExists) {
      await this.page.waitForSelector(this.enableCiliumNodesButton, { visible: true, timeout: 5000 });
      await this.page.click(this.enableCiliumNodesButton);
    }
  }

  async disableCiliumNodes() {
    const ciliumNodesButtonExists = await this.page.$(this.ciliumNodesButton) !== null;
    if (ciliumNodesButtonExists) {
      await this.page.waitForSelector(this.disableCiliumNodesButton, { visible: true, timeout: 5000 });
      await this.page.click(this.disableCiliumNodesButton);
    }
  }

  async fullscreenGraph() {
    await this.page.click(this.fullscreenButton);
    await new Promise(resolve => setTimeout(resolve, 150));
  }

  async centerGraph() {
    await this.page.click(this.centerButton);
    await new Promise(resolve => setTimeout(resolve, 150));
  }

  async waitForLoadingContainerToDisappear(timeout = 50000) {
    await this.page.waitForFunction(
      () => !document.querySelector('[data-testid="loading-container"]'),
      { timeout }
    );
  }

  async captureCanvasScreenshot(screenshotPath) {
    await this.page.waitForSelector(this.canvasSelector, { visible: true, timeout: 5000 });
    await this.waitForLoadingContainerToDisappear();
    await this.page.waitForNetworkIdle({ timeout: 5000, idleTime: 500, maxInflightRequests: 0 });

    const canvas = await this.page.$(this.canvasSelector);
    await canvas.screenshot({ path: screenshotPath, omitBackground: true });
  }
}

module.exports = GraphPage;