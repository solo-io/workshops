const BasePage = require("../base");

class OverviewPage extends BasePage {
  constructor(page) {
    super(page)

    // Selectors
    this.listedWorkspacesLinks = 'div[data-testid="overview-area"] div[data-testid="solo-link"] a';
    this.licensesButton = 'button[data-testid="topbar-licenses-toggle"]';
  }

  async getListedWorkspaces() {
    await this.page.waitForSelector(this.listedWorkspacesLinks, { visible: true, timeout: 5000 });

    const workspaceNames = await this.page.evaluate((selector) => {
      const links = document.querySelectorAll(selector);

      return Array.from(links).map(link => link.textContent.trim());
    }, this.listedWorkspacesLinks);

    return workspaceNames;
  }

  async hasPageLoaded() {
    await this.page.waitForSelector(this.licensesButton, { visible: true, timeout: 5000 });
    return true;
  }
}

module.exports = OverviewPage;