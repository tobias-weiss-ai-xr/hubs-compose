// @ts-check
const { chromium } = require('@playwright/test');

async function globalSetup(config) {
  console.log('🚀 Setting up Playwright tests for Hubs...');

  // Verify target URL is accessible
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    const targetUrl = config.use?.baseURL || 'https://hubs.chemie-lernen.org';
    console.log(`🔍 Checking connectivity to ${targetUrl}...`);

    const response = await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });

    if (response && response.ok()) {
      console.log('✅ Target server is accessible');
    } else {
      console.log(`⚠️  Target server returned status: ${response?.status()}`);
    }
  } catch (error) {
    console.log(`❌ Cannot reach target server: ${error.message}`);
    console.log('💡 Make sure the Hubs services are running before executing tests');
  } finally {
    await browser.close();
  }

  console.log('✅ Playwright setup complete');
}

async function globalTeardown(config) {
  console.log('🧹 Cleaning up after tests...');
}

module.exports = globalSetup;