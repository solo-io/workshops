class KeycloakSignInPage {
  constructor(page) {
    this.page = page;

    // Selectors
    this.usernameInput = '#username';
    this.passwordInput = '#password';
    this.loginButton = '#kc-login';
    this.showPasswordButton = 'button[data-password-toggle]';
  }

  async signIn(username, password) {
    await new Promise(resolve => setTimeout(resolve, 50));
    await this.page.waitForSelector(this.usernameInput, { visible: true });
    await this.page.type(this.usernameInput, username);

    await new Promise(resolve => setTimeout(resolve, 50));
    await this.page.waitForSelector(this.passwordInput, { visible: true });
    await this.page.type(this.passwordInput, password);

    await new Promise(resolve => setTimeout(resolve, 50));
    await this.page.waitForSelector(this.loginButton, { visible: true });
    await this.page.click(this.loginButton);
  }
}

module.exports = KeycloakSignInPage;