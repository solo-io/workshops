const { debugLog } = require('../utils/logging');

class BasePage {
  constructor(page) {
    this.page = page;
  }

  async navigateTo(url) {
    debugLog(`Navigating to ${url}`);
    await this.page.goto(url, { waitUntil: 'networkidle2' });
    debugLog('Navigation complete');
  }

  async findVisibleSelector(selectors) {
    for (const selector of selectors) {
      const element = await this.page.$(selector);
      if (element) {
        const visible = await this.page.evaluate(el => !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length), element);
        if (visible) {
          return selector;
        }
      }
    }
    throw new Error('No visible selector found for the provided options.');
  }
}

module.exports = BasePage;