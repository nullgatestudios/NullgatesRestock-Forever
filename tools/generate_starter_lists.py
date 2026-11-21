"""Builds Data/StarterLists.lua, the suggested restock lists, from the Forever client's tables on wago.tools.

Class reagents: every reagent of every spell a class learns (SkillLineAbility + SpellReagents),
with the level it's first needed (SpellLevels) and, when a higher rank stops using it, the level it's no longer needed (untilLevel).
Left out: items with no vendor price (Soul Shard), herbs, and items the class crafts itself.

Hunter ammo and pet food: a short list of the common vendor items (vendor stock isn't in the
client files), with level, ammo type and pet diet read from the client data.

Usage:
  python tools/generate_starter_lists.py [--build 1.60.1.70532] [--data DIR]

  --build  the client build to read (default: the latest wow_classic_beta build, which is Forever)
  --data   read the CSV files from DIR instead of downloading them
"""
import argparse
import csv
import io
import json
import os
import sys
import urllib.request
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "NullgatesRestock-Forever", "Data", "StarterLists.lua")
TABLES = ("SpellName", "SpellLevels", "SpellReagents", "SpellEffect", "SkillLineAbility", "ItemSparse", "Item", "ItemPetFood")

# The class skill lines (Poisons, 40, is the rogue's crafting line).
CLASS_LINES = {
    "MAGE": (237, 8, 6), "PRIEST": (56, 613, 78), "DRUID": (574, 134, 573), "PALADIN": (594, 267, 184),
    "WARLOCK": (355, 354, 593), "SHAMAN": (375, 373, 374), "WARRIOR": (26, 256, 257),
    "HUNTER": (50, 163, 51), "ROGUE": (253, 38, 39, 40),
}
CREATE_ITEM = "24"
HERB = ("7", "9")          # Item ClassID 7 (Trade Goods), SubclassID 9 (Herb)
PROJECTILE = "6"           # Item ClassID 6; SubclassID 2 arrows, 3 bullets
SEEDS = {17034, 17035, 17036, 17037, 17038}

# Common vendor ammo and pet food (what vendors stock isn't in the client data).
AMMO_ITEMS = [2512, 2515, 3030, 11285, 2516, 2519, 3033, 11284]
PET_FOOD_ITEMS = [
    117, 2287, 3770, 3771, 4599, 8952,          # meat
    4540, 4541, 4542, 4544, 4601, 8950,         # bread
    4592, 4593, 4594, 8957,                     # fish
    2070, 414, 422, 1707, 3927, 8932,           # cheese
    4536, 4537, 4538, 4539, 4602, 8953,         # fruit
    4604, 4605, 4606, 4607, 4608, 8948,         # fungus
]


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "NullgatesRestock-generator"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        return resp.read().decode("utf-8")


def latest_build():
    return json.loads(fetch("https://wago.tools/api/builds/latest"))["wow_classic_beta"]["version"]


def load(name, build, data_dir):
    if data_dir:
        with open(os.path.join(data_dir, name + ".csv"), encoding="utf-8") as f:
            text = f.read()
    else:
        text = fetch("https://wago.tools/db2/%s/csv?build=%s" % (name, build))
    return list(csv.DictReader(io.StringIO(text)))


def to_int(value):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return 0


def default_keep(item_id, stack):
    if item_id in SEEDS:
        return 5
    return max(1, min(stack or 20, 20))


def class_reagents(t):
    names = {r["ID"]: r["Name_lang"] for r in t["SpellName"]}
    levels = {}
    for r in t["SpellLevels"]:
        levels[r["SpellID"]] = to_int(r.get("BaseLevel")) or to_int(r.get("SpellLevel"))
    reagents = defaultdict(list)
    for r in t["SpellReagents"]:
        for i in range(8):
            item = to_int(r.get("Reagent_%d" % i))
            if item:
                reagents[r["SpellID"]].append(item)
    crafted = set()
    for r in t["SpellEffect"]:
        if r["Effect"] == CREATE_ITEM:
            crafted.add((r["SpellID"], to_int(r.get("EffectItemType"))))
    sparse = {to_int(r["ID"]): r for r in t["ItemSparse"]}
    items = {to_int(r["ID"]): r for r in t["Item"]}

    result = {}
    for cls, lines in CLASS_LINES.items():
        line_set = {str(x) for x in lines}
        uses = []          # (spell name, level, set of reagent items)
        made = set()       # items this class crafts
        for r in t["SkillLineAbility"]:
            if r["SkillLine"] not in line_set:
                continue
            spell = r["Spell"]
            for sid, item in crafted:
                if sid == spell:
                    made.add(item)
            if spell not in reagents:
                continue
            level = levels.get(spell, 0)
            uses.append((names.get(spell, spell), level, set(reagents[spell])))

        # Each rank needs its reagents from its level until the next rank of the same spell.
        # An item is needed from its earliest use until the latest such end (none if the top
        # rank of any spell still uses it).
        ranks = defaultdict(list)
        for name, level, its in uses:
            ranks[name].append((level, its))
        start, ends = {}, defaultdict(list)
        for entries in ranks.values():
            entries.sort(key=lambda e: e[0])
            for i, (level, its) in enumerate(entries):
                end = entries[i + 1][0] if i + 1 < len(entries) else None
                for item in its:
                    start[item] = min(start.get(item, level), level)
                    ends[item].append(end)
        until = {item: (None if None in e else max(e)) for item, e in ends.items()}

        out = []
        for item in sorted(start, key=lambda it: (start[it], it)):
            s = sparse.get(item)
            it = items.get(item, {})
            if not s or to_int(s.get("BuyPrice")) <= 0:
                continue
            if (it.get("ClassID"), it.get("SubclassID")) == HERB or item in made:
                continue
            out.append({"item": item, "name": s.get("Display_lang", ""), "level": max(1, start[item]),
                        "untilLevel": until.get(item), "keep": default_keep(item, to_int(s.get("Stackable")))})
        result[cls] = out
    return result


def ammo(t):
    sparse = {to_int(r["ID"]): r for r in t["ItemSparse"]}
    items = {to_int(r["ID"]): r for r in t["Item"]}
    kinds = {"2": "arrow", "3": "bullet"}
    out = {"arrow": [], "bullet": []}
    for item in AMMO_ITEMS:
        s, it = sparse.get(item), items.get(item)
        if not s or not it or it["ClassID"] != PROJECTILE or it["SubclassID"] not in kinds:
            sys.exit("ammo item %d is missing or not ammo in this build" % item)
        out[kinds[it["SubclassID"]]].append({"item": item, "name": s["Display_lang"], "level": max(1, to_int(s["RequiredLevel"]))})
    for kind in out:
        out[kind].sort(key=lambda e: e["level"])
    return out


def pet_food(t):
    sparse = {to_int(r["ID"]): r for r in t["ItemSparse"]}
    items = {to_int(r["ID"]): r for r in t["Item"]}
    diets = {r["ID"]: r["Name_lang"] for r in t["ItemPetFood"]}
    out = defaultdict(list)
    for item in PET_FOOD_ITEMS:
        s, it = sparse.get(item), items.get(item)
        if not s or not it or not diets.get(it.get("ItemPetFoodID")):
            sys.exit("pet food item %d is missing or has no diet in this build" % item)
        out[diets[it["ItemPetFoodID"]]].append({"item": item, "name": s["Display_lang"], "level": max(1, to_int(s["ItemLevel"]))})
    for diet in out:
        out[diet].sort(key=lambda e: e["level"])
    return dict(sorted(out.items()))


def lua_entry(e, extra=()):
    parts = ["item = %d" % e["item"], "level = %d" % e["level"]]
    if e.get("untilLevel"):
        parts.append("untilLevel = %d" % e["untilLevel"])
    if "keep" in e:
        parts.append("keep = %d" % e["keep"])
    return "{ %s }, -- %s" % (", ".join(parts), e["name"])


def write(build, classes, ammo_lists, food_lists):
    lines = [
        "-- Generated by tools/generate_starter_lists.py from the Forever client data. Do not edit by hand.",
        "local _, ns = ...",
        "",
        'ns.STARTER_DATA_BUILD = "%s"' % build,
        "",
        "-- Class reagents: needed from level, no longer needed from untilLevel; keep is the suggested amount.",
        "ns.STARTER_REAGENTS = {",
    ]
    for cls in sorted(classes):
        lines.append("    %s = {" % cls)
        for e in classes[cls]:
            lines.append("        " + lua_entry(e))
        lines.append("    },")
    lines += ["}", "", "-- Vendor ammo by type, lowest required level first.", "ns.STARTER_AMMO = {"]
    for kind in ("arrow", "bullet"):
        lines.append("    %s = {" % kind)
        for e in ammo_lists[kind]:
            lines.append("        " + lua_entry(e))
        lines.append("    },")
    lines += ["}", "", "-- Vendor pet food by diet (the English names GetPetFoodTypes returns), lowest item level first.",
              "ns.STARTER_PET_FOOD = {"]
    for diet, entries in food_lists.items():
        lines.append('    ["%s"] = {' % diet)
        for e in entries:
            lines.append("        " + lua_entry(e))
        lines.append("    },")
    lines.append("}")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build")
    parser.add_argument("--data")
    args = parser.parse_args()
    build = args.build or latest_build()
    tables = {name: load(name, build, args.data) for name in TABLES}
    classes = class_reagents(tables)
    write(build, classes, ammo(tables), pet_food(tables))
    for cls in sorted(classes):
        print("%-8s %s" % (cls, ", ".join("%s (%d%s)" % (e["name"], e["level"], "-%d" % e["untilLevel"] if e.get("untilLevel") else "") for e in classes[cls])))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
