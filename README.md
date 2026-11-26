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

1. When you join, pick one of your **3 save files** (or start a new game in an empty one). The **💾 Saves** button under the cash bar lets you switch any time. Then walk from the plaza to any lot with a blue **FOR SALE** pad and step on it. That lot is now yours.
   Everyone starts out living in a tiny **Garden Shed** (with a desk, a laptop and a camp bed) next to a driveway. Your lemonade stand is at the end of the driveway, and every Lemonade upgrade (more tanks, a better sign, advertising, a canopy...) improves that one stand. Its small round upgrade pads sit right next to the part they upgrade (the pad positions are `PAD_SPOTS` in `src/server/LemonadeStand.luau`). Customers walk up, grab a cup and leave.
2. Walk onto glowing buttons to buy things. **Green** = you can afford it, **red** = not yet, **grey** = you need to buy something else first (the button tells you what).
3. Every item earns money per second. A 💵 money icon floats above your lemonade stand showing how much is waiting. Walk up to the stand (or press **E** there) to collect it.
4. It's not a straight line. You choose your path:
   * Several items are open at once, and some need others first (like a skill tree).
   * Some items can be **upgraded** several times. Their building grows taller each level.
   * **PICK ONE** buttons are choices. In the Lemonade Stand you pick *Pink Lemonade* (boosts all lemonade income) **or** a *Slushie Machine* (big flat income), not both.
   * **Boost** items (glowing blocks) multiply the income of their whole business.
   * You don't need to buy everything in a business to open the next one.

5. **Your phone** 📱 sits in the bottom-right corner (click it or press **P**). It slides up with five apps:
   * **🏦 Bank** shows your cash, money waiting at your stand, your investments, profit or loss, and net worth.
   * **📈 Stocks**, **🪙 Crypto** and **🖼️ NFTs** open the big **Billionaire Exchange** window. Invest in 30 made-up companies, parody crypto like **BitBucks**, or NFT collections. Prices move every few seconds, sometimes with big news jumps. Type an amount (like `500` or `2.5k`) and press **BUY**. Press **SELL** or **SELL ALL** any time to cash out. The **My Portfolio** tab shows everything you own and your profit.
   * **🚗 Cars** is the car shop: Bicycle, Moped, Sedan, Pickup, Van, Sports Car, Limo and a Gold Hypercar. Buy one once and keep it forever. Press **SPAWN** and it appears on your driveway (or in front of you). Sit in it and drive with **W A S D**, jump to get out.
6. **💻 Laptop:** walk up to the laptop in your home and use it to open the same apps in a big desktop view. Walk away or press **Log off** to close it.
7. **🏠 Homes app (laptop only):** a house-shopping app with 3D photos of every home. Buy one and you move in straight away. You keep every home you buy and can move back into any of them for free:

   | Home | Price |
   |------|-------|
   | Garden Shed | Free |
   | Starter Cabin | $2.5K |
   | Cozy Bungalow (1 storey) | $25K |
   | Two-Storey House | $250K |
   | Big Family Home | $1.5M |
   | Modern Villa (with a pool) | $12M |
   | Grand Mansion | $100M |
   | Billionaire Mega Mansion (helipad!) | $750M |

   Homes are for show right now: they don't change your income.

**Customers** wear real Roblox avatars, and some of them look like the players in your server. Real players can visit too: walk up to the front of someone else's lemonade stand and press **E** to buy a cup. You pay a few dollars and get a 20-second lemon speed rush, and the stand's owner gets double what you paid.

Your progress saves automatically (in whichever save file you picked), including your investments. With smart play it takes roughly 75 minutes to hit $1B.

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
4. Wait a few seconds until a 💵 icon appears above the lemonade stand, then walk up to the stand (or press **E**). Your cash goes up in the bar at the top of the screen and in the player list.
5. To test with several players: **Test** tab → **Clients and Servers** → pick 2 players → **Start**. Each player can claim a different lot, and buy lemonade at the other one's stand.

### 5. Turn on saving (optional, but needed to test saving)

DataStores only work in a published place:

1. **File → Publish to Roblox** (make a new game).
2. **Home → Game Settings → Security** → turn on **Enable Studio Access to API Services** → Save.
3. While you're in Game Settings, set **Places → Max Players** to **6** (the city has 6 lots).

If saving is off you'll see a red pop-up when you join. The game still works, it just won't remember you.

> Tip: need money to test with? Type `/money 1m` in chat (works with `500`, `25k`, `2.5b`...) or click the purple **🛠️ +$1.00M / +$1.00B** buttons under the cash bar. This only works for the developer accounts listed at the top of `src/server/DevTools.luau` (Monsky) and in Studio tests. Nobody else can use it.

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
* **Homes** live in **`src/shared/HomeConfig.luau`** (names, prices, the listing text). What each home looks like is in `HOUSE_SPECS` in `src/server/HomeBuilder.luau`.
* **Don't rename an item's `Id`** once people have played, or they lose that item from their save. Renaming the `Name` is fine.

## Better-looking cars (Toolbox models)

The car shop builds simple block cars from code. You can swap any of them for a real car model from the Roblox Toolbox. No coding needed:

1. In Studio, in the **Explorer**, right-click **ServerStorage** → **Insert Object** → **Folder**. Name it exactly `Vehicles`.
2. Open the **Toolbox** (View tab → Toolbox) → **Models**, and search for a *drivable* car, for example `A-Chassis sedan`, `drivable van`, `drivable sports car`, `drivable bike`. Pick ones with lots of 👍 and a **verified** creator badge.
3. Click the model to insert it. Test it first: press Play, sit in it, and drive with W A S D. If it doesn't drive, delete it and try another.
4. Drag the model into **ServerStorage → Vehicles** and rename it to the car's id from the table below.
5. Press Play, buy that car on your phone, and press **SPAWN**. Your model appears on the driveway.

| Shop car | Name the model |
|----------|----------------|
| Bicycle | `bicycle` |
| Moped Scooter | `scooter` |
| Family Sedan | `sedan` |
| Pickup Truck | `pickup` |
| Delivery Van | `van` |
| Sports Car | `sports` |
| Stretch Limo | `limo` |
| Gold Hypercar | `hyper` |

* **Car facing the wrong way?** Select the model, scroll to the bottom of **Properties** → **Attributes** → **+** → name `SpawnRotation`, type **Number**, value `180` (or `90` / `-90`).
* Any car without a model in the folder still uses the built-in block car.
* **Safety:** free models can hide bad scripts. After inserting one, expand it in the Explorer and delete any script that isn't clearly part of the car (look for names like "Backdoor", "Virus", "Spread", "Loader", or scripts that use `require(` with a long number). Stick to well-rated, verified creators.
* Rojo doesn't touch **ServerStorage**, so your models stay put when you sync. They live in the place file, so **publish the place** (File → Publish to Roblox) to keep them.

## Rewards, Robux shop and badges (left side of the screen)

Four buttons sit on the left side:

* **🎡 Spin**: a free prize wheel every hour. Prizes grow with your income and how many upgrades you own.
* **🎁 Daily**: a reward every day (after 20 hours). Claim days in a row for a bigger reward, up to 10x on day 7. Miss two days and the streak restarts.
* **💰 Cash Shop**: buy cash with Robux. The cash you get grows with your income.
* **🏆 Badges**: milestone badges for total cash earned (Getting Started, $1K, $10K, $100K, $500K, $1M ... $1B). A pop-up shows when you unlock one.

All the numbers are in **`src/shared/RewardsConfig.luau`**.

### Turning on the Robux Cash Shop

The shop says "Coming soon" until you create the products on Roblox:

1. Publish the game (File → Publish to Roblox).
2. Go to [create.roblox.com](https://create.roblox.com) → **Creations** → your game → **Monetization** → **Developer Products** → **Create a Developer Product**.
3. Name it (e.g. "Bag of Cash"), set the Robux price, save, and copy the **Product ID**.
4. In `src/shared/RewardsConfig.luau`, find `RewardsConfig.Products` and replace the `0` after `ProductId =` with your ID. Do this for each pack.
5. Test in Studio: buying in Studio is free and doesn't charge real Robux.

Purchases are safe: the cash is saved before Roblox is told the purchase went through, and each purchase is only ever paid out once.

### Turning on real Roblox badges

The 🏆 panel works without this. To also give players real badges on their Roblox profile:

1. Go to create.roblox.com → **Creations** → your game → **Associated Items** → **Badges** → **Create a Badge**.
2. Upload a square picture, give it the same name as in the game (e.g. "Millionaire"), and create it. Roblox lets you make a few badges for free each day; after that they cost Robux (the page shows the current price).
3. Copy the **Badge ID** and paste it in place of the `0` after `BadgeId =` in `RewardsConfig.Milestones`.

Players who already unlocked a milestone get the real badge the next time they join.

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
    HomeConfig.luau         the homes you can buy, from the free shed to the mega mansion
  server/                   -> ServerScriptService.Server
    Main.server.luau        starting point: join/leave, claiming lots, loops
    Tycoon.luau             buying, upgrading, collecting cash
    CityBuilder.luau        roads, plaza, street lights, skyline
    PlotBuilder.luau        the claimable lots and their buttons
    HomeBuilder.luau        what every home looks like, the driveway and the laptop workstation
    Homes.luau              buying homes and moving in (the Homes app's server side)
    LemonadeStand.luau      the one lemonade stand that grows with every upgrade
    Customers.luau          NPC customers who line up at your lemonade stand
    PlayerData.luau         DataStore load/save
    Market.luau             stock prices, buying and selling (server only)
    Garage.luau             buying cars, spawning and driving them
    DevTools.luau           /money testing cheat, developer only
  client/                   -> StarterPlayerScripts.Client
    Hud.client.luau         the slim bar at the top (cash, income, progress) and pop-ups
    Phone.client.luau       the phone, Bank, Market, Cars and the laptop desktop
    HomesApp.luau           the 🏠 Homes app on the laptop
    SaveSlots.client.luau   the "choose your save" screen and the 💾 Saves button
```

File names matter to Rojo: `.server.luau` becomes a **Script**, `.client.luau` becomes a **LocalScript**, and plain `.luau` becomes a **ModuleScript**.

## Ideas for next steps

* More choices and upgrades in the later businesses, like the Lemonade Stand has.
* Give the later businesses real models and customers of their own, like the Lemonade Stand has.
* Rebirth/prestige: reset progress for a permanent income multiplier.
* Gamepasses like 2x cash, and sound effects when buying or collecting.
