# lacyyy's CS:GO script collection

Here are some useful scripts and configs, mainly for Bump Mine practice. I've also added scripts I used for reverse engineering CS:GO's game mechanics, but they are not explained or ready-to-use.

Some files in here are work-in-progress and I will publish updated versions here. Check the [change log](https://github.com/lacyyy/csgo-scripts-and-configs/commits/main) for recent changes to the files.


## How to Download, Install and Use
1. Download all scripts and configs in this collection by clicking the big green "Code" button on this page and then selecting "Download ZIP".
2. Copy the files you want to use from the ZIP folder to the correct installation directory, depending on their file type:
   - Copy files ending in "**.cfg**" to `<YOUR-STEAM-INSTALL-LOCATION>/steamapps/common/Counter-Strike Global Offensive/csgo/cfg/`
   - Copy files ending in "**.nut**" to `<YOUR-STEAM-INSTALL-LOCATION>/steamapps/common/Counter-Strike Global Offensive/csgo/scripts/vscripts/`

   - **Note:** On Windows, Steam is installed to `C:/Program Files (x86)/Steam/` by default.
    
3. Now in CS:GO, load an offline map and:
   - Start using files ending in "**.cfg**" by entering `exec <FILE-NAME>` into the game console. Don't include the "**.cfg**" ending in the command prompt.
   - Start using files ending in "**.nut**" by entering `script_execute <FILE-NAME>` into the game console. Don't include the "**.nut**" ending in the command prompt.


## Overview
- Danger Zone
  - `bm.nut` : Efficient Bump Mine practice for any map
  - `bm_trigger_fix.nut` : Enables Bump Mines consistently detonating, no matter how fast the activating player is moving
  - `bm_trigger_vis.nut` : Visualizes the area a Bump Mine can be triggered in by a player (only shown for hosting player) and roughly calculates Bump Mine activation odds
  - `dz_got_talent_e4.nut` : Practice script on dz_county for [Danger Zone's Got Talent Episode 4](https://youtu.be/wBbIr-EE1Gw)
  - `dz_got_talent_e5.nut` : Practice script on dz_vineyard for [Danger Zone's Got Talent Episode 5](https://youtube.com/playlist?list=PLyCGb0pwEr_SHF2ef6XJBpvQUfpY_oaXe)
  - `dz_got_talent_e5_with_chickens.nut` : Same as before, but adds functionality to reset chickens
  - `backpack_bump_practice.cfg` : *(Old and not easy to use)* Practice script for tricks using the [Backpack Bump Exploit](https://youtu.be/8Lc2LpoFi-8)
- Reverse Engineering
  - `dzsim_bm_trigger_area_scan.nut` and `dzsim_bm_trigger_area_display.nut` : Used to scan and visualize the area in which a player can activate a Bump Mine. [Demonstration video.](https://youtu.be/EF9KEgi35aE) *(Undocumented and not ready-to-use)*


## Tutorials for Bump Mine beginners
I recommend watching [this](https://youtu.be/IPWxlnEsLkQ) and [this](https://youtu.be/YblZkx7mXFM) video to learn the basics of using Bump Mines!
