# Courseplay Beta with Chopper Support for Farming Simulator 2022

This is an unofficial version of CP that includes chopper support. It will be kept in sync to the offical repo as best as possible. If enough interest is shown further development will continue. Please vote [here](https://github.com/pops64/Courseplay_FS22/discussions/10)
If using this version please post any bugs related to Combine/Chopper Drivers including their unloaders in this fork as there is enough of a departure from official CP that I will do my best to handle them. All other bugs try to reproduce them in the offical version and post in their fork. If not post them here and I will take a look

You can download [here](https://github.com/pops64/Courseplay_FS22/releases/latest) 

## What Works

* Chopper Support
* **Multiplayer support**
* Fieldwork mode:
  * Course generator for complex fields with many option like headlands or beets with combines and so on ..
  * Up to 5 workers with the same tools can work together on a field with the same course (multi tools)
  * Generate courses for vine work
  * Save/load/rename/move courses
  * Load courses for baling, straw or grass collection and so on
  * Combines can automatically unload into nearby trailers (combine self unload)
* Bale collector mode:
  * Wrapping bales on a field without a course
  * Collecting bales on the field without a course and unloading them with [AutoDrive](https://github.com/Stephan-S/FS22_AutoDrive)
* Combine unloader mode:
  * Unload combines on the field
  * Sending the giants helper or [AutoDrive](https://github.com/Stephan-S/FS22_AutoDrive) to unload at an unload station
  * Creating heaps of sugar beets or other fruits on the field
  * Unloading a loader vehicle, like the ``ROPA Maus`` and letting [AutoDrive](https://github.com/Stephan-S/FS22_AutoDrive) or Giants unload the trailer after that
* Silo load mode:
  * Loading from a heap or bunker silo with loader, like the ``ROPA Maus``
  * Using a wheel loader or a front loader to load from a heap or a bunker silo and unload to:
    * Unloading to nearby trailers
    * Unloading to an unloading station, which needs to be selected on the AI menu
* Bunker silo mode:
  * Compacting the silo with or without tools like this one [Silo distributor](https://www.farming-simulator.com/mod.php?lang=de&country=de&mod_id=242708&title=fs2022)
  * Using a shield in a silo with a back wall to push the chaff to the back of silo
* Misc:
  * Creating custom fields by recording the boarder with a vehicle or drawing on the AI Map.
  * Course editor in the buy menu to edit courses or custom fields.
* Mod support with [AutoDrive](https://github.com/Stephan-S/FS22_AutoDrive):
  * Sending the fieldwork driver to refill seeds/fertilizers and so on.
  * Sending the fieldworker/ bale collector to unload collected straw and so on.
  * Sending the fieldwork driver to refuel or repair.
* Bale collector mod support for:
  * [Pallet Autoload Specialization](https://www.farming-simulator.com/mod.php?lang=en&country=gb&mod_id=228819)
  * [Universal Autoload](https://farming-simulator.com/mod.php?lang=en&country=us&mod_id=237080&title=fs2022)

## Usage

Courseplay functions are now documented in the in-game help menu:

![image](https://user-images.githubusercontent.com/2379521/195123670-20773556-48d4-4292-ba06-28443a2f9c69.png)

If you prefer videos, YouTube has many great [tutorials](https://www.youtube.com/results?search_query=courseplay+fs22)

## Turning on Debug Channels

When there's an issue, you can turn on debug logging on the Courseplay vehicle settings page for each vehicle. This will
enable logging of debug information for only this vehicle. **Devs need those logs for troubleshooting and fixing bugs.**

What information is logged when you activated the debug logging for the vehicle depends on the active debug channels. This
are similar to those we had in CP 19, but the way to turn them on/off is different: you can bring up the debug channel menu
by pressing Shift+4, then use Shift+1 and Shift+3 to select a channel, and then Shift+2 to toggle the selected debug channel
(green is on).

Remember, you have to activate debug mode for the vehicle in the vehicle settings page, otherwise nothing is logged, even if
the channel is active.

## Developer version

Please be aware you're using a developer version, which may and will contain errors, bugs, mistakes and unfinished code. Chances are you computer will explode when using it. Twice. If you have no idea what "beta", "alpha", or "developer" means and entails, steer clear. The Courseplay team will not take any responsibility for crop destroyed, savegames deleted or baby pandas killed.

You have been warned.

If you're still ok with this, please remember to post possible issues that you find in the developer version. That's the only way we can find sources of error and fix them.
Be as specific as possible:

* tell us the version number
* only use the vehicles necessary, not 10 other ones at a time
* which vehicles are involved, what is the intended action?
* Post! The! Log! to [Gist](https://gist.github.com/) or [PasteBin](http://pastebin.com/)
* For more details on how to post a proper bug report, visit our [Wiki](https://github.com/Courseplay/Courseplay_FS22/wiki)

___

## Contributors

See [Contributors](/Contributors.md)


