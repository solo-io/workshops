class DeveloperPortalHomePage {
  constructor(page) {
    this.page = page;

    // Selectors
    this.loginLink = 'a[href="/v1/login"]';
    this.userHolder = '[class="userHolder"]';
  }

  async navigateTo(url) {
    await this.page.goto(url, { waitUntil: 'networkidle2' });
  }

  async clickLogin() {
    await this.page.waitForSelector(this.loginLink, { visible: true });
    await this.page.click(this.loginLink);
  }

  async getLoggedInUserName() {
    await this.page.waitForSelector(this.userHolder, { visible: true });

    const username = await this.page.evaluate(() => {
      const userHolderDiv = document.querySelector('.userHolder');
      const text = userHolderDiv ? userHolderDiv.textContent.trim() : '';
      return text.replace(/<svg[^>]*>([\s\S]*?)<\/svg>/g, '').trim();
    });

    return username;
  }
}

module.exports = DeveloperPortalHomePage;
