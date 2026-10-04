#!/usr/bin/env python3
"""Import real card sets from the Pokemon TCG API into the game's config.

Writes src/shared/Config/CardData.luau (sets, cards and packs).

    python3 tools/import_cards.py                       # default sets, live API prices
    python3 tools/import_cards.py --sets base1,sv3pt5   # pick sets (API set ids)
    python3 tools/import_cards.py --source github       # no API: use the API's GitHub
                                                        # dataset with estimated prices

Set POKEMONTCG_API_KEY for higher API rate limits (free at pokemontcg.io).
Only standard library is used.
"""

import argparse
import hashlib
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.pokemontcg.io/v2"
GITHUB = "https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master"
OUT = Path(__file__).resolve().parent.parent / "src" / "shared" / "Config" / "CardData.luau"

DEFAULT_SETS = ["base1", "base2", "sv3pt5", "sv8pt5", "sv10"]

TIERS = ["Common", "Uncommon", "Rare", "HoloRare", "UltraRare", "SecretRare"]

# API rarity string -> game tier. Anything unlisted falls back by keyword.
RARITY_MAP = {
    "Common": "Common",
    "Uncommon": "Uncommon",
    "Rare": "Rare",
    "Rare Holo": "HoloRare",
    "Double Rare": "HoloRare",
    "ACE SPEC Rare": "HoloRare",
    "Rare Holo EX": "UltraRare",
    "Rare Holo GX": "UltraRare",
    "Rare Holo V": "UltraRare",
    "Rare Holo VMAX": "UltraRare",
    "Rare Holo VSTAR": "UltraRare",
    "Rare Ultra": "UltraRare",
    "Ultra Rare": "UltraRare",
    "Illustration Rare": "UltraRare",
    "Special Illustration Rare": "SecretRare",
    "Hyper Rare": "SecretRare",
    "Mega Hyper Rare": "SecretRare",
    "Rare Secret": "SecretRare",
    "Rare Rainbow": "SecretRare",
}

# Estimated raw NM prices per tier when no market price is available.
ESTIMATES = {
    "Common": 0.15,
    "Uncommon": 0.30,
    "Rare": 0.80,
    "HoloRare": 4.0,
    "UltraRare": 12.0,
    "SecretRare": 60.0,
}
VINTAGE_BOOST = {"Rare": 4, "HoloRare": 10}  # sets released before 2003

# Fan favourites command a premium when estimating.
CHASE_DEX = {6, 25, 94, 133, 134, 135, 136, 149, 150, 151, 196, 197, 384, 448, 470, 471, 700}

# Odds. The last card of a pack is the hit slot.
SLOT_WEIGHTS = {"Common": 60, "Uncommon": 30, "Rare": 10}
HIT_WEIGHTS = {"Rare": 67, "HoloRare": 17, "UltraRare": 14, "SecretRare": 2}
VINTAGE_HIT_WEIGHTS = {"Rare": 67, "HoloRare": 33}
VAULT_WEIGHTS = {"HoloRare": 70, "UltraRare": 25, "SecretRare": 5}

CARDS_PER_PACK = 10
VAULT_CARDS = 3
AVG_CONDITION_MULT = 0.8  # average raw condition multiplier from PackService
PRICE_RATIO = 0.95  # pack price as a share of expected value
REPUTATION_STEPS = [0, 40, 200, 800, 2000, 5000]

SET_COLORS = [
    (232, 98, 52), (46, 170, 90), (122, 74, 214), (46, 150, 230),
    (220, 60, 110), (230, 170, 40), (60, 70, 90), (40, 190, 180),
]

PRICE_VARIANTS = [
    "holofoil", "normal", "unlimitedHolofoil", "unlimited",
    "1stEditionHolofoil", "1stEdition", "reverseHolofoil",
]


def fetch_json(url, headers=None):
    req = urllib.request.Request(url, headers={"User-Agent": "tcgtycoon-importer", **(headers or {})})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def api_headers():
    key = os.environ.get("POKEMONTCG_API_KEY")
    return {"X-Api-Key": key} if key else {}


def load_set_api(set_id):
    info = fetch_json(f"{API}/sets/{set_id}", api_headers())["data"]
    cards, page = [], 1
    while True:
        query = urllib.parse.urlencode({"q": f"set.id:{set_id}", "page": page, "pageSize": 250})
        body = fetch_json(f"{API}/cards?{query}", api_headers())
        cards += body["data"]
        if page * body["pageSize"] >= body["totalCount"]:
            break
        page += 1
    return info, cards


_github_sets = None


def load_set_github(set_id):
    global _github_sets
    if _github_sets is None:
        _github_sets = {s["id"]: s for s in fetch_json(f"{GITHUB}/sets/en.json")}
    if set_id not in _github_sets:
        sys.exit(f"Unknown set id: {set_id}")
    return _github_sets[set_id], fetch_json(f"{GITHUB}/cards/en/{set_id}.json")


def tier_for(rarity):
    if not rarity:
        return None
    if rarity in RARITY_MAP:
        return RARITY_MAP[rarity]
    lower = rarity.lower()
    if any(k in lower for k in ("secret", "hyper", "rainbow", "special", "gold", "shiny")):
        return "SecretRare"
    if "rare" in lower:
        return "UltraRare"
    return None  # promos and oddities aren't in packs


def market_price(card):
    prices = (card.get("tcgplayer") or {}).get("prices") or {}
    for variant in PRICE_VARIANTS:
        market = (prices.get(variant) or {}).get("market")
        if market:
            return float(market)
    return None


def estimate_price(card, tier, vintage):
    # Deterministic per-card spread so estimates don't all look identical.
    digest = hashlib.md5(card["id"].encode()).digest()
    spread = 0.6 + digest[0] / 255  # 0.6 .. 1.6
    price = ESTIMATES[tier] * spread
    if vintage:
        price *= VINTAGE_BOOST.get(tier, 1)
    if tier in ("HoloRare", "UltraRare", "SecretRare") and CHASE_DEX & set(card.get("nationalPokedexNumbers") or []):
        price *= 2.5
    return price


def round_price(value):
    return max(0.05, round(value, 2))


def build_set(set_id, source, index):
    info, raw_cards = load_set_api(set_id) if source == "api" else load_set_github(set_id)
    vintage = int(info["releaseDate"][:4]) < 2003
    cards = []
    priced = 0
    for card in raw_cards:
        tier = tier_for(card.get("rarity"))
        if not tier:
            continue
        price = market_price(card)
        if price:
            priced += 1
        else:
            price = estimate_price(card, tier, vintage)
        cards.append({
            "id": card["id"],
            "name": card["name"],
            "number": card.get("number", ""),
            "rarity": tier,
            "rarityLabel": card["rarity"],
            "type": (card.get("types") or [card.get("supertype", "")])[0],
            "value": round_price(price),
        })
    print(f"  {info['name']}: {len(cards)} cards, {priced} with market prices")
    return {
        "id": set_id,
        "name": info["name"],
        "releaseDate": info["releaseDate"],
        "vintage": vintage,
        "color": SET_COLORS[index % len(SET_COLORS)],
        "cards": cards,
    }


def present(weights, tiers):
    return {t: w for t, w in weights.items() if t in tiers}


def tier_average(cards, tier):
    values = [c["value"] for c in cards if c["rarity"] == tier]
    return sum(values) / len(values) if values else 0


def expected_value(slot_sets, weights):
    """EV of one card: averages over sets (for multi-set packs) then tiers."""
    total = sum(weights.values())
    ev = 0
    for cards in slot_sets:
        ev += sum(w / total * tier_average(cards, t) for t, w in weights.items()) / len(slot_sets)
    return ev


def nice_price(value):
    if value < 10:
        return max(1, round(value * 2) / 2)
    if value < 100:
        return float(round(value))
    return float(round(value / 5) * 5)


def build_packs(sets):
    packs = []
    for s in sets:
        tiers = {c["rarity"] for c in s["cards"]}
        slot = present(SLOT_WEIGHTS, tiers)
        hit = present(VINTAGE_HIT_WEIGHTS if s["vintage"] else HIT_WEIGHTS, tiers)
        ev = (CARDS_PER_PACK - 1) * expected_value([s["cards"]], slot) + expected_value([s["cards"]], hit)
        packs.append({
            "id": f"{s['id']}_booster",
            "name": f"{s['name']} Booster",
            "setId": s["id"],
            "price": nice_price(ev * AVG_CONDITION_MULT * PRICE_RATIO),
            "cardsPerPack": CARDS_PER_PACK,
            "slotWeights": slot,
            "hitWeights": hit,
        })

    # Mystery Vault: every card is a big hit from a random set that has that tier.
    vault_sets = [s["cards"] for s in sets]
    vault_ev = VAULT_CARDS * expected_value(vault_sets, VAULT_WEIGHTS)
    packs.append({
        "id": "mystery_vault",
        "name": "Mystery Vault Pack",
        "setId": None,
        "price": nice_price(vault_ev * AVG_CONDITION_MULT * PRICE_RATIO),
        "cardsPerPack": VAULT_CARDS,
        "slotWeights": VAULT_WEIGHTS,
        "hitWeights": VAULT_WEIGHTS,
        "color": (40, 40, 48),
    })

    packs.sort(key=lambda p: p["price"])
    for i, pack in enumerate(packs):
        pack["reputation"] = REPUTATION_STEPS[min(i, len(REPUTATION_STEPS) - 1)]
    return packs


def lua_string(s):
    return json.dumps(s, ensure_ascii=False)


def lua_value(v, indent):
    pad = "\t" * indent
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return lua_string(v)
    if isinstance(v, tuple):
        return f"Color3.fromRGB({v[0]}, {v[1]}, {v[2]})"
    if isinstance(v, list):
        if not v:
            return "{}"
        inner = ",\n".join(f"{pad}\t{lua_value(x, indent + 1)}" for x in v)
        return "{\n" + inner + ",\n" + pad + "}"
    if isinstance(v, dict):
        if not v:
            return "{}"
        parts = []
        for k, x in v.items():
            key = k if k.isidentifier() else f"[{lua_string(k)}]"
            parts.append(f"{key} = {lua_value(x, indent + 1)}")
        # Keep cards on one line each so the file stays readable.
        one_line = "{ " + ", ".join(parts) + " }"
        if len(one_line) + len(pad) <= 140 and "\n" not in one_line:
            return one_line
        return "{\n" + ",\n".join(f"{pad}\t{p}" for p in parts) + ",\n" + pad + "}"
    raise TypeError(type(v))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sets", default=",".join(DEFAULT_SETS), help="comma-separated API set ids")
    parser.add_argument("--source", choices=["api", "github"], default="api")
    args = parser.parse_args()

    set_ids = [s.strip() for s in args.sets.split(",") if s.strip()]
    print(f"Importing {len(set_ids)} sets from {args.source}...")
    sets = []
    for i, set_id in enumerate(set_ids):
        try:
            sets.append(build_set(set_id, args.source, i))
        except Exception as err:  # noqa: BLE001
            sys.exit(f"Failed to load {set_id} from {args.source}: {err}"
                     + ("\nTry --source github if the API is unreachable." if args.source == "api" else ""))

    packs = build_packs(sets)
    for set_ in sets:
        del set_["vintage"]

    body = (
        "-- GENERATED by tools/import_cards.py. Do not edit by hand; re-run the importer.\n"
        f"-- Source: {'Pokemon TCG API' if args.source == 'api' else 'pokemon-tcg-data (GitHub), estimated prices'}\n\n"
        "return {\n"
        f"\tsets = {lua_value(sets, 1)},\n"
        f"\tpacks = {lua_value(packs, 1)},\n"
        "}\n"
    )
    OUT.write_text(body, encoding="utf-8")
    total = sum(len(s["cards"]) for s in sets)
    print(f"Wrote {total} cards and {len(packs)} packs to {OUT.relative_to(Path.cwd()) if OUT.is_relative_to(Path.cwd()) else OUT}")
    for p in packs:
        print(f"  {p['name']}: ${p['price']:.2f}, {p['reputation']} rep")


if __name__ == "__main__":
    main()
