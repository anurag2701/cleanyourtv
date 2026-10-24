# A plain-language prompt for non-technical people

This is a version of [`PROMPT.md`](../PROMPT.md) for someone who is not technical and uses a desktop AI app
rather than a terminal. It asks the assistant to run every command itself, to ask one question at a time with
numbered answers, to explain every change and how to undo it, and to wait for a yes. It was used to clean a
Xiaomi Mi Box S (see [`docs/devices/xiaomi-mi-box-s.md`](devices/xiaomi-mi-box-s.md), third unit).

To use it, paste everything below the line into your assistant. The release and commit are pinned on purpose:
change them only if you want a different version. Where this prompt and `PROMPT.md` differ (no model or IP
question, no terminal, no home screen written from scratch), this one wins.

---

Help me clean up my TV so it runs faster, shows as few ads as it allows, and gets a clean, simple home screen. I'm not technical, so guide me step by step. Use the open-source project Clean Your TV, version 2.6.0 only (commit 0bb7f7edbf53349c7975a29495515453ed850526): https://github.com/Gathin23/cleanyourtv/tree/0bb7f7edbf53349c7975a29495515453ed850526

Don't assume anything about my TV. Find out what system it really runs, not just the brand:
- Android TV, Google TV, Android projectors and boxes: the clean-up, plus the new home screen if the TV allows it.
- Amazon Fire TV: the clean-up only. Fire TV keeps Amazon's home screen.
- Samsung (Tizen), LG (webOS), Roku, Apple TV or anything else that isn't Android: tell me plainly this can't be done, show me the TV's own privacy and ad settings instead, and stop.

# 1. HOW TO TALK TO ME
- Use simple, everyday words and short sentences. If you need a technical word, explain it in a few words.
- I'm using a desktop app, not a terminal. Run every command yourself and never ask me to type commands.
- Ask one question at a time. Give me numbered choices I can answer with a number, and say which one you recommend.
- Before every change, tell me what you want to change, why, what I gain, what I might lose, and how to undo it. Then wait for my yes. You can group similar changes into one question, but list every item in the group.
- After each step, tell me in one or two lines what happened and what comes next.
- If something goes wrong, stop, tell me plainly, and put it back the way it was. If you can't reach the TV to undo it, say so.
- Never ask for my passwords or PINs, and never type them; I'll enter PINs on the TV. For a pairing code, open a small input box on this computer so I can type it in, and pass it straight to adb.

# 2. FIRST QUESTION
Tell me this takes about 30 to 60 minutes, the TV must stay on, and almost every change can be undone (you'll warn me before any that can't). Then ask which brand my TV or streaming box is. Don't ask for the model or IP address: you'll find those yourself. I'll answer the other questions once you know my TV (step 4).

# 3. FIND AND CONNECT TO THE TV
- Check that this app can run commands and reach my home network. If something is blocked, tell me which permission to allow (on a Mac, also System Settings → Privacy & Security → Local Network).
- Check whether this computer is a Mac, Windows or Linux, and use commands that work there (on Windows, the repo's PowerShell scripts). Install what's missing: adb (Android platform-tools), git, Python 3, and the Java and Android SDK the repo's README lists for building. Ask me first if anything needs my password.
- Find the TV on my Wi-Fi yourself. Look for its network announcements with `adb mdns services` or this computer's own tools (`dns-sd` on a Mac, `avahi-browse` on Linux): `_googlecast._tcp` (its details include `md=` for the model and `fn=` for the TV's name), `_androidtvremote2._tcp` and `_adb-tls-connect._tcp`. Fire TV answers SSDP/DIAL searches instead. If nothing shows up, check the ARP table, then scan only my local network for ports 5555 (ADB) and 8008/8009 (casting). Ask me to confirm the name and model you found. From then on, send every command to that TV only; its address can change after a restart.
- Ask me if anything is plugged into the TV's USB port. Some TVs cut power to that port while USB debugging is on, which would also take a USB network adapter offline.
- Using the brand and model, give me the exact steps to turn on Developer options and USB debugging. Look them up if you're not sure. For example:
  - Newer Google TV: Settings → System → About → press OK on "Android TV OS build" 7 times, then Settings → System → Developer options → USB debugging.
  - Older Android TV: Settings → Device Preferences → About → press OK on "Build" 7 times, then Device Preferences → Developer options → USB debugging.
  - Fire TV: Settings → My Fire TV → About → press OK on the device name 7 times, then My Fire TV → Developer options → ADB debugging.
  - Some TVs call the switch "ADB debugging", and some Google TVs ask for my PIN first.
- Connect with `adb connect <ip>:5555`. Tell me to look at the TV, tick "Always allow from this computer" and press OK when "Allow USB debugging?" appears.
- If port 5555 is closed (common on newer Google TV), use Wireless debugging: ask me to open Developer options → Wireless debugging → Pair device with pairing code. `adb mdns services` lists the pairing port and the connection port, which differ. Run `adb pair` with the code I type into your box, then `adb connect`. The repo's tools need port 5555, so ask before running `adb tcpip 5555` (the TV may ask me to allow the computer again). Wireless debugging switches off when Wi-Fi drops or the TV restarts, and it needs Wi-Fi rather than a cable.

# 4. LEARN THE TV, BACK IT UP, AND ASK ME
- Read the brand, model, Android version and SDK level, RAM and chip. Identify the exact device from `ro.product.device`, `ro.product.model` and the board, not only the About screen.
- Find out which home screen it runs: Google TV (`com.google.android.apps.tv.launcherx`), older Android TV (`com.google.android.tvlauncher`), Fire TV (`com.amazon.tv.launcher`), or the maker's own. Check with `cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME`.
- Clone the repo (`git clone https://github.com/Gathin23/cleanyourtv`) and check out exactly commit 0bb7f7edbf53349c7975a29495515453ed850526 (version 2.6.0) with `git checkout 0bb7f7edbf53349c7975a29495515453ed850526`. Check that `git rev-parse HEAD` prints that same commit before you run anything from the repo. Never use newer code, never `git pull` or switch to another branch or tag, and never download its scripts or the launcher from anywhere else. Read README.md, docs/TROUBLESHOOTING.md and the notes for my device, or the closest one, in `examples/` and `docs/devices/`. They record real problems and fixes. A nearby model's list is a clue, not a list to copy. Where the repo's PROMPT.md differs from this prompt (asking for my model or IP, using a terminal, writing a home screen from scratch), follow this prompt.
- Use the repo's tools where they fit: they work on Windows too, check for known traps, and record the TV's state for undo. `tools/disable` and `tools/restore` turn a list of packages off and on, `tools/tv.py --screenshot` takes screenshots, and `tools/check.py` shows what a system update turned back on.
- Make a folder for this job with `backup/`, `screenshots/`, `log.md` (a table: When | Change | Why | Undo) and an undo file with the exact command that reverses each change. To undo a setting, put back the saved value, not a default.
- Back up every package list (all, system, installed by me, disabled, with paths), all settings (global, secure, system), `getprop`, screen size and density, the current home app and the current screensaver.
- Measure "before": free memory (MemAvailable in /proc/meminfo), swap in use, the number of processes and app processes, the biggest memory users (`dumpsys meminfo`), what runs all day (`dumpsys procstats --hours 24`) and how long the TV has been on.
- Take a screenshot of the home screen (the repo's tool, or `adb shell screencap -p /sdcard/s.png` then `adb pull`). A black screenshot of a playing video is normal.
- Now ask me, one at a time, only the questions that fit my TV:
  1. Which apps matter most to me? They'll go at the front of the new home screen, in my order (up to four).
  2. Which of these do I use? Casting from my phone; voice search with the remote's mic; cable, an antenna or a set-top box through the TV (Live TV or HDMI); accessibility features like a screen reader.
  3. Do I want automatic app updates?
  4. Do I want ad-blocking for the whole TV (a setting called Private DNS, Android 9 or newer)?
  5. Do I want a wallpaper on the new home screen: none, one picture, or several that change on a timer? If yes, pictures of what?

# 5. FIND WHAT CAN GO, AND ASK ME
- Go through every installed package and every app that runs or starts by itself. For each one that looks unnecessary, find out what it really does with `dumpsys package`, the repo's notes and a web search. Never open a package named factory, fac, AT or production; on some TVs that switches on a factory mode. Never factory reset, root or flash the TV, or try codes for hidden factory menus.
- Sort what you find into plain groups, for example: ads and sponsored content; tracking; recommendations; screensaver ads; preinstalled apps I don't use; features I said I don't use; apps that start by themselves.
- For each group, show me a short table: the name in plain words, what it does, what I'd lose, and your advice. Let me approve the group, or pick items out of it.
- Respect what I use. If I cast, keep everything casting needs. If I use voice search, keep the assistant (newer Google TVs may use Gemini instead). If I watch TV through an antenna or HDMI, keep the TV inputs and the Live TV app. Keep the accessibility tools I use.
- Never turn off what the TV needs to work, even if I ask: start-up, Settings and the way back into Developer options, System UI, the TV's app store and its services (Google's or Amazon's), WebView, the keyboard, the app installer and permission controller, Wi-Fi, Bluetooth and network services, the remote and pairing, HDMI, CEC, TV inputs and tuners, picture and sound, a projector's focus, keystone and fan, and anything named framework, overlay or provision. Judge what a package does, not only its name. The TV maker's own setup and configuration packages can hold the Wi-Fi, the HDMI switching or even the Developer options page, so check the repo's notes first. If you're not sure, keep it and say so.
- Some packages ship already turned off, and some refuse to change. Skip those.
- When the TV has its own built-in option, offer it first and explain the trade-off. On Google TV, Apps only mode (Settings → Accounts & Sign In → my profile) removes personal recommendations without ADB, but it also turns off the Assistant, Search and the watchlist, and some sponsored content can stay. Older Android TV homes can switch off video and audio previews. Fire TV has Settings → Preferences → Privacy Settings and Featured Content. Don't suggest Basic TV mode: it needs a factory reset.

# 6. MAKE THE CHANGES SAFELY
- Turn pre-installed apps off with `pm disable-user --user 0 <package>`, one per command, or with the repo's `tools/disable`. Confirm with `pm list packages -d`. If the TV refuses, check the repo's notes (some older TVs need `pm hide`). Never remove a system app completely.
- If something turns itself back on after a restart, tell me. Only for an ad or tracking app, offer `pm uninstall --user 0` (undo: `cmd package install-existing <package>`).
- Leave apps I installed myself, unless I ask to remove one; then warn me its data and sign-in go with it.
- Work in small batches. After each batch, check that the home screen opens and the internet works, then ask me to press a few buttons on the real remote and play something in one of my important apps. If anything breaks, undo that batch at once and tell me.
- Write each change and its undo into log.md and the undo file before you run it. Keep the approved packages in a list in the repo's debloat format.
- For apps I keep that run all day for no reason, offer `cmd appops set <package> RUN_ANY_IN_BACKGROUND ignore`; save the current value first, to undo. Never for a VPN or anything that must run in the background.
- Before turning off a screensaver, switch to another one and check it works.
- If I don't want automatic app updates, turn them off in the TV's app store settings by moving through its menu with key presses. Read the screen with `uiautomator dump`. Leave system updates on.
- If I want ad-blocking, save the current `private_dns_mode` and `private_dns_specifier`, then run `settings put global private_dns_specifier dns.adguard-dns.com` and `settings put global private_dns_mode hostname`. Tell me it won't block YouTube ads. Check that websites load and an app plays; if not, put the saved values back.

# 7. INSTALL THE NEW HOME SCREEN
Skip this on Fire TV and on any TV the repo's notes say can't hand over Home.
- First check that my TV can take it: its SDK level against `minSdk` in `launcher/app/build.gradle`, and whether it accepts a home screen installed from a computer. If it can't, tell me plainly and finish with the clean-up only. Don't try to work around it.
- Put my most important apps first, in my order (`launcher/app/src/main/res/values/config.xml`). If the TV has its own Live TV app, set `live_tv_package` to it.
- Build and install it with `launcher/build-and-install` (`.sh`, or `.ps1` on Windows). Read the script first, so my yes covers everything it changes. If `adb install` hangs on newer Android, it's waiting for a confirmation on the TV: push the APK and run `pm install -r` on the TV instead.
- Taking over the Home button works differently on different TVs. Read the notes for my TV first: some must keep the stock home or Google's setup wizard on, and some can't hand over Home at all. Then:
  - Before turning off Google's setup wizard (`com.google.android.tungsten.setupwraith`), check who owns the saved Wi-Fi: `dumpsys wifi | grep -o 'cname=[^ ]*'`. If it's the setup wizard, ask me to forget and re-join my Wi-Fi in Settings first, or the TV drops off the network.
  - On Google TV, `cmd package set-home-activity` often says Success and changes nothing. The new home only takes over once the stock home and the setup wizard are both turned off.
  - On some Google TV devices (Google's own Chromecast with Google TV and Google TV Streamer, at least), turning off the setup wizard also breaks casting from phones after a restart. See "Casting fails with Untrusted device" in docs/TROUBLESHOOTING.md. If I cast and this could affect my TV, explain the choice to me before you do it.
  - Order: install the new home and open it first, then turn off the setup wizard, then the stock home, then set the new home as default. Confirm with `dumpsys window | grep mCurrentFocus`, then ask me to press Home on the remote.
  - If the TV shows a black screen, keeps restarting or shows a recovery screen, turn the stock home back on at once (`pm enable --user 0 <stock home package>`), don't restart the TV, and tell me what happened.
  - Keep the undo for this as one block at the very end of the undo file, in reverse order.
- Ask me to press the remote's Home, Back, Input, Settings, app buttons and mic, and to hold volume down, and tell you what each one does. Fix buttons that stopped working with the launcher's key settings or the repo's notes.
- If I want a wallpaper, use the launcher's theme files (themes/README.md). Find free-to-use photos (Unsplash, for example), not random Google Images results. Show them to me with their sizes and sources, and wait for my yes before downloading. Keep them light so they don't stutter: for example 1280×720 JPEG, with the darkening built into the picture and `wallpaper_dim` set to 0.

# 8. CHECK EVERYTHING AND REPORT
- Once the home screen works, restart the TV and reconnect to it. Check that everything you turned off stayed off, the right home screen is the home, and the settings held. Take a screenshot.
- Ask me to try what I use: play something in my important apps, use the remote, turn the TV off and on with it, and try casting, voice search, TV inputs or accessibility if I use them. If I cast, first check that the TV still shows up on the network and the cast receiver isn't logging "No private key" (`logcat`); then ask me to cast from my phone.
- Two minutes after the restart, measure again. Show me before and after in a small table: free memory, memory in use, swap, number of processes, and the home screen's memory. Say if the "before" numbers were taken after a long time switched on. More free memory doesn't prove the TV feels faster, so ask me how it feels.
- Tell me that a system update can turn things back on. If it does, I can open this app in the same folder and ask you to check the TV against the saved list (`tools/check.py`); ask me before fixing anything.
- Give me a short, plain summary: what changed and why, what I gained, what still runs and why, what I should try on the TV myself, and how to undo everything (open this app in the same folder and ask you; I may need to turn debugging back on first).
- Finally, offer to turn debugging off and remove this computer's permission (Developer options → Revoke USB debugging authorizations). While it's on, a computer I allowed can control the TV, and on some cheap boxes anyone on my Wi-Fi can. Then check that the debugging ports no longer answer while the TV is on.
