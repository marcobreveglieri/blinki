/// <summary>
///   CanvasSmoke — Interactive smoke test for Blinki Phase 2: Render Buffer and Canvas.
///
///   Visually verifies the success criteria CANVAS-01..03 and criterion #4 (box drawing):
///   - CANVAS-01: 20fps animation without flicker (bouncing square, static background)
///   - CANVAS-02: no direct Backend.Write call in the rendering loop;
///                everything goes through Canvas.WriteAt / FillRect / DrawBox
///   - CANVAS-03: terminal resize during the animation without crashes or artifacts
///   - Criterion #4: 4 box styles (Single, Double, Rounded, Heavy) with centered title
/// </summary>
program CanvasSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Style,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Console,
  Blinki.Core.Render,
  Blinki.Core.Canvas;

var
  LBackend: ITuiConsoleBackend;
  LCanvas: TTuiCanvas;
  LKey: TTuiKeyEvent;
  LRunning: Boolean;
  LTick: Integer;
  LBallX: Integer;
  LBallDX: Integer;
begin
  ReportMemoryLeaksOnShutdown := True;

  LBackend := TTuiConsoleBackendFactory.CreateBackend;
  try
    LBackend.Open;
    LBackend.Write(TTuiAnsi.AlternateBufferOn);
    LBackend.Write(TTuiAnsi.CursorHide);
    LBackend.Write(TTuiAnsi.SetTitle('Blinki Phase 2 — Canvas Smoke Test'));
    LCanvas := TTuiCanvas.Create(LBackend);
    try
      LTick   := 0;
      LBallX  := 2;
      LBallDX := 1;
      LRunning := True;

      while LRunning do
      begin
        // Tick: timeout 50ms = 20fps
        if LBackend.TryReadKey(50, LKey) then
        begin
          if (LKey.Code = kcEscape) or
             ((LKey.Code = kcChar) and (UpCase(LKey.Character) = 'Q')) then
            LRunning := False;
        end;

        if not LRunning then
          Break;

        // Idempotent resize: no cost if the dimensions don't change
        LCanvas.HandleResize;

        // --- Frame start ---
        LCanvas.Clear;

        // 4 box styles side by side — verifies criterion #4
        if LCanvas.Width >= 56 then
        begin
          LCanvas.DrawBox(TRect.Create(1,  1, 13, 6), bsSingle,
            'Single',  TTuiStyle.Create(TTuiColors.BrightCyan,    TTuiColor.Default));
          LCanvas.DrawBox(TRect.Create(15, 1, 27, 6), bsDouble,
            'Double',  TTuiStyle.Create(TTuiColors.BrightGreen,   TTuiColor.Default));
          LCanvas.DrawBox(TRect.Create(29, 1, 41, 6), bsRounded,
            'Rounded', TTuiStyle.Create(TTuiColors.BrightYellow,  TTuiColor.Default));
          LCanvas.DrawBox(TRect.Create(43, 1, 55, 6), bsHeavy,
            'Heavy',   TTuiStyle.Create(TTuiColors.BrightMagenta, TTuiColor.Default));
        end;

        // Bouncing square — verifies CANVAS-01 (anti-flicker diff)
        if LCanvas.Width > 6 then
        begin
          var LMaxX := LCanvas.Width - 4;
          if LMaxX < 2 then LMaxX := 2;
          LCanvas.FillRect(
            TRect.Create(LBallX, 8, LBallX + 3, 10),
            '#',
            TTuiStyle.Create(TTuiColors.BrightRed, TTuiColor.Default)
          );
          Inc(LBallX, LBallDX);
          if LBallX <= 1 then
          begin
            LBallX  := 1;
            LBallDX := 1;
          end
          else if LBallX >= LMaxX then
          begin
            LBallX  := LMaxX;
            LBallDX := -1;
          end;
        end;

        // Tick counter with cyclic RGB color — verifies True Color
        if LCanvas.Height > 11 then
        begin
          var LR := Byte((LTick * 3) mod 256);
          var LG := Byte((LTick * 5 + 85) mod 256);
          var LB := Byte((LTick * 7 + 170) mod 256);
          var LMsg := Format('Tick: %d   (Q/ESC to quit)', [LTick]);
          var LMsgX := (LCanvas.Width - Length(LMsg)) div 2;
          if LMsgX < 0 then LMsgX := 0;
          LCanvas.WriteAt(LMsgX, LCanvas.Height - 2, LMsg,
            TTuiStyle.Create(TTuiColor.RGB(LR, LG, LB), TTuiColor.Default, [taBold]));
        end;

        // Flush: emits only the changed cells (CANVAS-01)
        LCanvas.Flush;
        Inc(LTick);
      end;

    finally
      LCanvas.Free;
      LBackend.Write(TTuiAnsi.CursorShow);
      LBackend.Write(TTuiAnsi.AlternateBufferOff);
      LBackend.Write(TTuiAnsi.Reset);
      LBackend.Close;
    end;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, 'ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
