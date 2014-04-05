ESODB-Addon
===================

This is the source for the Elder Scrolls Online Database Addon (ESODB Addon)
http://esodb.com.

Pull Requests
=============
Sorry, no pull requests yet.


How to use (PC)
===============
Place the folder "ESODB" in:
(if you dont have an AddOns folder, create it)
<VERSION> is either "live" or "liveeu", depending on your location
```
C:\Users\<YOUR USERNAME>\Documents\Elder Scrolls Online\<VERSION>\AddOns\
```
Enable it at character selection, or while being in-game.

Once you logged out after playing for a while, you can find an "ESODB.lua" file in:
```
C:\Users\<YOUR USERNAME>\Documents\Elder Scrolls Online\live\SavedVariables\
```

Send it to the quick uploader:
http://esodb.com/upload/

How to use (Mac/Osx)
====================
Place the folder "ESODB" in:
(if you dont have an AddOns folder, create it)
<VERSION> is either "live" or "liveeu", depending on your location
```
/Users/<YOUR USERNAME>/Documents/Elder Scrolls Online/<VERSION>/AddOns/
```
(You can find it easly starting Finder, and click "Documents" in the left menu)
Enable it at character selection, or while being in-game.

Once you logged out after playing for a while, you can find an "ESODB.lua" file in:
```
/Users/<YOUR USERNAME>/Documents/Elder Scrolls Online/<VERSION>/SavedVariables/
```

Send it to the quick uploader:
http://esodb.com/upload/

Thanks!

What it gathers:
================
	- Shows your account name
	- Character names (for later use, see all the info about your own characters online!)
	- Gathers:
	  - Books (Names + text)
	  - Quests
	  - Loot
	   - Quest items, regular loot, provisioning, harvesting
	  - Skyshards
	  - Chests
	  - NPC's (and conversations)
	  - Vendors (including what they sell)
	  - Wayshrines
	  - Crafting Stations

Commands:
=========

	/esodb info on/off - Shows info of what it gathers
	/esodb debug on/off - debug on or off (not recommended)
	/esodb clear - Clears ALL data!!
	/esodb clear book/vendor/npc/conversation/quest - clears just one type
	/rl - same as /reloadui
	
