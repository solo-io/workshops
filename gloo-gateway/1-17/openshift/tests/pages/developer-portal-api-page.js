const BasePage = require("./base");

class DeveloperPortalAPIPage extends BasePage {
  constructor(page) {
    super(page)

    // Selectors
    this.apiBlocksSelector = 'a[href^="/apis/"]';
  }

  async getAPIProducts() {
    await this.page.waitForSelector(this.apiBlocksSelector, { visible: true });

    const apiBlocks = await this.page.evaluate((selector) => {
      const blocks = document.querySelectorAll(selector);

      return Array.from(blocks).map(block => {
        const blockHTML = block.outerHTML;
        return blockHTML;
      });
    }, this.apiBlocksSelector);

    return apiBlocks;
  }
}

module.exports = DeveloperPortalAPIPage;
