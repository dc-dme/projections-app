const { test: base, expect } = require('@playwright/test');
const fs = require('node:fs/promises');
const { zipSync, strToU8 } = require('fflate');

const origin = 'http://127.0.0.1:4173';
// Shinylive routes R's stderr through console.error, including package startup
// messages. Allow only these observed bslib attachment lines, not arbitrary R errors.
const startupMessages = new Set([
  'preload error:',
  'preload error:Attaching package: \u2018bslib\u2019',
  'preload error:The following object is masked from \u2018package:utils\u2019:',
  'preload error:    page',
]);

const test = base.extend({
  context: async ({ playwright, launchOptions, baseURL, viewport, deviceScaleFactor,
    isMobile, hasTouch, userAgent, serviceWorkers, actionTimeout, channel, headless }, use, testInfo) => {
    const netlog = testInfo.outputPath('chromium-netlog.json');
    const browser = await playwright.chromium.launch({
      ...launchOptions,
      channel,
      headless,
      args: [...(launchOptions.args || []), `--log-net-log=${netlog}`],
    });
    const context = await browser.newContext({ baseURL, viewport, deviceScaleFactor,
      isMobile, hasTouch, userAgent, serviceWorkers, acceptDownloads: true });
    context.setDefaultTimeout(actionTimeout);
    const blockedExternal = [];
    await context.route('**/*', async route => {
      const request = route.request();
      if (new URL(request.url()).origin !== origin) {
        blockedExternal.push({ url: request.url(), method: request.method() });
        await route.abort('blockedbyclient');
      } else {
        await route.continue();
      }
    });
    try { await use(context); }
    finally {
      await context.close();
      await browser.close();
      // Browser-level NetLog includes dedicated/shared/service-worker requests,
      // unlike an audit that observes only the app page's requests.
      const log = JSON.parse(await fs.readFile(netlog, 'utf8'));
      const startType = log.constants.logEventTypes.URL_REQUEST_START_JOB;
      const requests = log.events.filter(e => e.type === startType && e.params?.url)
        .map(e => ({ url: e.params.url, method: e.params.method, source: e.source }));
      const external = requests.filter(r => /^(https?|wss?):/.test(r.url) && new URL(r.url).origin !== origin);
      const httpErrors = log.events.filter(e => e.type === log.constants.logEventTypes.HTTP_TRANSACTION_READ_RESPONSE_HEADERS)
        .filter(e => /^HTTP\/\S+ [45]\d\d/.test(e.params?.headers?.[0]))
        .map(e => ({ url: requests.find(r => r.source.id === e.source.id)?.url, headers: e.params.headers }));
      const auditPath = testInfo.outputPath('network-audit.json');
      await fs.writeFile(auditPath, JSON.stringify({ requestCount: requests.length, blockedExternal, external, httpErrors }, null, 2));
      await testInfo.attach('network-audit', { path: auditPath, contentType: 'application/json' });
      // Keep one raw log on disk; only copy it into the report on failure.
      if (testInfo.errors.length || external.length || blockedExternal.length || httpErrors.length) {
        await testInfo.attach('browser-network-log', { path: netlog, contentType: 'application/json' });
      }
      expect(requests.some(r => r.url.startsWith(`${origin}/projections-app/`)),
        'NetLog must actually observe the exported app').toBe(true);
      expect(external.filter(r => !['GET', 'HEAD'].includes(r.method)),
        'No external enrollment uploads, POSTs, or other writes').toEqual([]);
      expect(external.filter(r => r.url.includes('BROWSER_SYNTHETIC_DISTRICT')),
        'Synthetic school name must not leave the browser').toEqual([]);
      expect(blockedExternal, 'No attempted external requests, even when blocked').toEqual([]);
      expect(external, 'No external requests, including workers bypassing routing').toEqual([]);
      expect(httpErrors, 'Browser-wide HTTP errors, including downloads and workers').toEqual([]);
    }
  },
  app: async ({ page, context }, use, testInfo) => {
    const consoleMessages = [];
    const errors = [];
    const failedRequests = [];
    context.on('console', msg => consoleMessages.push({ type: msg.type(), text: msg.text(), location: msg.location() }));
    context.on('page', p => p.on('pageerror', error => errors.push(error.message)));
    page.on('pageerror', error => errors.push(error.message));
    context.on('requestfailed', req => failedRequests.push({ url: req.url(), error: req.failure() }));
    context.on('response', res => {
      if (res.status() >= 400) failedRequests.push({ url: res.url(), status: res.status() });
    });
    try {
      const response = await page.goto('./');
      expect(response.ok()).toBe(true);
      expect(response.headers()['cross-origin-opener-policy']).toBeUndefined();
      expect(response.headers()['cross-origin-embedder-policy']).toBeUndefined();
      let frame;
      await expect.poll(async () => {
        for (const candidate of page.frames()) {
          if (candidate === page.mainFrame()) continue;
          if (await candidate.locator('#history_status').getByText('9 records', { exact: false }).count()) {
            frame = candidate;
            return true;
          }
        }
        return false;
      }, { timeout: 120_000, message: 'Shinylive iframe boots and renders real Shiny example data' }).toBe(true);
      expect(await frame.evaluate(() => crossOriginIsolated), 'GitHub Pages-like non-isolated iframe').toBe(false);
      await expect(frame.locator('#history_status')).toBeVisible();
      await use(frame);
      if (testInfo.errors.length === 0) {
        const screenshot = testInfo.outputPath('workflow-complete.png');
        await page.screenshot({ path: screenshot, fullPage: true });
        await testInfo.attach('workflow-complete', { path: screenshot, contentType: 'image/png' });
      }
    } finally {
      const diagnostics = testInfo.outputPath('browser-diagnostics.json');
      await fs.writeFile(diagnostics, JSON.stringify({ consoleMessages, errors, failedRequests }, null, 2));
      await testInfo.attach('browser-diagnostics', {
        path: diagnostics,
        contentType: 'application/json',
      });
      expect(errors, 'Uncaught page errors').toEqual([]);
      expect(consoleMessages.filter(msg => msg.type === 'error' &&
        !(msg.location.url === `${origin}/projections-app/shinylive/shinylive.js` && startupMessages.has(msg.text))),
      'Console errors other than exact R startup messages').toEqual([]);
      expect(failedRequests, 'Failed runtime assets or requests').toEqual([]);
    }
  },
});

async function disclosure(app, id) {
  const details = app.locator(`details#${id}`);
  if (!await details.evaluate(element => element.open)) {
    await details.locator(':scope > summary').click();
  }
  await expect(details).toHaveAttribute('open', '');
}

async function number(app, id, value) {
  await app.locator(`#${id}`).fill(String(value));
  await app.locator(`#${id}`).press('Tab');
}

async function rows(app, id) {
  return app.locator(`#${id} tbody tr`).evaluateAll(trs => trs.map(tr =>
    Array.from(tr.querySelectorAll('td'), td => td.textContent.trim())));
}

async function results(app, expected) {
  await expect(app.locator('#result_status [role="status"], #result_status[role="status"]')).toContainText(/Example data|Uploaded data/);
  await expect(app.locator('#results .projection-body')).toBeVisible();
  await expect(app.locator('#projection_download')).toBeVisible();
  await disclosure(app, 'projection_details');
  await expect(app.locator('#projection_details #projection_table')).toBeVisible();
  await expect.poll(async () => (await rows(app, 'projection_table')).map(row =>
    [Number(row[0]), row[1], Number(row[2])])).toEqual(expected);
}

async function file(name, columns, data, excel = false) {
  if (excel) {
    const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    const rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    const escape = value => String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const sheet = records => `<worksheet xmlns="${ns}"><sheetData>${records.map((row, i) =>
      `<row r="${i + 1}">${row.map((cell, j) => {
        const ref = `${String.fromCharCode(65 + j)}${i + 1}`;
        return typeof cell === 'number' ? `<c r="${ref}"><v>${cell}</v></c>` :
          `<c r="${ref}" t="inlineStr"><is><t>${escape(cell)}</t></is></c>`;
      }).join('')}</row>`).join('')}</sheetData></worksheet>`;
    const parts = {
      '[Content_Types].xml': '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      '_rels/.rels': `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="${rel}/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
      'xl/workbook.xml': `<workbook xmlns="${ns}" xmlns:r="${rel}"><sheets><sheet name="Enrollment" sheetId="1" r:id="rId1"/><sheet name="Ignored" sheetId="2" r:id="rId2"/></sheets></workbook>`,
      'xl/_rels/workbook.xml.rels': `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="${rel}/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="${rel}/worksheet" Target="worksheets/sheet2.xml"/></Relationships>`,
      'xl/worksheets/sheet1.xml': sheet([columns, ...data]),
      'xl/worksheets/sheet2.xml': sheet([['not', 'enrollment'], ['must', 'ignore']]),
    };
    return { name: `${name}.xlsx`, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      buffer: Buffer.from(zipSync(Object.fromEntries(Object.entries(parts).map(([path, xml]) => [path, strToU8(xml)])))) };
  }
  return { name: `${name}.csv`, mimeType: 'text/csv',
    buffer: Buffer.from([columns, ...data].map(row => row.join(',')).join('\n') + '\n') };
}

async function download(page, app, id, filename) {
  const pending = page.waitForEvent('download');
  await app.locator(`#${id}`).click();
  const item = await pending;
  const failure = await item.failure();
  expect.soft(item.suggestedFilename(), `Download filename for ${id}`).toBe(filename);
  expect(failure, `Download ${id} must complete (${item.url()})`).toBeNull();
  const text = await fs.readFile(await item.path(), 'utf8');
  await test.info().attach(id, { body: text, contentType: 'text/csv' });
  // These generated CSVs have simple numeric/grade fields, not quoted commas.
  return text.trim().split(/\r?\n/).map(line => line.split(',').map(cell => cell.replace(/^"|"$/g, '')));
}

async function plot(app) {
  const image = app.locator('#projection_plot img');
  await expect(image).toBeVisible();
  await expect.poll(() => image.evaluate(img => img.complete && img.naturalWidth > 100 && img.naturalHeight > 100)).toBe(true);
  await expect(image).toHaveAttribute('alt', /Enrollment by year/);
  return image.getAttribute('src');
}

async function layoutScreenshot(page, app, path) {
  const viewport = page.viewportSize();
  const height = await app.evaluate(() => Math.max(document.body.scrollHeight, document.documentElement.scrollHeight));
  // Expand the outer viewport vertically so it does not clip the scrolling iframe.
  try {
    await page.setViewportSize({ width: viewport.width, height: Math.ceil(height) + 50 });
    await app.locator('body').screenshot({ path });
  } finally {
    await page.setViewportSize(viewport);
  }
}

module.exports = { test, expect, disclosure, number, rows, results, file, download, plot, layoutScreenshot };
