<#
Builds kellyiq-slate.xlsx from kellyiq-slate.pq with Excel for Windows (COM). Maintainers only:
users download the finished workbook.

    .\build-workbook.ps1                       # writes kellyiq-slate.xlsx next to this script
    .\build-workbook.ps1 -TestApi http://127.0.0.1:8765 -TestKeyFile C:\tmp\key.txt

Release builds take no test switches: nothing is refreshed, so the Stakes sheet stays empty until
the user's first refresh. With -TestApi -TestKeyFile -KeepTestQuery -OutFile <elsewhere>, the query
points at a stand-in API and is refreshed, for testing only.
#>
param(
    [string]$OutFile = (Join-Path $PSScriptRoot "kellyiq-slate.xlsx"),
    [string]$TestApi = "",
    [string]$TestKeyFile = "",
    [switch]$KeepTestQuery   # for scenario tests: leave the stand-in API and key path in place
)
$ErrorActionPreference = "Stop"
$query = Get-Content -Raw (Join-Path $PSScriptRoot "kellyiq-slate.pq")
$releaseFile = Join-Path $PSScriptRoot "kellyiq-slate.xlsx"
if ($TestKeyFile -and -not $TestApi) { throw "-TestKeyFile is for test builds only: pass -TestApi too." }
if ($TestApi -and ([IO.Path]::GetFullPath($OutFile) -eq [IO.Path]::GetFullPath($releaseFile))) {
    throw "Test builds must not overwrite the release workbook: pass -OutFile somewhere else."
}
$keyPlaceholder = "C:\Users\YOUR-NAME\kellyiq-key.txt"

function Set-Row($sheet, [int]$row, [object[]]$values) {
    for ($c = 0; $c -lt $values.Count; $c++) {
        $cell = $sheet.Range("A1").Offset($row - 1, $c)
        $v = $values[$c]
        if ($null -eq $v) { continue }
        if ($v -is [string]) { $cell.Value2 = [string]$v } else { $cell.Value2 = [double]$v }
    }
}

function Add-List($range, [string]$items, [int]$alert = 1) {
    $range.Validation.Delete()
    [void]$range.Validation.Add(3, $alert, 1, $items)   # xlValidateList; 1 = stop, 2 = warning; xlBetween
    $range.Validation.IgnoreBlank = $true
}

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
try {
    $wb = $xl.Workbooks.Add()
    while ($wb.Worksheets.Count -lt 4) { [void]$wb.Worksheets.Add([Type]::Missing, $wb.Worksheets.Item($wb.Worksheets.Count)) }
    $start = $wb.Worksheets.Item(1); $start.Name = "Start here"
    $slate = $wb.Worksheets.Item(2); $slate.Name = "Slate"
    $stakes = $wb.Worksheets.Item(3); $stakes.Name = "Stakes"
    $settings = $wb.Worksheets.Item(4); $settings.Name = "Settings"

    # ---- Start here ----------------------------------------------------------------------
    $lines = @(
        "KellyIQ: size your slate in Excel",
        "Enter your bankroll and your bets on the Slate sheet, then Data > Refresh All. KellyIQ returns a stake for every bet on the Stakes sheet, sized across the whole slate.",
        "",
        "One-time setup",
        "1. Create an API key in the KellyIQ app: Settings > API (every plan, Free included). https://app.kellyiq.com/settings",
        "2. Save the key in a plain text file in your own user folder, for example C:\Users\YOUR-NAME\kellyiq-key.txt. Keep it out of shared or synced folders.",
        "3. On the Settings sheet, enter that file's full path.",
        "4. If Excel shows a yellow bar, click Enable Content. The first time, Excel may ask how to connect to api.kellyiq.com: choose Anonymous and Connect (your key is sent from the file). If it ever asks about any other address, click Cancel.",
        "",
        "Each time",
        "Fill in the Slate sheet: one row per bet, with both sides' prices. Then Data > Refresh All. Each refresh uses one optimize from your daily allowance. Free sizes up to 3 bets per slate, Bettor 12, Sharp and Pro 50.",
        "",
        "Your key is never stored in this workbook, so sharing your copy doesn't share your key. Never paste the key into a cell.",
        "Only use a workbook downloaded from the KellyIQ examples repository (github.com/kellyiq/kellyiq-examples). A workbook from someone else can contain a changed query that sends your key elsewhere.",
        "If refreshing says 'The credentials provided for the Web source are invalid', the key in your file is wrong or was regenerated: create a new one in the app and save it in the file.",
        "Works in Excel for Windows (Microsoft 365, or Excel 2021 or later). Excel for Mac and Excel for the web are not supported.",
        "",
        "KellyIQ sizes the bets you choose. It does not choose bets or predict outcomes, and its results are calculations, not betting advice. 21+, where legal.",
        "Guide: https://www.kellyiq.com/developers/excel"
    )
    for ($i = 0; $i -lt $lines.Count; $i++) { $start.Range("A1").Offset($i, 0).Value2 = [string]$lines[$i] }
    $start.Range("A1").Font.Size = 16; $start.Range("A1").Font.Bold = $true
    $start.Range("A4").Font.Bold = $true; $start.Range("A10").Font.Bold = $true
    $start.Columns.Item(1).ColumnWidth = 120
    $start.Columns.Item(1).WrapText = $true

    # ---- Slate ---------------------------------------------------------------------------
    Set-Row $slate 1 @("Bankroll", 1000)
    [void]$wb.Names.Add("Bankroll", "=Slate!`$B`$1")
    $slate.Range("B1").NumberFormat = "`$#,##0.00"
    $slate.Range("A1").Font.Bold = $true
    # Totals live here, not beside the Stakes table: a refresh that returns a Problem row changes
    # that table's width and would shift anything next to it. Found by header, so they survive it.
    $slate.Range("D1").Value2 = [string]"Total stake"
    $slate.Range("E1").Formula = '=IFERROR(SUM(INDEX(Stakes!$A:$H,0,MATCH("Stake",Stakes!$1:$1,0))),"")'
    $slate.Range("F1").Value2 = [string]"Share of bankroll"
    $slate.Range("G1").Formula = '=IFERROR(E1/Bankroll,"")'
    $slate.Range("E1").NumberFormat = "`$#,##0.00"
    $slate.Range("G1").NumberFormat = "0.0%"
    $slate.Range("D1").Font.Bold = $true; $slate.Range("F1").Font.Bold = $true
    $slate.Range("A2").Value2 = [string]"Data > Refresh All sizes this slate; the result is on the Stakes sheet. Each refresh uses one optimize."
    $slate.Range("A2").Font.Italic = $true
    Set-Row $slate 3 @("Sport", "Team", "Opponent", "Bet", "Line", "Odds", "Other side odds", "Your view")
    Set-Row $slate 4 @("baseball_mlb", "Dodgers", "Padres", "Moneyline", $null, -145, 125, "Moderate edge")
    Set-Row $slate 5 @("baseball_mlb", "Cubs", "Cardinals", "Moneyline", $null, 120, -140, "Moderate edge")
    Set-Row $slate 6 @("baseball_mlb", "Mets", "Braves", "Moneyline", $null, 135, -155, "No edge (market price)")
    $table = $slate.ListObjects.Add(1, $slate.Range("A3:H6"), $true, 1)
    $table.Name = "Slate"
    # Sports change with the seasons, so this list only warns: a sport added later can still be typed.
    Add-List $table.ListColumns.Item("Sport").DataBodyRange "baseball_mlb,basketball_nba,basketball_ncaab,americanfootball_nfl,americanfootball_ncaaf,icehockey_nhl" 2
    Add-List $table.ListColumns.Item("Bet").DataBodyRange "Moneyline,Spread,Over,Under"
    Add-List $table.ListColumns.Item("Your view").DataBodyRange "Strong edge,Moderate edge,Small edge,No edge (market price)"
    $notes = @(
        "Odds: American odds for your side, such as -145 or +120. Other side odds: the opposite side of the same market, so the bookmaker's margin can be removed.",
        "Bet: Moneyline, Spread, Over or Under. Line: the spread from your team's side (-1.5 means your team must win by 2 or more), or the total. Leave it empty for moneylines.",
        "Your view: how much more likely you think your side is to win than the fair price says. Strong edge needs the Bettor plan or higher.",
        "Sport: only sports in season can be sized. Add rows by typing under the table. Free sizes up to 3 bets per slate, Bettor 12, Sharp and Pro 50."
    )
    for ($i = 0; $i -lt $notes.Count; $i++) { $slate.Range("J3").Offset($i, 0).Value2 = [string]$notes[$i] }
    $slate.Columns.Item(10).ColumnWidth = 90; $slate.Columns.Item(10).WrapText = $true
    [void]$table.Range.Columns.AutoFit()

    # ---- Settings ------------------------------------------------------------------------
    Set-Row $settings 1 @("Key file", $(if ($TestKeyFile) { $TestKeyFile } else { $keyPlaceholder }))
    [void]$wb.Names.Add("KeyFile", "=Settings!`$B`$1")
    $settings.Range("A1").Font.Bold = $true
    $settings.Range("A3").Value2 = [string]"The full path of a text file that holds only your API key. The key itself never goes in this workbook."
    $settings.Columns.Item(2).ColumnWidth = 60

    # ---- Stakes (the query) --------------------------------------------------------------
    $testQuery = if ($TestApi) { $query.Replace('Api = "https://api.kellyiq.com"', "Api = ""$TestApi""") } else { $query }
    if ($TestApi -and $testQuery -eq $query) { throw "Could not point the query at ${TestApi}: the Api line in kellyiq-slate.pq changed." }
    $q = $wb.Queries.Add("Stakes", $testQuery)
    # The query combines a local file, this workbook and the API; without this Excel refuses
    # ("specify a privacy level for each data source"). Saved in the file.
    $wb.Queries.FastCombine = $true
    $conn = "OLEDB;Provider=Microsoft.Mashup.OleDb.1;Data Source=`$Workbook`$;Location=Stakes;Extended Properties="""""
    $result = $stakes.ListObjects.Add(0, $conn, $true, 1, $stakes.Range("A1"))
    $qt = $result.QueryTable
    $qt.CommandType = 2
    $qt.CommandText = "SELECT * FROM [Stakes]"
    $qt.PreserveFormatting = $true
    $qt.AdjustColumnWidth = $true
    $qt.RefreshStyle = 0   # xlOverwriteCells: rows come and go without shifting the totals beside the table
    $result.Name = "StakesResult"

    if ($TestApi) {
        [void]$qt.Refresh($false)
        if (-not $KeepTestQuery) {
            $q.Formula = $query                            # production query back in
            $settings.Range("B1").Value2 = [string]$keyPlaceholder
        }
    }

    # Whole-column formats, set after any refresh so every row the query writes picks them up.
    $stakes.Range("D2:D1000").NumberFormat = "`$#,##0.00"
    $stakes.Range("E2:F1000").NumberFormat = "0.0%"
    $stakes.Range("G2:G1000").NumberFormat = "0.000"
    $wb.RemovePersonalInformation = $true
    $start.Activate()
    $wb.SaveAs($OutFile, 51)
    "saved $OutFile"
    $wb.Close($false)
} finally {
    $xl.Quit()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
