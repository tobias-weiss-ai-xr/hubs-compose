// @ts-check
const { test, expect } = require('@playwright/test');

const DOMAIN = 'chemie-lernen.org';

test.describe('New Pages and Features', () => {

  test.beforeEach(async ({ page }) => {
    // Ignore HTTPS errors for testing with self-signed certs
    await page.goto(`https://${DOMAIN}/`, { waitUntil: 'networkidle' });
  });

  test('Homepage has Wiki and Hubs link cards', async ({ page }) => {
    const hubsCard = page.locator('h3:has-text("Besuchen Sie unsere Hubs-Umgebung")');
    await expect(hubsCard).toBeVisible();
    
    const wikiCard = page.locator('h3:has-text("Besuchen Sie unser Wiki")');
    await expect(wikiCard).toBeVisible();
    
    // Check redundancy fix
    const hubsDescription = page.locator('text=Hier finden Sie interaktive Lernräume für Chemie (in VR).');
    await expect(hubsDescription).toBeVisible();
  });

  test('About page is reachable and has content', async ({ page }) => {
    await page.click('text=Über uns');
    await expect(page).toHaveURL(/\/pages\/about\//);
    await expect(page.locator('h1')).toContainText('Über uns');
    await expect(page.locator('text=Willkommen bei Chemie Lernen')).toBeVisible();
  });

  test('Contact page is reachable and has form', async ({ page }) => {
    await page.click('text=Kontakt');
    await expect(page).toHaveURL(/\/pages\/contact\//);
    await expect(page.locator('h1')).toContainText('Kontakt');
    
    // Verify form elements
    await expect(page.locator('label[for="name"]')).toBeVisible();
    await expect(page.locator('input#name')).toBeVisible();
    await expect(page.locator('input#email')).toBeVisible();
    await expect(page.locator('textarea#message')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
  });

  test('Footer is present and has correct description', async ({ page }) => {
    const footer = page.locator('footer');
    await expect(footer).toBeVisible();
    await expect(footer).toContainText('Chemie Lernen - Ihre Plattform für interaktive Chemie-Lernräume (in VR).');
    await expect(footer).toContainText(new Date().getFullYear().toString());
  });

  test('Navigation menu is dynamic', async ({ page }) => {
    const nav = page.locator('.nav.navbar-nav.navbar-right');
    await expect(nav.locator('text=Wiki')).toBeVisible();
    await expect(nav.locator('text=Hubs')).toBeVisible();
    await expect(nav.locator('text=Über uns')).toBeVisible();
    await expect(nav.locator('text=Kontakt')).toBeVisible();
  });
});
