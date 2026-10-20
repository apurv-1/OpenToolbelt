// Renders index.html frame by frame, generates the soundtrack from the page's
// event list, and encodes an H.264 MP4 with AAC audio.
// Usage: NODE_PATH=<dir with puppeteer-core> node render.cjs [--fps 60] [--start 0] [--end 30] [--out out/opentoolbelt-30s.mp4] [--no-audio]
const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');
const puppeteer = require('puppeteer-core');

const argv = process.argv.slice(2);
const flag = (name, def) => { const i = argv.indexOf('--' + name); return i >= 0 ? argv[i + 1] : def; };
const FPS = Number(flag('fps', 60));
const START = Number(flag('start', 0));
const END = Number(flag('end', 30));
const OUT = flag('out', 'out/opentoolbelt-30s.mp4');
const AUDIO = !argv.includes('--no-audio');
const CHROME = process.env.CHROME_PATH
  || path.join(process.env.HOME, 'Library/Caches/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-mac-arm64/chrome-headless-shell');

const root = __dirname;
const outDir = path.join(root, 'out');
const framesDir = path.join(outDir, 'frames');
fs.rmSync(framesDir, { recursive: true, force: true });
fs.mkdirSync(framesDir, { recursive: true });

(async () => {
  const browser = await puppeteer.launch({
    headless: true,
    executablePath: CHROME,
    args: ['--no-sandbox', '--font-render-hinting=none', '--hide-scrollbars', '--force-color-profile=srgb'],
  });
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.log('PAGEERR', e.message));
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(root, 'index.html'), { waitUntil: 'load' });
  await page.evaluate(() => window.ready);

  const events = await page.evaluate(() => window.EVENTS || []);
  fs.writeFileSync(path.join(outDir, 'events.json'), JSON.stringify(events, null, 1));
  console.log(`events: ${events.length}`);

  const total = Math.round((END - START) * FPS);
  const t0 = Date.now();
  for (let i = 0; i < total; i++) {
    const t = START + i / FPS;
    await page.evaluate((t) => window.seek(t), t);
    await page.screenshot({ path: path.join(framesDir, `f${String(i).padStart(5, '0')}.png`), type: 'png' });
    if (i % (FPS * 2) === 0) process.stdout.write(`frame ${i}/${total} (${((Date.now() - t0) / 1000).toFixed(1)}s)\n`);
  }
  await browser.close();

  const outPath = path.join(root, OUT);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  const videoArgs = ['-y', '-framerate', String(FPS), '-i', path.join(framesDir, 'f%05d.png')];
  const audioArgs = [];
  if (AUDIO) {
    execFileSync('python3', [path.join(root, 'audio.py')], { stdio: 'inherit' });
    // Drums dry; music and blips get a short ambient echo; then mix and normalise loudness.
    execFileSync('ffmpeg', [
      '-v', 'error', '-y', '-i', path.join(outDir, 'drums.wav'), '-i', path.join(outDir, 'music.wav'),
      '-filter_complex',
      '[1:a]aecho=0.7:0.5:38|71|113:0.28|0.2|0.12[wet];[0:a][wet]amix=inputs=2:weights=1 1:normalize=0,alimiter=limit=0.95,loudnorm=I=-14:TP=-1.2:LRA=9[a]',
      '-map', '[a]', '-ar', '48000', path.join(outDir, 'track.wav'),
    ], { stdio: 'inherit' });
    audioArgs.push('-i', path.join(outDir, 'track.wav'), '-c:a', 'aac', '-b:a', '192k', '-shortest');
  }
  execFileSync('ffmpeg', [
    '-v', 'error', ...videoArgs, ...audioArgs,
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p',
    '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709',
    '-movflags', '+faststart', outPath,
  ], { stdio: 'inherit' });
  fs.rmSync(framesDir, { recursive: true, force: true });
  console.log('wrote', OUT, `in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
})().catch((e) => { console.error(e); process.exit(1); });
