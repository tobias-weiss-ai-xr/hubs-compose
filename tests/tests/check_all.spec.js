// @ts-check
const { test, expect } = require('@playwright/test');

const DOMAIN = 'chemie-lernen.org';
const HUBS_DOMAIN = `hubs.${DOMAIN}`;

test.describe('Service Health Checks', () => {

  // Expected to fail with 503 through HAProxy due to HTTP backend for mock
  test('Reticulum via HAProxy (expected 503)', async ({ request }) => {
    const response = await request.get(`https://${HUBS_DOMAIN}/`, { ignoreHTTPSErrors: true });
    expect(response.status()).toBe(503);
  });

  // Expected to fail with 503 through HAProxy due to HTTP backend for mock
  test('Hubs Client via HAProxy (assets, expected 503)', async ({ request }) => {
    const response = await request.get(`https://${HUBS_DOMAIN}/assets`, { ignoreHTTPSErrors: true });
    expect(response.status()).toBe(503);
  });

  test('XWiki Direct (HTTP) is reachable', async ({ page }) => {
    await page.goto('http://xwiki:8080'); // Use internal Docker Compose service name
    await expect(page).toHaveTitle(/XWiki/);
  });

  test('Spoke Direct (HTTP) is reachable and says Hello', async ({ request }) => {
    const response = await request.get('http://spoke:9090'); // Use internal Docker Compose service name
    expect(response.ok()).toBeTruthy();
    expect(await response.text()).toContain('Hello from spoke:9090');
  });

  test('Hubs Admin Direct (HTTP) is reachable and says Hello', async ({ request }) => {
    const response = await request.get('http://hubs-admin:8989'); // Use internal Docker Compose service name
    expect(response.ok()).toBeTruthy();
    expect(await response.text()).toContain('Hello from hubs-admin:8989');
  });

  test('Dialog Direct (HTTP) is reachable and says Hello', async ({ request }) => {
    const response = await request.get('http://dialog:4443'); // Use internal Docker Compose service name
    expect(response.ok()).toBeTruthy();
    expect(await response.text()).toContain('Hello from dialog:4443');
  });

  test('Hubs Storybook Direct (HTTP) is reachable and says Hello', async ({ request }) => {
    const response = await request.get('http://hubs-storybook:6006'); // Use internal Docker Compose service name
    expect(response.ok()).toBeTruthy();
    expect(await response.text()).toContain('Hello from hubs-storybook:6006');
  });
});
