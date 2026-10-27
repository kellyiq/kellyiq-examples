// KellyIQ slate sizing for Excel (Power Query). This is the query inside kellyiq-slate.xlsx.
// It reads your API key from a text file (never from the workbook), sends the Slate table to
// POST /v1/optimize and returns one row per bet for the Results sheet. Each refresh uses one
// optimize. The last three columns (plan and usage) are hidden on the sheet and feed its summary.
//
// Excel replaces the API's 401 and 403 answers with its own "credentials are invalid" message, so
// everything the API would refuse with a 403 (plan limits) is checked here first, using the free
// GET /v1/me, and nothing that fails a check here is sent to the API.
let
    Api = "https://api.kellyiq.com",
    FirstRow = 4,   // the sheet row of the first bet (bankroll, note and headers sit above it)
    Cell = (name as text) => Excel.CurrentWorkbook(){[Name = name]}[Content]{0}[Column1],
    // One column, so the text runs on across the empty cells to its right.
    Problem = (problem as text, details as text) =>
        #table({"Problem"}, {{problem & (if details = "" then ""
            else (if Text.EndsWith(problem, ".") then " " else ": ") & details)}}),

    KeyPath = Text.Trim(Text.From(Cell("KeyFile") ?? "")),
    KeyRead = try Text.FromBinary(File.Contents(KeyPath), TextEncoding.Utf8),
    Key = if KeyRead[HasError] then null else Text.Trim(Text.Replace(KeyRead[Value], "#(feff)", "")),
    // kiqa_ and 43 more characters. Anything else is never sent, so a path pointed at the wrong
    // file can't leak that file's contents.
    KeyOk = Key <> null and Text.StartsWith(Key, "kiqa_") and Text.Length(Key) = 48
        and not Text.Contains(Key, " ") and not Text.Contains(Key, "#(lf)"),

    Bankroll = Cell("Bankroll"),
    Table0 = Table.AddIndexColumn(Excel.CurrentWorkbook(){[Name = "Slate"]}[Content], "Pos", 0),
    Rows = Table.ToRecords(Table.SelectRows(Table0, each [Team] <> null and Text.Trim(Text.From([Team])) <> "")),
    SheetRow = (k as number) => Rows{k}[Pos] + FirstRow,

    // Sports are entered by name (MLB) or key (baseball_mlb) and matched against GET /v1/sports,
    // which lists the sports that can be sized today, so a new sport needs no new workbook.
    Views = [#"Strong edge" = "STRONG_EDGE", #"Moderate edge" = "MODERATE_EDGE",
             #"Small edge" = "SMALL_EDGE", #"No edge (market price)" = "MARKET"],
    BetTypes = [Moneyline = "MONEYLINE", Spread = "SPREAD", Over = "TOTAL_OVER", Under = "TOTAL_UNDER"],
    BetOf = (r as record) => Text.From(r[Bet] ?? "Moneyline"),
    ViewOf = (r as record) => Text.From(r[#"Your view"] ?? ""),
    BadLabels = List.Select(List.Positions(Rows), (k) =>
        not Record.HasFields(Views, ViewOf(Rows{k})) or not Record.HasFields(BetTypes, BetOf(Rows{k}))),

    Picks = List.Transform(List.Positions(Rows), (k) =>
        let
            r = Rows{k},
            base = [
                id = Text.From(k),
                sport = SportKey(r[Sport]),
                team = r[Team],
                opponent = r[Opponent],
                betType = Record.Field(BetTypes, BetOf(r)),
                odds = r[Odds],
                opponentOdds = r[#"Other side odds"],
                confidence = Record.Field(Views, ViewOf(r))
            ]
        in
            if r[Line] = null then base else base & [line = r[Line]]),

    Call = (path as text, optional body as nullable record) => Web.Contents(Api, [
        RelativePath = path,
        Headers = [
            Authorization = "Bearer " & Key,
            Accept = "application/json",
            #"User-Agent" = "kellyiq-excel/1.0"
        ] & (if body = null then [] else [#"Content-Type" = "application/json"]),
        ManualStatusHandling = {400, 404, 422, 429, 500, 502, 503, 504}
    ] & (if body = null then [] else [Content = Json.FromValue(body)])),
    StatusOf = (response as binary) => Value.Metadata(response)[Response.Status],
    ApiProblem = (response as binary) =>
        let
            status = StatusOf(response),
            err = try Json.Document(response) otherwise [],
            code = Record.FieldOrDefault(err, "error", "HTTP " & Text.From(status)),
            violations = Record.FieldOrDefault(err, "violations", null) ?? {},
            // "picks[1].odds: ..." names the bet by its place in the request; show its sheet row.
            where = (v as text) =>
                let
                    k = try Number.From(Text.BetweenDelimiters(v, "picks[", "]")) otherwise null,
                    rest = Text.TrimStart(Text.AfterDelimiter(v, "]"), {".", ":", " "})
                in
                    if k = null or k >= List.Count(Rows) then v else "Row " & Text.From(SheetRow(k)) & ", " & rest
        in
            Problem(Text.From(status) & " " & code & ": " & Record.FieldOrDefault(err, "message", ""),
                    Text.Combine(List.Transform(violations, where), "; ")),

    MeResponse = Call("v1/me"),
    Me = Json.Document(MeResponse),
    Tier = Me[tier],
    MaxBets = if Tier = "free" then 3 else if Tier = "bettor" then 12 else 50,
    StrongOnFree = Tier = "free" and List.Contains(List.Transform(Picks, each [confidence]), "STRONG_EDGE"),
    Left = Me[limits][optimize][remainingToday],
    ResetsAt = DateTimeZone.RemoveZone(DateTimeZone.ToLocal(DateTimeZone.FromText(Me[limits][optimize][resetsAt]))),
    ResetsText = DateTime.ToText(ResetsAt, "dddd h:mm tt", "en-US"),

    SportsResponse = Call("v1/sports"),
    Sports = Json.Document(SportsResponse)[sports],
    SportOf = (v) => let t = Text.Lower(Text.Trim(Text.From(v ?? ""))) in
        List.First(List.Select(Sports, each Text.Lower([name]) = t or [key] = t), null),
    SportKey = (v) => SportOf(v)[key],
    BadSports = List.Select(List.Positions(Rows), (k) => SportOf(Rows{k}[Sport]) = null),

    Response = Call("v1/optimize", [bankroll = Bankroll, picks = Picks]),
    Body = Json.Document(Response),
    // Optimizes left after this one: GET /v1/me's count, less this run. Power Query passes on only
    // standard response headers, so the answer's X-RateLimit-Remaining can't be read here.
    LeftAfter = List.Max({Left - 1, 0}),
    Stakes = Record.FromList(
        List.Transform(Body[allocation][stakes], each [stake]),
        List.Transform(Body[allocation][stakes], each [id])),
    LineText = (betType as text, line as nullable number) =>
        if line = null then ""
        else " " & (if betType = "SPREAD" and line > 0 then "+" else "") & Number.ToText(line, "0.##", "en-US"),
    Sized = Table.FromRecords(List.Transform(Body[picks], (p) => [
        Team = p[team],
        Bet = Record.FieldOrDefault([MONEYLINE = "Moneyline", SPREAD = "Spread", TOTAL_OVER = "Over", TOTAL_UNDER = "Under"],
                  p[betType], p[betType]) & LineText(p[betType], p[line]),
        Odds = p[odds],
        Stake = Record.FieldOrDefault(Stakes, p[id], 0),
        #"Fair probability" = if p[probability] = null then null else p[probability][market],
        #"Your probability" = if p[probability] = null then null else p[probability][yours],
        #"Expected value per $1" = p[expectedValue],
        Note = Text.Replace(p[reason] ?? "", "_", " "),
        Plan = Text.Proper(Tier),
        #"Optimizes left today" = LeftAfter,
        #"Resets at" = ResetsAt
    ]), type table [Team = text, Bet = text, Odds = number, Stake = number, #"Fair probability" = number,
                    #"Your probability" = number, #"Expected value per $1" = number, Note = text,
                    Plan = text, #"Optimizes left today" = number, #"Resets at" = datetime]),

    Result =
        if KeyPath = "" then Problem("No key file set", "On the Settings sheet, enter the path of the text file that holds your API key.")
        else if Key = null then Problem("Key file not found", KeyPath)
        else if not KeyOk then Problem("That file doesn't hold an API key",
            "The key file should contain only your key: kiqa_ followed by 43 characters. " & KeyPath)
        else if List.IsEmpty(Rows) then Problem("The slate is empty", "Add at least one bet on the Slate sheet.")
        else if not List.IsEmpty(BadLabels) then Problem("Check row " & Text.From(SheetRow(BadLabels{0})),
            "Bet must be Moneyline, Spread, Over or Under, and Your view one of the dropdown choices.")
        else if StatusOf(MeResponse) <> 200 then ApiProblem(MeResponse)
        else if StatusOf(SportsResponse) <> 200 then ApiProblem(SportsResponse)
        else if not List.IsEmpty(BadSports) then Problem("Check row " & Text.From(SheetRow(BadSports{0})),
            Text.From(Rows{BadSports{0}}[Sport] ?? "(empty)") & " can't be sized now. "
            & (if List.IsEmpty(Sports) then "No sport is in season right now."
               else "Sports in season: " & Text.Combine(List.Transform(Sports, each [name]), ", ") & "."))
        else if List.Count(Picks) > MaxBets then Problem("Too many bets for your plan",
            "Your plan sizes up to " & Text.From(MaxBets) & " bets per slate; this slate has " & Text.From(List.Count(Picks)) & ".")
        else if StrongOnFree then Problem("Strong edge needs the Bettor plan", "Your plan is Free: use Moderate edge or lower.")
        else if Left <= 0 then Problem("No optimizes left today", "Your allowance resets " & ResetsText & ".")
        else if StatusOf(Response) <> 200 then ApiProblem(Response)
        else Sized
in
    Result
