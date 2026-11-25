# Peggle for Hailstone

Peggle is a peg-board arcade game for Hailstone. Aim a marble, chain rebounds, and clear the amber targets before you run out of shots. The catch tray sweeps while you aim, so you can time the launch to earn your shot back.

Play 13 original boards in Standard, Precision, or Practice mode. The **Boards** gallery shows your completion and lets you jump directly to any board. Each board and mode has a local score record, a best clear percentage, and separate markers for a win and a full clear.

## Install and play

1. Use Hailstone 0.7.2-beta or newer. On the login screen, open **Add-ons**, then **Find add-ons**.
2. Paste `fryguy503/hailstone-peggle`, choose **Look**, and review the install card.
3. After entering the world, type `/peggle` to open or close the cabinet. Aim with the mouse and click to launch, or use the arrow keys and Space while the cabinet has focus.

The dotted guide shows the initial flight. Aim at an exposed upper-edge peg to see the arc that reaches it.

Hailstone lists the add-on under its original install ID, `pegworks`. Updates preserve saved records, and `/pegworks` remains a shortcut.

The release is a portable Lua add-on. A server must allow the add-on and grant `ui` and `commands` for the cabinet and its slash command. Score sharing and duel tells use `chat`, and tell listening uses `events`.

## Beat a board and go for 100%

Hit every amber target to beat a board. In solo play, choose **Bank win** to keep the win and score your remaining shots, or keep playing to hit every peg for a **100% clear**. A full clear adds its own score bonus. If you use up the rest of your shots after beating the board, the win still counts.

The first win and first full clear on each board each earn one talent point across all modes, for up to 26 points. Existing winning records count toward the first win. In **Talents**, spend points on 11 ranked upgrades across **Trajectory** and **Fortune**, or reset your ranks to try another build.

Choose **Ricochet** to make green pegs boost the marble's rebound, or **Catchfield** to make them widen the catcher for that shot. Violet pegs double points on up to three newly hit pegs in the shot, with additional hits available through talents. Launcher powers and talent bonuses apply to solo play. Friend challenges use the same fixed rules for both players.

## Share a high score

Open **Records** and select a saved score. Choose Group, Guild, Raid, or Say, then select **Link score** to post the previewed message. You can also copy the message and paste it into another chat.

## Play a friend

Open **Friend duels** and choose **Create challenge**. Send the generated code to a friend. They paste it in **Join or compare**, choose **Read code**, and choose **Play challenge**. You can then each play the same board, seed, and mode at your own pace.

Once your run ends, choose **Get result code** and send it back. Importing a result replays the aim angles and catcher position at each launch, then checks the final score against your run of that challenge. Higher score wins.

Both players need 1.0.3 or newer for new challenges. Codes from older releases still use their original aim and catcher timing.

Copy codes from the share field and paste them into any chat. To send from the cabinet, enter your friend's character name and select **Send tell**. To receive codes there, enable **Tells on** for that session. The receiver chooses which code to open. The duel runs locally and scores are for friendly play.

## Build and test

From this repository, with Lua and Python installed and a Hailstone checkout available:

```sh
lua tests/game_test.lua
lua tests/progress_test.lua
lua tests/duel_test.lua
lua tests/score_chat_test.lua
python tools/package.py --hailstone ../hailstone-client --version 1.1.0
```

The package command stages the runtime Lua files and license, then runs Hailstone's packager. Upload `dist/hailstone-addon.txt` and the ZIP it names to the same GitHub release. Hailstone picks up a regular published release when players install by repository name.

## Credits and license

Thanks to **PopCap Games** for the original World of Warcraft add-on and to **Ketho17 and the Peggle Classic contributors** for maintaining its source. This Hailstone release uses original code, boards, artwork, and powers. [Peggle Classic source](https://github.com/ketho-wow/wow_peggle) · [Peggle Classic project](https://www.curseforge.com/wow/addons/peggle-classic)

The original release advertised 12 Quick Play stages. The maintained 2.4.2 source includes a playable 13th board, which sets the board count for this release. The source review also covered the original talent tiers, win and full-clear scoring, master powers, themed backgrounds, sprites, sound cues, duels, timed Battle play, and loot contests. [Upstream level data](https://github.com/ketho-wow/wow_peggle/blob/2.4.2/Levels.lua#L2-L17) · [Upstream game code](https://github.com/ketho-wow/wow_peggle/blob/2.4.2/Peggle.lua) · [Upstream graphics](https://github.com/ketho-wow/wow_peggle/tree/2.4.2/images) · [Upstream audio](https://github.com/ketho-wow/wow_peggle/tree/2.4.2/sounds)

This add-on is All Rights Reserved, matching the upstream release's licensing model. Its personal-use permission is in [LICENSE](LICENSE).
