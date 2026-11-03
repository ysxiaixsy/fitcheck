const { test, expect } = require('@playwright/test');

async function enableSemantics(page) {
  await page.locator('flutter-view').waitFor({ state: 'attached' });
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) await placeholder.evaluate(element => element.click());
}

async function enterText(page, field, value) {
  await field.click();
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(value, { delay: 5 });
  await expect(field).toHaveValue(value);
  await page.keyboard.press('Tab');
}

async function addItem(page, item) {
  await page.getByRole('button', { name: 'Add item', exact: true }).click();
  await enterText(page, page.getByRole('textbox', { name: /Name/ }), item.name);
  await enterText(page, page.getByRole('textbox', { name: /Color/ }), item.color);
  await page.getByRole('button', { name: item.category, exact: true }).click();
  if (item.washAfter === 1) {
    await page.mouse.move(180, 400);
    await page.mouse.wheel(0, 700);
    await page.getByRole('button', { name: '1 wear', exact: true }).click();
  }
  await page.getByRole('button', { name: 'Save item', exact: true }).click();
  await expect(page.getByRole('button', {
    name: `${item.name}, ${item.color}, Clean`, exact: true,
  })).toBeVisible();
}

function swapLabel(item) {
  return `Swap ${item.category.toLowerCase()}: ${item.name}, ${item.color}, Clean`;
}

async function authenticatedWardrobe(request, email, password) {
  const auth = await request.post(
    'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-only',
    { data: { email, password, returnSecureToken: true } },
  );
  expect(auth.ok()).toBeTruthy();
  const { localId, idToken } = await auth.json();
  // Read as the same user through the public API; ownership rules still apply.
  const url = `http://127.0.0.1:8080/v1/projects/demo-fitcheck/databases/(default)/documents/users/${localId}/clothes`;
  return async () => {
    const response = await request.get(url, { headers: { Authorization: `Bearer ${idToken}` } });
    expect(response.ok()).toBeTruthy();
    const { documents = [] } = await response.json();
    return Object.fromEntries(documents.map(({ fields }) => [
      fields.name.stringValue, Number(fields.wearsSinceWash.integerValue),
    ]));
  };
}

test('Today swaps, full outfit details and one persisted daily wear', async ({ page, request }) => {
  test.setTimeout(180000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const email = `fitcheck-today-${Date.now()}@example.test`;
  const password = 'FitCheck-today-2026!';
  const tops = [
    { name: 'Navy cotton polo with a long embroidered school crest', color: 'Navy blue', category: 'Top' },
    { name: 'White linen shirt with a long tailored button down collar', color: 'Ivory white', category: 'Top' },
  ];
  const bottom = { name: 'Beige chinos', color: 'Warm beige', category: 'Bottom' };
  const shoes = { name: 'Brown leather loafers', color: 'Chestnut brown', category: 'Shoes', washAfter: 1 };

  await page.goto('/');
  await enableSemantics(page);
  await page.getByRole('button', { name: 'Create an account', exact: true }).click();
  await enterText(page, page.getByRole('textbox', { name: 'Email', exact: true }), email);
  await enterText(page, page.getByRole('textbox', { name: /Password/ }), password);
  await page.getByRole('button', { name: 'Create account', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Add clothes', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Wardrobe', exact: true }).click();
  for (const item of [...tops, bottom, shoes]) await addItem(page, item);

  await page.getByRole('button', { name: 'Today', exact: true }).click();
  const reason = page.getByRole('group', { name: /^Outfit of the day For School with matching casual pieces\./ });
  await expect(reason).toBeVisible();
  const topButton = page.getByRole('button', { name: /^Swap top: / });
  await expect(topButton).toBeVisible();
  const current = await page.getByRole('button', {
    name: swapLabel(tops[0]), exact: true,
  }).isVisible() ? tops[0] : tops[1];
  await expect(page.getByRole('button', { name: swapLabel(current), exact: true })).toBeVisible();
  const alternate = tops.find(item => item !== current);
  await page.mouse.move(359, 0);
  await page.screenshot({ path: 'artifacts/today-outfit-light.png' });

  await topButton.click();
  await expect(page.getByRole('button', {
    name: `${current.name}, ${current.color}, Clean, current pick`, exact: true,
  })).toBeVisible();
  await page.getByRole('button', {
    name: `${alternate.name}, ${alternate.color}, Clean`, exact: true,
  }).click();
  await page.mouse.move(359, 0);
  await page.screenshot({ path: 'artifacts/today-swap-light.png' });
  await page.getByRole('button', { name: 'Use this top', exact: true }).click();
  await expect(page.getByRole('button', { name: swapLabel(alternate), exact: true })).toBeVisible();

  await page.getByRole('button', { name: 'Swap all', exact: true }).click();
  // Bottom and shoes have no replacement; an incomplete swap keeps this outfit.
  await expect(page.getByRole('group', {
    name: /There aren’t enough clean alternatives for a full swap\. Your current outfit is kept\./,
  })).toBeVisible();
  await expect(page.getByRole('button', { name: swapLabel(alternate), exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: swapLabel(bottom), exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: swapLabel(shoes), exact: true })).toBeVisible();
  await expect(reason).toBeVisible();

  await page.getByRole('button', { name: 'View outfit', exact: true }).click();
  for (const item of [alternate, bottom, shoes]) {
    await expect(page.locator('flutter-view').getByText(`${item.category}: ${item.name}, ${item.color}, Casual, Clean`, { exact: true })).toBeVisible();
  }
  await page.getByRole('button', { name: 'Wear this', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Worn today', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: 'Close outfit', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Worn today', exact: true })).toBeDisabled();
  const readWears = await authenticatedWardrobe(request, email, password);
  const expectedWears = { [current.name]: 0, [alternate.name]: 1, [bottom.name]: 1, [shoes.name]: 1 };
  await expect.poll(readWears).toEqual(expectedWears);

  await page.reload();
  await enableSemantics(page);
  await expect(page.getByRole('button', { name: 'Worn today', exact: true })).toBeDisabled();
  await expect(reason).toBeVisible();
  await page.getByRole('button', { name: 'Account and appearance', exact: true }).click();
  await page.getByRole('radio', { name: 'Dark', exact: true }).click();
  await page.getByRole('button', { name: 'Close account', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Close account', exact: true })).toHaveCount(0);
  await page.mouse.move(359, 0);
  await page.screenshot({ path: 'artifacts/today-outfit-dark.png' });

  await page.getByRole('button', { name: 'View outfit', exact: true }).click();
  for (const item of [alternate, bottom, shoes]) {
    const status = item === shoes ? 'To wash' : 'Worn';
    await expect(page.locator('flutter-view').getByText(`${item.category}: ${item.name}, ${item.color}, Casual, ${status}`, { exact: true })).toBeVisible();
  }
  await expect(page.getByRole('button', { name: 'Worn today', exact: true })).toBeDisabled();
  await page.mouse.move(359, 0);
  await page.screenshot({ path: 'artifacts/today-detail-dark.png' });
  await expect.poll(readWears).toEqual(expectedWears);
  expect(errors).toEqual([]);
});
