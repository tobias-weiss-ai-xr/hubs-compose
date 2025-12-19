// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Tobias Weiss Website', () => {
  test('Logo is present and loads correctly', async ({ page }) => {
    await page.goto('http://hugo-tobias-weiss-org:1313/');
    const logo = page.locator('img.headshot');
    await expect(logo).toBeVisible();
    const src = await logo.getAttribute('src');
    expect(src).toBe('/img/me_wanted_big.png');
    const response = await page.request.get('http://hugo-tobias-weiss-org:1313/img/me_wanted_big.png');
    expect(response.status()).toBe(200);
  });
});
