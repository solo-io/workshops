const BasePage = require("../base");

class OverviewPage extends BasePage {
  constructor(page) {
    super(page)

    // Selectors
    this.listedWorkspacesLinks = 'div[data-testid="overview-area"] div[data-testid="solo-link"] a';
    this.licensesButtons = [
      'button[data-testid="topbar-licenses-toggle"]',
      'div[data-testid="topbar-licenses-toggle"] button'
    ];
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
    const licenseButton = await this.findVisibleSelector(this.licensesButtons);
    await this.page.waitForSelector(licenseButton, { visible: true, timeout: 1000 });
    return true;
  }
}

module.exports = OverviewPage;