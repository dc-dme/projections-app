const { test, expect } = require('@playwright/test');
const { file, download, plot } = require('./helpers');

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
    await expect(app.locator('#history_preview tbody tr')).toHaveCount(9);
    await app.locator('#horizon').fill('1');
    await app.locator('#horizon').press('Tab');
    await app.getByRole('tab', { name: /3. Review projections/ }).click();
    await expect(app.locator('#projection_table tbody tr')).toHaveCount(3);
    await expect(app.locator('#summary')).toContainText('327');
    const initialPlot = await plot(app);
    await expect(app.locator('#projection_table tbody tr').first()).toContainText('120');
    const csv = await download(page, app, 'projection_download', 'enrollment-projection.csv');
    expect(csv[1]).toEqual(['2024', 'K', '120']);

    await app.getByRole('tab', { name: /2. Define entry/ }).click();
    await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
    await app.locator('#entry_2024').fill('150');
    await app.locator('#entry_2024').press('Tab');
    await app.getByRole('tab', { name: /3. Review projections/ }).click();
    await expect(app.locator('#projection_table tbody tr').first()).toContainText('150');
    await expect.poll(() => app.locator('#projection_plot img').getAttribute('src')).not.toBe(initialPlot);
    await plot(app);

    await app.getByRole('tab', { name: /2. Define entry/ }).click();
    await app.locator('input[name="entry_mode"][value="upload"]').check();
    await app.locator('#entry_file').setInputFiles(await file('entry', ['year', 'enrollment'], [[2024, 140]], true));
    await app.getByRole('tab', { name: /3. Review projections/ }).click();
    await expect(app.locator('#projection_table tbody tr').first()).toContainText('140');
    await plot(app);
    await page.setViewportSize({ width: 430, height: 850 });
    await expect.poll(() => app.locator('#projection_plot img').evaluate(img => img.width)).toBeLessThan(430);
    await plot(app);
    await page.screenshot({ path: testInfo.outputPath('webkit-results.png'), fullPage: true });
    expect(errors).toEqual([]);
  } finally {
    await testInfo.attach('webkit-startup', {
      body: JSON.stringify({ errors, messages }, null, 2), contentType: 'application/json',
    });
  }
});
