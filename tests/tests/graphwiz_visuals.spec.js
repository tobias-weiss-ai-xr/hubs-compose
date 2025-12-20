// @ts-check
const { test, expect } = require('@playwright/test');

const DOMAIN = 'graphwiz.ai';

test.describe('GraphWiz Visuals', () => {

  test('Logo is visible', async ({ page }) => {
    await page.goto(`https://${DOMAIN}/`);
    
    // Check if the logo image exists and is visible
    const logo = page.locator('img.headshot');
    await expect(logo).toBeVisible();
    
    // Verify the src attribute contains the expected image filename
    await expect(logo).toHaveAttribute('src', /graphwiz_big\.png/);

    // Verify the image natural width is greater than 0 (loaded)
    const isLoaded = await logo.evaluate((img) => {
        return img instanceof HTMLImageElement && img.naturalWidth > 0;
    });
    expect(isLoaded).toBeTruthy();
  });

  test('Dark theme is default', async ({ page }) => {
    await page.goto(`https://${DOMAIN}/`);
    
    // Check if dark theme CSS is enabled
    // The theme toggle script enables/disables the link element with id 'dark-mode-theme'
    const darkThemeLink = page.locator('#dark-mode-theme');
    
    // It should not have the 'disabled' attribute, or 'disabled' should be false
    const isDisabled = await darkThemeLink.evaluate((link) => {
         return link instanceof HTMLLinkElement && link.disabled;
    });
    expect(isDisabled).toBeFalsy();

    // Optionally check computed style - background color of html should be inverted or dark
    // dark.css sets html { background-color: #171717 !important; }
    // But it also uses filters: filter: invert(100%) ...
    // Let's check the background-color of html
    const html = page.locator('html');
    await expect(html).toHaveCSS('background-color', 'rgb(23, 23, 23)');
  });

  test('No duplicate headers', async ({ page }) => {
    await page.goto(`https://${DOMAIN}/`);
    
    // There should be only one header block with class 'header' that contains the author image/name
    // However, the theme has two .header blocks: one for Avatar/Name, one for "GraphWiz" title?
    // Let's count them. The issue was a DUPLICATE of the avatar header.
    
    // The avatar header has class "row text-center header" and contains ".headshot"
    const avatarHeader = page.locator('header.header').filter({ has: page.locator('.headshot') });
    
    // We expect exactly 1 such header
    await expect(avatarHeader).toHaveCount(1);
  });
});
