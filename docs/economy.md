# Gold, shops and services (design notes)

Design notes. The whole build order is built: `Campaign.gold`, `Battle.gold`,
`Items.PRICES` (`data/economy.cfg`), `scripts/shop.gd`, and gold and shops in the campaign chapters
(rewards 1000-3000, gold on the thieves and bosses, a gold village in chapters 1
and 3, a gold chest in chapter 5, a map shop in chapter 3, bigger prep stocks from
chapter 3 on).

## Gold

- **Army funds:** one purse for the whole army. In the campaign it's
  `Campaign.gold`, carried from chapter to chapter and saved with the campaign. A
  battle works on its own copy (saved with suspends and rewinds), written back to
  the campaign when the chapter is won; a lost chapter retries with the gold it
  started with, like the army. Test maps start from the level's `"gold"` (0 if
  unset).
- Shown on the prep screen, the Objective screen and in shops.

## Income

| Source | How |
|---|---|
| Chapter rewards | A chapter's `"reward"`: gold added when it's won |
| Villages | A village object's `"gold"`, with or without an `"item"` |
| Chests | A chest object's `"gold"`, with or without an `"item"` |
| Enemies carry gold | Roster `"gold"`: when the player's side defeats the unit, the gold goes to the funds. Steal can take it instead (a "Gold" entry in the Steal menu) |
| Selling | Shops buy items back at half their value |

Only the player's side earns gold: a green ally killing a gold-carrying enemy gets
nothing (it isn't your army's purse).

## Prices

- Weapons and items get a `"cost"`: the price of a fresh one. A worn item is worth
  its cost times uses left over max uses (FE); items that never run out are worth
  their cost.
- Selling pays half the value. Items with no cost (quest items) can't be sold.
- Rough scale, GBA-like: Iron weapons 400-500, Steel 600-800, Silver 1500-2000,
  Potion 300, Antitoxin 450, Chest Key 300, Repair Kit 800.

## Shops

- **Prep screen:** a Shop entry. Buy puts the item in the convoy; Sell sells from the
  convoy. The stock is the chapter's `"shop"` list (a default list if unset).
- **On the map:** shop objects (`{"type": "shop", "cell", "stock": [...]}`, drawn like
  villages) give a unit standing on them a Shop command: buy into that unit's
  inventory (full: the campaign's convoy, outside it no room means no buying), sell
  from its inventory. Buying or selling ends the unit's turn; leaving without one goes
  back to the unit menu.
- Prices and the funds are shown; items you can't afford are marked (x). On the map
  the shop is the unit menu's Shop > Buy / Sell; on the prep screen, one screen with
  the stock on the left and the convoy on the right (Left/Right to switch).

## Services

- **Repair** (prep screen) costs the price of the uses it restores: cost times
  missing uses over max uses. Repair Kits stay free to use.

## Build order

1. **Gold:** funds (campaign and battle, saved), prices and item values, income from
   chapter rewards, villages, chests and enemies (and Steal), repair costs, funds on
   the prep and Objective screens.
2. **Shops:** the shop screen, the prep screen's Shop, shop objects and the Shop
   command on maps.
3. **Content:** prices on every item, gold and shops in the campaign chapters and a
   test map.
