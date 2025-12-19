const { Builder, Browser, By, Key, until } = require('selenium-webdriver');
const fs = require('fs');
const chrome = require('selenium-webdriver/chrome');

(async function example() {
  let options = new chrome.Options();
  options.addArguments('--ignore-certificate-errors');
  options.addArguments('--disable-dev-shm-usage');

  console.log('Connecting to Selenium Grid...');
  let driver = await new Builder()
    .forBrowser(Browser.CHROME)
    .usingServer('http://localhost:4444/wd/hub')
    .setChromeOptions(options)
    .build();

  try {
    // Test Reticulum (HTTPS)
    console.log('Navigating to Reticulum...');
    await driver.get('https://reticulum:4000/api/v1/meta'); // Internal hostname
    let body = await driver.findElement(By.tagName('body')).getText();
    console.log('Reticulum Response:', body);
    
    // Take screenshot of Reticulum response
    let encodedString = await driver.takeScreenshot();
    fs.writeFileSync('./reticulum_screenshot.png', encodedString, 'base64');
    console.log('Saved reticulum_screenshot.png');

    // Test Hubs Admin (HTTPS)
    console.log('Navigating to Hubs Admin...');
    await driver.get('https://hubs-admin:8989/admin.html');
    let title = await driver.getTitle();
    console.log('Hubs Admin Title:', title);

    // Take screenshot of Hubs Admin
    encodedString = await driver.takeScreenshot();
    fs.writeFileSync('./hubs_admin_screenshot.png', encodedString, 'base64');
    console.log('Saved hubs_admin_screenshot.png');

  } catch (e) {
      console.error('Test failed:', e);
  } finally {
    await driver.quit();
  }
})();
