// Renders single frames for layout checks: node stills.cjs 1.5 4.0 ...
const path = require('path');
const puppeteer = require('puppeteer-core');
const CHROME = process.env.CHROME_PATH
  || path.join(process.env.HOME, 'Library/Caches/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-mac-arm64/chrome-headless-shell');
(async () => {
  const browser = await puppeteer.launch({ headless: true, executablePath: CHROME, args: ['--no-sandbox', '--font-render-hinting=none', '--force-color-profile=srgb'] });
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.log('PAGEERR', e.message));
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, 'index.html'), { waitUntil: 'load' });
  await page.evaluate(() => window.ready);
  for (const t of process.argv.slice(2).map(Number)) {
    await page.evaluate((t) => window.seek(t), t);
    await page.screenshot({ path: path.join(__dirname, 'out', `still-${t.toFixed(2)}.png`) });
  }
  await browser.close();
})();
