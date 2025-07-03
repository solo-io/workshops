const BasePage = require("../base");

class DeveloperPortalAdminSubscriptionPage extends BasePage {
  constructor(page) {
    super(page);
    
    // Subscription management selectors
    this.approveButton = 'button ::-p-text("Approve")';
    this.confirmApproveButton = 'button[type="submit"] ::-p-text("Approve Subscription")';

    // Metadata selectors
    this.editMetadataButton = 'button ::-p-text("Edit Custom Metadata")';
    this.metadataKeyInput = '#meta-key-input';
    this.metadataValueInput = '#meta-value-input';
    this.addMetadataButton = 'button[type="submit"] ::-p-text("Add Metadata")';
    this.saveMetadataButton = 'button[type="button"] ::-p-text("Save")';

    // Rate limit selectors
    this.editRateLimitButton = 'button ::-p-text("Edit Rate Limit")';
    this.requestsPerUnitInput = '#rpu-input';
    this.unitSelect = '#unit-input';
    this.saveRateLimitButton = 'button[type="submit"] ::-p-text("Save")';
  }

  async approveSubscription() {
    // Click the initial approve button
    await this.page.waitForSelector(this.approveButton, { visible: true });
    await this.page.locator(this.approveButton).click();

    // Wait for and click the confirm approve button in the modal
    await this.page.waitForSelector(this.confirmApproveButton, { visible: true });
    await this.page.locator(this.confirmApproveButton).click();

    // Wait for approve button to become disabled
    await this.page.waitForFunction(() => {
      const button = document.querySelector('button[data-disabled="true"]');
        return button && button.innerText.includes("Approve");
    }, { timeout: 3000 });
  }

  async addCustomMetadata(key, value) {
    // Click the edit metadata button
    await this.page.waitForSelector(this.editMetadataButton, { visible: true });
    await this.page.locator(this.editMetadataButton).click();

    // Fill in key and value
    await this.page.waitForSelector(this.metadataKeyInput, { visible: true });
    await this.page.type(this.metadataKeyInput, key);

    await this.page.waitForSelector(this.metadataValueInput, { visible: true });
    await this.page.type(this.metadataValueInput, value);

    // Click add metadata button
    await this.page.waitForSelector(this.addMetadataButton, { visible: true });
    await this.page.locator(this.addMetadataButton).click();

    // Click save button
    await this.page.waitForSelector(this.saveMetadataButton, { visible: true });
    await this.page.click(this.saveMetadataButton);
  }

  async setRateLimit(requests, unit) {
    // Click edit rate limit button
    await this.page.waitForSelector(this.editRateLimitButton, { visible: true });
    await this.page.locator(this.editRateLimitButton).click();

    // Set requests per unit
    await this.page.waitForSelector(this.requestsPerUnitInput, { visible: true });
    await this.page.type(this.requestsPerUnitInput, requests.toString());

    // Click unit select to open dropdown
    await this.page.click(this.unitSelect);

    // Select the unit from dropdown
    await this.page.keyboard.press('ArrowDown');
    await this.page.keyboard.press('ArrowDown');
    await this.page.keyboard.press('Enter');

    // Click save button
    await this.page.waitForSelector(this.saveRateLimitButton, { visible: true });
    await this.page.click(this.saveRateLimitButton);
  }
}

module.exports = DeveloperPortalAdminSubscriptionPage;