# Nullgate's Restock - Forever: Plan

Status: planning, with no code written yet. Planned on 2026-11-20.

- **Folder:** `NullgatesRestock-Forever`
- **Saved variables:** `NullgatesRestockDB` (per character)
- **Commands:** `/nrestock` and `/restock`

## Decisions made

- Works for every class. It is the only Nullgate addon that buys anything; Pet & Ammo, Poisons and Shards & Stones only warn.
- **Every purchase asks for confirmation by default.**
- **Confirmation can be turned off only with a spending limit.** The player must set a maximum spend per vendor visit, a minimum gold to keep, or both. Until one is set, the setting stays on (the toggle shows why). Clearing both limits later turns confirmation back on.
- When a purchase without confirmation would break a limit, the addon buys what fits and asks about the rest.
- Class starting lists are offered once per character and are off until the player accepts or edits them.
- Ships as 1.0.0-beta.1 for testers. Every class can test it.

## Why this one is low risk

Buying from vendors (`BuyMerchantItem`) is not protected, so there are no secure buttons and no combat restrictions. The risk is spending gold the player didn't mean to spend, which the confirmation and limits handle.

---

## Phase 0: Repo and checks

- Repo, README, plan, license, logo, CurseForge workflow, `/zips` packaging, tests.
- `/nrestock check` in-game self test. Confirm in the Forever client:
  - `GetMerchantNumItems`, `GetMerchantItemID`, `GetMerchantItemInfo` and `GetMerchantItemMaxStack` behave as in original Classic.
  - `BuyMerchantItem(index, quantity)` with quantities above one stack, and limited-stock items.

## Phase 1: List data and buying logic

- Shopping list per character: item ID and amount to keep.
- On `MERCHANT_SHOW`: match the vendor's items to the list, work out the shortfall from bag counts (optionally plus the remembered bank count).
- Purchase plan respecting stack sizes, limited stock, the per-visit maximum and the minimum gold to keep.
- Confirmation dialog listing items and total cost; chat summary afterwards.
- Unit tests for the plan and every limit, including the "confirmation off requires a limit" rule.

## Phase 2: List editor

- Window listing items, amounts and current counts.
- Drag an item to add it; Shift-click an item in a vendor's window to add it; `/nrestock add`.

## Phase 3: Class lists and bank counts

- Starting lists for every class (Hunter ammo follows the equipped weapon; pet food follows the pet's diet).
- Remember bank counts on each bank visit.

## Phase 4: Settings, languages, beta

- Confirmation setting with the required limits, pause command.
- Settings window and Nullgate's Addon Config page.
- The 10 client languages.
- DESCRIPTION.md, CHANGELOG.md, 1.0.0-beta.1.
