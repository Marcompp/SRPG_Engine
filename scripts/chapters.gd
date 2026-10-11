class_name Chapters
extends RefCounted
## Campaign chapters (see Campaign), played in ORDER by one persistent army.
## Same format as Levels, plus:
##   deploy:          player starting cells, in order (the Lord takes the first);
##                    its size is the number of units the chapter allows.
##   recruits:        units (roster format) that join the army at this chapter.
##   objective:       see Objectives.
##   objects:         villages, chests and shops (see BattleMap.objects).
##   reward:          gold for winning the chapter (docs/economy.md).
##   shop:            what the prep screen's Shop sells before it (default:
##                    Shop.DEFAULT_STOCK).
##   reinforcements:  [{"turn": N, "units": [enemy roster entries]}]; they appear at
##                    the start of enemy phase N and act from the next one.
## Chapters have no "players": the army is deployed from the prep screen.

static var ORDER := GameData.strings("chapters/index", "", "order")

static var DATA := GameData.folder("chapters")
