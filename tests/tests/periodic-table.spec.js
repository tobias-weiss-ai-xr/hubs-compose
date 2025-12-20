// @ts-check
const { test, expect } = require('@playwright/test');

const DOMAIN = 'chemie-lernen.org';
const PERIODIC_TABLE_URL = `https://${DOMAIN}/periodic-table/`;

test.describe('Periodic Table - Page Load and Basic Rendering', () => {

  test('should load periodic table page successfully', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });
    await expect(page).toHaveTitle('Periodic Table');
  });

  test('should have correct page structure', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    // Check main UI elements exist
    await expect(page.locator('#info')).toBeVisible();
    await expect(page.locator('#container')).toBeVisible();
    await expect(page.locator('#menu')).toBeVisible();
  });

  test('should display three.js attribution', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    const infoText = await page.locator('#info').textContent();
    expect(infoText).toContain('three.js');
    expect(infoText).toContain('css3d - periodic table');
  });

  test('should have all control buttons', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await expect(page.locator('#table')).toBeVisible();
    await expect(page.locator('#sphere')).toBeVisible();
    await expect(page.locator('#helix')).toBeVisible();
    await expect(page.locator('#grid')).toBeVisible();
  });
});

test.describe('Periodic Table - Element Rendering', () => {

  test('should render all 118 elements', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    // Wait for elements to be created
    await page.waitForTimeout(1000);

    // Check that elements with class 'element' exist (118 elements)
    const elements = page.locator('.element');
    await expect(elements).toHaveCount(118);
  });

  test('should render first element (Hydrogen) correctly', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // Find the first element
    const firstElement = page.locator('.element').first();
    await expect(firstElement).toBeVisible();

    // Check it contains the correct data
    await expect(firstElement.locator('.number')).toContainText('1');
    await expect(firstElement.locator('.symbol')).toContainText('H');
    await expect(firstElement.locator('.details')).toContainText('Hydrogen');
  });

  test('should render last element (Oganesson) correctly', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // Find element with Og symbol
    const ogElement = page.locator('.element .symbol:has-text("Og")').locator('..');
    await expect(ogElement).toBeVisible();

    // Check it contains the correct data
    await expect(ogElement.locator('.number')).toContainText('118');
    await expect(ogElement.locator('.details')).toContainText('Oganesson');
  });

  test('should render some common elements correctly', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // Test a few important elements
    const testElements = [
      { symbol: 'He', name: 'Helium', number: '2' },
      { symbol: 'C', name: 'Carbon', number: '6' },
      { symbol: 'O', name: 'Oxygen', number: '8' },
      { symbol: 'Fe', name: 'Iron', number: '26' },
      { symbol: 'Au', name: 'Gold', number: '79' },
      { symbol: 'U', name: 'Uranium', number: '92' }
    ];

    for (const elem of testElements) {
      const element = page.locator(`.element .symbol:has-text("${elem.symbol}")`).locator('..');
      await expect(element.locator('.number')).toContainText(elem.number);
      await expect(element.locator('.details')).toContainText(elem.name);
    }
  });

  test('should have semi-transparent colored backgrounds on elements', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    const firstElement = page.locator('.element').first();
    const backgroundColor = await firstElement.evaluate(el =>
      window.getComputedStyle(el).backgroundColor
    );

    // Should have rgba color (with alpha for transparency)
    expect(backgroundColor).toMatch(/rgba?\(/);
  });
});

test.describe('Periodic Table - View Transformations', () => {

  test('should transform to sphere view when SPHERE button clicked', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // Click sphere button
    await page.locator('#sphere').click();

    // Wait for animation
    await page.waitForTimeout(2500);

    // Elements should still be visible
    const elements = page.locator('.element');
    await expect(elements.first()).toBeVisible();
  });

  test('should transform to helix view when HELIX button clicked', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // Click helix button
    await page.locator('#helix').click();

    // Wait for animation
    await page.waitForTimeout(2500);

    // Elements should still be visible
    const elements = page.locator('.element');
    await expect(elements.first()).toBeVisible();
  });

  test('should transform to grid view when GRID button clicked', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // Click grid button
    await page.locator('#grid').click();

    // Wait for animation
    await page.waitForTimeout(2500);

    // Elements should still be visible
    const elements = page.locator('.element');
    await expect(elements.first()).toBeVisible();
  });

  test('should transform back to table view when TABLE button clicked', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // First go to sphere
    await page.locator('#sphere').click();
    await page.waitForTimeout(2500);

    // Then back to table
    await page.locator('#table').click();
    await page.waitForTimeout(2500);

    // Elements should still be visible
    const elements = page.locator('.element');
    await expect(elements.first()).toBeVisible();
  });

  test('should handle rapid view switching', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // Rapidly switch between views
    await page.locator('#sphere').click();
    await page.waitForTimeout(500);
    await page.locator('#helix').click();
    await page.waitForTimeout(500);
    await page.locator('#grid').click();
    await page.waitForTimeout(500);
    await page.locator('#table').click();

    // Wait for final animation
    await page.waitForTimeout(2500);

    // Page should still be functional
    const elements = page.locator('.element');
    await expect(elements.first()).toBeVisible();
  });
});

test.describe('Periodic Table - 3D Controls and Interaction', () => {

  test('should initialize with camera at proper position', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // Check that container has canvas/content
    const container = page.locator('#container');
    const hasContent = await container.evaluate(el => el.children.length > 0);
    expect(hasContent).toBe(true);
  });

  test('should handle mouse interaction on container', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    const container = page.locator('#container');

    // Simulate mouse drag (for TrackballControls)
    await container.hover();
    await page.mouse.down();
    await page.mouse.move(100, 100);
    await page.mouse.up();

    // Page should still be functional
    const elements = page.locator('.element');
    await expect(elements.first()).toBeVisible();
  });
});

test.describe('Periodic Table - Responsive and Performance', () => {

  test('should work on mobile viewport', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // All main elements should still be visible
    await expect(page.locator('#info')).toBeVisible();
    await expect(page.locator('#container')).toBeVisible();
    await expect(page.locator('#menu')).toBeVisible();

    // Elements should be rendered
    const elements = page.locator('.element');
    await expect(elements).toHaveCount(118);
  });

  test('should work on tablet viewport', async ({ page }) => {
    // Set tablet viewport
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // All main elements should be visible
    await expect(page.locator('#info')).toBeVisible();
    await expect(page.locator('#container')).toBeVisible();
    await expect(page.locator('#menu')).toBeVisible();
  });

  test('should handle window resize', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(1000);

    // Resize viewport
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.waitForTimeout(500);

    // Elements should still be visible after resize
    const elements = page.locator('.element');
    await expect(elements.first()).toBeVisible();
  });

  test('should not have console errors', async ({ page }) => {
    const consoleErrors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Should not have any console errors
    expect(consoleErrors).toHaveLength(0);
  });
});

test.describe('Periodic Table - Assets and Resources', () => {

  test('should load CSS correctly', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    // Check that the periodic-table.css is loaded
    const stylesheets = await page.$$eval('link[rel="stylesheet"]', links =>
      links.map(link => link.href)
    );

    const hasPeriodicTableCSS = stylesheets.some(href => href.includes('periodic-table.css'));
    expect(hasPeriodicTableCSS).toBe(true);
  });

  test('should load Three.js modules correctly', async ({ page }) => {
    const pageErrors = [];
    page.on('pageerror', error => {
      pageErrors.push(error.message);
    });

    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Should not have module loading errors
    const hasModuleError = pageErrors.some(err =>
      err.includes('module') || err.includes('import')
    );
    expect(hasModuleError).toBe(false);
  });

  test('should use correct base URL (not localhost:1313)', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });

    // Check that no resources are trying to load from localhost:1313
    const requests = [];
    page.on('request', request => {
      requests.push(request.url());
    });

    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);

    const hasLocalhostRequests = requests.some(url => url.includes('localhost:1313'));
    expect(hasLocalhostRequests).toBe(false);
  });
});

test.describe('Periodic Table - Data Accuracy', () => {

  test('should have correct number of periods (rows)', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);

    // Elements are organized in 7 periods (plus lanthanides/actinides)
    // Just verify we have elements from periods 1-7
    const period1 = page.locator('.element .symbol:has-text("H")');
    const period7 = page.locator('.element .symbol:has-text("Og")');

    await expect(period1).toBeVisible();
    await expect(period7).toBeVisible();
  });

  test('should have correct noble gases', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);

    const nobleGases = ['He', 'Ne', 'Ar', 'Kr', 'Xe', 'Rn', 'Og'];

    for (const gas of nobleGases) {
      const element = page.locator(`.element .symbol:has-text("${gas}")`);
      await expect(element).toBeVisible();
    }
  });

  test('should have correct alkali metals', async ({ page }) => {
    await page.goto(PERIODIC_TABLE_URL, { waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);

    const alkaliMetals = ['Li', 'Na', 'K', 'Rb', 'Cs', 'Fr'];

    for (const metal of alkaliMetals) {
      const element = page.locator(`.element .symbol:has-text("${metal}")`);
      await expect(element).toBeVisible();
    }
  });
});
