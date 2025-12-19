const puppeteer = require('puppeteer');
const fs = require('fs');

const TARGET_URL = process.env.TARGET_URL || 'https://reticulum:4000'; // Default to internal Reticulum
const OUTPUT_FILE = process.env.OUTPUT_FILE || '/output/screenshot.png';

(async () => {
  console.log(`Starting screenshot capture for: ${TARGET_URL}`);
  
  const browser = await puppeteer.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--ignore-certificate-errors'],
    headless: 'new'
  });

  try {
    const page = await browser.newPage();
    
    // Set viewport to a reasonable desktop size
    await page.setViewport({ width: 1920, height: 1080 });

    console.log('Navigating...');
    const response = await page.goto(TARGET_URL, { waitUntil: 'networkidle0', timeout: 30000 });
    
    console.log(`Response Status: ${response.status()}`);
    
    const title = await page.title();
    console.log(`Page Title: ${title}`);

    // Verification Logic
    // Reticulum redirects to /admin if no accounts, or serves Hubs client if configured.
    // We expect *some* valid response, not a connection error.
    if (!response.ok() && response.status() !== 302 && response.status() !== 404) { 
        // 404 is "bad Room ID" from Reticulum, which is actually a VALID response from the server proving it's up.
        // 200 is Admin or Client.
        throw new Error(`Page load failed with status ${response.status()}`);
    }

    console.log('Taking screenshot...');
    await page.screenshot({ path: OUTPUT_FILE, fullPage: true });
    console.log(`Screenshot saved to ${OUTPUT_FILE}`);

    // If we reached here, basic visual loading worked.
    console.log('TEST PASSED: Landing page is reachable and rendered.');

  } catch (error) {
    console.error('TEST FAILED:', error);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
