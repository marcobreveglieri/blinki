/// <summary>
///   AppSmoke — Interactive smoke test for Blinki Phase 4: Application and Event Loop.
///
///   Verifies the success criteria APP-01..APP-05:
///   - APP-01: TTuiApp.Create + SetRoot + Run in 3 lines in the begin block
///   - APP-02: OnKeyPress (Q/Esc = quit), OnTimer (tick counter), OnResize (size label)
///   - APP-03: tick counter advances ~20 times/sec without input (non-blocking 20fps loop)
///   - APP-04: resizing the terminal updates the size label within one tick
///   - APP-05: Q/Esc restores the terminal; Ctrl+C does too (Phase 1 handler)
///
///   Widget tree:
///     TSmokePanel (root, non-focusable)
///       TTuiLabel  "Phase 4 Smoke ..."   (row 0)
///       TTuiLabel  "Tick: N (M ms)"      (row 1 — updated by OnTimer)
///       TTuiLabel  "Size: WxH"           (row 2 — updated by OnResize)
///       TTuiLabel  ""                    (row 3 — separator)
///       TSmokeFocusable "[A]"            (row 4 — focusable)
///       TSmokeFocusable "[B]"            (row 5 — focusable)
///       TSmokeFocusable "[C]"            (row 6 — focusable)
///   Expected focus ring: [A] [B] [C]
/// </summary>
program AppSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  Blinki.Core.Style,
  Blinki.Core.Input,
  Blinki.Core.Canvas,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Widgets.Labels;

type
  /// <summary>Focusable test widget: label with inverse video when focused.</summary>
  TSmokeFocusable = class(TTuiWidget)
  strict private
    FCaption: string;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create(const ACaption: string; AParent: TTuiWidget = nil); reintroduce;
    /// <summary>Text displayed by the widget.</summary>
    property Caption: string read FCaption;
  end;

  /// <summary>
  ///   Smoke root panel: simple vertical layout (1 row per child).
  ///   Exposes UpdateTick and UpdateSize for the App's anonymous handlers.
  /// </summary>
  TSmokePanel = class(TTuiWidget)
  strict private
    FLabelHint: TTuiLabel;
    FLabelTick: TTuiLabel;
    FLabelSize: TTuiLabel;
    FLabelSep: TTuiLabel;
    FFocA: TSmokeFocusable;
    FFocB: TSmokeFocusable;
    FFocC: TSmokeFocusable;
    FTotalMs: Int64;
    FTickCount: Integer;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create; reintroduce;
    /// <summary>Updates the tick counter; called by the App's OnTimer.</summary>
    procedure UpdateTick(AElapsedMs: Integer);
    /// <summary>Updates the size label; called by the App's OnResize.</summary>
    procedure UpdateSize(const ASize: TSize);
  end;

{ TSmokeFocusable }

constructor TSmokeFocusable.Create(const ACaption: string; AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FCaption := ACaption;
end;

procedure TSmokeFocusable.DoInit;
begin
  inherited DoInit;
  SetFocusable(True);
end;

procedure TSmokeFocusable.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
var
  LStyle: TTuiStyle;
  LText: string;
begin
  if ARect.IsEmpty then
    Exit;
  if Focused then
    LStyle := TTuiStyle.Create(TTuiColors.Black, TTuiColors.BrightWhite)
  else
    LStyle := TTuiStyle.Default;
  LText := FCaption;
  if Length(LText) > ARect.Width then
    LText := Copy(LText, 1, ARect.Width);
  ACanvas.WriteAt(ARect.Left, ARect.Top, LText, LStyle);
end;

{ TSmokePanel }

constructor TSmokePanel.Create;
begin
  inherited Create(nil);
  FLabelHint := TTuiLabel.Create(Self);
  FLabelTick := TTuiLabel.Create(Self);
  FLabelSize := TTuiLabel.Create(Self);
  FLabelSep  := TTuiLabel.Create(Self);
  FFocA      := TSmokeFocusable.Create('[A] widget focusable', Self);
  FFocB      := TSmokeFocusable.Create('[B] widget focusable', Self);
  FFocC      := TSmokeFocusable.Create('[C] widget focusable', Self);
  FTotalMs   := 0;
  FTickCount := 0;
end;

procedure TSmokePanel.DoInit;
begin
  inherited DoInit;
  FLabelHint.Text  := 'Phase 4 Smoke | Tab/Shift-Tab: focus | Q/Esc: quit';
  FLabelHint.Style := TTuiStyle.Create(TTuiColors.BrightYellow, TTuiColor.Default, [taBold]);
  FLabelTick.Text  := 'Tick: 0 (0 ms total)';
  FLabelSize.Text  := 'Size: (waiting for first resize)';
  FLabelSep.Text   := '';
end;

procedure TSmokePanel.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
var
  LI: Integer;
  LY: Integer;
begin
  LY := ARect.Top;
  for LI := 0 to ChildCount - 1 do
  begin
    if LY >= ARect.Bottom then
      Break;
    Children[LI].Render(ACanvas, TRect.Create(ARect.Left, LY, ARect.Right, LY + 1));
    Inc(LY);
  end;
end;

procedure TSmokePanel.UpdateTick(AElapsedMs: Integer);
begin
  Inc(FTotalMs, AElapsedMs);
  Inc(FTickCount);
  FLabelTick.Text := Format('Tick: %d (%d ms total)', [FTickCount, FTotalMs]);
end;

procedure TSmokePanel.UpdateSize(const ASize: TSize);
begin
  FLabelSize.Text := Format('Size: %dx%d', [ASize.cx, ASize.cy]);
end;

// ---------------------------------------------------------------------------

var
  LApp: TTuiApp;
  LPanel: TSmokePanel;

begin
  ReportMemoryLeaksOnShutdown := True;

  LApp   := TTuiApp.Create;
  LPanel := TSmokePanel.Create;
  try
    LApp.SetRoot(LPanel);                // ownership to the App (default AOwnsRoot=True)

    LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        if (AKey.Code = kcEscape) or
           ((AKey.Code = kcChar) and (UpCase(AKey.Character) = 'Q')) then
          LApp.Quit;
      end;

    LApp.OnTimer := procedure(AElapsedMs: Integer)
      begin
        LPanel.UpdateTick(AElapsedMs);
      end;

    LApp.OnResize := procedure(const ASize: TSize)
      begin
        LPanel.UpdateSize(ASize);
      end;

    LApp.Run;
  finally
    LApp.Free;  // also frees LPanel (FOwnsRoot=True)
  end;
end.
