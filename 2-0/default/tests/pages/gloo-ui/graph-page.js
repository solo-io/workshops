const BasePage = require("../base");

class GraphPage extends BasePage {
  constructor(page) {
    super(page)

    // Selectors
    this.selectCheckbox = (value) => `input[type="checkbox"][value="${value}"]`;
    this.graphTypeSelector = '[data-testid="graph-type-text"]';
    this.fullscreenButton = '[data-testid="graph-fullscreen-button"]';
    this.canvasSelector = '[data-testid="graph-screenshot-container"]';
    this.layoutSettingsButton = '[data-testid="graph-layout-settings-button"]';
    this.ciliumNodesButton = '[data-testid="graph-cilium-toggle"]';
    this.disableCiliumNodesButton = '[data-testid="graph-cilium-toggle"][aria-checked="true"]';
    this.enableCiliumNodesButton = '[data-testid="graph-cilium-toggle"][aria-checked="false"]';

    this.originalUISelectors = {
      clusterDropdownButton: '[data-testid="cluster-dropdown"] button',
      namespaceDropdownButton: '[data-testid="namespace-dropdown"] button',
      centerButton: '[data-testid="graph-center-button"]',
    };
    this.reactFlowUISelectors = {
      clusterDropdownButton: '[data-testid="clusters-dropdown"] button',
      namespaceDropdownButton: '[data-testid="namespaces-dropdown"] button',
      centerButton: '[data-testid="graph-fit-view-button"]',
    };
  }

  async selectClusters(clusters) {
    const selector = this[await this.getCurrentGlooUISelectors()]['clusterDropdownButton'];
    await this.page.waitForSelector(selector, { visible: true });
    await this.page.$$eval(selector, elHandles => elHandles.forEach(el => el.click()));
    for (const cluster of clusters) {
      await this.page.waitForSelector(this.selectCheckbox(cluster), { visible: true });
      await this.page.$$eval(this.selectCheckbox(cluster), elHandles => elHandles.forEach(el => el.click()));
      await new Promise(resolve => setTimeout(resolve, 50));
    }
  }

  async selectNamespaces(namespaces) {
    const selector = this[await this.getCurrentGlooUISelectors()]['namespaceDropdownButton'];
    await this.page.waitForSelector(selector, { visible: true });
    await this.page.$$eval(selector, elHandles => elHandles.forEach(el => el.click()));
    for (const namespace of namespaces) {
      await this.page.waitForSelector(this.selectCheckbox(namespace), { visible: true });
      await this.page.$$eval(this.selectCheckbox(namespace), elHandles => elHandles.forEach(el => el.click()));
      await new Promise(resolve => setTimeout(resolve, 50));
    }
  }

  async toggleLayoutSettings() {
    await this.page.waitForSelector(this.layoutSettingsButton, { visible: true, timeout: 5000 });
    await this.page.$$eval(this.layoutSettingsButton, elHandles => elHandles.forEach(el => el.click()));
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
    //await this.page.click(this.fullscreenButton);
    await this.page.screenshot({path: 'blah.png', omitBackground: true})
    await this.page.$$eval(this.fullscreenButton, elHandles => elHandles.forEach(el => el.click()));
    await new Promise(resolve => setTimeout(resolve, 150));
  }

  async centerGraph() {
    //await this.page.click(this.centerButton);
    const selector = this[await this.getCurrentGlooUISelectors()]['centerButton'];
    await this.page.$$eval(selector, elHandles => elHandles.forEach(el => el.click()));
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
    const glooUISelector = await this.getCurrentGlooUISelectors()
    if (glooUISelector === 'reactFlowUISelectors') {
      await this.page.screenshot({ path: screenshotPath, omitBackground: true });
    } else {
      await canvas.screenshot({ path: screenshotPath, omitBackground: true });
    }
  }

  async getCurrentGlooUISelectors() {
    const element = await this.page.$(this.graphTypeSelector);
    if (element) {
      const elementText = await this.page.evaluate(el => el.textContent, element);
      // Full text - View original Graph experience
      if (elementText.includes("original Graph")) {
        return 'reactFlowUISelectors';
      }
    }
    // default
    return 'originalUISelectors';
  }
}

module.exports = GraphPage;