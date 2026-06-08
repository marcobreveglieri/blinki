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
{   Unit:        Recorder.View.pas                               }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   RecorderDemo -- custom widgets:
///   TAudioMeterView: single-row VU meter with gradient blocks and peak-hold.
///   TMicView: ASCII microphone illustration with reactive sound arcs.
///   TTranscriptView: scrollable, word-wrapped transcription log.
/// </summary>
unit Recorder.View;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  System.Generics.Collections,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Widget;

type

{ TAudioMeterView }

  /// <summary>
  ///   Single-row VU meter widget. The bar fills left-to-right using Unicode
  ///   partial-block characters (U+258F..U+2588) with colour zones: Success
  ///   below ThresholdWarn, Warning up to ThresholdError, Error above.
  ///   A peak-hold marker (|) is held for CPeakHoldMs then decays linearly
  ///   over CPeakDecayMs, driven by DoTick.  Not focusable.
  /// </summary>
  TAudioMeterView = class(TTuiWidget)
  strict private
    FLevel:           Double;
    FPeakAccumMs:     Integer;
    FPeakHold:        Double;
    FPeakOriginal:    Double;
    FThresholdError:  Double;
    FThresholdWarn:   Double;
    procedure SetLevel(AValue: Double);
    function ColorForValue(AValue: Double): TTuiColor;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    /// <summary>
    ///   Creates the meter. ThresholdWarn: 0.6; ThresholdError: 0.85.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Current input level [0.0, 1.0].  Updates the peak-hold when the
    ///   new value exceeds the current held peak.
    /// </summary>
    property Level: Double read FLevel write SetLevel;
    /// <summary>
    ///   Level at which the bar colour changes from Success to Warning. Default: 0.6.
    /// </summary>
    property ThresholdError: Double read FThresholdError write FThresholdError;
    /// <summary>
    ///   Level at which the bar colour changes from Warning to Error. Default: 0.85.
    /// </summary>
    property ThresholdWarn: Double read FThresholdWarn write FThresholdWarn;
  end;

{ TMicView }

  /// <summary>
  ///   ASCII microphone illustration, 3 rows tall.  Draws a rounded capsule
  ///   with a stand, coloured by Active state.  When Active, up to three
  ///   concentric arcs are drawn to the right of the capsule; their count and
  ///   colour track Level (same thresholds as TAudioMeterView).
  ///   Width: designed for LayoutConstraint Fixed(12).
  /// </summary>
  TMicView = class(TTuiWidget)
  strict private
    FActive: Boolean;
    FLevel:  Double;
    procedure SetActive(AValue: Boolean);
    procedure SetLevel(AValue: Double);
    function ArcColor: TTuiColor;
    function ArcCount: Integer;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas;
      const ARect: TRect); override;
  public
    /// <summary>
    ///   Creates the mic illustration widget; not focusable.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   True while recording is in progress; changes the capsule colour.
    /// </summary>
    property Active: Boolean read FActive write SetActive;
    /// <summary>
    ///   Current signal level [0.0, 1.0]; drives the arc count and colour.
    /// </summary>
    property Level: Double read FLevel write SetLevel;
  end;

{ TTranscriptView }

  /// <summary>
  ///   Scrollable word-wrapped log of transcribed phrases.  Appended text
  ///   is word-wrapped to the current widget width and auto-scrolls to the
  ///   tail.  Up/Down/PgUp/PgDn/Home/End scroll manually; End re-enables
  ///   follow-tail.  An optional hypothesis string is shown in dim italic.
  /// </summary>
  TTranscriptView = class(TTuiWidget)
  strict private
    FCachedDisplay: TList<string>;
    FCacheWidth: Integer;
    FFollowTail:     Boolean;
    FHypothesis:     string;
    FLines:          TList<string>;
    FScrollOffset:   Integer;
    FLastViewHeight: Integer;
    FLastTotalLines: Integer;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas;
      const ARect: TRect); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
  public
    constructor Create(AParent: TTuiWidget = nil);
    destructor Destroy; override;
    /// <summary>
    ///   Appends a final phrase to the transcript and triggers a redraw.
    /// </summary>
    procedure AppendText(const AText: string);
    /// <summary>
    ///   Sets a partial (hypothesis) phrase displayed in dim italic at the
    ///   bottom.  Pass an empty string to clear it.
    /// </summary>
    procedure SetHypothesis(const AText: string);
    /// <summary>
    ///   Removes all lines and the hypothesis from the transcript.
    /// </summary>
    procedure Clear;
  end;

implementation

uses
  Blinki.Core.Theme,
  System.Math,
  Recorder.Helpers;

const

  // Horizontal partial blocks U+258F (1/8) .. U+2588 (8/8)
  CBlocks: array[0..7] of string = (
    #$258F, #$258E, #$258D, #$258C,
    #$258B, #$258A, #$2589, #$2588);

  CPeakHoldMs  = 1500;  // time the peak marker stays at its maximum (ms)
  CPeakDecayMs = 2000;  // time for the marker to decay from peak to zero (ms)

{ TAudioMeterView }

constructor TAudioMeterView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FThresholdWarn := 0.6;
  FThresholdError := 0.85;
end;

function TAudioMeterView.ColorForValue(AValue: Double): TTuiColor;
begin
  if AValue < FThresholdWarn then
    Result := Theme.Success
  else if AValue < FThresholdError then
    Result := Theme.Warning
  else
    Result := Theme.Error;
end;

procedure TAudioMeterView.SetLevel(AValue: Double);
begin
  if AValue < 0.0 then
    AValue := 0.0;
  if AValue > 1.0 then
    AValue := 1.0;
  if FLevel = AValue then
    Exit;
  FLevel := AValue;
  if FLevel > FPeakHold then
  begin
    FPeakHold := FLevel;
    FPeakOriginal := FLevel;
    FPeakAccumMs := 0;
  end;
  Invalidate;
end;

procedure TAudioMeterView.DoTick(AElapsedMs: Integer);
begin
  if FPeakHold <= 0 then
    Exit;
  Inc(FPeakAccumMs, AElapsedMs);
  // Hold phase: keep the marker fixed
  if FPeakAccumMs < CPeakHoldMs then
    Exit;
  // Decay phase: linear fade from FPeakOriginal to 0 over CPeakDecayMs
  var LDecayElapsed := FPeakAccumMs - CPeakHoldMs;
  var LPrev := FPeakHold;
  if LDecayElapsed >= CPeakDecayMs then
    FPeakHold := 0
  else
    FPeakHold := FPeakOriginal * (1.0 - LDecayElapsed / CPeakDecayMs);
  if Abs(FPeakHold - LPrev) >= 0.01 then
    Invalidate;
end;

procedure TAudioMeterView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  var LBgStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  ACanvas.FillRect(ARect, ' ', LBgStyle);

  // Reserve the rightmost cell for the peak-hold marker when there is room
  var LBarWidth := ARect.Width;
  if LBarWidth > 2 then
    Dec(LBarWidth);

  // Draw the level bar using partial-block glyphs and a per-cell colour gradient
  var LFilledEighths := Round(FLevel * LBarWidth * 8);
  var LFullBlocks := LFilledEighths div 8;
  var LRemEighths := LFilledEighths mod 8;

  for var LX := 0 to LFullBlocks - 1 do
  begin
    if ARect.Left + LX >= ARect.Right then
      Break;
    // Each column is coloured according to where it sits on the 0..1 scale
    var LSegLevel := (LX + 1.0) / LBarWidth;
    ACanvas.WriteAt(ARect.Left + LX, ARect.Top, CBlocks[7],
      TTuiStyle.Create(ColorForValue(LSegLevel), Theme.Surface));
  end;

  var LPartialX := ARect.Left + LFullBlocks;
  if (LRemEighths > 0) and (LPartialX < ARect.Left + LBarWidth) then
    ACanvas.WriteAt(LPartialX, ARect.Top, CBlocks[LRemEighths - 1],
      TTuiStyle.Create(ColorForValue(FLevel), Theme.Surface));

  // Draw peak-hold marker
  if (FPeakHold > 0) and (ARect.Width > 2) then
  begin
    var LPeakX := ARect.Left + Round(FPeakHold * LBarWidth);
    if LPeakX >= ARect.Right then
      LPeakX := ARect.Right - 1;
    ACanvas.WriteAt(LPeakX, ARect.Top, '|',
      TTuiStyle.Create(ColorForValue(FPeakHold), Theme.Surface));
  end;
end;

// ============================================================================
// TMicView
// ============================================================================

const
  // Thresholds matching TAudioMeterView defaults.
  CMicWarnLevel  = 0.6;
  CMicErrorLevel = 0.85;

  // Capsule art lines (7 chars each; space + 5 chars + nothing or space).
  CMicTop    = ' ╭───╮';  // row 0: capsule top
  CMicMid    = ' │   │';  // row 1: capsule middle (inactive)
  CMicRec    = ' │REC│';  // row 1: capsule middle (active)
  CMicBot    = ' ╰─┬─╯';  // row 2: capsule bottom + stand stub

constructor TMicView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
end;

procedure TMicView.SetActive(AValue: Boolean);
begin
  if FActive = AValue then
    Exit;
  FActive := AValue;
  Invalidate;
end;

procedure TMicView.SetLevel(AValue: Double);
begin
  if AValue < 0.0 then
    AValue := 0.0;
  if AValue > 1.0 then
    AValue := 1.0;
  if FLevel = AValue then
    Exit;
  FLevel := AValue;
  if FActive then
    Invalidate;
end;

function TMicView.ArcColor: TTuiColor;
begin
  if FLevel < CMicWarnLevel then
    Result := Theme.Success
  else if FLevel < CMicErrorLevel then
    Result := Theme.Warning
  else
    Result := Theme.Error;
end;

function TMicView.ArcCount: Integer;
begin
  if FLevel < 0.2 then
    Result := 0
  else if FLevel < CMicWarnLevel then
    Result := 1
  else if FLevel < CMicErrorLevel then
    Result := 2
  else
    Result := 3;
end;

procedure TMicView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
const
  // Arc strings positioned after the capsule (pad to fixed width).
  CArcs: array[0..3] of string = ('     ', ' )   ', ' ))  ', ' ))) ');
  CWidth = 12;  // design width; hard-clip if ARect is narrower
begin
  if ARect.IsEmpty then
    Exit;

  var LBg := TTuiStyle.Create(Theme.Text, Theme.Surface);
  ACanvas.FillRect(ARect, ' ', LBg);

  // Cap the draw height at 3 rows; centre vertically if given more space.
  var LRows := Min(3, ARect.Height);
  var LStartY := ARect.Top + (ARect.Height - LRows) div 2;

  // Choose colours.
  var LBodyFg: TTuiColor;
  if FActive then
    LBodyFg := Theme.Error
  else
    LBodyFg := Theme.TextDim;
  var LBodyStyle := TTuiStyle.Create(LBodyFg, Theme.Surface);

  var LMidLine: string;
  if FActive then
    LMidLine := CMicRec
  else
    LMidLine := CMicMid;

  // Arcs are only drawn when active.
  var LArcStr := '';
  var LArcStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
  if FActive and (FLevel > 0.0) then
  begin
    LArcStr := CArcs[ArcCount];
    LArcStyle := TTuiStyle.Create(ArcColor, Theme.Surface);
  end
  else
    LArcStr := CArcs[0];

  var LLines: array[0..2] of string;
  LLines[0] := CMicTop + LArcStr;
  LLines[1] := LMidLine + CArcs[0]; // arcs only on top row
  LLines[2] := CMicBot + CArcs[0];

  // Row 0 carries the arc indicator; rows 1-2 are plain body.
  LLines[0] := CMicTop + LArcStr;

  for var LRow := 0 to LRows - 1 do
  begin
    var LY := LStartY + LRow;
    if LY >= ARect.Top + ARect.Height then
      Break;
    // Body part (first 7 chars).
    var LBodyPart := Copy(LLines[LRow], 1, 7);
    ACanvas.WriteAt(ARect.Left, LY, LBodyPart, LBodyStyle);
    // Arcs / filler (remaining chars up to CWidth).
    var LArcPart := Copy(LLines[LRow], 8, CWidth - 7);
    if LRow = 0 then
      ACanvas.WriteAt(ARect.Left + 7, LY, LArcPart, LArcStyle)
    else
      ACanvas.WriteAt(ARect.Left + 7, LY, LArcPart, LBg);
  end;
end;

// ============================================================================
// TTranscriptView
// ============================================================================

constructor TTranscriptView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FCachedDisplay := TList<string>.Create;
  FCacheWidth := -1;
  FLines := TList<string>.Create;
  FFollowTail := True;
  FLastViewHeight := 1;
end;

destructor TTranscriptView.Destroy;
begin
  FCachedDisplay.Free;
  FLines.Free;
  inherited;
end;

procedure TTranscriptView.DoInit;
begin
  SetFocusable(True);
end;

procedure TTranscriptView.AppendText(const AText: string);
begin
  FLines.Add(AText);
  FCacheWidth := -1;
  Invalidate;
end;

procedure TTranscriptView.SetHypothesis(const AText: string);
begin
  if FHypothesis = AText then
    Exit;
  FHypothesis := AText;
  Invalidate;
end;

procedure TTranscriptView.Clear;
begin
  FLines.Clear;
  FCacheWidth := -1;
  FHypothesis := '';
  FScrollOffset := 0;
  FFollowTail := True;
  Invalidate;
end;

procedure TTranscriptView.DoRender(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  var LBg := TTuiStyle.Create(TTuiColor.Default, Theme.Surface);
  ACanvas.FillRect(ARect, ' ', LBg);

  var LViewHeight := ARect.Height;
  var LBodyWidth := ARect.Width - 1;
  if LBodyWidth < 1 then
    LBodyWidth := 1;

  // rebuild message display cache when width or content changed
  if LBodyWidth <> FCacheWidth then
  begin
    FCachedDisplay.Clear;
    for var LPhrase in FLines do
      for var LWrapped in WrapWords(LPhrase, LBodyWidth) do
        FCachedDisplay.Add(LWrapped);
    FCacheWidth := LBodyWidth;
  end;

  // hypothesis wrapped live (changes with each speech event)
  var LHypoLines: TArray<string>;
  var LHasHypo := FHypothesis <> '';
  if LHasHypo then
  begin
    var LRaw := WrapWords(FHypothesis, LBodyWidth - 2);
    SetLength(LHypoLines, Length(LRaw));
    for var LJ := 0 to High(LRaw) do
      LHypoLines[LJ] := '  ' + LRaw[LJ];
  end;

  var LMsgLines := FCachedDisplay.Count;
  var LTotalLines := LMsgLines + Length(LHypoLines);

  // compute scroll offset
  var LScrollOff: Integer;
  if FFollowTail then
    LScrollOff := Max(0, LTotalLines - LViewHeight)
  else
    LScrollOff := Max(0, Min(FScrollOffset, LTotalLines - LViewHeight));

  FLastViewHeight := LViewHeight;
  FLastTotalLines := LTotalLines;

  // draw visible rows
  var LY := ARect.Top;
  var LI := LScrollOff;
  while (LI < LTotalLines) and (LY < ARect.Top + ARect.Height) do
  begin
    var LIsHypo := LHasHypo and (LI >= LMsgLines);
    var LText: string;
    if LIsHypo then
      LText := ' ' + Copy(LHypoLines[LI - LMsgLines], 1, ARect.Width - 1)
    else
      LText := ' ' + Copy(FCachedDisplay[LI], 1, ARect.Width - 1);
    var LStyle: TTuiStyle;
    if LIsHypo then
      LStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface, [taItalic])
    else
      LStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
    ACanvas.WriteAt(ARect.Left, LY, LText, LStyle);
    Inc(LY);
    Inc(LI);
  end;
end;

function TTranscriptView.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;

  var LMaxOffset := Max(0, FLastTotalLines - FLastViewHeight);

  case AEvent.Key.Code of
    kcUp:
    begin
      if FFollowTail then
      begin
        FFollowTail := False;
        FScrollOffset := Max(0, LMaxOffset - 1);
      end
      else
        FScrollOffset := Max(0, FScrollOffset - 1);
      Invalidate;
      Result := True;
    end;

    kcDown:
    begin
      if not FFollowTail then
      begin
        if FScrollOffset < LMaxOffset then
          Inc(FScrollOffset)
        else
          FFollowTail := True;
        Invalidate;
        Result := True;
      end;
    end;

    kcPageUp:
    begin
      var LStep := Max(1, FLastViewHeight - 1);
      if FFollowTail then
      begin
        FFollowTail := False;
        FScrollOffset := Max(0, LMaxOffset - LStep);
      end
      else
        FScrollOffset := Max(0, FScrollOffset - LStep);
      Invalidate;
      Result := True;
    end;

    kcPageDown:
    begin
      var LStep := Max(1, FLastViewHeight - 1);
      if not FFollowTail then
      begin
        FScrollOffset := FScrollOffset + LStep;
        if FScrollOffset >= LMaxOffset then
          FFollowTail := True;
        Invalidate;
        Result := True;
      end;
    end;

    kcHome:
    begin
      FFollowTail := False;
      FScrollOffset := 0;
      Invalidate;
      Result := True;
    end;

    kcEnd:
    begin
      FFollowTail := True;
      Invalidate;
      Result := True;
    end;
  end;
end;

end.
