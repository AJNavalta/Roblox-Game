# Become a Billionaire Tycoon

A Roblox progression tycoon. Start with a lemonade stand and work your way up to a billion dollars:

| # | Business | Items | Price range |
|---|----------|-------|-------------|
| 1 | 🍋 Lemonade Stand | Pitcher, Folding Table, Sign, Ice Cooler, Second Stand | Free – $550 |
| 2 | 👕 Clothing Brand | Thrift Rack, Sewing Machine, T-Shirt Printer, Boutique, Designer Line | $1.5K – $60K |
| 3 | 🚗 Car Dealership | Used Car Lot, Repair Garage, Dealership, Sports Showroom, Luxury Imports | $150K – $5M |
| 4 | 📦 Dropshipping Empire | Online Store, Viral Ads, Warehouse, Van Fleet, Fulfillment Center | $12M – $200M |
| 5 | 🟩 WOWVidia GPUs | Garage Chip Lab, Chip Factory, WOWForce GPU Line, AI Supercomputer, Mega HQ | $400M – $3.5B |

*(WOWVidia is a made-up parody company.)*

**How to play:** walk onto a glowing button to buy that item (green = you can afford it, red = not yet). Every item earns money per second, which piles up on your gold **Cash Collector** pad. Step on the collector to bank it. Buy every item in a business to unlock the next one. Your progress saves automatically.

With perfect play it takes roughly 80 minutes to hit $1B.

---

## Getting it running (first time)

You need: **Roblox Studio**, **VS Code** with the **Rojo** extension, and **Git**.

### 1. Get the code onto your computer

In VS Code: press `Ctrl+Shift+P` (`Cmd+Shift+P` on Mac) → **Git: Clone** → paste
`https://github.com/AJNavalta/Roblox-Game` → pick a folder → **Open**.

To try an unmerged branch (like a pull request), click the branch name in the bottom-left corner of VS Code and pick it from the list.

### 2. Start Rojo in VS Code

1. Press `Ctrl+Shift+P` → **Rojo: Open menu**.
2. If it offers to **install the Roblox Studio plugin**, click it (one-time step).
3. Click **default.project.json** to start the Rojo server. You'll see it running on port 34872.

### 3. Connect from Roblox Studio

1. Open Roblox Studio and create a new **Baseplate** place.
2. Go to the **Plugins** tab → click **Rojo** → **Connect**.
3. The scripts appear in Studio:
   * `ServerScriptService > Server` (game logic)
   * `StarterPlayer > StarterPlayerScripts > Client` (the on-screen display)
   * `ReplicatedStorage > Shared` (config both sides use)

While connected, every time you save a file in VS Code it updates in Studio instantly. **Edit code in VS Code, not in Studio**, or Rojo will overwrite your Studio edits.

### 4. Test it

1. Press **Play** (F5) in Studio.
2. You spawn on your own plot. Step on the free **Lemonade Pitcher** button.
3. Wait a few seconds, then step on the gold **Cash Collector** pad. Your cash goes up on the top display and in the player list.
4. To test with several players: **Test** tab → **Clients and Servers** → pick 2 players → **Start**.

### 5. Turn on saving (optional, but needed to test saving)

DataStores only work in a published place:

1. **File → Publish to Roblox** (make a new game).
2. **Home → Game Settings → Security** → turn on **Enable Studio Access to API Services** → Save.
3. While you're in Game Settings, set **Places → Max Players** to **6** (the map has 6 plots).

If saving is off you'll see a red pop-up when you join. The game still works, it just won't remember you.

> Tip: to wipe everyone's progress while testing, change `DataStoreName` in `src/shared/Config.luau` (e.g. `_v1` → `_v2`).

### 6. Save the place file

Your code lives in Git, but the place (baseplate, lighting, game settings) lives in Roblox. Publishing (step 5) keeps it safe. Place files (`.rbxl`) are ignored by Git on purpose.

---

## Changing the game

Almost everything you'll want to tweak is in **`src/shared/Config.luau`**:

* **Prices and income:** change `Cost` and `Income` on any item.
* **Add an item:** copy a line inside a stage's `Items` and give it a new unique `Id`.
* **Add a whole business:** copy a stage block (`{ Id = ..., Name = ..., Color = ..., Items = { ... } }`) and paste it at the end of `Config.Stages`. The plot grows a new row automatically.
* **Don't rename an item's `Id`** once people have played, or they lose that item from their save. Renaming the `Name` is fine.

## How the code is organised

```
default.project.json        tells Rojo where each folder goes in Studio
src/
  shared/                   -> ReplicatedStorage.Shared
    Config.luau             all stages, items, prices, settings
    Format.luau             turns 2500000 into "$2.50M"
  server/                   -> ServerScriptService.Server
    Main.server.luau        starting point: join/leave, income + autosave loops
    Tycoon.luau             game rules: buy, collect, unlock stages
    PlotBuilder.luau        builds each plot out of Parts from code
    PlayerData.luau         DataStore load/save
  client/                   -> StarterPlayerScripts.Client
    Hud.client.luau         cash display, income, progress bar, pop-ups
```

File names matter to Rojo: `.server.luau` becomes a **Script**, `.client.luau` becomes a **LocalScript**, and plain `.luau` becomes a **ModuleScript**.

## Ideas for next steps

* Swap the plain blocks for real models (a lemonade stand, a car lot, a GPU factory) built in Studio.
* Rebirth/prestige: reset progress for a permanent income multiplier.
* Gamepasses like 2x cash, and sound effects when buying or collecting.
