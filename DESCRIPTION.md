**Nullgate's Restock** keeps your reagents, ammo, poison ingredients and pet food topped up in **World of Warcraft: Forever**. Set how many of each item you want to carry. When you open a vendor who sells them, the addon offers to buy what you're missing.

No more arriving at the raid without candles, running out of teleport runes in the middle of nowhere, or buying arrows one stack at a time.

> **Beta:** this is an early test version and we're looking for players of every class to try it. If something doesn't work, run `/nrestock check`, then send us the results with a short description.

---

## Features

- **Shopping list for each character**: every item with the amount you want to carry. Optionally counts what's in your bank, from your last bank visit.
- **Suggested lists for every class**: teleport and portal runes, candles, symbols, ankhs, seeds, vials and poison ingredients, ammo for your ranged weapon and food for your pet's diet. Use them, change them or start empty.
- **Easy to add items**: drag an item onto the list, or Alt-click it in a vendor's window.
- **Confirmation before every purchase**, listing each item and the total cost.
- **Spending limits**: a maximum to spend per vendor visit and a minimum amount of gold to always keep.
- **Respects stack sizes and vendors with limited stock.**
- **Purchase summary** in chat after every visit.
- **Simple settings**: confirmation, spending limits, bank counting, the class list and the language.

---

## How It Works

1. **Build your list** and set how many of each item to keep.
2. **Open a vendor.** The addon works out which items on your list that vendor sells, and how many you need.
3. **Confirm the purchase**: *"Buy 200 Jagged Arrows and 10 Symbol of Kings for 1g 45s?"* Nothing is bought until you say yes.

---

## Buying Without Confirmation

You can turn the confirmation off in the settings, but only after setting at least one spending limit:

- **Maximum spend per vendor visit**: the addon never spends more than this on one visit.
- **Minimum gold to keep**: the addon never takes you below this amount.

Until one is set, the confirmation stays on. If you later clear both limits, it turns back on. When a purchase would break a limit, the addon buys what fits and asks you about the rest.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/nrestock` or `/restock` | Open the shopping list. |
| `/nrestock add <item link> <amount>` | Add an item to your list (the amount is optional). |
| `/nrestock remove <item link>` | Remove an item from your list. |
| `/nrestock suggest` | Add the suggested items for your class and level. |
| `/nrestock pause` | Stop offering purchases until you turn it back on. |
| `/nrestock config` | Open the settings. |
| `/nrestock check` | Test what the addon needs in your game client and save the results (for bug reports). |

---

## Installation

1. Download the latest file.
2. Extract the `NullgatesRestock-Forever` folder into the `Interface\AddOns` folder of your World of Warcraft: Forever installation.
3. Log in and type `/nrestock` to set up your list.

---

## Good to Know

- Works for every class.
- It never sells anything, and never buys an item that isn't on your list.
- Available in 10 languages: English, Deutsch, Español, Français, Italiano, Português (Brasil), Русский, 한국어, 简体中文 and 繁體中文 (every language the game client runs in). The game's language is used automatically, and you can pick another in the settings. The translations were made with machine assistance; corrections are welcome.
