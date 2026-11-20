# Nullgate's Restock - Forever

> **Status: planning.** No code yet. See [PLAN.md](PLAN.md).

**Nullgate's Restock** keeps your reagents, ammo, poison ingredients and pet food topped up in **World of Warcraft: Forever**. Set how many of each item you want to carry. When you open a vendor who sells them, the addon offers to buy what you're missing.

It works for every class, and each class starts with a suggested list you can edit or ignore.

---

## How It Works

1. **Build your list**: drag an item onto the list, or Shift-click it in a vendor's window, and set how many to keep.
2. **Open a vendor.** The addon works out what that vendor sells from your list and how many you need.
3. **Confirm the purchase**: *"Buy 200 Jagged Arrows and 10 Symbol of Kings for 1g 45s?"* Nothing is bought until you say yes.

After each purchase, a line in chat lists what was bought and the total cost.

---

## Buying Without Confirmation

You can turn the confirmation off in the settings. When you do, you must also set at least one spending limit, and the addon refuses to buy automatically until one is set:

- **Maximum spend per vendor visit**: the addon buys nothing past this amount.
- **Minimum gold to keep**: the addon never takes you below this amount.

If a purchase would break a limit, the addon buys what fits and asks you about the rest.

---

## Features

- **Per-character shopping list** with amounts to keep, optionally counting what's in your bank (from your last bank visit).
- **Suggested starting lists for every class**: teleport and portal runes, candles, symbols, ankhs, seeds, vials and poison ingredients, ammo for your ranged weapon, pet food for your pet's diet.
- **Respects stack sizes and vendors with limited stock.**
- **Purchase summary** in chat after every visit.
- **Settings** in its own window or inside Nullgate's Addon Config.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/nrestock` or `/restock` | Open the shopping list and settings. |
| `/nrestock add <item link> <amount>` | Add an item to your list. |
| `/nrestock pause` | Stop offering purchases until you turn it back on. |
| `/nrestock check` | Test what the addon needs in your game client and save the results. |

---

## Installation

Not released yet. Once it is:

1. Download the latest release from CurseForge or the GitHub releases page.
2. Extract the `NullgatesRestock-Forever` folder into the `Interface\AddOns` folder of your World of Warcraft: Forever installation.
3. Log in and type `/nrestock`.

---

## Part of the Nullgate Addon Suite

- **Nullgate's Addon Config**: one settings hub and profile manager for the whole suite.
- **Nullgate's Food & Water**, **Pet & Ammo**, **Poisons**, **Shards & Stones**, **Quest Tracker** and more.

---

## License

Source-available, all rights reserved. See [LICENSE.md](LICENSE.md).
