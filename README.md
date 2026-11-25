# Peggle for Hailstone

Peggle is a peg-board arcade game for Hailstone. Aim a marble, chain rebounds, and clear the amber targets before you run out of shots. The moving tray gives back any shot it catches.

Play 12 original boards in Standard, Precision, or Practice mode. Green pegs boost the rebound off that peg. Violet pegs double up to three new hits in the same shot, and the cabinet shows how many boosted hits remain. Each board and mode has a local record, and completed runs track your best combo.

## Install and play

1. Use Hailstone 0.7.2-beta or newer. On the login screen, open **Add-ons**, then **Find add-ons**.
2. Paste `fryguy503/hailstone-peggle`, choose **Look**, and review the install card.
3. After entering the world, type `/peggle` to open or close the cabinet. Aim with the mouse and click to launch, or use the arrow keys and Space while the cabinet has focus.

The dotted guide shows the initial flight. Aim at an exposed upper-edge peg to see the arc that reaches it.

Hailstone lists the add-on under its original install ID, `pegworks`. Updates preserve saved records, and `/pegworks` remains a shortcut.

The release is a portable Lua add-on. A server must allow the add-on and grant `ui` and `commands` for the cabinet and its slash command. Score sharing and duel tells use `chat`, and tell listening uses `events`.

## Share a high score

Open **Records** and select a saved score. Choose Group, Guild, Raid, or Say, then select **Link score** to post the previewed message. You can also copy the message and paste it into another chat.

## Play a friend

Open **Friend duels** and choose **Create challenge**. Send the generated code to a friend. They paste it in **Join or compare**, choose **Read code**, and choose **Play challenge**. You can then each play the same board, seed, and mode at your own pace.

Once your run ends, choose **Get result code** and send it back. Importing a result replays the submitted aim angles and checks the final score against your run of that same challenge. Higher score wins.

Both players need 1.0.2 or newer for new challenges. Codes from older releases still open with the original aim rules.

Copy codes from the share field and paste them into any chat. To send from the cabinet, enter your friend's character name and select **Send tell**. To receive codes there, enable **Tells on** for that session. The receiver chooses which code to open. The duel runs locally and scores are for friendly play.

## Build and test

From this repository, with Lua and Python installed and a Hailstone checkout available:

```sh
lua tests/game_test.lua
lua tests/duel_test.lua
lua tests/score_chat_test.lua
python tools/package.py --hailstone ../hailstone-client --version 1.0.2
```

The package command stages the runtime Lua files and license, then runs Hailstone's packager. Upload `dist/hailstone-addon.txt` and the ZIP it names to the same GitHub release. Hailstone picks up a regular published release when players install by repository name.

## Credits and license

The project was inspired by the WoW Peggle add-on. This Hailstone release ships original code, board layouts, and artwork. [WoW add-on archive](https://github.com/ketho-wow/wow_peggle)

This add-on is All Rights Reserved, matching the upstream release's licensing model. Its personal-use permission is in [LICENSE](LICENSE).
