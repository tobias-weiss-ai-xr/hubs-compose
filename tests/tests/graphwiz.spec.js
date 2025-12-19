// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('GraphWiz AI New Content', () => {
  // Use localhost:1314 as verified in previous steps, or the configured domain if resolvable.
  // Since we are running from the host, and we know port mapping 1314:1313 exists for graphwiz-ai (or should),
  // we will use http://localhost:1314.
  // If HAProxy routing is used in a real env, it would be https://graphwiz.ai
  
  const BASE_URL = 'http://localhost:1314'; 

  test('Focus Areas page should contain link to XR article', async ({ page }) => {
    await page.goto(`${BASE_URL}/focus-areas/`);
    // Theme sets static title "GraphWiz", so we check H1 instead
    await expect(page.locator('h1.title')).toContainText('Focus Areas');
    
    // Check for the XR section and the link
    const xrSection = page.locator('h3', { hasText: 'XR 🕶️ eXtended Reality' }).locator('..'); // Parent element
    await expect(xrSection).toBeVisible();
    
    const articleLink = page.locator('a[href="/xr/extended-reality-environments/"]');
    await expect(articleLink).toBeVisible();
    await expect(articleLink).toHaveText('Read more about XR environments.');
  });

  test('XR Article page should be reachable and have correct content', async ({ page }) => {
    await page.goto(`${BASE_URL}/xr/extended-reality-environments/`);
    // Theme sets static title "GraphWiz", so we check H1 instead
    await expect(page.locator('h1.title')).toContainText('Exploring Extended Reality (XR) Environments');
    
    // Check for key headers and content
    await expect(page.locator('h1').nth(1)).toContainText('The Evolution of Immersive Spaces');
    await expect(page.locator('h2', { hasText: 'Defining XR Environments' })).toBeVisible();
    await expect(page.locator('h2', { hasText: 'Key Applications' })).toBeVisible();
    await expect(page.locator('text=At GraphWiz, we are committed')).toBeVisible();
  });

  test('XR Section Index page should be reachable and list articles', async ({ page }) => {
    await page.goto(`${BASE_URL}/xr/`);
    // Check for the section title
    await expect(page.locator('h1.title')).toContainText('eXtended Reality (XR)');
    
    // Check if the articles are listed (depending on theme, might be in a list or grid)
    // We look for links to the articles
    await expect(page.locator('a[href="/xr/extended-reality-environments/"]')).toBeVisible();
    await expect(page.locator('a[href="/xr/hubs-learning-rooms/"]')).toBeVisible();
  });

  test('Pages should not have duplicate H1 headlines', async ({ page }) => {
    // Check XR index page
    await page.goto(`${BASE_URL}/xr/`);
    // Theme creates one H1 in header, content should not have another H1 with same text
    // We expect exactly ONE H1 with the title "eXtended Reality (XR)"
    const h1Count = await page.locator('h1', { hasText: 'eXtended Reality (XR)' }).count();
    expect(h1Count).toBe(1);
  });
});
