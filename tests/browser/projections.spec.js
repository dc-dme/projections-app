const { test, expect, disclosure, number, results, file, download, plot, layoutScreenshot } = require('./helpers');

const history = [[2021, 'K', 100], [2021, '1', 90], [2021, '2', 80],
  [2022, 'K', 110], [2022, '1', 95], [2022, '2', 88],
  [2023, 'K', 120], [2023, '1', 99], [2023, '2', 91]];
const ratio1 = (95 / 100 + 99 / 110) / 2;
const ratio2 = (88 / 90 + 91 / 95) / 2;

test('example numbers, singular/range years, constant/manual entry and total/grade plots', async ({ app, page }, testInfo) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await expect(app.getByRole('tab')).toHaveCount(0);
  await expect(app.getByRole('tablist')).toHaveCount(0);
  await expect(app.locator('.bslib-sidebar-layout, aside')).toHaveCount(0);
  await expect(app.locator('h1')).toHaveCount(1);
  await expect(app.getByRole('heading', { level: 1, name: 'Project enrollment', exact: true })).toBeVisible();
  await expect(app.locator('#results .projection-body')).toBeVisible();
  await expect(app.locator('#result_status')).toContainText('Example data');
  await expect(app.locator('#result_status [role="status"], #result_status[role="status"]')).toBeVisible();
  await expect(app.locator('#projection_download')).toBeVisible();
  expect(await app.locator('#projection_download').evaluate(el => el.closest('details') === null)).toBe(true);
  await plot(app);
  for (const id of ['grades', 'horizon', 'history_file', 'history_template', 'source']) {
    await expect(app.locator(`#inputs #${id}`)).toBeVisible();
  }
  await expect(app.getByLabel('Use example data', { exact: true })).toBeVisible();
  await expect(app.getByLabel('Upload enrollment data', { exact: true })).toBeVisible();
  const exampleRadio = await app.getByLabel('Use example data', { exact: true }).boundingBox();
  const uploadRadio = await app.getByLabel('Upload enrollment data', { exact: true }).boundingBox();
  expect(Math.abs(exampleRadio.y - uploadRadio.y), 'Source choices stay inline').toBeLessThan(2);
  for (const label of ['Hold constant at base-year entry enrollment',
    'Enter enrollment for each projected year', 'Upload entry enrollment']) {
    await expect(app.locator('#entry_mode').getByLabel(label, { exact: true })).toBeVisible();
  }
  for (const [id, label] of [
    ['advanced_details', 'Base enrollment and calculation settings'],
    ['history_details', 'File format and data preview'],
    ['projection_details', 'View projected enrollment table'],
    ['ratios_details', 'Review progression ratios'],
  ]) {
    await expect(app.locator(`details#${id} > summary`)).toHaveText(label);
    await expect(app.locator(`details#${id}`)).not.toHaveAttribute('open', '');
  }
  expect(await app.locator('#history_template').evaluate(el => el.closest('details') === null)).toBe(true);
  expect(await app.locator('#history_status').evaluate(el => el.closest('details') === null)).toBe(true);
  expect(await app.locator('#inputs').evaluate(el =>
    Boolean(el.compareDocumentPosition(document.getElementById('results')) & Node.DOCUMENT_POSITION_FOLLOWING))).toBe(true);
  const inputs = await app.locator('#inputs').boundingBox();
  const output = await app.locator('#results').boundingBox();
  expect(inputs.x + inputs.width).toBeLessThanOrEqual(output.x + 1);
  expect(Math.abs(inputs.y - output.y)).toBeLessThan(100);
  await expect(app.locator('#summary dl.projection-summary, dl#summary.projection-summary')).toBeVisible();
  await expect(app.locator('#summary .bslib-value-box')).toHaveCount(0);
  await expect(app.locator('select#view_grade')).toBeVisible();
  await expect(app.locator('#entry_template')).toBeHidden();
  await layoutScreenshot(page, app, testInfo.outputPath('desktop-1280-layout.png'));
  await disclosure(app, 'history_details');
  await expect(app.locator('#history_details #history_preview tbody tr')).toHaveCount(9);
  await disclosure(app, 'advanced_details');
  for (const id of ['school', 'method', 'base_mode', 'base_template']) {
    await expect(app.locator(`#advanced_details #${id}`)).toBeVisible();
  }
  await expect(app.locator('select#method')).toBeVisible();
  await app.locator('#school').fill('BROWSER_SYNTHETIC_DISTRICT');
  await number(app, 'horizon', 1);
  await expect(app.locator('#entry_context')).toHaveText('Entry grade: K. Projected year: 2024. Base year: 2023.');
  await results(app, [[2024, 'K', 120], [2024, '1', 111], [2024, '2', 96]]);
  await expect(app.locator('#summary')).toContainText('310');
  await expect(app.locator('#summary')).toContainText('327');
  const totalPlot = await plot(app);
  await app.locator('#projection_plot').screenshot({ path: testInfo.outputPath('desktop-total-plot.png') });
  await app.locator('select#view_grade').selectOption('1');
  await expect.poll(() => app.locator('#projection_plot img').getAttribute('src')).not.toBe(totalPlot);
  await plot(app);
  await app.locator('#projection_plot').screenshot({ path: testInfo.outputPath('desktop-grade-chart.png') });
  await page.screenshot({ path: testInfo.outputPath('desktop-grade-plot.png'), fullPage: true });
  await number(app, 'horizon', 2);
  await expect(app.locator('#entry_context')).toHaveText('Entry grade: K. Projected years: 2024 to 2025. Base year: 2023.');
  await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
  await expect(app.locator('#entry_template')).toBeHidden();
  await number(app, 'entry_2024', 125);
  await number(app, 'entry_2025', 130);
  await results(app, [[2024, 'K', 125], [2024, '1', 111], [2024, '2', 96],
    [2025, 'K', 130], [2025, '1', 116], [2025, '2', 107]]);
});

for (const [id, filename, detail, expected] of [
  ['history_template', 'history-template.csv', null,
    [['year', 'grade', 'enrollment'], ...history]],
  ['base_template', 'base-template.csv', 'advanced_details',
    [['year', 'grade', 'enrollment'], ...history.slice(-3)]],
  ['entry_template', 'entry-template.csv', null,
    [['year', 'enrollment'], [2024, 120], [2025, 120]]],
  ['projection_download', 'enrollment-projection.csv', null,
    [['year', 'grade', 'enrollment'], [2024, 'K', 125], [2024, '1', 120 * ratio1],
      [2024, '2', 99 * ratio2], [2025, 'K', 130], [2025, '1', 125 * ratio1], [2025, '2', 120 * ratio1 * ratio2]]],
  ['ratios_download', 'progression-ratios.csv', 'ratios_details',
    [['grade_from', 'grade_to', 'ratio'], ['K', '1', ratio1], ['1', '2', ratio2]]],
]) {
  test(`download ${filename} has correct name and contents`, async ({ app, page }) => {
    await number(app, 'horizon', 2);
    if (id === 'projection_download') {
      await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
      await number(app, 'entry_2024', 125);
      await number(app, 'entry_2025', 130);
      await results(app, [[2024, 'K', 125], [2024, '1', 111], [2024, '2', 96],
        [2025, 'K', 130], [2025, '1', 116], [2025, '2', 107]]);
    }
    if (detail) await disclosure(app, detail);
    if (id === 'ratios_download') await expect(app.locator('#ratios_details #ratios_table')).toBeVisible();
    if (id === 'entry_template') await app.locator('input[name="entry_mode"][value="upload"]').check();
    const actual = await download(page, app, id, filename);
    expect(actual).toHaveLength(expected.length);
    expected.forEach((row, i) => {
      expect(actual[i]).toHaveLength(row.length);
      row.forEach((value, j) => {
        if (typeof value === 'number') expect(Number(actual[i][j])).toBeCloseTo(value, 9);
        else expect(actual[i][j]).toBe(value);
      });
    });
  });
}

test('download failure gives an accessible alert and the next click recovers', async ({ app, page }) => {
  const downloads = [];
  page.on('download', item => downloads.push(item));
  await app.evaluate(() => {
    const originalFetch = window.fetch;
    const target = document.getElementById('history_template').href;
    window.fetch = function(input, ...args) {
      const url = input instanceof Request ? input.url : String(input);
      if (url === target) {
        window.fetch = originalFetch;
        return Promise.reject(new TypeError('Synthetic download network failure'));
      }
      return originalFetch.call(this, input, ...args);
    };
  });
  await app.locator('#history_template').click();
  const alert = app.getByRole('alert');
  await expect(alert).toHaveText('Download could not be completed. Check the current inputs and try again.');
  await expect(alert).toBeVisible();
  expect(downloads, 'Failed fetch must not produce a download').toHaveLength(0);
  expect(await download(page, app, 'history_template', 'history-template.csv'))
    .toEqual([['year', 'grade', 'enrollment'], ...history.map(row => row.map(String))]);
  await expect(alert).toHaveCount(0);
  expect(downloads, 'Retry produces exactly one real download').toHaveLength(1);
});

for (const excel of [false, true]) {
  test(`${excel ? 'Excel' : 'CSV'} history, separate base and out-of-order entry uploads`, async ({ app }) => {
    await number(app, 'horizon', 2);
    await expect(app.getByLabel('Use example data', { exact: true })).toBeChecked();
    await app.locator('#history_file').setInputFiles(await file('history', ['YEAR', 'Grade', 'Enrollment'], [
      [2022, 'K', 100], [2022, '1', 80], [2022, '2', 60],
      [2023, 'K', 120], [2023, '1', 110], [2023, '2', 100],
    ], excel));
    await expect(app.locator('#history_status')).toContainText('6 records');
    await expect(app.getByLabel('Upload enrollment data', { exact: true })).toBeChecked();
    await results(app, [[2024, 'K', 120], [2024, '1', 132], [2024, '2', 138],
      [2025, 'K', 120], [2025, '1', 132], [2025, '2', 165]]);
    await expect(app.locator('#result_status')).toContainText('Uploaded data');
    await disclosure(app, 'advanced_details');
    await app.getByLabel('Upload a separate file', { exact: true }).check();
    await expect(app.locator('#advanced_details #base_file')).toBeAttached();
    await expect(app.locator('#advanced_details #base_year')).toBeVisible();
    await app.locator('#base_file').setInputFiles(await file('base', ['grade', 'enrollment'],
      [['2', 160], ['K', 200], ['1', 180]], excel));
    await results(app, [[2024, 'K', 200], [2024, '1', 220], [2024, '2', 225],
      [2025, 'K', 200], [2025, '1', 220], [2025, '2', 275]]);
    await app.locator('input[name="entry_mode"][value="upload"]').check();
    await app.locator('#entry_file').setInputFiles(await file('entry', ['year', 'enrollment'],
      [[2025, 140], [2024, 130]], excel));
    await results(app, [[2024, 'K', 130], [2024, '1', 220], [2024, '2', 225],
      [2025, 'K', 140], [2025, '1', 143], [2025, '2', 275]]);
    await expect(app.locator('#result_status')).toContainText('Uploaded data');
  });
}

test('history upload suggests an editable grade order and flags uncertain labels', async ({ app }) => {
  await app.locator('#history_file').setInputFiles(await file('unsorted-grades',
    ['year', 'grade', 'enrollment'], [
      [2022, '10', 60], [2022, 'K', 100], [2022, '2', 80],
      [2023, '10', 65], [2023, 'K', 110], [2023, '2', 90],
    ]));
  await expect(app.locator('#history_status')).toContainText('6 records');
  await expect(app.locator('#grades')).toHaveValue('K, 2, 10');
  await expect(app.locator('#grade_order_hint')).toContainText('Suggested from your data');

  await app.locator('#grades').fill('K, 10, 2');
  await app.locator('#grades').press('Tab');
  await expect(app.locator('#grade_order_hint')).toContainText('Custom grade order');
  await expect(app.locator('#grades')).toHaveValue('K, 10, 2');

  await app.locator('#history_file').setInputFiles(await file('uncertain-grades',
    ['year', 'grade', 'enrollment'], [
      [2022, '2', 80], [2022, 'Ungraded', 5], [2022, 'K', 100],
      [2023, '2', 90], [2023, 'Ungraded', 6], [2023, 'K', 110],
    ]));
  await expect(app.locator('#history_status')).toContainText('6 records');
  await expect(app.locator('#grades')).toHaveValue('2, Ungraded, K');
  await expect(app.locator('#grade_order_hint')).toContainText('An order could not be inferred');
  await expect(app.locator('#grade_order_hint')).toContainText('Unrecognized labels: Ungraded');
});

test('manual values survive period changes and invalid base years', async ({ app }) => {
  await number(app, 'horizon', 2);
  await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
  await number(app, 'entry_2024', 125);
  await number(app, 'entry_2025', 130);
  await results(app, [[2024, 'K', 125], [2024, '1', 111], [2024, '2', 96],
    [2025, 'K', 130], [2025, '1', 116], [2025, '2', 107]]);
  await number(app, 'horizon', 3);
  await expect(app.locator('#entry_2026')).toBeVisible();
  await expect(app.locator('#entry_2024')).toHaveValue('125');
  await expect(app.locator('#entry_2025')).toHaveValue('130');
  await number(app, 'horizon', 2);
  await expect(app.locator('#entry_2026')).toHaveCount(0);
  await expect(app.locator('#entry_2024')).toHaveValue('125');
  await disclosure(app, 'advanced_details');
  await app.getByLabel('Upload a separate file', { exact: true }).check();
  await app.locator('#base_file').setInputFiles(await file('base', ['grade', 'enrollment'],
    [['K', 120], ['1', 99], ['2', 91]]));
  await number(app, 'base_year', 2023.5);
  await expect(app.locator('#results .projection-body')).toBeHidden();
  await number(app, 'base_year', 2023);
  await expect(app.locator('#entry_fields input')).toHaveCount(2);
  await expect(app.locator('#entry_2024')).toHaveValue('125');
  await expect(app.locator('#entry_2025')).toHaveValue('130');
  await results(app, [[2024, 'K', 125], [2024, '1', 111], [2024, '2', 96],
    [2025, 'K', 130], [2025, '1', 116], [2025, '2', 107]]);
});

test('invalid edits and uploads clear stale results and recover', async ({ app }) => {
  await number(app, 'horizon', 1);
  const valid = [[2024, 'K', 120], [2024, '1', 111], [2024, '2', 96]];
  async function cleared(message) {
    await expect(app.locator('#result_status [role="alert"], #result_status[role="alert"]')).toContainText(message);
    await expect(app.locator('#result_status [role="alert"], #result_status[role="alert"]')).toBeVisible();
    await expect(app.locator('#results [role="alert"]:visible')).toHaveCount(1);
    await expect(app.locator('#results .projection-body')).toBeHidden();
    for (const id of ['projection_table', 'ratios_table', 'summary', 'projection_plot', 'projection_download']) {
      await expect(app.locator(`#${id}`)).toBeHidden();
    }
  }
  await results(app, valid);
  await number(app, 'horizon', 0);
  await cleared('projection period');
  await number(app, 'horizon', 1);
  await results(app, valid);
  await app.locator('#grades').fill('K, 1');
  await app.locator('#grades').press('Tab');
  await cleared('Grade order');
  await app.locator('#grades').fill('K, 1, 2');
  await app.locator('#grades').press('Tab');
  await results(app, valid);
  await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
  await number(app, 'entry_2024', -1);
  await cleared('Entry needs');
  await number(app, 'entry_2024', 120);
  await results(app, valid);
  await app.locator('input[name="entry_mode"][value="upload"]').check();
  await app.locator('#entry_file').setInputFiles(await file('wrong-years', ['year', 'enrollment'], [[2025, 120]]));
  await cleared('exactly one row');
  await app.locator('input[name="entry_mode"][value="constant"]').check();
  await results(app, valid);
  await app.getByLabel('Upload enrollment data', { exact: true }).check();
  await cleared('Choose a file');
  await app.locator('#history_file').setInputFiles(await file('blank-count', ['year', 'grade', 'enrollment'], [[2023, 'K', '']]));
  await cleared('no blanks');
  await app.getByLabel('Use example data', { exact: true }).check();
  await results(app, valid);
  await disclosure(app, 'advanced_details');
  await app.getByLabel('Upload a separate file', { exact: true }).check();
  await app.locator('#base_file').setInputFiles(await file('wrong-base-year', ['year', 'grade', 'enrollment'],
    [[2024, 'K', 120], [2024, '1', 99], [2024, '2', 91]]));
  await cleared('Base year does not match');
  await app.getByLabel('Most recent historical year', { exact: true }).check();
  await results(app, valid);
});
