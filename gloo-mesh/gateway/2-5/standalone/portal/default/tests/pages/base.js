const { logDebug } = require('../utils/logging');

class BasePage {
  constructor(page) {
    this.page = page;
  }

  async navigateTo(url) {
    logDebug(`Navigating to ${url}`);
    await this.page.goto(url, { waitUntil: 'networkidle2' });
    logDebug('Navigation complete');
  }
}

module.exports = BasePage;