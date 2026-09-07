const { test, expect, tab, number, results, file, download, plot } = require('./helpers');

const history = [[2021, 'K', 100], [2021, '1', 90], [2021, '2', 80],
  [2022, 'K', 110], [2022, '1', 95], [2022, '2', 88],
  [2023, 'K', 120], [2023, '1', 99], [2023, '2', 91]];
const ratio1 = (95 / 100 + 99 / 110) / 2;
const ratio2 = (88 / 90 + 91 / 95) / 2;

test('example numbers, singular/range years, constant/manual entry and total/grade plots', async ({ app, page }, testInfo) => {
  await app.locator('#school').fill('BROWSER_SYNTHETIC_DISTRICT');
  await number(app, 'horizon', 1);
  await tab(app, '2. Define entry');
  await expect(app.locator('#entry_context')).toHaveText('Entry grade: K. Projected year: 2024. Base year: 2023.');
  await results(app, [[2024, 'K', 120], [2024, '1', 111], [2024, '2', 96]]);
  await expect(app.locator('#summary')).toContainText('310');
  await expect(app.locator('#summary')).toContainText('327');
  const totalPlot = await plot(app);
  await app.locator('#projection_plot').screenshot({ path: testInfo.outputPath('desktop-total-plot.png') });
  // selectize hides the native select; interact with its visible combobox.
  await app.locator('#view_grade + .selectize-control .selectize-input').click();
  await app.locator('.selectize-dropdown [data-value="1"]').click();
  await expect.poll(() => app.locator('#projection_plot img').getAttribute('src')).not.toBe(totalPlot);
  await plot(app);
  await app.locator('#projection_plot').screenshot({ path: testInfo.outputPath('desktop-grade-chart.png') });
  await page.screenshot({ path: testInfo.outputPath('desktop-grade-plot.png'), fullPage: true });
  await number(app, 'horizon', 2);
  await tab(app, '2. Define entry');
  await expect(app.locator('#entry_context')).toHaveText('Entry grade: K. Projected years: 2024 to 2025. Base year: 2023.');
  await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
  await number(app, 'entry_2024', 125);
  await number(app, 'entry_2025', 130);
  await results(app, [[2024, 'K', 125], [2024, '1', 111], [2024, '2', 96],
    [2025, 'K', 130], [2025, '1', 116], [2025, '2', 107]]);
});

for (const [id, filename, step, expected] of [
  ['history_template', 'history-template.csv', '1. Review enrollment',
    [['year', 'grade', 'enrollment'], ...history]],
  ['base_template', 'base-template.csv', '1. Review enrollment',
    [['year', 'grade', 'enrollment'], ...history.slice(-3)]],
  ['entry_template', 'entry-template.csv', '2. Define entry',
    [['year', 'enrollment'], [2024, 120], [2025, 120]]],
  ['projection_download', 'enrollment-projection.csv', '3. Review projections',
    [['year', 'grade', 'enrollment'], [2024, 'K', 125], [2024, '1', 120 * ratio1],
      [2024, '2', 99 * ratio2], [2025, 'K', 130], [2025, '1', 125 * ratio1], [2025, '2', 120 * ratio1 * ratio2]]],
  ['ratios_download', 'progression-ratios.csv', '3. Review projections',
    [['grade_from', 'grade_to', 'ratio'], ['K', '1', ratio1], ['1', '2', ratio2]]],
]) {
  test(`download ${filename} has correct name and contents`, async ({ app, page }) => {
    await number(app, 'horizon', 2);
    if (id === 'projection_download') {
      await tab(app, '2. Define entry');
      await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
      await number(app, 'entry_2024', 125);
      await number(app, 'entry_2025', 130);
      await results(app, [[2024, 'K', 125], [2024, '1', 111], [2024, '2', 96],
        [2025, 'K', 130], [2025, '1', 116], [2025, '2', 107]]);
    }
    await tab(app, step);
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
    await app.getByLabel('Upload enrollment data', { exact: true }).check();
    await app.locator('#history_file').setInputFiles(await file('history', ['YEAR', 'Grade', 'Enrollment'], [
      [2022, 'K', 100], [2022, '1', 80], [2022, '2', 60],
      [2023, 'K', 120], [2023, '1', 110], [2023, '2', 100],
    ], excel));
    await expect(app.locator('#history_status')).toContainText('6 records');
    await app.getByLabel('Upload a separate file', { exact: true }).check();
    await app.locator('#base_file').setInputFiles(await file('base', ['grade', 'enrollment'],
      [['2', 160], ['K', 200], ['1', 180]], excel));
    await results(app, [[2024, 'K', 200], [2024, '1', 220], [2024, '2', 225],
      [2025, 'K', 200], [2025, '1', 220], [2025, '2', 275]]);
    await tab(app, '2. Define entry');
    await app.locator('input[name="entry_mode"][value="upload"]').check();
    await app.locator('#entry_file').setInputFiles(await file('entry', ['year', 'enrollment'],
      [[2025, 140], [2024, 130]], excel));
    await results(app, [[2024, 'K', 130], [2024, '1', 220], [2024, '2', 225],
      [2025, 'K', 140], [2025, '1', 143], [2025, '2', 275]]);
    await expect(app.locator('#result_status')).toContainText('uploaded enrollment records');
  });
}

test('invalid edits and uploads clear stale results and recover', async ({ app }) => {
  await number(app, 'horizon', 1);
  const valid = [[2024, 'K', 120], [2024, '1', 111], [2024, '2', 96]];
  async function cleared(message) {
    await tab(app, '3. Review projections');
    await expect(app.locator('#result_status [role="alert"]')).toContainText(message);
    await expect(app.locator('#projection_table tbody tr')).toHaveCount(0);
    await expect(app.locator('#ratios_table tbody tr')).toHaveCount(0);
    await expect(app.locator('#summary .bslib-value-box')).toHaveCount(0);
    await expect(app.locator('#projection_plot img')).toHaveCount(0);
  }
  await results(app, valid);
  await number(app, 'horizon', 0);
  await cleared('projection period');
  await number(app, 'horizon', 1);
  await results(app, valid);
  await tab(app, '1. Review enrollment');
  await app.locator('#grades').fill('K, 1');
  await app.locator('#grades').press('Tab');
  await cleared('Grade order');
  await tab(app, '1. Review enrollment');
  await app.locator('#grades').fill('K, 1, 2');
  await app.locator('#grades').press('Tab');
  await results(app, valid);
  await tab(app, '2. Define entry');
  await app.getByLabel('Enter enrollment for each projected year', { exact: true }).check();
  await number(app, 'entry_2024', -1);
  await cleared('Entry needs');
  await tab(app, '2. Define entry');
  await number(app, 'entry_2024', 120);
  await results(app, valid);
  await tab(app, '2. Define entry');
  await app.locator('input[name="entry_mode"][value="upload"]').check();
  await app.locator('#entry_file').setInputFiles(await file('wrong-years', ['year', 'enrollment'], [[2025, 120]]));
  await cleared('exactly one row');
  await tab(app, '2. Define entry');
  await app.locator('input[name="entry_mode"][value="constant"]').check();
  await results(app, valid);
  await app.getByLabel('Upload enrollment data', { exact: true }).check();
  await cleared('Choose a file');
  await tab(app, '1. Review enrollment');
  await app.locator('#history_file').setInputFiles(await file('blank-count', ['year', 'grade', 'enrollment'], [[2023, 'K', '']]));
  await cleared('no blanks');
  await app.getByLabel('Use example data', { exact: true }).check();
  await results(app, valid);
  await tab(app, '1. Review enrollment');
  await app.getByLabel('Upload a separate file', { exact: true }).check();
  await app.locator('#base_file').setInputFiles(await file('wrong-base-year', ['year', 'grade', 'enrollment'],
    [[2024, 'K', 120], [2024, '1', 99], [2024, '2', 91]]));
  await cleared('Base year does not match');
  await tab(app, '1. Review enrollment');
  await app.getByLabel('Most recent historical year', { exact: true }).check();
  await results(app, valid);
});
