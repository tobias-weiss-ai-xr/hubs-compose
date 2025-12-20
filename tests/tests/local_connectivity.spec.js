// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Local Connectivity Checks', () => {

  test('Hubs Admin (localhost:8989) is reachable', async ({ request }) => {
    const response = await request.get('https://localhost:8989/admin.html', { ignoreHTTPSErrors: true });
    expect(response.ok()).toBeTruthy();
    expect(await response.text()).toContain('<title>Admin | App by Company</title>');
  });

  test('Hubs Client (localhost:8082) is reachable', async ({ request }) => {
    // Note: Hubs Client uses port 8082 on host now (mapped to 8080)
    const response = await request.get('https://localhost:8082/', { ignoreHTTPSErrors: true });
    expect(response.ok()).toBeTruthy();
    expect(await response.text()).toContain('<title>App</title>');
  });

  test('Reticulum (localhost:4000) is reachable', async ({ request }) => {
    const response = await request.get('https://localhost:4000/api/v1/meta', { ignoreHTTPSErrors: true });
    expect(response.ok()).toBeTruthy();
  });

  test('Reticulum Health (localhost:4000) is reachable', async ({ request }) => {
    const response = await request.get('https://localhost:4000/health', { ignoreHTTPSErrors: true });
    expect(response.ok()).toBeTruthy();
  });

});
