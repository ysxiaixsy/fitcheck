const { expect } = require('@playwright/test');

// Flutter web can apply a Ctrl+A selection after the next key event arrives,
// so a single Backspace may delete only the last character. Clear until the
// field is actually empty, confirming the full selection before each delete.
async function clearField(page, field) {
  await expect(async () => {
    if ((await field.inputValue()) === '') return;
    await page.keyboard.press('ControlOrMeta+A');
    await expect
      .poll(() => field.evaluate(input =>
        input.selectionStart === 0 && input.selectionEnd === input.value.length), { timeout: 1000 })
      .toBe(true);
    await page.keyboard.press('Backspace');
    await expect(field).toHaveValue('', { timeout: 1000 });
  }).toPass({ timeout: 15000 });
}

async function enterText(page, field, value) {
  await field.click();
  await expect(field).toBeFocused();
  await clearField(page, field);
  await page.keyboard.type(value, { delay: 5 });
  await expect(field).toHaveValue(value);
  await page.keyboard.press('Tab');
}

module.exports = { enterText };
