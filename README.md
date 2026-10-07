# Galaxian2

**A native, open-source Galaxy on Fire 2 remake.** Play the main campaign through
its ending, trade ships, take freelance jobs and explore the base-game galaxy.

**You need your own Galaxy on Fire 2 Full HD Mac game files to play, on every platform.**
The game imports it locally on first launch. Game assets and the original
executable are not included in the download. No original executable is run.

![Alioth orbit](screenshots/01-alioth-orbit.png)

## Download and play

Get the **[latest release](https://github.com/TheWWWorm/galaxian2/releases/latest)**.
The whole game is playable: the main campaign and both add-ons, Valkyrie and
Supernova, plus the Supernova Challenge.

Version 1.0.5 reduces flight processing and loading costs, restores keyboard
and controller focus inside Yes/No questions, and fixes departures with several
expansion ships.

| Download | Platform | Launch |
| --- | --- | --- |
| Windows x64 | Windows 10/11, Intel or AMD 64-bit | Extract the ZIP, then open `Galaxian2.exe` |
| Linux x64 | Modern Linux with glibc, Intel or AMD 64-bit | Extract the archive, then run `./Galaxian2` |
| macOS Apple Silicon | M-series Macs | Extract the ZIP and open `Galaxian2.app` |
| Android ARM64 (experimental) | Android 10 or later, 64-bit ARM | Install the APK, then select your Mac `.dmg` or a ZIP containing its `.app` |

Desktop packages include the engine and offline import helpers. Keep each package
intact. Windows and macOS builds are unsigned. Linux is the tested platform;
Windows and macOS exports have not yet been tested on their native systems.
The Android importer has passed a document-picker and dependency smoke check,
but a complete import and gameplay have not been tested on an ARM64 device.
A playable Web package is not available yet.

1. Start Galaxian2 and choose **Choose Mac game…**.
2. Select your **Galaxy on Fire 2 Full HD Mac disk image (.dmg)** or the
   **application folder (.app)** itself. Allow several minutes
   and at least **8 GB of free space** for extraction and preparation.
3. Choose **Start new game**. Follow the opening instructions.

Later launches reuse your local import. Cancelling an import preserves an existing
installation and its saves. This release is tested with the Mac App Store
Full HD bundle. The older Mac Full HD 1.0.6 reader remains available but has not
been retested for this release. Application
folders and disk images use the same content preparation. Existing completed
imports and their saves remain usable.

On Android, transfer your original Mac `.dmg` to the device and select it through
**Choose Mac game…**. You can also select a ZIP containing the original Mac `.app`
folder. Keep ample free space for the selected file, extracted files and prepared
content; the importer reports storage requirements. Importing can take several
minutes. The APK includes its import tools and requires no separate Python or
archive utility installation. Updating the APK preserves existing local imports
and saves; there is no need to import the same game again.

## What's playable

- The main campaign, from the opening encounter and mining tutorials through
  the final Void escape, ending and continued free travel.
- **Valkyrie** and **Supernova** through their endings, with their systems,
  ships, weapons, devices, cinematics, the Kaamo Club, pirate bases, the Loma
  toll and the Most Wanted boards; the **Supernova Challenge** from the menu.
- New Game difficulty (Easy, Normal, Hard, Extreme), medals and the Status
  screen, the in-flight pause window, wingmen, coordinate sellers and diplomats.
- Freelance combat, recovery, delivery, escort, informer and intercept jobs.
- The galaxy overview, local travel, jumpgates and Khador Drive travel into
  normal space and the Void, using owned energy cells.
- Hangar ship exchanges with trade-in credit and retained cargo/equipment;
  base-game hulls, cloaking devices, mounted turrets, boosters, mines and bombs.
- Blueprint material supply, production and collection.
- Station saves, autosaves, loading and retrying from a saved station after death.
- Main menu, display and sound settings, language selection, mouse/controller input and optional
  larger touch controls. Play is landscape only.

Campaign rewards and freelance progress remain in station saves and fresh
Resume. Desktop flight hides touch controls by default; mobile flight uses
the original control artwork and exposes fitted equipment through Actions.

![Portal and freighters](screenshots/02-portal-and-freighters.png)

## Controls and station services

Follow the tutorial prompts for flying, targeting, firing and mining.

| Action | Controls |
| --- | --- |
| Steer | **Mouse** or **arrow keys** |
| Strafe left / right | **A / D** |
| Brake / resume previous throttle | Hold / release **S** |
| Increase / decrease throttle | **] / /** |
| Primary fire / mining action | **Left click** or **Space** |
| Secondary fire / selection | **R / G** |
| Main menu / pause and controls reference | **P** or **Esc** |
| Toggle fullscreen | **F11** |
| Actions, including navigation and fitted devices | **E** |
| Autopilot destinations / cancel guidance | **Q** / controller **Y** |
| Dock at the locked station / mine selected asteroid / stop drilling | **F** |
| Fast Forward when navigation permits | Hold **Tab** / controller **Back** |
| Switch mouse between ship and menus | **M** |
| Hangar at a station | **H** |
| Space Lounge at a station | **L** |
| Save / load at a supported station | **F5 / F9** |
| Confirm / back | **Enter / Esc** |
| Skip a station launch, arrival or cinematic | **Click**, **Enter** or controller **A** |

Mouse steering is enabled by default on desktop. Move the mouse to turn your ship;
the cursor is released in menus, maps and station screens. **Options** lets you
adjust mouse sensitivity, invert pitch or turn mouse steering off.

Use **Map** at the station or **E → Map** in flight to plot an available course. Travel to Gome C or Dis to
reach its system's jumpgate, select the other system and a destination, and
confirm the course. **Enter** accepts the gate question; **Esc** opens its map.

At a station, **Hangar** buys and sells one item per action. **Cargo → Mount**
installs supported equipment; **Ship → Demount** removes it. Check cargo capacity
before departing. Some replacements need confirmation.

**Space Lounge** shows job requirements and destinations. Couriers need cargo
space; passengers need installed cabin berths. Accept a supported job, travel to
its marker and dock. **Close** the delivery result to receive payment. You can
refit supported equipment during a delivery job; occupied passenger berths and
protected mission cargo remain protected.

Recovering floating containers requires an equipped **tractor beam**. The starter
scanner and mining drill do not collect containers.

## Display settings

Open **Options** to choose your display mode, window resolution, aspect ratio and
frame rate. **Fullscreen** uses your display's native resolution, including Retina
and ultrawide displays. Windowed mode offers common resolutions and **Native**,
fitting the window within your desktop when necessary.

**Automatic** aspect ratio fills the window without stretching the scene.
**Native display** matches your monitor's ratio; fixed ratios add bars as needed.
**Unlimited (V-Sync off)** removes the frame cap. You can also choose a fixed FPS
limit or **Display refresh (V-Sync)**. These settings are remembered between launches.

**UI scale** automatically enlarges menus and flight controls on high-resolution
displays. Choose **75%–300%** for a fixed size, or return to **Automatic**. Smaller
windows limit the scale so controls remain reachable. The 3D view keeps its full
resolution.

Windows and Linux use Vulkan by default; Apple Silicon uses Metal. Older GPUs
can fall back to OpenGL. If a graphics driver cannot start the game, try launching
with `--rendering-method gl_compatibility --rendering-driver opengl3`. On Windows,
`--rendering-method mobile --rendering-driver vulkan` explicitly selects Vulkan.

## Saves

Finish a station conversation and close its services before saving. Autosaves
also occur at supported service exits, acknowledged results and departures.
**Resume** returns to your running game, or loads the saved station after a
restart or death. A previous-save backup protects against an interrupted write.

Saving during flight or a conversation is unavailable. Saves belong to their
imported content and gameplay-data version. Original game saves and migration
between incompatible versions are not supported yet. Back up your user-data
folder before updating from a preview.

## Known differences

A few cosmetic details differ from the original where its data could not be
fully recovered, such as the size of some cutscene explosions and the
supernova sky background.

Screenshots show the native engine using locally imported Mac content. They are
promotional images, not game resources distributed with the engine.

![Native flight](screenshots/03-native-flight.png)

## Help and feedback

Report problems in **[GitHub Issues](https://github.com/TheWWWorm/galaxian2/issues)**.
Include your operating system, release version, steps to reproduce and any error
message. Do not upload your DMG, original executable, imported content or saves
to public issues.

## Run from source

Use Godot **4.7**, Python **3.10+**, and 7-Zip (`7zz` or `7z`). Install the importer
dependencies in a Python environment, set `GOF2_IMPORT_PYTHON` to that environment's
Python executable, then run:

```sh
python -m pip install -r tools/requirements-visuals.txt -r tools/requirements-bindings.txt
godot --path game
```

If 7-Zip is not on PATH, set `GOF2_7ZIP` to its executable. Source checks and build
commands are available through `python tools/run_checks.py --help` and
`python tools/package_releases.py --help` (packaging requires Python 3.12+). Original content stays outside the
source tree and release packages. Android build instructions are in
[the importer README](platform/android_importer/README.md).

## License

The engine is licensed under [Apache 2.0](LICENSE.md).
[Third-party notices](THIRD_PARTY_NOTICES.md) cover reused components.
Galaxy on Fire 2 and its original content belong to their respective rights
holders. This is an independent, unofficial project.
