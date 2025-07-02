const BasePage = require("../base");

class DeveloperPortalTeamsPage extends BasePage {
  constructor(page) {
    super(page);
    
    // Team creation selectors
    this.createTeamButton = 'button ::-p-text("CREATE NEW TEAM")';
    this.teamNameInput = '#team-name-input';
    this.teamDescriptionInput = '#team-description-input';
    this.submitTeamButton = 'button[type="submit"] ::-p-text("Create Team")';
    
    // Team details and user management selectors
    this.detailsLink = 'a::-p-text("DETAILS")';
    this.addUserButton = 'div::-p-text("ADD USER")';
    this.memberEmailInput = '#member-email-input';
    this.submitAddUserButton = 'button[type="submit"] ::-p-text("ADD USER")';
  }

  async clickCreateNewTeam() {
    await this.page.locator(this.createTeamButton).click();
  }

  async fillTeamDetails(name, description) {
    await this.page.waitForSelector(this.teamNameInput, { visible: true });
    await this.page.type(this.teamNameInput, name);
    
    await this.page.waitForSelector(this.teamDescriptionInput, { visible: true });
    await this.page.type(this.teamDescriptionInput, description);
  }

  async submitTeamCreation() {
    await this.page.locator(this.submitTeamButton).click();
  }

  async createNewTeam(name, description) {
    await this.clickCreateNewTeam();
    await this.fillTeamDetails(name, description);
    await this.submitTeamCreation();
  }

  async navigateToTeamDetails() {
    await this.page.locator(this.detailsLink).click();
  }

  async addUserToTeam(email) {
    // Click the initial ADD USER button to open the form
    await this.page.locator(this.addUserButton).click();
    
    // Wait for and fill in the email input
    await this.page.waitForSelector(this.memberEmailInput, { visible: true });
    await this.page.type(this.memberEmailInput, email);
    
    // Click the submit button to add the user
    await this.page.locator(this.submitAddUserButton).click();
  }

  async createTeamAndAddUser(teamName, teamDescription, userEmail) {
    await this.createNewTeam(teamName, teamDescription);
    await this.navigateToTeamDetails();
    await this.addUserToTeam(userEmail);
  }
}

module.exports = DeveloperPortalTeamsPage;