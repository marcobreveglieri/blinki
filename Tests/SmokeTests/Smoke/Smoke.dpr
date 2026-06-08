/// <summary>
///   Smoke — Interactive smoke test for Blinki Phase 1: Console Foundation.
///
///   Visually verifies the success criteria CORE-01..08:
///   - CORE-01: VT100 enabled, colored text visible
///   - CORE-02: guaranteed cleanup in finally (test by uncommenting the raise)
///   - CORE-03: no {$IFDEF} in this file; everything cross-platform above ITuiConsoleBackend
///   - CORE-04: Unicode box drawing (┌─┐│└┘ etc.) visible without configuration
///   - CORE-05: non-blocking input with key decoding (arrows, F-keys, Esc, Tab, Ctrl+)
///   - CORE-06: 16 standard colors, 256 palette, True Color RGB
///   - CORE-07: text styles (bold, dim, italic, underline, blink, inverse, strike)
///   - CORE-08: TTuiLayoutConstraint available (compilation verifies usage)
/// </summary>
program Smoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Geometry,
  Blinki.Core.Style,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Console;

procedure WriteAt(const ABackend: ITuiConsoleBackend; ARow, ACol: Integer;
  const AText: string; const AStyle: TTuiStyle);
begin
  ABackend.Write(
    TTuiAnsi.CursorTo(ARow, ACol) +
    TTuiAnsi.ApplyStyle(AStyle) +
    AText +
    TTuiAnsi.Reset
  );
end;

procedure DrawBox(const ABackend: ITuiConsoleBackend; ARow, ACol, AWidth, AHeight: Integer;
  ABoxStyle: TTuiBoxStyle; const ATitle: string; const AStyle: TTuiStyle);
var
  LChars: TTuiBoxCharSet;
  LI: Integer;
  LTitleLine: string;
begin
  LChars := TTuiAnsi.BoxCharset(ABoxStyle);
  ABackend.Write(TTuiAnsi.ApplyStyle(AStyle));

  // Top row with optional title
  if ATitle <> '' then
  begin
    LTitleLine := LChars.TopLeft + LChars.Horizontal +
      ' ' + ATitle + ' ';
    LI := TTuiAnsi.VisibleLength(LTitleLine);
    while LI < AWidth - 1 do
    begin
      LTitleLine := LTitleLine + LChars.Horizontal;
      Inc(LI);
    end;
    LTitleLine := LTitleLine + LChars.TopRight;
  end
  else
  begin
    LTitleLine := LChars.TopLeft;
    for LI := 2 to AWidth - 1 do
      LTitleLine := LTitleLine + LChars.Horizontal;
    LTitleLine := LTitleLine + LChars.TopRight;
  end;
  ABackend.Write(TTuiAnsi.CursorTo(ARow, ACol) + LTitleLine);

  // Side rows
  for LI := 1 to AHeight - 2 do
  begin
    ABackend.Write(
      TTuiAnsi.CursorTo(ARow + LI, ACol) + LChars.Vertical +
      TTuiAnsi.CursorTo(ARow + LI, ACol + AWidth - 1) + LChars.Vertical
    );
  end;

  // Bottom row
  var LBottom: string := LChars.BottomLeft;
  for LI := 2 to AWidth - 1 do
    LBottom := LBottom + LChars.Horizontal;
  LBottom := LBottom + LChars.BottomRight;
  ABackend.Write(TTuiAnsi.CursorTo(ARow + AHeight - 1, ACol) + LBottom);

  ABackend.Write(TTuiAnsi.Reset);
end;

procedure ShowColors16(const ABackend: ITuiConsoleBackend; AStartRow: Integer);
const
  Names: array[0..15] of string = (
    'Black', 'Red', 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'White',
    'BrightBlack', 'BrightRed', 'BrightGreen', 'BrightYellow',
    'BrightBlue', 'BrightMagenta', 'BrightCyan', 'BrightWhite'
  );
var
  LI: Integer;
begin
  for LI := 0 to 15 do
  begin
    var LStyle := TTuiStyle.Create(TTuiColor.Standard(LI), TTuiColor.Default);
    WriteAt(ABackend, AStartRow, 3 + LI * 5, '███', LStyle);
    ABackend.Write(
      TTuiAnsi.CursorTo(AStartRow + 1, 3 + LI * 5) +
      TTuiAnsi.SetForeground(TTuiColor.Standard(LI)) +
      Copy(Names[LI], 1, 4) +
      TTuiAnsi.Reset
    );
  end;
end;

procedure ShowColors256(const ABackend: ITuiConsoleBackend; AStartRow: Integer);
var
  LI: Integer;
begin
  ABackend.Write(TTuiAnsi.CursorTo(AStartRow, 3));
  for LI := 0 to 255 do
  begin
    var LStyle := TTuiStyle.Create(TTuiColor.Default, TTuiColor.Palette(LI));
    ABackend.Write(TTuiAnsi.ApplyStyle(LStyle) + ' ');
  end;
  ABackend.Write(TTuiAnsi.Reset);
end;

procedure ShowRGBGradient(const ABackend: ITuiConsoleBackend; AStartRow: Integer);
var
  LI: Integer;
begin
  ABackend.Write(TTuiAnsi.CursorTo(AStartRow, 3));
  for LI := 0 to 77 do
  begin
    var LR := Byte(Round((255.0 * LI) / 77));
    var LG := Byte(Round((255.0 * (77 - LI)) / 77));
    var LB := Byte(128 + Round((127.0 * LI) / 77));
    var LStyle := TTuiStyle.Create(TTuiColor.Default, TTuiColor.RGB(LR, LG, LB));
    ABackend.Write(TTuiAnsi.ApplyStyle(LStyle) + ' ');
  end;
  ABackend.Write(TTuiAnsi.Reset);
end;

procedure ShowTextStyles(const ABackend: ITuiConsoleBackend; AStartRow: Integer);
const
  StyleNames: array[TTuiTextAttr] of string = (
    'Bold', 'Dim', 'Italic', 'Underline', 'Blink', 'Inverse', 'Strike'
  );
var
  LAttr: TTuiTextAttr;
  LCol: Integer;
begin
  LCol := 3;
  for LAttr := Low(TTuiTextAttr) to High(TTuiTextAttr) do
  begin
    var LStyle := TTuiStyle.Create(
      TTuiColors.BrightWhite,
      TTuiColor.Default,
      [LAttr]
    );
    ABackend.Write(
      TTuiAnsi.CursorTo(AStartRow, LCol) +
      TTuiAnsi.ApplyStyle(LStyle) +
      StyleNames[LAttr] +
      TTuiAnsi.Reset
    );
    Inc(LCol, Length(StyleNames[LAttr]) + 2);
  end;
end;

procedure ShowBoxStyles(const ABackend: ITuiConsoleBackend; AStartRow: Integer);
var
  LStyle: TTuiBoxStyle;
  LNames: array[TTuiBoxStyle] of string;
  LCol: Integer;
begin
  LNames[bsSingle]  := 'Single';
  LNames[bsDouble]  := 'Double';
  LNames[bsRounded] := 'Rounded';
  LNames[bsHeavy]   := 'Heavy';

  LCol := 3;
  for LStyle := Low(TTuiBoxStyle) to High(TTuiBoxStyle) do
  begin
    var LBoxStyle := TTuiStyle.Create(TTuiColors.BrightCyan, TTuiColor.Default);
    DrawBox(ABackend, AStartRow, LCol, 12, 3, LStyle, LNames[LStyle], LBoxStyle);
    Inc(LCol, 14);
  end;
end;

procedure RunInputLoop(const ABackend: ITuiConsoleBackend; AStartRow: Integer);
const
  MaxHistory = 5;
var
  LKey: TTuiKeyEvent;
  LHistory: array[0..MaxHistory - 1] of string;
  LHistIdx: Integer;
  LRunning: Boolean;
  LI: Integer;
  LSize: TSize;
begin
  for LI := 0 to MaxHistory - 1 do
    LHistory[LI] := '';
  LHistIdx := 0;
  LRunning := True;

  // Input section header
  var LHeadStyle := TTuiStyle.Create(TTuiColors.BrightYellow, TTuiColor.Default, [taBold]);
  WriteAt(ABackend, AStartRow, 3, 'Press keys (Esc to quit):', LHeadStyle);

  while LRunning do
  begin
    // Update and display terminal size
    LSize := ABackend.GetSize;
    ABackend.Write(
      TTuiAnsi.CursorTo(AStartRow + 1, 3) +
      TTuiAnsi.SetForeground(TTuiColors.BrightBlack) +
      Format('Terminal: %dx%d cols x rows', [LSize.cx, LSize.cy]) +
      TTuiAnsi.Reset +
      TTuiAnsi.ClearLineToEnd
    );

    if ABackend.TryReadKey(100, LKey) then
    begin
      if LKey.Code = kcEscape then
      begin
        LRunning := False;
        Continue;
      end;

      // Add to history
      LHistory[LHistIdx mod MaxHistory] := LKey.ToString;
      Inc(LHistIdx);

      // Show the last N key presses
      for LI := 0 to MaxHistory - 1 do
      begin
        var LSlot := (LHistIdx - MaxHistory + LI + 100 * MaxHistory) mod MaxHistory;
        var LKeyStyle := TTuiStyle.Create(TTuiColors.BrightGreen, TTuiColor.Default);
        ABackend.Write(
          TTuiAnsi.CursorTo(AStartRow + 3 + LI, 3) +
          TTuiAnsi.ApplyStyle(LKeyStyle) +
          Format('%-30s', [LHistory[LSlot]]) +
          TTuiAnsi.Reset
        );
      end;
    end;
  end;
end;

var
  LBackend: ITuiConsoleBackend;
  LTitleStyle: TTuiStyle;
  LLabelStyle: TTuiStyle;
  // Compilation check CORE-08: TTuiLayoutConstraint must be available
  LConstraint: TTuiLayoutConstraint;
begin
  ReportMemoryLeaksOnShutdown := True;

  // CORE-08: verify that TTuiLayoutConstraint works correctly (runtime check)
  LConstraint := TTuiLayoutConstraint.Fixed(80);
  Assert(LConstraint.Kind = lckFixed, 'TTuiLayoutConstraint.Fixed precondition');
  Assert(LConstraint.Value = 80, 'TTuiLayoutConstraint.Fixed.Value = 80');
  LConstraint := TTuiLayoutConstraint.Fill(2);
  Assert(LConstraint.Kind = lckFill, 'TTuiLayoutConstraint.Fill precondition');
  Assert(LConstraint.Value = 2, 'TTuiLayoutConstraint.Fill.Value = 2');

  LBackend := TTuiConsoleBackendFactory.CreateBackend;
  try
    LBackend.Open;
    LBackend.Write(TTuiAnsi.AlternateBufferOn);
    LBackend.Write(TTuiAnsi.CursorHide);
    LBackend.Write(TTuiAnsi.SetTitle('Blinki Phase 1 — Smoke Test'));
    try
      // Background
      LBackend.Write(TTuiAnsi.ClearScreen);

      // Main title
      LTitleStyle := TTuiStyle.Create(TTuiColors.BrightCyan, TTuiColor.Default, [taBold]);
      WriteAt(LBackend, 1, 3, 'Blinki — Phase 1: Console Foundation Smoke Test', LTitleStyle);

      // Section: 16 colors
      LLabelStyle := TTuiStyle.Create(TTuiColors.BrightYellow, TTuiColor.Default);
      WriteAt(LBackend, 3, 3, 'Standard ANSI colors (16):', LLabelStyle);
      ShowColors16(LBackend, 4);

      // Section: 256-color palette
      WriteAt(LBackend, 7, 3, '256-color palette:', LLabelStyle);
      ShowColors256(LBackend, 8);

      // Section: RGB gradient
      WriteAt(LBackend, 10, 3, 'Gradient True Color RGB 24-bit:', LLabelStyle);
      ShowRGBGradient(LBackend, 11);

      // Section: text styles
      WriteAt(LBackend, 13, 3, 'Text styles:', LLabelStyle);
      ShowTextStyles(LBackend, 14);

      // Section: box drawing
      WriteAt(LBackend, 16, 3, 'Box drawing (4 styles):', LLabelStyle);
      ShowBoxStyles(LBackend, 17);

      // Section: input loop
      // To test CORE-02 (cleanup on exception):
      // uncomment the line below and observe that the terminal is restored cleanly
      // raise EAbort.Create('Test cleanup on exception');

      RunInputLoop(LBackend, 21);

    finally
      LBackend.Write(TTuiAnsi.CursorShow);
      LBackend.Write(TTuiAnsi.AlternateBufferOff);
      LBackend.Write(TTuiAnsi.Reset);
      LBackend.Close;
    end;
  except
    on E: Exception do
    begin
      // On unhandled exception: the finally block above already restored the
      // terminal; here we print the error to the standard error output.
      Writeln(ErrOutput, 'ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
