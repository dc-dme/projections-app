const { test, expect } = require('@playwright/test');
const fs = require('node:fs/promises');
const { disclosure, results, file, download, plot, layoutScreenshot } = require('./helpers');

test('WebKit renders projections, updates inputs, downloads, and resizes', async ({ page }, testInfo) => {
  const errors = [];
  const messages = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => messages.push(`${message.type()}: ${message.text()}`));
  // Service-worker activation reloads the outer document on a first visit.
  // Retain diagnostics, but judge uncaught errors in the active document.
  page.on('framenavigated', frame => {
    if (frame === page.mainFrame()) errors.length = 0;
  });
  try {
    await page.goto('./');
    let app;
    await expect.poll(async () => {
      expect(errors, 'Fatal browser startup errors').toEqual([]);
      for (const frame of page.frames()) {
        if (frame === page.mainFrame() || frame.isDetached()) continue;
        const ready = await frame.locator('#history_status')
          .getByText('9 records', { exact: false }).count().catch(error => {
            if (frame.isDetached()) return 0;
            throw error;
          });
        if (ready) {
          app = frame;
          return true;
        }
      }
      return false;
    }, { timeout: 120_000 }).toBe(true);
    await page.setViewportSize({ width: 1280, height: 900 });
    await expect(app.locator('#history_status')).toBeVisible();
    await expect(app.getByRole('tab')).toHaveCount(0);
    await expect(app.locator('.bslib-sidebar-layout, aside')).toHaveCount(0);
    await expect(app.locator('#results .projection-body')).toBeVisible();
    await plot(app);
    await layoutScreenshot(page, app, testInfo.outputPath('webkit-1280-layout.png'));
    await disclosure(app, 'history_details');
    await expect(app.locator('#history_preview tbody tr')).toHaveCount(9);
    await app.locator('#horizon').fill('1');
    await app.locator('#horizon').press('Tab');
    await results(app, [[2024, 'K', 120], [2024, '1', 111], [2024, '2', 96]]);
    await expect(app.locator('#summary')).toContainText('327');
    const initialPlot = await plot(app);
    await expect(app.locator('#projection_table tbody tr').first()).toContainText('120');
    const csv = await download(page, app, 'projection_download', 'enrollment-projection.csv');
    expect(csv[1]).toEqual(['2024', 'K', '120']);

    await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
    await app.locator('#entry_2024').fill('150');
    await app.locator('#entry_2024').press('Tab');
    await results(app, [[2024, 'K', 150], [2024, '1', 111], [2024, '2', 96]]);
    await expect.poll(() => app.locator('#projection_plot img').getAttribute('src')).not.toBe(initialPlot);
    await plot(app);

    await app.locator('input[name="entry_mode"][value="upload"]').check();
    await app.locator('#entry_file').setInputFiles(await file('entry', ['year', 'enrollment'], [[2024, 140]], true));
    await results(app, [[2024, 'K', 140], [2024, '1', 111], [2024, '2', 96]]);
    await plot(app);
    await app.locator('#horizon').fill('0');
    await app.locator('#horizon').press('Tab');
    await expect(app.locator('#result_status [role="alert"], #result_status[role="alert"]')).toContainText('projection period');
    await expect(app.locator('#results .projection-body')).toBeHidden();
    await expect(app.locator('#projection_table')).toBeHidden();
    await expect(app.locator('#projection_plot')).toBeHidden();
    await app.locator('#horizon').fill('1');
    await app.locator('#horizon').press('Tab');
    await results(app, [[2024, 'K', 140], [2024, '1', 111], [2024, '2', 96]]);
    await page.setViewportSize({ width: 430, height: 850 });
    await expect.poll(() => app.locator('#projection_plot img').evaluate(img => img.width)).toBeLessThan(430);
    await plot(app);
    await page.screenshot({ path: testInfo.outputPath('webkit-results.png'), fullPage: true });
    await layoutScreenshot(page, app, testInfo.outputPath('webkit-430-layout.png'));
    await expect(app.getByLabel('Use example data', { exact: true })).toBeChecked();
    await app.locator('#history_file').setInputFiles(await file('history', ['year', 'grade', 'enrollment'], [
      [2022, 'K', 100], [2022, '1', 80], [2022, '2', 60],
      [2023, 'K', 120], [2023, '1', 110], [2023, '2', 100],
    ]));
    await expect(app.getByLabel('Upload enrollment data', { exact: true })).toBeChecked();
    await results(app, [[2024, 'K', 140], [2024, '1', 132], [2024, '2', 138]]);
    await expect(app.locator('#result_status')).toContainText('Uploaded data');
    await plot(app);
    expect(errors).toEqual([]);
  } finally {
    const diagnostics = testInfo.outputPath('webkit-startup.json');
    await fs.writeFile(diagnostics, JSON.stringify({ errors, messages }, null, 2));
    await testInfo.attach('webkit-startup', {
      path: diagnostics, contentType: 'application/json',
    });
  }
});
