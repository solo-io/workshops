const BasePage = require("../base");

class WelcomePage extends BasePage {
  constructor(page) {
    super(page);

    // Selectors
    this.signInButton = 'button';
  }

  async clickSignIn() {
    await this.page.waitForSelector(this.signInButton, { visible: true, timeout: 5000 });
    await this.page.click(this.signInButton);
  }
}

module.exports = WelcomePage;