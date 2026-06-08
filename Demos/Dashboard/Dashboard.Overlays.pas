{****************************************************************}
{                                                                }
{            ██████╗ ██╗     ██╗███╗   ██╗██╗  ██╗██╗            }
{            ██╔══██╗██║     ██║████╗  ██║██║ ██╔╝██║            }
{            ██████╔╝██║     ██║██╔██╗ ██║█████╔╝ ██║            }
{            ██╔══██╗██║     ██║██║╚██╗██║██╔═██╗ ██║            }
{            ██████╔╝███████╗██║██║ ╚████║██║  ██╗██║            }
{            ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝            }
{                                                                }
{       Modern, beautiful Text User Interfaces for Delphi        }
{                                                                }
{****************************************************************}
{                                                                }
{   Unit:        Dashboard.Overlays.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Dashboard demo — full-screen modal overlays pushed onto the
///   TTuiApp modal stack.
///
///   TDashboardOverlay   — base class: focusable, Esc/Enter close via OnClose.
///   TDashboardStatsView — severity breakdown + totals (key i).
///   TDashboardHelpView  — keyboard shortcut reference (keys ? / h).
///   TDashboardDetailView — all fields of a selected log entry (Enter).
///
///   All three classes are created with a nil parent and owned by the app
///   modal stack (PushModal ownsModal = True by default).
/// </summary>
unit Dashboard.Overlays;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Geometry,
  Blinki.Core.Widget,
  Dashboard.Model;

type

{ TDashboardOverlay }

  /// <summary>
  ///   Abstract base for Dashboard full-screen modal overlays.
  ///   Sets itself focusable so it receives keyboard input from the modal stack.
  ///   Both Esc and Enter fire OnClose; the host is responsible for calling
  ///   App.PopModal inside that callback.
  /// </summary>
  TDashboardOverlay = class(TTuiWidget)
  strict private
    FOnClose: TProc;
  protected
    procedure DoInit; override;
    /// <summary>
    ///   Draws the rounded-border panel filling ARect, with ATitle embedded
    ///   in the top border.  Fills the interior and returns it as AInner.
    /// </summary>
    procedure DrawPanel(const ACanvas: TTuiCanvas; const ARect: TRect;
      const ATitle: string; out AInner: TRect);
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
  public
    /// <summary>
    ///   Called when the user presses Esc or Enter.  The host must call
    ///   App.PopModal inside this callback.
    /// </summary>
    property OnClose: TProc read FOnClose write FOnClose;
  end;

{ TDashboardDetailView }

  /// <summary>
  ///   Full-screen modal showing all fields of a single TLogEntry.
  ///   Opened when the user presses Enter on a selected log row.
  /// </summary>
  TDashboardDetailView = class(TDashboardOverlay)
  strict private
    FEntry: TLogEntry;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Creates the detail view for AEntry.  Does not own the entry.
    /// </summary>
    constructor Create(AParent: TTuiWidget; const AEntry: TLogEntry);
  end;

{ TDashboardHelpView }

  /// <summary>
  ///   Full-screen modal listing all keyboard shortcuts for the Dashboard demo.
  ///   Opened with ? or H.
  /// </summary>
  TDashboardHelpView = class(TDashboardOverlay)
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  end;

{ TDashboardStatsView }

  /// <summary>
  ///   Full-screen modal showing a severity breakdown, log totals, and pattern
  ///   count.  Reads live data from TDashboardModel on every render frame.
  ///   Opened with I.
  /// </summary>
  TDashboardStatsView = class(TDashboardOverlay)
  strict private
    FModel: TDashboardModel;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Creates the stats view.  AModel is a reference (not owned).
    /// </summary>
    constructor Create(AParent: TTuiWidget; AModel: TDashboardModel);
  end;

implementation

uses
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Dashboard.Consts,
  Dashboard.Helpers;

{ TDashboardOverlay }

procedure TDashboardOverlay.DoInit;
begin
  SetFocusable(True);
end;

procedure TDashboardOverlay.DrawPanel(const ACanvas: TTuiCanvas; const ARect: TRect;
  const ATitle: string; out AInner: TRect);
var
  LBorderStyle, LBgStyle: TTuiStyle;
begin
  LBorderStyle := TTuiStyle.Create(CColorBorderFocus, CColorBlack);
  LBgStyle := TTuiStyle.Create(CColorText, CColorBlack);
  ACanvas.DrawBox(ARect, bsRounded, ATitle, LBorderStyle);
  AInner := ARect.Interior;
  if not AInner.IsEmpty then
    ACanvas.FillRect(AInner, ' ', LBgStyle);
end;

function TDashboardOverlay.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  case AEvent.Key.Code of
    kcEscape, kcEnter:
    begin
      if Assigned(FOnClose) then
        FOnClose;
      Result := True;
    end;
  end;
end;

{ TDashboardDetailView }

constructor TDashboardDetailView.Create(AParent: TTuiWidget; const AEntry: TLogEntry);
begin
  inherited Create(AParent);
  FEntry := AEntry;
end;

procedure TDashboardDetailView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
const
  CLabelW = 10;
var
  LInner: TRect;
  LLabelStyle, LValueStyle, LDimStyle: TTuiStyle;
  LY, LValueX, LMaxW: Integer;
begin
  DrawPanel(ACanvas, ARect, ' Log Entry Details ', LInner);
  if LInner.IsEmpty then
    Exit;

  LLabelStyle := TTuiStyle.Create(CColorDim, CColorBlack);
  LValueStyle := TTuiStyle.Create(CColorText, CColorBlack);
  LDimStyle := TTuiStyle.Create(CColorDim, CColorBlack);
  LY := LInner.Top + 1;
  LValueX := LInner.Left + CLabelW + 1;
  LMaxW := LInner.Right - LValueX;

  ACanvas.PushClip(LInner);
  try
    // Time
    if (LY < LInner.Bottom) and (LMaxW > 0) then
    begin
      ACanvas.WriteAt(LInner.Left, LY, PadRight('Time:', CLabelW), LLabelStyle);
      ACanvas.WriteAt(LValueX, LY, TruncateStr(FEntry.Time, LMaxW), LValueStyle);
      Inc(LY);
    end;
    // Level
    if (LY < LInner.Bottom) and (LMaxW > 0) then
    begin
      ACanvas.WriteAt(LInner.Left, LY, PadRight('Level:', CLabelW), LLabelStyle);
      ACanvas.WriteAt(LValueX, LY, TruncateStr(FEntry.Level, LMaxW), LevelStyle(FEntry.Level));
      Inc(LY);
    end;
    // Host
    if (LY < LInner.Bottom) and (LMaxW > 0) then
    begin
      ACanvas.WriteAt(LInner.Left, LY, PadRight('Host:', CLabelW), LLabelStyle);
      ACanvas.WriteAt(LValueX, LY, TruncateStr(FEntry.Host, LMaxW), LValueStyle);
      Inc(LY);
    end;
    // Service
    if (LY < LInner.Bottom) and (LMaxW > 0) then
    begin
      ACanvas.WriteAt(LInner.Left, LY, PadRight('Service:', CLabelW), LLabelStyle);
      ACanvas.WriteAt(LValueX, LY, TruncateStr(FEntry.Service, LMaxW),
        TTuiStyle.Create(CColorService, CColorBlack));
      Inc(LY);
    end;
    // blank separator
    Inc(LY);
    // Message — word-wrap across multiple lines
    if (LY < LInner.Bottom) and (LMaxW > 0) then
    begin
      ACanvas.WriteAt(LInner.Left, LY, PadRight('Message:', CLabelW), LLabelStyle);
      var LOffset := 1;
      var LFirst := True;
      while (LOffset <= Length(FEntry.Message)) and (LY < LInner.Bottom - 2) do
      begin
        if not LFirst then
          ACanvas.WriteAt(LInner.Left, LY, PadRight('', CLabelW), LLabelStyle);
        var LChunk := Min(LMaxW, Length(FEntry.Message) - LOffset + 1);
        ACanvas.WriteAt(LValueX, LY,
          Copy(FEntry.Message, LOffset, LChunk),
          TTuiStyle.Create(CColorMessage, CColorBlack));
        Inc(LOffset, LChunk);
        Inc(LY);
        LFirst := False;
      end;
    end;
    // Close hint centred at the bottom
    var LHintY := LInner.Bottom - 2;
    if LHintY > LY then
    begin
      var LHint := 'Press Esc or Enter to close';
      var LHintX := LInner.Left + (LInner.Width - Length(LHint)) div 2;
      if LHintX < LInner.Left then
        LHintX := LInner.Left;
      ACanvas.WriteAt(LHintX, LHintY, LHint, LDimStyle);
    end;
  finally
    ACanvas.PopClip;
  end;
end;

{ TDashboardHelpView }

procedure TDashboardHelpView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
const
  CKeyW = 20;
  CKeys: array[0..11] of string = (
    'Tab / Shift+Tab',
    'Up / Down',
    'PgUp / PgDn',
    'Home / End',
    'Enter',
    'Scroll wheel',
    'Click',
    'Space',
    'T',
    'i',
    '? / h',
    'Esc / Q'
  );
  CDescs: array[0..11] of string = (
    'Cycle focus between panels',
    'Move row selection in log table',
    'Page through log entries',
    'Jump to first / last log entry',
    'Open details of selected entry',
    'Scroll log table',
    'Focus a panel',
    'Pause / Resume simulation',
    'Toggle Dark / Light theme',
    'Show statistics',
    'Show this help screen',
    'Quit'
  );
var
  LInner: TRect;
  LKeyStyle, LDescStyle, LDimStyle: TTuiStyle;
  LDescX, LY: Integer;
begin
  DrawPanel(ACanvas, ARect, ' Keyboard Shortcuts ', LInner);
  if LInner.IsEmpty then
    Exit;

  LKeyStyle := TTuiStyle.Create(CColorTitle, CColorBlack, [taBold]);
  LDescStyle := TTuiStyle.Create(CColorText, CColorBlack);
  LDimStyle := TTuiStyle.Create(CColorDim, CColorBlack);
  LDescX := LInner.Left + CKeyW + 2;
  LY := LInner.Top + 1;

  ACanvas.PushClip(LInner);
  try
    for var LI := Low(CKeys) to High(CKeys) do
    begin
      if LY >= LInner.Bottom - 2 then
        Break;
      ACanvas.WriteAt(LInner.Left, LY, PadRight(CKeys[LI], CKeyW), LKeyStyle);
      if LDescX < LInner.Right then
      begin
        var LMaxDescW := LInner.Right - LDescX;
        ACanvas.WriteAt(LDescX, LY, TruncateStr(CDescs[LI], LMaxDescW), LDescStyle);
      end;
      Inc(LY);
    end;
    // Close hint
    var LHintY := LInner.Bottom - 2;
    if LHintY > LY then
    begin
      var LHint := 'Press Esc or Enter to close';
      var LHintX := LInner.Left + (LInner.Width - Length(LHint)) div 2;
      if LHintX < LInner.Left then
        LHintX := LInner.Left;
      ACanvas.WriteAt(LHintX, LHintY, LHint, LDimStyle);
    end;
  finally
    ACanvas.PopClip;
  end;
end;

{ TDashboardStatsView }

constructor TDashboardStatsView.Create(AParent: TTuiWidget; AModel: TDashboardModel);
begin
  inherited Create(AParent);
  FModel := AModel;
end;

procedure TDashboardStatsView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
const
  CBarW    = 20;
  CLabelW  = 7;
  CCountW  = 6;
  CPctW    = 9;   // " (nnn.n%)"
var
  LInner: TRect;
  LHeadStyle, LLabelStyle, LDimStyle, LBorderStyle: TTuiStyle;
  LSev: TSeverityCounts;
  LTotalSev, LY, LBarX: Integer;

  procedure SevRow(const ALabel: string; ACount: Integer;
    const AStyle: TTuiStyle);
  begin
    if LY >= LInner.Bottom then
      Exit;
    var LPct := 0.0;
    var LFilled := 0;
    if LTotalSev > 0 then
    begin
      LPct := ACount / LTotalSev * 100.0;
      LFilled := Min(Round(ACount / LTotalSev * CBarW), CBarW);
    end;
    ACanvas.WriteAt(LInner.Left, LY, PadRight(ALabel, CLabelW), AStyle);
    ACanvas.WriteAt(LInner.Left + CLabelW, LY,
      Format('%6d (%5.1f%%)', [ACount, LPct]), LLabelStyle);
    if LBarX + CBarW + 2 <= LInner.Right then
      DrawHBar(ACanvas, LBarX, LY, CBarW, LFilled, AStyle, LDimStyle, LBorderStyle);
    Inc(LY);
  end;

begin
  DrawPanel(ACanvas, ARect, ' Statistics ', LInner);
  if LInner.IsEmpty then
    Exit;

  LHeadStyle := TTuiStyle.Create(CColorTitle, CColorBlack, [taBold]);
  LLabelStyle := TTuiStyle.Create(CColorText, CColorBlack);
  LDimStyle := TTuiStyle.Create(CColorDim, CColorBlack);
  LBorderStyle := TTuiStyle.Create(CColorBarFull, CColorBlack);

  LSev := FModel.Severities;
  LTotalSev := LSev.Total;
  // CLabelW + CCountW + 1 space + CPctW + 1 space = 24 chars before bar
  LBarX := LInner.Left + CLabelW + CCountW + 1 + CPctW + 1;

  LY := LInner.Top + 1;

  ACanvas.PushClip(LInner);
  try
    // --- Severity breakdown ---
    ACanvas.WriteAt(LInner.Left, LY, 'Severity Breakdown', LHeadStyle);
    Inc(LY, 2);
    SevRow(CSevFatal, LSev.Fatal, TTuiStyle.Create(CColorSevFatal, CColorBlack, [taBold]));
    SevRow(CSevError, LSev.Error, TTuiStyle.Create(CColorSevError, CColorBlack, [taBold]));
    SevRow(CSevWarn,  LSev.Warn,  TTuiStyle.Create(CColorSevWarn,  CColorBlack));
    SevRow(CSevInfo,  LSev.Info,  TTuiStyle.Create(CColorSevInfo,  CColorBlack));
    SevRow(CSevDebug, LSev.Debug, TTuiStyle.Create(CColorSevDebug, CColorBlack));
    SevRow(CSevTrace, LSev.Trace, TTuiStyle.Create(CColorSevTrace, CColorBlack));

    Inc(LY);

    // --- Totals ---
    if LY < LInner.Bottom then
    begin
      ACanvas.WriteAt(LInner.Left, LY, 'Totals', LHeadStyle);
      Inc(LY, 2);
    end;
    if LY < LInner.Bottom then
    begin
      ACanvas.WriteAt(LInner.Left, LY,
        PadRight('Total log lines:', 22) + Format('%d', [FModel.TotalLogs]),
        LLabelStyle);
      Inc(LY);
    end;
    if LY < LInner.Bottom then
    begin
      ACanvas.WriteAt(LInner.Left, LY,
        PadRight('Visible entries:', 22) + Format('%d', [FModel.LogEntries.Count]),
        LLabelStyle);
      Inc(LY);
    end;
    if LY < LInner.Bottom then
    begin
      ACanvas.WriteAt(LInner.Left, LY,
        PadRight('Pattern count:', 22) + Format('%d', [FModel.PatternCount]),
        LLabelStyle);
      Inc(LY);
    end;

    // Close hint
    var LHintY := LInner.Bottom - 2;
    if LHintY > LY then
    begin
      var LHint := 'Press Esc or Enter to close';
      var LHintX := LInner.Left + (LInner.Width - Length(LHint)) div 2;
      if LHintX < LInner.Left then
        LHintX := LInner.Left;
      ACanvas.WriteAt(LHintX, LHintY, LHint, LDimStyle);
    end;
  finally
    ACanvas.PopClip;
  end;
end;

end.
