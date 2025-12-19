const { test, expect } = require('@playwright/test');

test.describe('GraphWiz Ops Section', () => {
  test('Ops section lists the new automated testing article', async ({ request }) => {
    // Note: connecting to localhost:1314 as mapped in docker-compose for graphwiz
    const response = await request.get('http://localhost:1313/ops/');
    expect(response.ok()).toBeTruthy();
    
    const text = await response.text();
    expect(text).toContain('Automated Visual Testing & Screenshots');
    expect(text).toContain('Operational Excellence');
  });

  test('New article content is visible', async ({ request }) => {
    const response = await request.get('http://localhost:1313/ops/automated-testing-and-screenshots/');
    expect(response.ok()).toBeTruthy();
    
    const text = await response.text();
    expect(text).toContain('Ensuring Quality with Automated Visual Verification');
    expect(text).toContain('screenshot-service');
  });
});
