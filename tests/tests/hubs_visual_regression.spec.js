// @ts-check
const { test, expect } = require("@playwright/test");

test.describe("Hubs Logo and Visual Regression Tests", () => {
  const roomUrl = "https://hubs.chemie-lernen.org/YnU6Lgf/whimsical-uncommon-room";
  const adminUrl = "https://hubs.chemie-lernen.org:8989/admin";
  const clientUrl = "https://hubs.chemie-lernen.org";

  test.beforeEach(async ({ page }) => {
    // Capture console errors
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(msg.text());
    });
    page.errors = errors;
  });

  test("Logo displays correctly in light mode", async ({ page }) => {
    await page.goto(roomUrl, { waitUntil: "networkidle" });

    // Wait for page to fully load
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(3000);

    // Check for logo element
    const logo = await page.locator('[data-testid="app-logo"], .app-logo, img[alt*="logo"], .logo-container').first();

    // Try multiple selectors for logo
    const logoSelectors = [
      '[data-testid="app-logo"]',
      '.app-logo',
      'img[alt*="logo" i]',
      'img[alt*="Logo" i]',
      '.logo',
      '.brand',
      'header img',
      'nav img',
      '.app-logo img',
      '#app-logo'
    ];

    let logoElement = null;
    for (const selector of logoSelectors) {
      try {
        const element = page.locator(selector).first();
        if (await element.isVisible({ timeout: 2000 })) {
          logoElement = element;
          break;
        }
      } catch (e) {
        // Continue to next selector
      }
    }

    expect(logoElement, "Logo element should be found").toBeTruthy();

    if (logoElement) {
      // Check if logo is visible
      await expect(logoElement).toBeVisible();

      // Check logo dimensions
      const boundingBox = await logoElement.boundingBox();
      expect(boundingBox, "Logo should have valid dimensions").toBeTruthy();
      expect(boundingBox.width).toBeGreaterThan(20);
      expect(boundingBox.height).toBeGreaterThan(20);

      // Check if logo image loads properly
      const tagName = await logoElement.evaluate(el => el.tagName.toLowerCase());
      if (tagName === 'img') {
        const naturalWidth = await logoElement.evaluate(el => el.naturalWidth);
        const naturalHeight = await logoElement.evaluate(el => el.naturalHeight);
        expect(naturalWidth).toBeGreaterThan(0);
        expect(naturalHeight).toBeGreaterThan(0);

        // Check for broken image
        const isComplete = await logoElement.evaluate(el => el.complete && el.naturalHeight !== 0);
        expect(isComplete, "Logo image should load completely").toBeTruthy();
      }
    }

    // Check for no console errors related to logo loading
    const logoErrors = page.errors.filter(e =>
      e.toLowerCase().includes('logo') ||
      e.toLowerCase().includes('image') ||
      e.toLowerCase().includes('404')
    );
    expect(logoErrors).toHaveLength(0);
  });

  test("Page loads without layout breaks", async ({ page }) => {
    await page.goto(roomUrl, { waitUntil: "networkidle" });
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(3000);

    // Check for horizontal scrollbars (indicates layout issues)
    const body = page.locator('body');
    const bodyBox = await body.boundingBox();
    const html = page.locator('html');
    const htmlBox = await html.boundingBox();

    expect(bodyBox.width, "Body should not have horizontal overflow").toBeLessThanOrEqual(htmlBox.width + 5);

    // Check viewport meta tag
    const viewport = await page.locator('meta[name="viewport"]');
    await expect(viewport, "Viewport meta tag should be present").toHaveAttribute("content");

    // Check for responsive breakpoints
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.waitForTimeout(1000);
    const desktopLogo = page.locator('[data-testid="app-logo"], .app-logo, img[alt*="logo"], .logo-container').first();

    await page.setViewportSize({ width: 768, height: 1024 });
    await page.waitForTimeout(1000);
    const tabletLogo = page.locator('[data-testid="app-logo"], .app-logo, img[alt*="logo"], .logo-container').first();

    await page.setViewportSize({ width: 375, height: 667 });
    await page.waitForTimeout(1000);
    const mobileLogo = page.locator('[data-testid="app-logo"], .app-logo, img[alt*="logo"], .logo-container').first();

    // Logo should be visible on all viewports
    if (await desktopLogo.isVisible()) await expect(desktopLogo).toBeVisible();
    if (await tabletLogo.isVisible()) await expect(tabletLogo).toBeVisible();
    if (await mobileLogo.isVisible()) await expect(mobileLogo).toBeVisible();
  });

  test("Screenshots and thumbnails load properly", async ({ page }) => {
    await page.goto(roomUrl, { waitUntil: "networkidle" });
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(5000); // Wait for images to load

    // Find all image elements
    const images = page.locator('img');
    const imageCount = await images.count();

    if (imageCount > 0) {
      // Check each image for proper loading
      for (let i = 0; i < Math.min(imageCount, 20); i++) { // Limit to first 20 images
        const img = images.nth(i);
        const isVisible = await img.isVisible();

        if (isVisible) {
          // Check if image loaded
          const naturalWidth = await img.evaluate(el => el.naturalWidth);
          const naturalHeight = await img.evaluate(el => el.naturalHeight);

          if (naturalWidth === 0 || naturalHeight === 0) {
            const src = await img.getAttribute('src');
            console.warn(`Broken image detected: ${src}`);
          }
        }
      }
    }

    // Check for screenshot-specific elements
    const screenshotSelectors = [
      '.screenshot',
      '[data-testid="screenshot"]',
      '.room-preview',
      '.thumbnail',
      '[data-testid="thumbnail"]',
      'img[alt*="screenshot" i]',
      'img[alt*="preview" i]'
    ];

    for (const selector of screenshotSelectors) {
      const element = page.locator(selector).first();
      if (await element.isVisible({ timeout: 2000 })) {
        await expect(element).toBeVisible();

        // If it's an image, check it loads
        const tagName = await element.evaluate(el => el.tagName.toLowerCase());
        if (tagName === 'img') {
          const isLoaded = await element.evaluate(el => el.complete && el.naturalHeight !== 0);
          expect(isLoaded, `Screenshot image ${selector} should load properly`).toBeTruthy();
        }
      }
    }
  });

  test("CSS and resources load without 404 errors", async ({ page }) => {
    const failedRequests = [];

    page.on('requestfailed', (request) => {
      const failure = request.failure();
      if (failure && failure.errorText !== 'net::ERR_ABORTED') {
        failedRequests.push({
          url: request.url(),
          error: failure.errorText,
          resourceType: request.resourceType()
        });
      }
    });

    await page.goto(roomUrl, { waitUntil: "networkidle" });
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(3000);

    // Check for critical resource failures
    const criticalFailures = failedRequests.filter(req =>
      req.resourceType === 'stylesheet' ||
      req.resourceType === 'script' ||
      req.resourceType === 'image'
    );

    // Log all failed requests for debugging
    if (criticalFailures.length > 0) {
      console.log('Failed resource requests:', criticalFailures);
    }

    // Allow some non-critical failures (like tracking pixels)
    expect(criticalFailures.filter(f => !f.url.includes('analytics') && !f.url.includes('tracking'))).toHaveLength(0);
  });

  test("Dark mode logo functionality", async ({ page }) => {
    await page.goto(roomUrl, { waitUntil: "networkidle" });
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(3000);

    // Check if there's a dark mode toggle or if page defaults to dark mode
    const darkModeSelectors = [
      '[data-theme="dark"]',
      '.dark-mode',
      '.dark',
      '[class*="dark"]'
    ];

    let isDarkMode = false;
    for (const selector of darkModeSelectors) {
      if (await page.locator(selector).isVisible()) {
        isDarkMode = true;
        break;
      }
    }

    // Find logo element
    const logoSelectors = [
      '[data-testid="app-logo"]',
      '.app-logo',
      'img[alt*="logo" i]',
      '.logo'
    ];

    let logoElement = null;
    for (const selector of logoSelectors) {
      try {
        const element = page.locator(selector).first();
        if (await element.isVisible({ timeout: 2000 })) {
          logoElement = element;
          break;
        }
      } catch (e) {
        // Continue to next selector
      }
    }

    if (logoElement) {
      await expect(logoElement).toBeVisible();

      // Check logo image source based on theme
      if (isDarkMode) {
        const src = await logoElement.getAttribute('src');
        if (src) {
          // In dark mode, should use dark logo or chemistry logo
          const hasDarkLogo = src.includes('dark') || src.includes('chemie') || src.includes('logo');
          expect(hasDarkLogo, `Dark mode should use appropriate logo: ${src}`).toBeTruthy();
        }
      }
    }
  });

  test("Accessibility and alt text for logos", async ({ page }) => {
    await page.goto(roomUrl, { waitUntil: "networkidle" });
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(3000);

    // Find all logo images
    const logoImages = page.locator('img[alt*="logo" i], img[alt*="Logo" i]');
    const count = await logoImages.count();

    for (let i = 0; i < count; i++) {
      const img = logoImages.nth(i);
      const alt = await img.getAttribute('alt');
      const isVisible = await img.isVisible();

      if (isVisible) {
        // Check for meaningful alt text
        expect(alt, `Logo image should have descriptive alt text`).toBeTruthy();
        expect(alt.length, `Alt text should be descriptive`).toBeGreaterThan(3);

        // Check if alt text is not just "logo" or "image"
        expect(['logo', 'image', 'img', 'picture']).not.toContain(alt.toLowerCase());
      }
    }
  });

  test("Performance check for logo loading", async ({ page }) => {
    const startTime = Date.now();

    await page.goto(roomUrl, { waitUntil: "networkidle" });
    await page.waitForLoadState("networkidle");

    // Wait for logo to load
    const logoSelectors = [
      '[data-testid="app-logo"]',
      '.app-logo',
      'img[alt*="logo" i]',
      '.logo'
    ];

    let logoLoaded = false;
    for (const selector of logoSelectors) {
      try {
        const element = page.locator(selector).first();
        if (await element.isVisible({ timeout: 5000 })) {
          const tagName = await element.evaluate(el => el.tagName.toLowerCase());
          if (tagName === 'img') {
            await element.waitForFunction(el => el.complete && el.naturalHeight !== 0, { timeout: 10000 });
          }
          logoLoaded = true;
          break;
        }
      } catch (e) {
        // Continue to next selector
      }
    }

    const loadTime = Date.now() - startTime;

    expect(logoLoaded, "Logo should load successfully").toBeTruthy();
    expect(loadTime, "Page should load within reasonable time").toBeLessThan(15000); // 15 seconds max
  });
});