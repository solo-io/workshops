class DeveloperPortalAPIPage {
  constructor(page) {
    this.page = page;

    // Selectors
    this.apiBlocksSelector = 'a[href^="/apis/"]';
  }

  async navigateTo(url) {
    await this.page.goto(url, { waitUntil: 'networkidle2' });
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
