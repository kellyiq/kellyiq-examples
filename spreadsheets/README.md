# Excel

[`kellyiq-slate.xlsx`](kellyiq-slate.xlsx): enter your bankroll and your bets, then **Data → Refresh
All**. KellyIQ returns a stake for every bet, sized across the whole slate, with the fair probability,
your probability and the expected value behind each one. No macros.

Excel for Windows only (Microsoft 365, or Excel 2021 or later). Excel for Mac and Excel for the web
can't run it: the workbook reads your key from a file on your computer, and calls the API through
Power Query.

## Your API key stays out of the workbook

One key gives full access to your KellyIQ account, and workbooks get shared. So the key is never in a
cell or in the file: the workbook reads it from a text file you keep in your own user folder.

1. Create an API key in the KellyIQ app under **Settings → API**. Every plan includes it, Free too.
2. Save the key, on its own, in a plain text file such as `C:\Users\YOUR-NAME\kellyiq-key.txt`. Keep it
   out of shared or synced folders (OneDrive, Dropbox, a shared drive).
3. Open the workbook and enter that file's full path on the **Settings** sheet.
4. Click **Enable Content** if Excel shows a yellow bar. The first time, Excel may ask how to connect to
   `api.kellyiq.com`: choose **Anonymous** and **Connect** (the key is sent from your file).

Never paste the key into a cell, and never type it into Excel's credentials dialog. If Excel ever asks
how to connect to any address other than `api.kellyiq.com`, click **Cancel**.

**Only use a workbook downloaded from this repository.** Sharing your copy doesn't share your key, but a
workbook from someone else can contain a changed query that reads your key file and sends it
elsewhere. To check a copy: Data → Queries & Connections → Stakes → Advanced Editor should show
`Api = "https://api.kellyiq.com"`. The workbook only ever sends a file that looks like a KellyIQ key.

## Each time

Fill in the **Slate** sheet, one row per bet, with both sides' prices, then **Data → Refresh All**. The
result is on the **Stakes** sheet, and the total stake and share of bankroll are next to your bankroll.
Each refresh uses one optimize from your daily allowance; the plan check that runs first is free, and
nothing is sent when the workbook can already see a problem. Opening the query in the Power Query
Editor runs it too, so that can use an optimize as well.

A slate holds up to 3 bets on Free, 12 on Bettor, and 50 on Sharp and Pro.

| Column | What to enter |
|---|---|
| Sport | A sport in season (dropdown) |
| Team, Opponent | The team you're betting, and the other team |
| Bet | Moneyline, Spread, Over or Under |
| Line | The spread from your team's side (-1.5 means your team must win by 2 or more), or the total. Empty for moneylines |
| Odds | American odds for your side, such as -145 or +120 |
| Other side odds | The opposite side of the same market, so the bookmaker's margin can be removed |
| Your view | Strong edge (Bettor plan and up), Moderate edge, Small edge, or No edge |

## If something goes wrong

Most problems show as a **Problem** row on the Stakes sheet, with the row and field to fix.

| You see | What it means |
|---|---|
| *The credentials provided for the Web source are invalid* | Excel's wording for a wrong or regenerated key. Create a new key in the app and save it in your key file |
| *Information is needed in order to combine data* | The workbook's privacy setting was changed. Data → Get Data → Query Options → Current Workbook → Privacy: *Ignore the Privacy Levels* |
| Key file not found | The path on the Settings sheet doesn't match where the file is |
| That file doesn't hold an API key | The key file should contain only the key: `kiqa_` and 43 more characters |
| Too many bets for your plan | Remove bets, or upgrade: Free sizes 3 per slate, Bettor 12 |
| No optimizes left today | Your allowance resets at the time shown (UTC) |

## For maintainers

[`kellyiq-slate.pq`](kellyiq-slate.pq) is the query inside the workbook, and
[`build-workbook.ps1`](build-workbook.ps1) rebuilds the workbook from it with Excel for Windows.

KellyIQ sizes the bets you choose. It does not choose bets or predict outcomes, and its results are
calculations, not betting advice. 21+, where legal.
