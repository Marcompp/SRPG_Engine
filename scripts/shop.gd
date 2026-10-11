class_name Shop
extends RefCounted
## Buying and selling (design: docs/economy.md), shared by the prep screen's Shop
## (buys into and sells from the convoy) and shop objects on maps (a unit standing
## on one buys into and sells from its own inventory). Prices: Items.PRICES.

## What the prep screen's Shop sells when a chapter has no "shop" list.
static var DEFAULT_STOCK := GameData.strings("economy", "shop", "default_stock")


## The prep screen's stock for a chapter (Chapters.DATA entry).
static func stock_for(chapter: Dictionary) -> Array:
	return chapter.get("shop", DEFAULT_STOCK)


static func can_afford(item_name: String, gold: int) -> bool:
	return Items.cost(item_name) > 0 and Items.cost(item_name) <= gold


## "Iron Sword  460G", marked (x) when `gold` can't pay for it.
static func buy_label(item_name: String, gold: int) -> String:
	var text := "%s  %dG" % [item_name, Items.cost(item_name)]
	return text if can_afford(item_name, gold) else text + "  (x)"


## "Iron Sword 23  115G", or "--" for what can't be sold.
static func sell_label(item: Dictionary) -> String:
	var price := Items.sell_price(item)
	return "%s  %s" % [Items.label(item, " "), "%dG" % price if price > 0 else "--"]
