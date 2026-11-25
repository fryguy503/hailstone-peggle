# Pegworks

Pegworks is a peg-board arcade game for Hailstone. Aim a marble, chain rebounds, and clear the amber targets before you run out of shots. The moving tray gives back any shot it catches.

Play six original boards in Standard, Precision, or Practice mode. Green pegs boost a rebound. Violet pegs double the points on your next three hits during that shot. Each board and mode has a local record, and completed runs track your best combo.

## Install and play

1. Use Hailstone 0.7.2-beta or newer. On the login screen, open **Add-ons**, then **Find add-ons**.
2. Paste `fryguy503/hailstone-peggle`, choose **Look**, and review the install card.
3. After entering the world, type `/pegworks` to open or close the cabinet. Aim with the mouse and click to launch, or use the arrow keys and Space while the cabinet has focus.

The release is a portable Lua add-on. A server must allow the add-on and grant `ui` and `commands` for the cabinet and its slash command. The optional tell controls use `chat` and `events`.

## Play a friend

Open **Friend duels** and choose **Create challenge**. Send the generated code to a friend. They paste it in **Join or compare**, choose **Read code**, and choose **Play challenge**. You can then each play the same board, seed, and mode at your own pace.

Once your run ends, choose **Get result code** and send it back. Importing a result replays the submitted aim angles and checks the final score against your run of that same challenge. Higher score wins.

Copy codes from the share field and paste them into any chat. To send from the cabinet, enter your friend's character name and select **Send tell**. To receive codes there, enable **Tells on** for that session. The receiver chooses which code to open. The duel runs locally and scores are for friendly play.

## Build and test

From this repository, with Lua and Python installed and a Hailstone checkout available:

```sh
lua tests/game_test.lua
lua tests/duel_test.lua
python tools/package.py --hailstone ../hailstone-client --version 1.0.0
```

The package command stages the runtime Lua files and license, then runs Hailstone's packager. Upload `dist/hailstone-addon.txt` and the ZIP it names to the same GitHub release. Hailstone picks up a regular published release when players install by repository name.

## Credits and license

The project was inspired by the WoW Peggle add-on. Pegworks ships original code, board layouts, naming, and artwork. [WoW add-on archive](https://github.com/ketho-wow/wow_peggle)

Pegworks is All Rights Reserved, matching the upstream release's licensing model. Its personal-use permission is in [LICENSE](LICENSE).
