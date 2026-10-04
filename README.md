# TCG Tycoon

A GUI-driven Roblox trading card game: rip packs, build a collection, send cards
for grading, and sell them through your store, online, and at card shows.

## Gameplay

- **Packs** – Buy boosters from three sets plus a high-end Mystery Vault pack.
  The last card is always Rare or better. Better packs unlock with reputation.
- **Collection** – Every card has a hidden condition (Mint → Damaged) that
  affects its value. Filter, sort, inspect, list, or quick-sell to the dealer
  at 50%.
- **Grading** – Send raw cards to PGS (Value / Regular / Express). Grades 1–10
  replace the condition multiplier; a Gem Mint 10 is worth 6x.
- **Store** – Limited shelf space, steady walk-in customers, no fees. Upgrade
  for more slots and foot traffic.
- **Online** – Up to 30 listings and a 12% fee. Buyers are price-sensitive;
  graded cards sell faster.
- **Shows** – Pay a table fee, bring a box of cards, and sell to a crowd for a
  limited time. Bigger shows tolerate higher prices and pay extra for slabs.
- **Market** – Card prices drift every 45 seconds and can spike when a card is
  trending, so timing your sales matters.

Selling through the store, online, or at shows earns reputation, which unlocks
better packs and shows.

## Project layout

```
src/shared/          ReplicatedStorage.Shared
  Config/            Cards, Packs, Grading, Economy (all tuning lives here)
  Valuation.luau     Card value + buyer demand math (used by server and client)
  Money.luau
src/server/          ServerScriptService.Server
  Main.server.luau   Boots the services
  Services/          Data, Market, Pack, Grading, Store, Online, Show, Dealer
src/client/          StarterPlayerScripts.Client
  Main.client.luau   Builds the GUI
  State.luau         Client copy of player data + server action helper
  UI/                Components (CardTile, Grid, Modals, Toasts, PackOpening)
  UI/Pages/          Packs, Collection, Grading, Store, Online, Shows
```

The server is authoritative: the client only calls actions through a single
`Remotes.Action` RemoteFunction, and the server pushes the full player state
back through `Remotes.Sync`.

## Running it

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install`
   (or install Rojo 7.4+ any other way) and the Rojo Studio plugin.
2. Run `rojo serve` in this folder, open a Baseplate in Roblox Studio and
   connect with the Rojo plugin.
3. Press Play.

To build a place file instead: `rojo build -o TCGTycoon.rbxlx`.

Saving uses DataStores. In Studio, enable *Game Settings → Security → Enable
Studio Access to API Services* after publishing the place; otherwise the game
still runs but progress isn't saved.
