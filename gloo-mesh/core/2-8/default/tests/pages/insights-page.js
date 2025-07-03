const BasePage = require("./base");

class InsightsPage extends BasePage {
  constructor(page) {
    super(page);

    // Selectors
    this.insightTypeQuickFilters = {
      healthy: [
        '[data-testid="health-count-box-healthy"]',
        '[data-testid="health-count-healthy-ui-unit-testing"]'
      ],
      warning: [
        '[data-testid="health-count-box-warning"]',
        '[data-testid="health-count-warning-ui-unit-testing"]'
      ],
      error: [
        '[data-testid="health-count-box-error"]',
        '[data-testid="health-count-erronenous-ui-unit-testing"]',
      ],
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

  async getQuickFiltersResourcesCount(filterType) {
    const quickFilterSelectorName = await this.findVisibleSelector(this.insightTypeQuickFilters[filterType]);
    return parseInt(await this.page.$eval(quickFilterSelectorName, el => el.textContent));
  }

  async openFilterByTypeDropdown() {
    await this.page.waitForSelector(this.filterByTypeDropdown, { visible: true });
    await this.page.$$eval(this.filterByTypeDropdown, elHandles => elHandles.forEach(el => el.click()));
  }

  async openSearchByClusterDropdown() {
    const clusterDropdownButton = await this.findVisibleSelector(this.clusterDropdownButtonSelectors);
    await this.page.$$eval(clusterDropdownButton, elHandles => elHandles.forEach(el => el.click()));
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
      await this.page.$$eval(this.selectCheckbox(cluster), elHandles => elHandles.forEach(el => el.click()));
      await new Promise(resolve => setTimeout(resolve, 50));
    }
  }

  async selectInsightTypes(types) {
    this.openFilterByTypeDropdown();
    for (const type of types) {
      await this.page.$$eval(this.selectCheckbox(type), elHandles => elHandles.forEach(el => el.click()));
      await new Promise(resolve => setTimeout(resolve, 50));
    }
  }
}

module.exports = InsightsPage;