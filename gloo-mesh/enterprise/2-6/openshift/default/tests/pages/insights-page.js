const BasePage = require("./base");

class InsightsPage extends BasePage {
  constructor(page) {
    super(page);

    // Selectors
    this.insightTypeQuickFilters = {
      healthy: '[data-testid="health-count-box-healthy"]',
      warning: '[data-testid="health-count-box-warning"]',
      error: '[data-testid="health-count-box-error"]'
    };
    this.clusterDropdownButtonSelectors = [
      '[data-testid="filter by cluster...-dropdown"] button',
      '[data-testid="search by cluster...-dropdown"] button'
    ];

    this.filterByTypeDropdown = '[data-testid="filter by type...-dropdown"] button';
    this.clearAllButton = '[data-testid="solo-tag"]:first-child';
    this.tableHeaders = '.ant-table-thead th';
    this.tableRows = '.ant-table-tbody tr';
    this.paginationTotalText = '.ant-pagination-total-text';
    this.selectCheckbox = (name) => `input[type="checkbox"][value="${name}"]`;
  }

  async getHealthyResourcesCount() {
    return parseInt(await this.page.$eval(this.insightTypeQuickFilters.healthy, el => el.querySelector('div').textContent));
  }

  async getWarningResourcesCount() {
    return parseInt(await this.page.$eval(this.insightTypeQuickFilters.warning, el => el.querySelector('div').textContent));
  }

  async getErrorResourcesCount() {
    return parseInt(await this.page.$eval(this.insightTypeQuickFilters.error, el => el.querySelector('div').textContent));
  }


  async openFilterByTypeDropdown() {
    await this.page.waitForSelector(this.filterByTypeDropdown, { visible: true });
    await this.page.click(this.filterByTypeDropdown);
  }

  async openSearchByClusterDropdown() {
    const clusterDropdownButton = await this.findVisibleSelector(this.clusterDropdownButtonSelectors);
    await this.page.waitForSelector(clusterDropdownButton, { visible: true });
    await this.page.click(clusterDropdownButton);
  }

  async clearAllFilters() {
    await this.page.click(this.clearAllButton);
  }

  async getTableHeaders() {
    return this.page.$$eval(this.tableHeaders, headers => headers.map(h => h.textContent.trim()));
  }

  /**
   * Returns a string of arrays for each row.
   * @returns {Promise<string[]>} The table data rows as a string of arrays.
   */
  async getTableDataRows() {
    const rowsData = await this.page.$$eval(this.tableRows, rows =>
      rows.map(row => {
        const cells = row.querySelectorAll('td');
        const rowData = [];
        for (const cell of cells) {
          rowData.push(cell.textContent.trim());
        }
        return rowData.join(' ');
      })
    );
    return rowsData;
  }

  async clickDetailsButton(rowIndex) {
    const buttons = await this.page.$$(this.detailsButton);
    if (rowIndex < buttons.length) {
      await buttons[rowIndex].click();
    } else {
      throw new Error(`Row index ${rowIndex} is out of bounds`);
    }
  }

  async getTotalItemsCount() {
    const totalText = await this.page.$eval(this.paginationTotalText, el => el.textContent);
    return parseInt(totalText.match(/Total (\d+) items/)[1]);
  }

  async selectClusters(clusters) {
    this.openSearchByClusterDropdown();
    for (const cluster of clusters) {
      await this.page.waitForSelector(this.selectCheckbox(cluster), { visible: true });
      await this.page.click(this.selectCheckbox(cluster));
      await new Promise(resolve => setTimeout(resolve, 50));
    }
  }

  async selectInsightTypes(types) {
    this.openFilterByTypeDropdown();
    for (const type of types) {
      await this.page.waitForSelector(this.selectCheckbox(type), { visible: true });
      await this.page.click(this.selectCheckbox(type));
      await new Promise(resolve => setTimeout(resolve, 50));
    }
  }
}

module.exports = InsightsPage;