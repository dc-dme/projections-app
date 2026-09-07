const { test, expect, tab, number, results, plot } = require('./helpers');

test('mobile sidebar, step navigation and plot/table stay usable', async ({ app, page }, testInfo) => {
  async function fits() {
    for (const frame of [page.mainFrame(), app]) {
      expect(await frame.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1),
        'No document-level horizontal overflow').toBe(true);
    }
  }
  await fits();
  // This non-fillable bslib layout stacks an always-open sidebar below main
  // content on mobile; it does not expose a mobile collapse button.
  await expect(app.getByRole('complementary')).toBeVisible();
  await number(app, 'horizon', 1);
  await app.locator('#school').fill('BROWSER_SYNTHETIC_DISTRICT');
  await tab(app, '2. Define entry');
  await expect(app.locator('#entry_context')).toContainText('Projected year: 2024.');
  await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
  await number(app, 'entry_2024', 125);
  await fits();
  await results(app, [[2024, 'K', 125], [2024, '1', 111], [2024, '2', 96]]);
  await plot(app);
  await app.locator('#projection_plot').screenshot({ path: testInfo.outputPath('mobile-chart.png') });
  const caption = app.getByText('Diamond: base enrollment. Dashed line: projected enrollment. Uncertainty intervals are not shown.', { exact: true });
  await expect(caption).toBeVisible();
  expect(await caption.evaluate(element => element.scrollWidth <= element.clientWidth),
    'HTML chart caption wraps without horizontal clipping').toBe(true);
  await caption.screenshot({ path: testInfo.outputPath('mobile-chart-caption.png') });
  await fits();
  const bounds = await app.locator('#projection_plot').boundingBox();
  expect(bounds.width).toBeGreaterThan(100);
  expect(bounds.width).toBeLessThanOrEqual(page.viewportSize().width);
  await expect(app.locator('#projection_download')).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('mobile-results.png'), fullPage: true });
  await tab(app, '1. Review enrollment');
  await expect(app.locator('#history_preview tbody tr')).toHaveCount(9);
  await fits();
});
