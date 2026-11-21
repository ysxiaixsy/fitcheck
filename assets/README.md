# Asset sources

## Figma assets

The SVGs in `icons/` and `illustrations/` were exported through the Figma MCP from the project's final [Mobile prototype page](https://www.figma.com/design/leBVZp8eURCGW8T82kjvH8/FitCheck?node-id=115-43). They are bundled locally; the app does not depend on temporary Figma asset URLs.

| Local assets | Design source |
| --- | --- |
| `icons/home.svg`, `wardrobe.svg`, `calendar.svg`, `plus.svg` | Today — new user, node `115:470` |
| `illustrations/top.svg`, `bottom.svg`, `shoes.svg` | Today — new user checklist, node `115:470` |
| `icons/search.svg` | Wardrobe, node `115:259` |
| `icons/previous.svg`, `next.svg` | Planner, node `115:315` |
| `icons/close.svg`, `camera.svg` | Add item, node `115:281` |
| `icons/outfit_badge_shuffle.svg`, `outfit_shuffle.svg`, `outfit_sparkles.svg` | Today, frame `115:44` |
| `icons/outfit_check.svg` | Wear this action in Today and View outfit, frames `115:44` and `115:154` |
| `icons/outfit_selected_check.svg` | Swap top selection, frame `115:92` |
| `illustrations/scent.svg`, `icons/droplet.svg`, `icons/weather.svg` | Fragrance card, Change fragrance, and weather chip, frame `115:197` |

Use the SVG geometry from Figma. Runtime theme colors are applied through semantic tokens; clothing photos remain user-supplied content. Design screenshots are references, not app background images.

## Typography

`fonts/PlusJakartaSans.ttf` is the Plus Jakarta Sans variable font from the [Google Fonts source repository](https://github.com/google/fonts/tree/main/ofl/plusjakartasans). The app registers weights 400, 600, and 700 from this bundled file, so text rendering does not fetch fonts at runtime.

The font's SIL Open Font License is included in [fonts/OFL.txt](fonts/OFL.txt).

## Launcher and splash artwork

The generated Flutter launcher and splash assets under `android/`, `ios/`, and `web/` are scaffold placeholders. Approved FitCheck release artwork is tracked in [milestone 6](https://github.com/ysxiaixsy/fitcheck/issues/7).
