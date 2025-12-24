// @ts-check
const { test, expect } = require("@playwright/test");

test.describe("Hubs Room Functionality", () => {
  const roomUrl = "https://hubs.chemie-lernen.org/YnU6Lgf/whimsical-uncommon-room";

  test("Room loads with HTTP 200", async ({ request }) => {
    const response = await request.get(roomUrl);
    expect(response.status()).toBe(200);
    expect(response.ok()).toBeTruthy();
  });

  test("Room has substantial content (not blank page)", async ({ request }) => {
    const response = await request.get(roomUrl);
    expect(response.ok()).toBeTruthy();

    const html = await response.text();
    expect(html.length).toBeGreaterThan(50000);
    expect(html).toContain("Whimsical Uncommon Room");
    expect(html).toContain("hubs.chemie-lernen.org");
  });

  test("Room has proper HTML structure", async ({ request }) => {
    const response = await request.get(roomUrl);
    expect(response.ok()).toBeTruthy();

    const html = await response.text();
    expect(html).toContain("<\!DOCTYPE html>");
    expect(html).toContain("<html");
    expect(html).toContain("<head>");
    expect(html).toContain("<body>");
    expect(html).toContain("</html>");
  });

  test("Security headers are present", async ({ request }) => {
    const response = await request.get(roomUrl);
    expect(response.ok()).toBeTruthy();

    const headers = response.headers();
    expect(headers["x-content-type-options"]).toBe("nosniff");
    expect(headers["x-frame-options"]).toBe("SAMEORIGIN");
    expect(headers["x-xss-protection"]).toBe("1; mode=block");
  });

  test("Hubs-specific headers are present", async ({ request }) => {
    const response = await request.get(roomUrl);
    expect(response.ok()).toBeTruthy();

    const headers = response.headers();
    expect(headers["hub-entity-type"]).toBe("room");
    expect(headers["hub-name"]).toBe("hubs.chemie-lernen.org");
    expect(headers["server"]).toBe("Cowboy");
  });

  test("JSON-LD structured data is present", async ({ request }) => {
    const response = await request.get(roomUrl);
    expect(response.ok()).toBeTruthy();

    const html = await response.text();
    expect(html).toContain("@context");
    expect(html).toContain("VirtualLocation");
    expect(html).toContain("Whimsical Uncommon Room");
    expect(html).toContain(roomUrl);
  });

  test("Content size indicates full page load", async ({ request }) => {
    const response = await request.get(roomUrl);
    expect(response.ok()).toBeTruthy();

    const contentLength = response.headers()["content-length"];
    const size = parseInt(contentLength);
    expect(size).toBeGreaterThan(50000);
  });

  test("Page loads in browser", async ({ page }) => {
    const response = await page.goto(roomUrl);
    expect(response?.ok()).toBeTruthy();
    await page.waitForLoadState("networkidle");
    
    const title = await page.title();
    expect(title.length).toBeGreaterThan(0);
  });

  test("No JavaScript errors", async ({ page }) => {
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));

    await page.goto(roomUrl);
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(2000);

    expect(errors.filter(e => e.includes("TypeError") || e.includes("ReferenceError"))).toHaveLength(0);
  });

  test("Logo and branding elements are present", async ({ page }) => {
    await page.goto(roomUrl);
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(3000);

    // Check for logo elements
    const logoSelectors = [
      '[data-testid="app-logo"]',
      '.app-logo',
      'img[alt*="logo" i]',
      '.logo',
      '.brand',
      'header img',
      'nav img'
    ];

    let logoFound = false;
    for (const selector of logoSelectors) {
      try {
        const logo = page.locator(selector).first();
        if (await logo.isVisible({ timeout: 2000 })) {
          logoFound = true;

          // Check if logo image loads properly
          const tagName = await logo.evaluate(el => el.tagName.toLowerCase());
          if (tagName === 'img') {
            const naturalWidth = await logo.evaluate(el => el.naturalWidth);
            const naturalHeight = await logo.evaluate(el => el.naturalHeight);
            expect(naturalWidth, "Logo should load properly").toBeGreaterThan(0);
            expect(naturalHeight, "Logo should load properly").toBeGreaterThan(0);
          }
          break;
        }
      } catch (e) {
        // Continue to next selector
      }
    }

    expect(logoFound, "At least one logo element should be visible").toBeTruthy();

    // Check for branding elements
    const title = await page.title();
    expect(title, "Page should have a title").toBeTruthy();
    expect(title.length, "Title should not be empty").toBeGreaterThan(0);

    // Check for meta tags
    const description = await page.locator('meta[name="description"]').getAttribute('content');
    expect(description, "Should have meta description").toBeTruthy();
  });
});
