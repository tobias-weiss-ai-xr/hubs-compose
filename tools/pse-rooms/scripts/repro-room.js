const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const failed = [];
  page.on('requestfailed', r => failed.push(`FAILED ${r.url()} :: ${r.failure()?.errorText}`));
  page.on('response', r => { if (r.status() >= 400) failed.push(`HTTP ${r.status()} ${r.url()}`); });
  const logs = [];
  page.on('console', m => logs.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', e => logs.push(`[PAGEERROR] ${e.message}`));

  await page.goto('https://hubs.chemie-lernen.org/rooms', { waitUntil: 'networkidle', timeout: 60000 }).catch(e => console.log('goto err', e.message));
  await page.waitForTimeout(3000);
  console.log('URL after /rooms:', page.url());
  // dump room-ish links
  const links = await page.evaluate(() => Array.from(document.querySelectorAll('a[href]')).map(a => a.getAttribute('href')).filter(h => h && (h.includes('hub') || h.includes('room') || h.includes('scene'))).slice(0, 20));
  console.log('room links sample:', JSON.stringify(links, null, 1));
  const bodySnippet = (await page.evaluate(() => document.body ? document.body.innerText.slice(0, 400) : 'NO BODY')).replace(/\n+/g, ' | ');
  console.log('BODY text sample:', bodySnippet);
  // images state
  const imgs = await page.evaluate(() => Array.from(document.images).slice(0, 10).map(i => ({src: i.src.slice(0,120), w: i.naturalWidth, h: i.naturalHeight, complete: i.complete})));
  console.log('images:', JSON.stringify(imgs, null, 1));

  await page.screenshot({ path: '/tmp/rooms-page.png', fullPage: false });
  console.log('---CONSOLE---'); logs.slice(0, 40).forEach(l => console.log(l));
  console.log('---FAILED/NETWORK---'); failed.slice(0, 40).forEach(f => console.log(f));
  await browser.close();
})();
