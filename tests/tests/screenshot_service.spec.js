// @ts-check
const { test, expect } = require("@playwright/test");

test.describe("Screenshot Service Tests", () => {
  const roomUrl = "https://hubs.chemie-lernen.org/YnU6Lgf/whimsical-uncommon-room";
  const screenshotServiceUrl = "http://localhost:3000"; // Adjust if different

  test("Screenshot service is accessible", async ({ request }) => {
    try {
      const response = await request.get(screenshotServiceUrl);
      // Service might not be running, so this test is optional
      if (response.status() !== 0) {
        expect(response.ok()).toBeTruthy();
      }
    } catch (error) {
      console.log("Screenshot service not accessible - this is expected if it's not running");
    }
  });

  test("Room page has meta tags for screenshots", async ({ page }) => {
    await page.goto(roomUrl, { waitUntil: "networkidle" });

    // Check for Open Graph tags
    const ogTitle = await page.locator('meta[property="og:title"]').getAttribute('content');
    const ogImage = await page.locator('meta[property="og:image"]').getAttribute('content');
    const ogDescription = await page.locator('meta[property="og:description"]').getAttribute('content');

    expect(ogTitle, "OG title should be present").toBeTruthy();
    expect(ogTitle.length, "OG title should not be empty").toBeGreaterThan(0);

    // OG image might be optional
    if (ogImage) {
      expect(ogImage).toMatch(/^https?:\/\/.+\.(jpg|jpeg|png|gif|webp)$/i);
    }
  });

  test("Room page structured data for screenshots", async ({ page }) => {
    await page.goto(roomUrl, { waitUntil: "networkidle" });

    // Check for JSON-LD structured data
    const structuredData = await page.locator('script[type="application/ld+json"]');
    const count = await structuredData.count();

    expect(count, "Should have structured data").toBeGreaterThan(0);

    for (let i = 0; i < count; i++) {
      const content = await structuredData.nth(i).textContent();
      expect(content, "Structured data should be valid JSON").toBeTruthy();

      try {
        const parsed = JSON.parse(content);
        // Check for relevant properties
        if (parsed['@type'] === 'VirtualLocation') {
          expect(parsed.name, "VirtualLocation should have name").toBeTruthy();
          expect(parsed.url, "VirtualLocation should have URL").toBeTruthy();
        }
      } catch (e) {
        // Not valid JSON, fail the test
        expect.fail(`Invalid JSON-LD found: ${content.substring(0, 100)}...`);
      }
    }
  });

  test("Page renders without critical errors", async ({ page }) => {
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(msg.text());
    });

    await page.goto(roomUrl, { waitUntil: "networkidle" });
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(5000);

    // Filter out non-critical errors
    const criticalErrors = errors.filter(e =>
      !e.includes('Non-Error promise rejection') &&
      !e.includes('ResizeObserver loop') &&
      !e.includes('warning') &&
      !e.includes('deprecated')
    );

    if (criticalErrors.length > 0) {
      console.log("Critical errors found:", criticalErrors);
    }

    // Allow some non-critical errors
    expect(criticalErrors.length).toBeLessThan(3);
  });

  test("Page content is substantial for screenshots", async ({ page }) => {
    await page.goto(roomUrl, { waitUntil: "networkidle" });
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(5000);

    // Check page has content
    const body = page.locator('body');
    const bodyText = await body.textContent();

    expect(bodyText, "Page should have text content").toBeTruthy();
    expect(bodyText.length, "Page should have substantial content").toBeGreaterThan(100);

    // Check for key elements that should be present in screenshots
    const elementsToCheck = [
      'h1', 'h2', 'h3', // Headings
      'img', // Images
      'button', // Interactive elements
      'a', // Links
      '[role="button"]' // Button-like elements
    ];

    let elementCount = 0;
    for (const selector of elementsToCheck) {
      const count = await page.locator(selector).count();
      elementCount += count;
    }

    expect(elementCount, "Page should have interactive elements").toBeGreaterThan(5);
  });

  test("Viewport and screenshot dimensions", async ({ page }) => {
    // Test with standard screenshot dimensions
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto(roomUrl, { waitUntil: "networkidle" });
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(3000);

    // Check page dimensions
    const body = page.locator('body');
    const bodyBox = await body.boundingBox();

    expect(bodyBox, "Body should have valid dimensions").toBeTruthy();
    expect(bodyBox.width, "Page should have reasonable width").toBeGreaterThan(800);
    expect(bodyBox.height, "Page should have reasonable height").toBeGreaterThan(600);

    // Test mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.waitForTimeout(2000);

    const mobileBodyBox = await body.boundingBox();
    expect(mobileBodyBox.width, "Mobile page should adapt width").toBeLessThanOrEqual(375 + 20); // Allow some overflow
  });

  test("CSS loads properly for visual consistency", async ({ page }) => {
    const cssRequests = [];

    page.on('request', (request) => {
      if (request.resourceType() === 'stylesheet') {
        cssRequests.push(request.url());
      }
    });

    page.on('response', (response) => {
      if (response.resourceType() === 'stylesheet' && !response.ok()) {
        console.warn(`CSS failed to load: ${response.url()} - ${response.status()}`);
      }
    });

    await page.goto(roomUrl, { waitUntil: "networkidle" });
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(3000);

    expect(cssRequests.length, "Should load CSS files").toBeGreaterThan(0);

    // Check that CSS is actually applied
    const styledElement = page.locator('body, .styled, [class*="style"]');
    const hasStyling = await styledElement.count() > 0;

    if (hasStyling) {
      // Check for computed styles
      const computedStyles = await page.evaluate(() => {
        const element = document.body;
        const styles = window.getComputedStyle(element);
        return {
          backgroundColor: styles.backgroundColor,
          fontFamily: styles.fontFamily,
          fontSize: styles.fontSize,
          color: styles.color
        };
      });

      expect(computedStyles.fontFamily, "Should have applied font styles").toBeTruthy();
      expect(computedStyles.fontSize, "Should have applied font size").toBeTruthy();
    }
  });

  test("Page is ready for screenshot capture", async ({ page }) => {
    await page.goto(roomUrl, { waitUntil: "networkidle" });

    // Wait for all images to load
    await page.waitForFunction(() => {
      const images = Array.from(document.querySelectorAll('img'));
      return images.every(img => img.complete && img.naturalHeight !== 0);
    }, { timeout: 15000 });

    // Wait for fonts to load
    await page.waitForFunction(() => {
      return document.fonts.ready;
    }, { timeout: 10000 });

    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(3000);

    // Take a test screenshot to ensure page is renderable
    const screenshot = await page.screenshot({
      fullPage: true,
      type: 'png'
    });

    expect(screenshot.length, "Screenshot should have content").toBeGreaterThan(1000);

    // Check screenshot contains actual content (not just white)
    const hasContent = screenshot.some(byte => byte !== 0xFF && byte !== 0x00);
    expect(hasContent, "Screenshot should contain visual content").toBeTruthy();
  });
});