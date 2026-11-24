# Changelog

All notable changes to Nullgate's Restock - Forever.

## [1.0.0-beta.2] - 2026-11-24

### New

- **Bug report window.** `/nrestock check` now opens a window with its report, ready to copy.
- Press Ctrl+C to copy the report, then paste it into the report form at nullgatestudios.com/report?addon=restock, which opens with this addon already picked. You can report without an account.
- Every Nullgate addon now uses the same report window.

### Good to know

- The game doesn't let addons open a web browser, so type or copy the link into your browser yourself. The **Select link** button selects it for copying.

## [1.0.0-beta.1] - 2026-11-20

First test version, looking for players of every class to try it.

### New

- **Shopping list for each character**: items and how many of each to carry, in priority order. Add items by dragging them onto the list, Alt-clicking them in a vendor's window, or with `/nrestock add`.
- **Asks before buying**: at a vendor that sells something on your list, a popup lists each item and the total cost. Nothing is bought until you say yes.
- **Spending limits**: a maximum per vendor visit and a minimum amount of gold to keep. Buying without asking can only be turned on once at least one limit is set, and turns off again if both are cleared. Anything over a limit is offered separately.
- **Suggested lists for every class and level**, read from the Forever client data: teleport and portal runes, candles, symbols, seeds and berries, ankhs, poison ingredients, ammo for your ranged weapon and food for your pet's diet. Offered once per character, and any time with `/nrestock suggest`.
- **Bank counting**: optionally count what's in your bank as well as your bags.
- **Purchase summary** in chat after buying.
- **Settings** in its own window or inside Nullgate's Addon Config.
- **`/nrestock check`**: tests what the addon needs in your client, lists what a vendor sells as the addon sees it, and has a one-purchase test. Results are saved for bug reports.
- Available in English, Deutsch, Español, Français, Italiano, Português (Brasil), Русский, 한국어, 简体中文 and 繁體中文.

### Good to know

- Items sold in bundles (such as 200 arrows) are bought one bundle at a time, so you may end up with slightly more than your amount.
- The addon never sells anything and never buys an item that isn't on your list.
