const BasePage = require("../base");

class DeveloperPortalAdminAppsPage extends BasePage {
  constructor(page) {
    super(page);
    // Metadata selectors
    this.editMetadataButton = 'button ::-p-text("Edit Custom Metadata")';
    this.metadataKeyInput = '#meta-key-input';
    this.metadataValueInput = '#meta-value-input';
    this.addMetadataButton = 'button[type="submit"] ::-p-text("Add Metadata")';
    this.saveMetadataButton = 'button[type="button"] ::-p-text("Save")';
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
}

module.exports = DeveloperPortalAdminAppsPage;