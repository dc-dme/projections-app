const { test, expect, disclosure, number, results, plot, layoutScreenshot } = require('./helpers');

test('mobile continuous inputs, keyboard anchors and plot/table stay usable', async ({ app, page }, testInfo) => {
  await page.setViewportSize({ width: 430, height: 850 });
  async function fits() {
    for (const frame of [page.mainFrame(), app]) {
      expect(await frame.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1),
        'No document-level horizontal overflow').toBe(true);
    }
  }
  await fits();
  await expect(app.getByRole('tab')).toHaveCount(0);
  await expect(app.locator('.bslib-sidebar-layout, aside')).toHaveCount(0);
  await expect(app.locator('#results .projection-body')).toBeVisible();
  await plot(app);
  const inputs = await app.locator('#inputs').boundingBox();
  const output = await app.locator('#results').boundingBox();
  expect(inputs.y + inputs.height).toBeLessThanOrEqual(output.y + 1);
  for (const id of ['history_file', 'source', 'grades', 'horizon', 'entry_mode', 'advanced_details']) {
    await expect(app.locator(`#inputs #${id}`)).toBeVisible();
  }
  for (const [href, name] of [['#main-content', null], ['#results', 'View projection']]) {
    const link = app.locator(`${name ? '.service-header ' : ''}a[href="${href}"]`);
    if (name) await expect(link).toHaveText(name);
    expect(await link.evaluate(el => el.tabIndex)).toBeGreaterThanOrEqual(0);
    await link.focus();
    await expect(link).toBeFocused();
    await link.press('Enter');
    await expect.poll(() => app.evaluate(() => location.hash)).toBe(href);
    await expect.poll(() => app.locator(href).evaluate(el => {
      const rect = el.getBoundingClientRect();
      return rect.top < window.innerHeight && rect.bottom > 0;
    })).toBe(true);
  }
  await layoutScreenshot(page, app, testInfo.outputPath('mobile-430-layout.png'));
  const caption = app.locator('.chart-caption');
  await expect(caption).toHaveText('Solid line: observed enrollment. Dashed line: projection. Diamond: base enrollment.');
  await expect(caption).toBeVisible();
  expect(await caption.evaluate(element => element.scrollWidth <= element.clientWidth),
    'HTML chart caption wraps without horizontal clipping').toBe(true);
  await caption.screenshot({ path: testInfo.outputPath('mobile-chart-caption.png') });
  await app.locator('#projection_plot').screenshot({ path: testInfo.outputPath('mobile-chart.png') });
  await page.setViewportSize({ width: 320, height: 750 });
  await expect.poll(() => app.locator('#projection_plot img').evaluate(img => img.width)).toBeLessThanOrEqual(320);
  await plot(app);
  await fits();
  await page.setViewportSize({ width: 430, height: 850 });
  const advanced = app.locator('#advanced_details');
  await expect(advanced).not.toHaveAttribute('open', '');
  await advanced.locator(':scope > summary').focus();
  await advanced.locator(':scope > summary').press('Enter');
  await expect(advanced).toHaveAttribute('open', '');
  await expect(app.locator('#advanced_details #school')).toBeVisible();
  await number(app, 'horizon', 1);
  await app.locator('#school').fill('BROWSER_SYNTHETIC_DISTRICT');
  await expect(app.locator('#entry_context')).toContainText('Projected year: 2024.');
  await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
  await number(app, 'entry_2024', 125);
  await fits();
  await results(app, [[2024, 'K', 125], [2024, '1', 111], [2024, '2', 96]]);
  await plot(app);
  await app.locator('#projection_plot').screenshot({ path: testInfo.outputPath('mobile-chart.png') });
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
  await disclosure(app, 'history_details');
  await expect(app.locator('#history_preview tbody tr')).toHaveCount(9);
  await fits();
});
