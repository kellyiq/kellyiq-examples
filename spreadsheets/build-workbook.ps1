<#
Builds kellyiq-slate.xlsx from kellyiq-slate.pq with Excel for Windows (COM). Maintainers only:
users download the finished workbook.

    .\build-workbook.ps1                       # writes kellyiq-slate.xlsx next to this script
    .\build-workbook.ps1 -TestApi http://127.0.0.1:8765 -TestKeyFile C:\tmp\key.txt -OutFile C:\tmp\t.xlsx

Nothing is refreshed at build time, so the Results sheet stays empty until the first refresh, the
same as a user's download. With -TestApi -TestKeyFile -OutFile <elsewhere>, the query points at a
stand-in API and the key path is filled in, for testing only.
#>
param(
    [string]$OutFile = (Join-Path $PSScriptRoot "kellyiq-slate.xlsx"),
    [string]$TestApi = "",
    [string]$TestKeyFile = ""
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
    $results = $wb.Worksheets.Item(3); $results.Name = "Results"
    $settings = $wb.Worksheets.Item(4); $settings.Name = "Settings"

    # ---- Start here ----------------------------------------------------------------------
    $lines = @(
        "KellyIQ: size your slate in Excel",
        "Enter your bankroll and your bets on the Slate sheet, then press Ctrl+Alt+F5 (Data > Refresh All). KellyIQ returns a stake for every bet on the Results sheet, sized across the whole slate, with a summary and your remaining optimizes.",
        "",
        "One-time setup",
        "1. Create an API key in the KellyIQ app: Settings > API (every plan, Free included). https://app.kellyiq.com/settings",
        "2. Save the key in a plain text file in your own user folder, for example C:\Users\YOUR-NAME\kellyiq-key.txt. Keep it out of shared or synced folders.",
        "3. On the Settings sheet, enter that file's full path.",
        "4. If Excel shows a yellow bar, click Enable Content. The first time, Excel may ask how to connect to api.kellyiq.com: choose Anonymous and Connect (your key is sent from the file). If it ever asks about any other address, click Cancel.",
        "",
        "Each time",
        "Fill in the Slate sheet: one row per bet, with both sides' prices. Then press Ctrl+Alt+F5 (Data > Refresh All) and open the Results sheet. Each run uses one optimize from your daily allowance. Free sizes up to 3 bets per slate, Bettor 12, Sharp and Pro 50.",
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
    $slate.Range("D1").Formula = '=HYPERLINK("#Results!A1","Go to results")'
    # No macros, so no button: the shortcut is the quickest way to run it.
    $slate.Range("A2").Value2 = [string]"To size this slate: press Ctrl+Alt+F5 (or Data > Refresh All). Each run uses one optimize."
    $slate.Range("A2").Font.Bold = $true
    $slate.Range("A2:H2").Interior.Color = 0xD9F2FF   # light amber (BGR)
    Set-Row $slate 3 @("Sport", "Team", "Opponent", "Bet", "Line", "Odds", "Other side odds", "Your view")
    Set-Row $slate 4 @("MLB", "Dodgers", "Padres", "Moneyline", $null, -145, 125, "Moderate edge")
    Set-Row $slate 5 @("MLB", "Cubs", "Cardinals", "Moneyline", $null, 120, -140, "Moderate edge")
    Set-Row $slate 6 @("MLB", "Mets", "Braves", "Moneyline", $null, 135, -155, "No edge (market price)")
    $table = $slate.ListObjects.Add(1, $slate.Range("A3:H6"), $true, 1)
    $table.Name = "Slate"
    # Sports change with the seasons, so this list only warns: a sport added later can still be typed.
    Add-List $table.ListColumns.Item("Sport").DataBodyRange "MLB,NBA,NCAAB,NFL,NCAAF,NHL" 2
    Add-List $table.ListColumns.Item("Bet").DataBodyRange "Moneyline,Spread,Over,Under"
    Add-List $table.ListColumns.Item("Your view").DataBodyRange "Strong edge,Moderate edge,Small edge,No edge (market price)"
    $notes = @(
        "Odds: American odds for your side, such as -145 or +120. Other side odds: the opposite side of the same market, so the bookmaker's margin can be removed.",
        "Bet: Moneyline, Spread, Over or Under. Line: the spread from your team's side (-1.5 means your team must win by 2 or more), or the total. Leave it empty for moneylines.",
        "Your view: how much more likely you think your side is to win than the fair price says. Strong edge needs the Bettor plan or higher.",
        "Sport: MLB, NBA, NCAAB, NFL, NCAAF or NHL, while in season. Add rows by typing under the table. Free sizes up to 3 bets per slate, Bettor 12, Sharp and Pro 50."
    )
    for ($i = 0; $i -lt $notes.Count; $i++) { $slate.Range("J3").Offset($i, 0).Value2 = [string]$notes[$i] }
    # Not wrapped: wrapping would make the bet rows beside the notes tall. The text runs on into
    # the empty columns to the right.
    [void]$table.Range.Columns.AutoFit()
    # Row 1 sits above the table, so AutoFit on the table misses the bankroll.
    if ($slate.Columns.Item(2).ColumnWidth -lt 12) { $slate.Columns.Item(2).ColumnWidth = 12 }

    # ---- Settings ------------------------------------------------------------------------
    Set-Row $settings 1 @("Key file", $(if ($TestKeyFile) { $TestKeyFile } else { $keyPlaceholder }))
    [void]$wb.Names.Add("KeyFile", "=Settings!`$B`$1")
    $settings.Range("A1").Font.Bold = $true
    $settings.Range("A3").Value2 = [string]"The full path of a text file that holds only your API key. The key itself never goes in this workbook."
    $settings.Columns.Item(2).ColumnWidth = 60
    Set-Row $settings 5 @("Plan")
    Set-Row $settings 6 @("Optimizes left today")
    Set-Row $settings 7 @("Resets")
    $settings.Range("B5").Formula = '=Results!E2'
    $settings.Range("B6").Formula = '=Results!E3'
    $settings.Range("B7").Formula = '=Results!E4'
    $settings.Range("B7").NumberFormat = "dddd h:mm AM/PM"
    $settings.Range("B5:B7").HorizontalAlignment = -4131   # xlLeft
    $settings.Range("A8").Value2 = [string]"Updated each time you size a slate."
    $settings.Range("A8").Font.Italic = $true
    $settings.Columns.Item(1).ColumnWidth = 22

    # ---- Results (the query) -------------------------------------------------------------
    $testQuery = if ($TestApi) { $query.Replace('Api = "https://api.kellyiq.com"', "Api = ""$TestApi""") } else { $query }
    if ($TestApi -and $testQuery -eq $query) { throw "Could not point the query at ${TestApi}: the Api line in kellyiq-slate.pq changed." }
    [void]$wb.Queries.Add("Results", $testQuery)
    # The query combines a local file, this workbook and the API; without this Excel refuses
    # ("specify a privacy level for each data source"). Saved in the file.
    $wb.Queries.FastCombine = $true
    $conn = "OLEDB;Provider=Microsoft.Mashup.OleDb.1;Data Source=`$Workbook`$;Location=Results;Extended Properties="""""
    $tableRow = 8   # the summary sits above the table
    $first = $tableRow + 1
    $result = $results.ListObjects.Add(0, $conn, $true, 1, $results.Range("A$tableRow"))
    $qt = $result.QueryTable
    $qt.CommandType = 2
    $qt.CommandText = "SELECT * FROM [Results]"
    $qt.PreserveFormatting = $true
    $qt.AdjustColumnWidth = $false   # fixed widths below fit both the table and the summary
    $qt.RefreshStyle = 0   # xlOverwriteCells: rows come and go without shifting the summary above
    $result.Name = "Results"
    # Until the first refresh the table shows Excel's "ExternalData_1: Getting Data ..." placeholder.
    $results.Range("A$tableRow").Value2 = [string]"Your stakes appear here after Ctrl+Alt+F5 on the Slate sheet."

    # The summary finds each column by its header, so after a refresh that returns a Problem row
    # instead (a different shape) it shows blanks rather than errors.
    function Col([string]$header) {
        'INDEX($A$' + $first + ':$K$1000,0,MATCH("' + $header + '",$A$' + $tableRow + ':$K$' + $tableRow + ',0))'
    }
    Set-Row $results 1 @("This slate", $null, $null, "Your account")
    $results.Range("A1").Font.Bold = $true; $results.Range("D1").Font.Bold = $true
    $summary = @(
        @("A2", "Bankroll", '=Bankroll', '$#,##0.00'),
        @("A3", "Total stake", ('=IFERROR(SUM(' + (Col 'Stake') + '),"")'), '$#,##0.00'),
        @("A4", "Share of bankroll", '=IFERROR(B3/B2,"")', '0.0%'),
        @("A5", "Expected profit", ('=IFERROR(SUMPRODUCT(' + (Col 'Stake') + ',' + (Col 'Expected value per $1') + '),"")'), '$#,##0.00'),
        @("A6", "Bets with a stake", ('=IFERROR(COUNTIF(' + (Col 'Stake') + ',">0"),"")'), '0'),
        @("D2", "Plan", ('=IFERROR(INDEX(' + (Col 'Plan') + ',1)&"","")'), 'General'),
        @("D3", "Optimizes left today", ('=IFERROR(INDEX(' + (Col 'Optimizes left today') + ',1)+0,"")'), '0'),
        @("D4", "Resets", ('=IFERROR(INDEX(' + (Col 'Resets at') + ',1)+0,"")'), 'dddd h:mm AM/PM')
    )
    foreach ($row in $summary) {
        $label = $results.Range($row[0]); $label.Value2 = [string]$row[1]
        $value = $label.Offset(0, 1); $value.Formula = $row[2]; $value.NumberFormat = $row[3]
        $value.HorizontalAlignment = -4152   # xlRight, the plan name too
    }
    $results.Range("G1").Formula = '=HYPERLINK("#Slate!A1","Back to slate")'
    $widths = 20, 13, 8, 20, 19, 16, 21, 16   # A to H
    for ($c = 0; $c -lt $widths.Count; $c++) { $results.Columns.Item($c + 1).ColumnWidth = $widths[$c] }
    # Plan and usage ride along in the last three columns of every row, for the summary above.
    $results.Range("I:K").EntireColumn.Hidden = $true

    # Number formats as always-on conditional formats: rows a refresh adds to the table come in as
    # General whatever the cells held before, but conditional formats stay on the cells.
    foreach ($f in @(@("D", "D", '$#,##0.00'), @("E", "F", '0.0%'), @("G", "G", '0.000'))) {
        $results.Range("$($f[0])${first}:$($f[1])1000").FormatConditions.Add(2, 0, "=TRUE").NumberFormat = $f[2]
    }
    $wb.RemovePersonalInformation = $true
    $start.Activate()
    $wb.SaveAs($OutFile, 51)
    "saved $OutFile"
    $wb.Close($false)
} finally {
    $xl.Quit()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
