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

  test('Hugo Tobias Weiss (localhost:1315) is reachable', async ({ request }) => {
     // Checking the port based on docker-compose.hugo.yml, though docker ps showed 1313.
     // If this fails, we know the mapping is missing.
    try {
        const response = await request.get('http://localhost:1315/');
        expect(response.ok()).toBeTruthy();
    } catch (e) {
        console.log('Port 1315 not reachable, checking 1313?');
        // This test might fail if port mapping is still missing
        throw e;
    }
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
