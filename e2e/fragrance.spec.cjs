const { test, expect } = require('@playwright/test');
const path = require('node:path');
const { enterText } = require('./support/text.cjs');

async function enableSemantics(page) {
  await page.locator('flutter-view').waitFor({ state: 'attached' });
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) await placeholder.evaluate(element => element.click());
}

async function openScents(page) {
  await page.getByRole('button', { name: 'Wardrobe', exact: true }).click();
  await page.mouse.move(240, 80);
  await page.mouse.wheel(600, 0);
  await page.getByRole('button', { name: 'Scents', exact: true }).click();
}

async function chooseBands(page, temperature, humidity) {
  await page.mouse.move(180, 450);
  await page.mouse.wheel(0, 1400);
  await page.getByRole('button', { name: temperature, exact: true }).click();
  await page.getByRole('button', { name: humidity, exact: true }).click();
}

async function scrollToFragrance(page) {
  await page.mouse.move(180, 450);
  await page.mouse.wheel(0, 1000);
  await expect(page.getByRole('button', { name: 'Change', exact: true })).toBeVisible();
}

function fragranceCard(page, name) {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return page.getByRole('group', { name: new RegExp(`^Fragrance of the day[\\s\\S]*${escaped}`) });
}

test('fragrance collection, weather ranking, chosen scent persistence and deletion fallback', async ({ page }) => {
  test.setTimeout(180000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('https://geocoding-api.open-meteo.com/v1/search?**', route => route.fulfill({
    json: { results: [{ id: 1701668, name: 'Manila', latitude: 14.6042, longitude: 120.9822, country: 'Philippines' }] },
    headers: { 'access-control-allow-origin': '*' },
  }));
  await page.route('https://api.open-meteo.com/v1/forecast?**', route => route.fulfill({
    json: {
      utc_offset_seconds: 0,
      current_units: { time: 'unixtime', temperature_2m: '°C', relative_humidity_2m: '%' },
      current: { time: Math.floor(Date.now() / 1000), temperature_2m: 31, relative_humidity_2m: 85 },
    },
    headers: { 'access-control-allow-origin': '*' },
  }));

  const email = `fitcheck-fragrance-${Date.now()}@example.test`;
  const warm = 'Citrus garden with jasmine and a long fresh morning finish';
  const cool = 'Cedar evening with a long quiet woody finish';
  await page.goto('/');
  await enableSemantics(page);
  await page.getByRole('button', { name: 'Create an account', exact: true }).click();
  await enterText(page, page.getByRole('textbox', { name: 'Email', exact: true }), email);
  await enterText(page, page.getByRole('textbox', { name: /Password/ }), 'FitCheck-fragrance-2026!');
  await page.getByRole('button', { name: 'Create account', exact: true }).click();
  await page.getByRole('button', { name: 'Add a fragrance (optional)', exact: true }).click();
  await page.getByRole('button', { name: 'Save fragrance', exact: true }).click();
  await expect(page.locator('flutter-view').getByText('Enter a fragrance name.', { exact: true })).toBeVisible();
  await enterText(page, page.getByRole('textbox', { name: /Fragrance name/ }), warm);
  await enterText(page, page.getByRole('textbox', { name: /Scent notes/ }), 'Bergamot, jasmine, and light cedar.');
  await page.mouse.move(180, 350);
  await page.mouse.wheel(0, -1400);
  const fileChooser = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Add photo', exact: true }).click();
  await (await fileChooser).setFiles(path.resolve('web/icons/Icon-192.png'));
  await expect(page.getByRole('button', { name: 'Change photo', exact: true })).toBeVisible();
  await chooseBands(page, 'Warm · above 27°C', 'Humid · above 70%');
  await page.mouse.move(359, 0);
  await page.screenshot({ path: 'artifacts/fragrance-form-light.png' });
  await page.getByRole('button', { name: 'Save fragrance', exact: true }).click();

  await openScents(page);
  await expect(page.getByRole('button', { name: `${warm}, Warm, Humid`, exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Add fragrance', exact: true }).click();
  await enterText(page, page.getByRole('textbox', { name: /Fragrance name/ }), 'Cedar evening');
  await enterText(page, page.getByRole('textbox', { name: /Scent notes/ }), 'Dry cedar and sandalwood.');
  await chooseBands(page, 'Cool · below 20°C', 'Dry · below 40%');
  await page.getByRole('button', { name: 'Save fragrance', exact: true }).click();
  const search = page.getByRole('textbox', { name: 'Search your wardrobe', exact: true });
  await enterText(page, search, 'evening');
  await expect(page.getByRole('button', { name: `${warm}, Warm, Humid`, exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Cedar evening, Cool, Dry', exact: true }).click();
  await page.getByRole('button', { name: 'Edit fragrance', exact: true }).click();
  const editNotes = page.getByRole('textbox', { name: /Scent notes/ });
  await editNotes.click();
  await expect(editNotes).toHaveValue('Dry cedar and sandalwood.');
  await page.keyboard.press('Tab');
  await enterText(page, page.getByRole('textbox', { name: /Fragrance name/ }), cool);
  await page.getByRole('button', { name: 'Save fragrance', exact: true }).click();
  await expect(page.locator('flutter-view').getByText(cool, { exact: false })).toBeVisible();
  await page.getByRole('button', { name: 'Close fragrance', exact: true }).click();
  await enterText(page, search, '');
  await page.mouse.move(359, 0);
  await page.screenshot({ path: 'artifacts/fragrance-collection-light.png' });

  await page.reload();
  await enableSemantics(page);
  await openScents(page);
  await expect(page.getByRole('button', { name: `${cool}, Cool, Dry`, exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: `${warm}, Warm, Humid`, exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Today', exact: true }).click();
  await page.getByRole('button', { name: 'City', exact: true }).click();
  await enterText(page, page.getByRole('textbox', { name: /City name/ }), 'Manila');
  await page.getByRole('button', { name: 'Search cities', exact: true }).click();
  await page.getByRole('button', { name: /^Manila/ }).click();
  await expect(page.getByRole('button', { name: '31° Manila', exact: true })).toBeVisible();
  await scrollToFragrance(page);
  await expect(fragranceCard(page, warm)).toBeVisible();
  await page.getByRole('button', { name: 'Change', exact: true }).click();
  const options = page.getByRole('button', { name: /^(Citrus garden|Cedar evening).*31°C and 85% humidity:/ });
  await expect(options).toHaveCount(2);
  await expect(options.nth(0)).toHaveAccessibleName(new RegExp(`^${warm}\\.`));
  await expect(options.nth(1)).toHaveAccessibleName(new RegExp(`^${cool}\\.`));
  await page.mouse.move(359, 0);
  await page.screenshot({ path: 'artifacts/fragrance-change-light.png' });
  await options.nth(1).click();
  await page.getByRole('button', { name: 'Use this fragrance', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Close change fragrance', exact: true })).toHaveCount(0);
  await expect(fragranceCard(page, cool)).toBeVisible();

  await page.reload();
  await enableSemantics(page);
  await scrollToFragrance(page);
  await expect(fragranceCard(page, cool)).toBeVisible();
  await page.getByRole('button', { name: 'Account and appearance', exact: true }).click();
  await page.getByRole('radio', { name: 'Dark', exact: true }).click();
  await page.getByRole('button', { name: 'Close account', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Close account', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Change', exact: true }).click();
  await expect(options.nth(0)).toHaveAccessibleName(new RegExp(`^${warm}\\.`));
  await page.mouse.move(359, 0);
  await page.screenshot({ path: 'artifacts/fragrance-change-dark.png' });
  await page.getByRole('button', { name: 'Close change fragrance', exact: true }).click();
  await openScents(page);
  await page.getByRole('button', { name: `${cool}, Cool, Dry`, exact: true }).click();
  await expect(page.locator('flutter-view').getByText(cool, { exact: false })).toBeVisible();
  await expect(page.locator('flutter-view').getByText('Dry cedar and sandalwood.', { exact: false })).toBeVisible();
  await page.mouse.move(359, 0);
  await page.screenshot({ path: 'artifacts/fragrance-detail-dark.png' });
  await page.getByRole('button', { name: 'Delete fragrance', exact: true }).click();
  await expect(page.locator('flutter-view').getByText('Delete this fragrance from your collection?', { exact: false })).toBeVisible();
  await page.getByRole('button', { name: 'Confirm delete fragrance', exact: true }).click();
  await expect(page.getByRole('button', { name: `${cool}, Cool, Dry`, exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Today', exact: true }).click();
  await scrollToFragrance(page);
  await expect(fragranceCard(page, warm)).toBeVisible();
  expect(errors).toEqual([]);
});
