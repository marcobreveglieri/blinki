/// <summary>
///   LayoutSmoke — Interactive smoke test for Blinki Phase 5: Layout Engine.
///
///   Verifies the success criteria LAYOUT-01..LAYOUT-04:
///   - LAYOUT-01: TTuiHStack + TTuiVStack with Fixed/Fill/Percentage constraints
///   - LAYOUT-02: TTuiGrid(2,2) with Place() and ColSpan
///   - LAYOUT-03: TTuiScrollable with 40 scrollable labels via arrow/PgUp-Dn/Home-End
///   - LAYOUT-04: terminal resize automatically recalculates all TRect values
///
///   Widget tree:
///     LRoot (TTuiVStack)
///       LHeader (TTuiLabel) Fixed(1)
///       LBody (TTuiHStack) Fill(1)
///         LSidebar (TTuiVStack) Fixed(24)
///           LCaption  (TTuiLabel) Fixed(1)
///           LHint1..4 (TTuiLabel) Fill(1) x4
///         LMain (TTuiVStack) Fill(1)
///           LConstraintDemo (TTuiHStack) Fixed(5)
///             LFixed  (TTuiLabel) Fixed(12) — red background
///             LFill1  (TTuiLabel) Fill(1)   — green background
///             LPct    (TTuiLabel) Percentage(25) — blue background
///             LFill2  (TTuiLabel) Fill(2)   — magenta background (double Fill)
///           LGrid (TTuiGrid 2x2) Fixed(8)
///             [0,0] LG00  (TTuiLabel)
///             [0,1] LG01  (TTuiLabel)
///             [1,0] LG10  (TTuiLabel) ColSpan=2
///           LScroll (TTuiScrollable) Fill(1)
///             LScrollContent (TTuiVStack) — 40 TTuiLabel
///       LFooter (TTuiLabel) Fixed(1) — tick + size (updated by OnTimer/OnResize)
/// </summary>
program LayoutSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Style,
  Blinki.Core.Input,
  Blinki.Core.Canvas,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Geometry,
  Blinki.Widgets.Labels,
  Blinki.Layout.Stack,
  Blinki.Layout.Grid,
  Blinki.Layout.Scrollable;

// ---------------------------------------------------------------------------
// Helpers to create the colored labels for the constraint demo
// ---------------------------------------------------------------------------

function MakeColorLabel(const AText: string; AFg, ABg: TTuiColor;
  AParent: TTuiWidget = nil): TTuiLabel;
begin
  Result       := TTuiLabel.Create(AParent);
  Result.Text  := AText;
  Result.Style := TTuiStyle.Create(AFg, ABg, []);
end;

// ---------------------------------------------------------------------------

var
  LApp: TTuiApp;
  LRoot: TTuiVStack;
  LHeader: TTuiLabel;
  LFooter: TTuiLabel;
  LBody: TTuiHStack;

  // Sidebar
  LSidebar: TTuiVStack;
  LSCap: TTuiLabel;

  // Main panel
  LMain: TTuiVStack;
  LConstraintDemo: TTuiHStack;
  LGrid: TTuiGrid;
  LG00, LG01, LG10: TTuiLabel;

  // Scrollable
  LScroll: TTuiScrollable;
  LScrollContent: TTuiVStack;
  LScrollLabel: TTuiLabel;

  LI: Integer;
  LTickN: Integer;
  LTotalMs: Int64;
  LLastSize: TSize;

begin
  ReportMemoryLeaksOnShutdown := True;
  LTickN    := 0;
  LTotalMs  := 0;
  LLastSize := TSize.Create(0, 0);

  LApp  := TTuiApp.Create;
  LRoot := TTuiVStack.Create;
  try
    // ---- Header ----
    LHeader       := TTuiLabel.Create(LRoot);
    LHeader.Text  := ' Blinki Phase 5 — Layout Engine Smoke | Tab: focus | Q/Esc: quit';
    LHeader.Style := TTuiStyle.Create(TTuiColors.Black, TTuiColors.BrightCyan, [taBold]);
    LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- Body (HStack: sidebar + main) ----
    LBody := TTuiHStack.Create(LRoot);
    LBody.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // Sidebar (Fixed 24 col)
    LSidebar := TTuiVStack.Create(LBody);
    LSidebar.LayoutConstraint := TTuiLayoutConstraint.Fixed(24);

    LSCap       := TTuiLabel.Create(LSidebar);
    LSCap.Text  := ' [ SIDEBAR ]';
    LSCap.Style := TTuiStyle.Create(TTuiColors.BrightYellow, TTuiColor.Default, [taBold]);
    LSCap.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    with TTuiLabel.Create(LSidebar) do
    begin
      Text  := ' A: HStack constraints';
      Style := TTuiStyle.Create(TTuiColors.White, TTuiColor.Default, []);
    end;
    with TTuiLabel.Create(LSidebar) do
    begin
      Text  := ' B: Grid 2x2 + span';
      Style := TTuiStyle.Create(TTuiColors.White, TTuiColor.Default, []);
    end;
    with TTuiLabel.Create(LSidebar) do
    begin
      Text  := ' C: Scrollable (40 rows)';
      Style := TTuiStyle.Create(TTuiColors.White, TTuiColor.Default, []);
    end;
    with TTuiLabel.Create(LSidebar) do
    begin
      Text  := ' D: Resize → recalculate';
      Style := TTuiStyle.Create(TTuiColors.White, TTuiColor.Default, []);
    end;

    // Main panel (Fill 1)
    LMain := TTuiVStack.Create(LBody);
    LMain.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // ---- A: HStack constraint demo (Fixed 5 rows) ----
    LConstraintDemo := TTuiHStack.Create(LMain);
    LConstraintDemo.LayoutConstraint := TTuiLayoutConstraint.Fixed(5);

    MakeColorLabel(' Fixed(12) ',
      TTuiColors.BrightWhite, TTuiColors.Red, LConstraintDemo)
      .LayoutConstraint := TTuiLayoutConstraint.Fixed(12);

    MakeColorLabel(' Fill(1) ',
      TTuiColors.BrightWhite, TTuiColors.Green, LConstraintDemo)
      .LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    MakeColorLabel(' Pct(25%) ',
      TTuiColors.BrightWhite, TTuiColors.Blue, LConstraintDemo)
      .LayoutConstraint := TTuiLayoutConstraint.Percentage(25);

    MakeColorLabel(' Fill(2) ',
      TTuiColors.BrightWhite, TTuiColors.Magenta, LConstraintDemo)
      .LayoutConstraint := TTuiLayoutConstraint.Fill(2);

    // ---- B: Grid 2x2 (Fixed 8 rows) ----
    LGrid := TTuiGrid.Create(2, 2, LMain);
    LGrid.LayoutConstraint := TTuiLayoutConstraint.Fixed(8);

    LG00       := TTuiLabel.Create(LGrid);
    LG00.Text  := ' [0,0] Grid cell (row 0, col 0)';
    LG00.Style := TTuiStyle.Create(TTuiColors.BrightBlack, TTuiColors.White, []);
    LGrid.Place(LG00, TTuiGridPlacement.Make(0, 0));

    LG01       := TTuiLabel.Create(LGrid);
    LG01.Text  := ' [0,1] Grid cell (row 0, col 1)';
    LG01.Style := TTuiStyle.Create(TTuiColors.BrightBlack, TTuiColors.BrightYellow, []);
    LGrid.Place(LG01, TTuiGridPlacement.Make(0, 1));

    LG10       := TTuiLabel.Create(LGrid);
    LG10.Text  := ' [1,0] ColSpan=2 — spans the entire row 1';
    LG10.Style := TTuiStyle.Create(TTuiColors.BrightWhite, TTuiColors.Blue, [taBold]);
    LGrid.Place(LG10, TTuiGridPlacement.Make(1, 0, 1, 2));

    // ---- C: Scrollable (Fill 1) ----
    LScrollContent := TTuiVStack.Create(nil);
    for LI := 1 to 40 do
    begin
      LScrollLabel       := TTuiLabel.Create(LScrollContent);
      LScrollLabel.Text  := Format(' Row %2d of 40 — scroll with ↑↓ PgUp PgDn Home End', [LI]);
      if LI mod 2 = 0 then
        LScrollLabel.Style := TTuiStyle.Create(TTuiColors.BrightCyan, TTuiColor.Default, [])
      else
        LScrollLabel.Style := TTuiStyle.Create(TTuiColors.Cyan, TTuiColor.Default, []);
    end;

    LScroll := TTuiScrollable.Create(LScrollContent, sdVertical, LMain);
    LScroll.LayoutConstraint := TTuiLayoutConstraint.Fill(1);
    LScroll.ContentSize := TSize.Create(200, 40);

    // ---- Footer ----
    LFooter       := TTuiLabel.Create(LRoot);
    LFooter.Text  := ' Tick: 0  |  Size: ?';
    LFooter.Style := TTuiStyle.Create(TTuiColors.Black, TTuiColors.BrightBlack, []);
    LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- App handlers ----
    LApp.SetRoot(LRoot);

    LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        if (AKey.Code = kcEscape) or
           ((AKey.Code = kcChar) and (UpCase(AKey.Character) = 'Q')) then
          LApp.Quit;
      end;

    LApp.OnTimer := procedure(AElapsedMs: Integer)
      begin
        Inc(LTickN);
        Inc(LTotalMs, AElapsedMs);
        LFooter.Text := Format(
          ' Tick: %d  |  Time: %dms  |  Terminal: %dx%d',
          [LTickN, LTotalMs, LLastSize.cx, LLastSize.cy]);
      end;

    LApp.OnResize := procedure(const ASize: TSize)
      begin
        LLastSize := ASize;
        LFooter.Text := Format(
          ' Resize → Terminal: %dx%d',
          [ASize.cx, ASize.cy]);
      end;

    LApp.Run;

  finally
    LApp.Free;  // also frees LRoot (FOwnsRoot=True)
  end;
end.
