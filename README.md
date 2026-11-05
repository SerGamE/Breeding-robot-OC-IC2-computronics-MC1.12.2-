**Languages:** [English](#) | [Русский](README.ru.md)

# Breeding Robot (OpenComputers + IC2 + Computronics)

**Minecraft:** 1.12.2  
**Mods:** OpenComputers, IndustrialCraft 2 Experimental, Computronics

---

## 📌 Description
An automated system for breeding, selection, and mutation of IC2 crops. 
The robot performs routine work: destroys weeds, replants the best seeds, collects top seeds and new species seeds, and protects the field from aggressive mutations (G24 from IC2 Experimental).

### ✨ Key Features:
- **Breeding:** Automatically breeds a single sprout for full crossbreeding using double crop sticks.
- **Selection:** Destroys weak, excessive, and new species (if `destroy` mode is enabled in `config.lua`), and replants only the best candidates.
- **Mutation:** Preserves new species and collects top seeds that have reached target stats.
- **Emergency Mode:** If the robot's inventory breaks, the server switches to emergency field cleanup mode.
- **Localization:** Supports Russian, English, and Japanese languages (configurable in `config.lua`).
- **Web Interface:** Renders the field, logs, and control buttons directly on the monitor.

---

## 🔧 Hardware Setup

### Server:
- **Server Rack.**
- **Server Tier 3.**
- **CPU Tier 3.**
- **EEPROM (Lua BIOS).**
- **Component Buses** — choose according to your build. For a 5x5 field, you might need 29-32 components (2x Tier 3 buses).
- **Graphics Card Tier 3.**
- **Memory Tier 3/3.5** — 1 stick should be enough.
- **Wireless Network Card Tier 1/2.** Tier 1 is enough for a small field.
- **Internet Card** — for software installation.
- **Hard Drive** with OpenOS installed.
- **Monitor Tier 3.**
- **Keyboard.**

### Robot:
- **Computer Case Tier 3.**
- **CPU with APU Tier 2.**
- **EEPROM (Lua BIOS).**
- **Memory Tier 2/2.5** — 1 stick is enough.
- **Hard Drive Tier 1** with **pre-installed** OpenOS.
- **Monitor Tier 1.**
- **Keyboard.**
- **Wireless Network Card Tier 1/2.**
- **Inventory Upgrade** — 1 is enough, but more is better.
- **Inventory Controller Upgrade.**
- **Hover Upgrade Tier 2.**
- **Card Container Tier 2** — 1 pc. For the Internet Card (for installation).
- **Upgrade Container Tier 2.** For the Navigation Upgrade (can be built-in).
- **Upgrade Container Tier 3.** — optional, used for a Tier 3 battery.
- Remaining points can be spent on **Inventory Upgrades** or **Solar Generator Upgrades.**

---

## 🛠️ Installation

1. Install an **Internet Card** in both the robot and the server.
2. Run the following command in the terminal to start the auto-installer:


    ```
    wget -f "https://raw.githubusercontent.com/SerGamE/Breeding-robot-OC-IC2-computronics-MC1.12.2-/refs/heads/main/installer.lua" /home/installer.lua && installer
    ```


3. The installer will detect if it's running on the robot or the server and download the necessary files.
4. Follow the console instructions (autostart setup, component installation).

---

## ⚙️ Configuration (`config.lua`)

| Parameter | Description |
| :--- | :--- |
| `language` | UI language (`"Ru"`, `"En"`, `"Ja"`). |
| `max_growth` | Growth gene threshold for aggressive weeds (G24). Set to `nil` or `0` for classic IC2. |
| `field_x`, `field_z` | Field dimensions along X and Z axes. |
| `crop_id` | ID of the crop to breed (e.g., `"stickreed"`, `"hops"`, `"wheat"`). |
| `target` | Target genes (`{ g = 21, ga = 31, r = 0 }`). |
| `new_species` | New species handling: `"destroy"` or `"save"` (to chest). |
| `min_dead_parents` | Number of dead parents required to exit MUTATION mode. |

---

## 🖥️ Controls

- **PAUSE button** (or `PAUSE` key) — pauses task assignment. The robot will finish the current task, clean up threats, and park at the charger.
- **SHUTDOWN button** (or `END` key) — safe shutdown. The server waits for the robot to clean the field from dangers (weeds, empty sticks) and then terminates.
- Only players added to the computer's user list (`computer.users()`) can use the buttons.

---

## 🏗️ Build Guide & First Run

1. Build the field, hydrate it with water, and till it with a hoe.
2. Place adapters under the field (directly under the crops or with a block gap).
3. Place a crop stick on the dirt, right-click it with the MFE (MFU). A green hologram should appear. Break the stick and place the MFE into the adapter under that crop. Repeat for all crops.
4. Connect the adapters to the Server Rack with cables, set up the server side, connect the monitor, keyboard, install the software, and configure `config.lua`.
5. Place the charger level with the crop sticks. The robot should be on it facing South (towards the field).
6. Place a Waypoint above the robot, point it down, and name it "CHICHI" (or your custom name). If changed, update `local WAYPOINT_LABEL = "your_name"` in `r.lua`. You can also change port, wake message, and chest coordinates there.
7. Run `r.lua`, put the tools (sticks, vajra/axe, weeding trowel) and press Enter to save the tools list.
8. Place chests relative to the charger:
- Chest 1 (left) — trash.
- Chest 2 (right) — crop sticks.
- Chest 3 (further right) — new species seeds.
- Chest 4 (furthest right) — top seeds.
*The robot must fly directly above the chests and crop sticks.*
9. Ensure the robot is turned on, equipped, and `r.lua` is running.
10. On the server, run `mapping.lua`. The server and robot will create and save the field map (do this **only once**).
11. Run `server.lua`. The field layout will appear: dark green cells are parents, dark blue are crossbreeding spots.
12. Plant **at least one** crop (if more then in a checkerboard pattern). The program will handle the rest.

---

## 📝 License
MIT License. Do whatever you want, but the author is not responsible for blown-up farmlands or eaten creepers.