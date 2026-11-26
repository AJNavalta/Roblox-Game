# Become a Billionaire Tycoon

A Roblox progression tycoon set in **Billionaire City**. Claim a home, sell lemonade at the end of your driveway, and work your way up to a billion dollars:

| # | Business | Unlocks when you own | Price range |
|---|----------|----------------------|-------------|
| 1 | 🍋 Lemonade Stand (11 items) | open from the start | Free – $2K |
| 2 | 👕 Clothing Brand | 6 Lemonade items | $2.5K – $110K |
| 3 | 🚗 Car Dealership | 4 Clothing items | $150K – $5M |
| 4 | 📦 Dropshipping Empire | 4 Car items | $12M – $200M |
| 5 | 🟩 WOWVidia GPUs | 4 Dropshipping items | $400M – $3.5B |

*(WOWVidia is a made-up parody company.)*

**How to play:**

1. You spawn in the plaza in the middle of the city. Walk to any lot with a blue **FOR SALE** pad and step on it. That lot is now yours.
   Each lot comes with a house (with a laptop workstation inside), a garage and a driveway. Your lemonade stand is at the end of the driveway, and every Lemonade upgrade (more tanks, a better sign, advertising, a canopy...) improves that one stand. Its small round upgrade pads sit right next to the part they upgrade (the pad positions are `PAD_SPOTS` in `src/server/LemonadeStand.luau`). Customers walk up, grab a cup and leave.
2. Walk onto glowing buttons to buy things. **Green** = you can afford it, **red** = not yet, **grey** = you need to buy something else first (the button tells you what).
3. Every item earns money per second, which piles up on your gold **Cash Collector** pad. Step on it to bank the money.
4. It's not a straight line. You choose your path:
   * Several items are open at once, and some need others first (like a skill tree).
   * Some items can be **upgraded** several times. Their building grows taller each level.
   * **PICK ONE** buttons are choices. In the Lemonade Stand you pick *Pink Lemonade* (boosts all lemonade income) **or** a *Slushie Machine* (big flat income), not both.
   * **Boost** items (glowing blocks) multiply the income of their whole business.
   * You don't need to buy everything in a business to open the next one.

5. **Your phone** 📱 sits in the bottom-right corner (click it or press **P**). It slides up with five apps:
   * **🏦 Bank** shows your cash, money waiting at the collector, your investments, profit or loss, and net worth.
   * **📈 Stocks**, **🪙 Crypto** and **🖼️ NFTs** open the big **Billionaire Exchange** window. Invest in 30 made-up companies, parody crypto like **BitBucks**, or NFT collections. Prices move every few seconds, sometimes with big news jumps. Type an amount (like `500` or `2.5k`) and press **BUY**. Press **SELL** or **SELL ALL** any time to cash out. The **My Portfolio** tab shows everything you own and your profit.
   * **🚗 Cars** is the car shop: Bicycle, Moped, Sedan, Pickup, Van, Sports Car, Limo and a Gold Hypercar. Buy one once and keep it forever. Press **SPAWN** and it appears on your driveway (or in front of you). Sit in it and drive with **W A S D**, jump to get out.
6. **💻 Laptop:** walk up to the laptop in your house and use it to open the same apps in a big desktop view. Walk away or press **Log off** to close it.

Your progress saves automatically, including your investments. With smart play it takes roughly 75 minutes to hit $1B.

---

## Getting it running (first time)

You need: **Roblox Studio**, **VS Code** with the **Rojo** extension, and **Git**.

### 1. Get the code onto your computer

In VS Code: press `Ctrl+Shift+P` (`Cmd+Shift+P` on Mac) → **Git: Clone** → paste
`https://github.com/AJNavalta/Roblox-Game` → pick a folder → **Open**.

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

The city is built by code when you press Play, so you won't see it in the editor before that.

### 4. Test it

1. Press **Play** (F5) in Studio.
2. You spawn in the city plaza. Walk to a blue **FOR SALE** pad and step on it to claim that lot.
3. Step on the free **Lemonade Pitcher** button.
4. Wait a few seconds, then step on the gold **Cash Collector** pad. Your cash goes up on the top display and in the player list.
5. To test with several players: **Test** tab → **Clients and Servers** → pick 2 players → **Start**. Each player can claim a different lot.

### 5. Turn on saving (optional, but needed to test saving)

DataStores only work in a published place:

1. **File → Publish to Roblox** (make a new game).
2. **Home → Game Settings → Security** → turn on **Enable Studio Access to API Services** → Save.
3. While you're in Game Settings, set **Places → Max Players** to **6** (the city has 6 lots).

If saving is off you'll see a red pop-up when you join. The game still works, it just won't remember you.

> Tip: to wipe everyone's progress while testing, change `DataStoreName` in `src/shared/Config.luau` (e.g. `_v1` → `_v2`).

### Trying a pull request before you merge it

1. In VS Code, click the branch name in the bottom-left corner and pick the PR's branch. If it isn't listed, run **Git: Fetch** from `Ctrl+Shift+P` first.
2. Rojo picks up the changed files automatically. If the game is running, stop it and press Play again.
3. Happy with it? Click **Merge pull request** on GitHub, then switch VS Code back to `main` and run **Git: Pull**.

### 6. Save the place file

Your code lives in Git, but the place (baseplate, lighting, game settings) lives in Roblox. Publishing (step 5) keeps it safe. Place files (`.rbxl`) are ignored by Git on purpose.

---

## Changing the game

Almost everything you'll want to tweak is in **`src/shared/Config.luau`** (the top of that file explains every field):

* **Prices and income:** change `Cost` and `Income` on any item.
* **Add an item:** copy a line inside a business's `Items` and give it a new unique `Id`. The lot makes room for it automatically.
* **Make something need something else:** add `Requires = { "other_item_id" }`.
* **Make it upgradeable:** add `MaxLevel = 3`.
* **Make a pick-one choice:** give two or more items the same `Choice = "some_name"`.
* **Make a booster:** add `Boost = 1.5` (+50% income for that business).
* **Change when a business opens:** edit its `Unlock = { Stage = "...", ItemsOwned = 4 }`.
* **More lots in the city:** raise `LotColumns` (there are 2 rows, so 3 columns = 6 lots).
* **Stocks, crypto and NFTs** live in **`src/shared/MarketConfig.luau`**. Add a company by copying a line, change a `Base` price, or make something wilder with a bigger `Vol`. Same rule: don't rename an asset's `Id` once people have invested in it.
* **Don't rename an item's `Id`** once people have played, or they lose that item from their save. Renaming the `Name` is fine.

## How the code is organised

```
default.project.json        tells Rojo where each folder goes in Studio
src/
  shared/                   -> ReplicatedStorage.Shared
    Config.luau             all businesses, items, prices, settings
    Progression.luau        rules: what can I buy, what unlocks, income math
    Format.luau             turns 2500000 into "$2.50M"
    MarketConfig.luau       the 30 stocks, crypto coins and NFTs, and how prices move
    VehicleConfig.luau      the cars in the car shop: prices, speeds, sizes
  server/                   -> ServerScriptService.Server
    Main.server.luau        starting point: join/leave, claiming lots, loops
    Tycoon.luau             buying, upgrading, collecting cash
    CityBuilder.luau        roads, plaza, street lights, skyline
    PlotBuilder.luau        the claimable lots and their buttons
    HomeBuilder.luau        your house, garage, driveway and the laptop workstation
    LemonadeStand.luau      the one lemonade stand that grows with every upgrade
    Customers.luau          NPC customers who line up at your lemonade stand
    PlayerData.luau         DataStore load/save
    Market.luau             stock prices, buying and selling (server only)
    Garage.luau             buying cars, spawning and driving them
  client/                   -> StarterPlayerScripts.Client
    Hud.client.luau         cash display, income, progress bar, pop-ups
    Phone.client.luau       the phone, Bank, Market, Cars and the laptop desktop
```

File names matter to Rojo: `.server.luau` becomes a **Script**, `.client.luau` becomes a **LocalScript**, and plain `.luau` becomes a **ModuleScript**.

## Ideas for next steps

* More choices and upgrades in the later businesses, like the Lemonade Stand has.
* Give the later businesses real models and customers of their own, like the Lemonade Stand has.
* Rebirth/prestige: reset progress for a permanent income multiplier.
* Gamepasses like 2x cash, and sound effects when buying or collecting.
