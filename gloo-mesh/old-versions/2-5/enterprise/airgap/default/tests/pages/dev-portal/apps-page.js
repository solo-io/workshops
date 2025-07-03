const BasePage = require("../base");

class DeveloperPortalAppsPage extends BasePage {
  constructor(page) {
    super(page);
    
    // App creation selectors
    this.createAppButton = 'button ::-p-text("CREATE NEW APP")';
    this.teamSelectInput = '#app-team-select';
    this.appNameInput = '#app-name-input';
    this.appDescriptionInput = '#app-description-input';
    this.createAppSubmitButton = 'button[type="submit"] ::-p-text("Create App")';
    
    // App details and subscription selectors
    this.detailsLink = 'a::-p-text("DETAILS")';
    this.addSubscriptionButton = 'div::-p-text("ADD SUBSCRIPTION")';
    this.apiProductSelect = '#api-product-select';
    this.createSubscriptionButton = 'button[type="submit"] ::-p-text("Create Subscription")';

    // API Key selectors
    this.addApiKeyButton = 'div::-p-text("ADD API KEY")';
    this.apiKeyNameInput = '#api-key-name-input';
    this.submitApiKeyButton = 'button[type="submit"] ::-p-text("ADD API Key")';
    this.copyApiKeyButton = 'button[aria-label="Copy this API Key"]';
    this.closeModalButton = 'button ::-p-text("Close")';

    // OAuth client selectors
    this.createOAuthClientButton = 'button ::-p-text("Create OAuth Client")';
    this.confirmOAuthClientButton = 'button[type="submit"] ::-p-text("Create OAuth Client")';
    this.copyOAuthClientButton = 'button[aria-label="Copy this Client Secret"]';
  }

  async clickCreateNewApp() {
    await this.page.locator(this.createAppButton).click();
  }

  async selectTeam(teamName) {
    await this.page.waitForSelector(this.teamSelectInput);
    await this.page.click(this.teamSelectInput);

    const teamOption = `div[role="option"]::-p-text("${teamName}")`;
    await this.page.waitForSelector(teamOption);
    await this.page.click(teamOption);
  }

  async fillAppDetails(name, description) {
    await this.page.waitForSelector(this.appNameInput, { visible: true });
    await this.page.type(this.appNameInput, name);
    
    await this.page.waitForSelector(this.appDescriptionInput, { visible: true });
    await this.page.type(this.appDescriptionInput, description);
  }

  async submitAppCreation() {
    await this.page.locator(this.createAppSubmitButton).click();
  }

  async createNewApp(teamName, appName, appDescription) {
    await this.clickCreateNewApp();
    await this.selectTeam(teamName);
    await this.fillAppDetails(appName, appDescription);
    await this.submitAppCreation();
  }

  async navigateToAppDetails() {
    await this.page.locator(this.detailsLink).click();
  }

  async clickAddSubscription() {
    await this.page.locator(this.addSubscriptionButton).click();
  }

  async selectApiProduct(productName) {
    await this.page.waitForSelector(this.apiProductSelect);
    await this.page.click(this.apiProductSelect);

    const productOption = `div[role="option"]::-p-text("${productName}")`;
    await this.page.waitForSelector(productOption);
    await this.page.click(productOption);
  }

  async submitSubscriptionCreation() {
    await this.page.locator(this.createSubscriptionButton).click();
  }

  async createSubscription(apiProductName) {
    await this.clickAddSubscription();
    await this.selectApiProduct(apiProductName);
    await this.submitSubscriptionCreation();
  }

  async createAppAndSubscribe(teamName, appName, appDescription, apiProductName) {
    await this.createNewApp(teamName, appName, appDescription);
    await this.navigateToAppDetails();
    await this.createSubscription(apiProductName);
  }

  async createApiKey(keyName) {
    // Click ADD API KEY button
    await this.page.locator(this.addApiKeyButton).click();

    // Wait for and fill in the name input
    await this.page.waitForSelector(this.apiKeyNameInput, { visible: true });
    await this.page.type(this.apiKeyNameInput, keyName);

    // Click create button
    await this.page.locator(this.submitApiKeyButton).click();

    // Get API key value from clipboard
    await this.page.waitForSelector(this.copyApiKeyButton, { visible: true });
    await this.page.click(this.copyApiKeyButton);

    const clipboardContent = await this.page.evaluate(() => navigator.clipboard.readText());

    // Close the modal
    await this.page.locator(this.closeModalButton).click();

    return clipboardContent;
  }

  async createOAuthClient() {
    // Click initial Create OAuth Client button
    await this.page.click(this.createOAuthClientButton);
  
    // Wait for and click confirm button in modal
    await this.page.waitForSelector(this.confirmOAuthClientButton, { visible: true });
    await this.page.locator(this.confirmOAuthClientButton).click();

    // Wait for and click copy button
    await this.page.waitForSelector(this.copyOAuthClientButton, { visible: true });
    await this.page.click(this.copyOAuthClientButton);
  
    // Wait for the 'Client ID' label to appear in the modal using page.waitForFunction with XPath
    await this.page.waitForFunction(() => {
      return document.evaluate(
        '//div[text()="Client ID"]',
        document,
        null,
        XPathResult.FIRST_ORDERED_NODE_TYPE,
        null
      ).singleNodeValue !== null;
    });
  
    // Get the Client ID
    const clientId = await this.page.evaluate(() => {
      const clientIdLabel = document.evaluate(
        '//div[text()="Client ID"]',
        document,
        null,
        XPathResult.FIRST_ORDERED_NODE_TYPE,
        null
      ).singleNodeValue;
  
      if (clientIdLabel && clientIdLabel.nextElementSibling) {
        return clientIdLabel.nextElementSibling.textContent.trim();
      }
      return null;
    });
  
    // Get the Client Secret
    const clientSecret = await this.page.evaluate(() => {
      const clientSecretLabel = document.evaluate(
        '//div[text()="Client Secret"]',
        document,
        null,
        XPathResult.FIRST_ORDERED_NODE_TYPE,
        null
      ).singleNodeValue;
  
      if (clientSecretLabel && clientSecretLabel.nextElementSibling) {
        const button = clientSecretLabel.nextElementSibling;
        // The secret value is inside the button's inner text
        const secretText = button.innerText.trim().split('\n')[0];
        return secretText;
      }
      return null;
    });
  
    // Close the modal
    await this.page.click(this.closeModalButton);
  
    return {
      clientId,
      clientSecret,
    };
  }
  
}

module.exports = DeveloperPortalAppsPage;