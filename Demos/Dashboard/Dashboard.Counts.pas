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
{   Unit:        Dashboard.Counts.pas                            }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Dashboard demo — TDashboardCounts: the "Log Counts" panel widget.
///   Left half: vertical bar chart histogram with sub-cell Unicode blocks.
///   Right half: Min/Max label and a colour-coded severity count table.
/// </summary>
unit Dashboard.Counts;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Geometry,
  Blinki.Core.Style,
  Blinki.Core.Widget,
  Dashboard.Model;

type

{ TDashboardCounts }

  /// <summary>
  ///   Focusable panel that shows the histogram and per-severity log counts.
  /// </summary>
  TDashboardCounts = class(TTuiWidget)
  strict private
    FModel: TDashboardModel;
    FSectionName: string;
    procedure DrawHistogram(const ACanvas: TTuiCanvas; const AInner: TRect;
      AHistWidth, AMaxVal: Integer);
    procedure DrawSevRow(const ACanvas: TTuiCanvas; AX, AY: Integer;
      const ALabel: string; AValue: Integer; const AColor: TTuiColor);
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Creates the Counts panel. AModel is a reference (not owned).
    /// </summary>
    constructor Create(AParent: TTuiWidget; AModel: TDashboardModel);
    /// <summary>
    ///   Short name used by the status bar.
    /// </summary>
    property SectionName: string read FSectionName;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Blinki.Core.Ansi,
  Dashboard.Consts,
  Dashboard.Helpers;

{ TDashboardCounts }

constructor TDashboardCounts.Create(AParent: TTuiWidget; AModel: TDashboardModel);
begin
  inherited Create(AParent);
  FModel := AModel;
  FSectionName := 'Counts';
end;

procedure TDashboardCounts.DoInit;
begin
  SetFocusable(True);
end;

procedure TDashboardCounts.DrawHistogram(const ACanvas: TTuiCanvas;
  const AInner: TRect; AHistWidth, AMaxVal: Integer);
begin
  var LH := AInner.Height;
  var LHistStyle := TTuiStyle.Create(CColorHistogram, CColorBlack);

  for var LI := 0 to AHistWidth - 1 do
  begin
    if LI >= Length(FModel.Histogram) then
      Break;

    var LBarX := AInner.Left + LI;
    var LBarVal := FModel.Histogram[LI];

    var LBarHeightF := 0.0;
    if AMaxVal > 0 then
      LBarHeightF := LBarVal / AMaxVal * LH;

    var LFullChars := Trunc(LBarHeightF);
    var LFrac := LBarHeightF - LFullChars;
    var LSubLevel := Round(LFrac * 8);
    if LSubLevel > 8 then
      LSubLevel := 8;

    // Draw full blocks from bottom up
    for var LRow := 0 to LFullChars - 1 do
    begin
      var LY := AInner.Bottom - 1 - LRow;
      if (LY >= AInner.Top) and (LY < AInner.Bottom) then
        ACanvas.WriteAt(LBarX, LY, CGlyphBlockFull, LHistStyle);
    end;

    // Draw sub-cell block above the full bars
    if LSubLevel > 0 then
    begin
      var LY := AInner.Bottom - 1 - LFullChars;
      if (LY >= AInner.Top) and (LY < AInner.Bottom) then
      begin
        var LSubChar: string;
        case LSubLevel of
          1: LSubChar := CGlyphBlock1;
          2: LSubChar := CGlyphBlock2;
          3: LSubChar := CGlyphBlock3;
          4: LSubChar := CGlyphBlock4;
          5: LSubChar := CGlyphBlock5;
          6: LSubChar := CGlyphBlock6;
          7: LSubChar := CGlyphBlock7;
          else
            LSubChar := CGlyphBlockFull;
        end;
        ACanvas.WriteAt(LBarX, LY, LSubChar, LHistStyle);
      end;
    end;
  end;
end;

procedure TDashboardCounts.DrawSevRow(const ACanvas: TTuiCanvas; AX, AY: Integer;
  const ALabel: string; AValue: Integer; const AColor: TTuiColor);
begin
  var LStyle := TTuiStyle.Create(AColor, CColorBlack);
  var LStr := Format('%-5s : %4d', [ALabel, AValue]);
  ACanvas.WriteAt(AX, AY, LStr, LStyle);
end;

procedure TDashboardCounts.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
var
  LBorderStyle, LBgStyle, LDimStyle, LTextStyle: TTuiStyle;
  LInner: TRect;
  LMaxVal, LMinVal: Integer;
  LHistWidth, LStatsX: Integer;
begin
  if Focused then
    LBorderStyle := TTuiStyle.Create(CColorBorderFocus, CColorBlack)
  else
    LBorderStyle := TTuiStyle.Create(CColorBorderNormal, CColorBlack);

  LBgStyle := TTuiStyle.Create(CColorText, CColorBlack);
  LDimStyle := TTuiStyle.Create(CColorDim, CColorBlack);
  LTextStyle := TTuiStyle.Create(CColorText, CColorBlack);

  ACanvas.DrawBox(ARect, bsRounded, CPanelLogCounts, LBorderStyle);
  LInner := ARect.Interior;
  if LInner.IsEmpty then
    Exit;

  ACanvas.FillRect(LInner, ' ', LBgStyle);

  ACanvas.PushClip(LInner);
  try
    // Compute min and max from histogram
    LMaxVal := 0;
    LMinVal := MaxInt;
    for var LV in FModel.Histogram do
    begin
      if LV > LMaxVal then
        LMaxVal := LV;
      if LV < LMinVal then
        LMinVal := LV;
    end;
    if (LMinVal = MaxInt) or (Length(FModel.Histogram) = 0) then
      LMinVal := 0;

    LHistWidth := Min(CHistogramBars, LInner.Width div 2);
    LStatsX := LInner.Left + LHistWidth + 1;

    // Draw vertical histogram on the left
    if LHistWidth > 0 then
      DrawHistogram(ACanvas, TRect.Create(LInner.Left, LInner.Top,
        LInner.Left + LHistWidth, LInner.Bottom), LHistWidth, LMaxVal);

    // Min / Max label — right-aligned in the inner area
    var LMinMaxStr := Format('Min: %d  |  Max: %d', [LMinVal, LMaxVal]);
    var LMinMaxX := LInner.Right - Length(LMinMaxStr);
    if LMinMaxX < LStatsX then
      LMinMaxX := LStatsX;
    ACanvas.WriteAt(LMinMaxX, LInner.Top, LMinMaxStr, LTextStyle);

    // Severity table starting at row 2 (one blank row gap after Min/Max)
    var LSevY := LInner.Top + 2;
    if LSevY >= LInner.Bottom then
      Exit;

    DrawSevRow(ACanvas, LStatsX, LSevY, CSevFatal, FModel.Severities.Fatal, CColorSevFatal);
    Inc(LSevY);
    if LSevY < LInner.Bottom then
      DrawSevRow(ACanvas, LStatsX, LSevY, CSevError, FModel.Severities.Error, CColorSevError);
    Inc(LSevY);
    if LSevY < LInner.Bottom then
      DrawSevRow(ACanvas, LStatsX, LSevY, CSevWarn, FModel.Severities.Warn, CColorSevWarn);
    Inc(LSevY);
    if LSevY < LInner.Bottom then
      DrawSevRow(ACanvas, LStatsX, LSevY, CSevInfo, FModel.Severities.Info, CColorSevInfo);
    Inc(LSevY);
    if LSevY < LInner.Bottom then
      DrawSevRow(ACanvas, LStatsX, LSevY, CSevDebug, FModel.Severities.Debug, CColorSevDebug);
    Inc(LSevY);
    if LSevY < LInner.Bottom then
      DrawSevRow(ACanvas, LStatsX, LSevY, CSevTrace, FModel.Severities.Trace, CColorSevTrace);
    Inc(LSevY);

    // Separator line
    if LSevY < LInner.Bottom then
    begin
      var LRuleWidth := Min(12, LInner.Right - LStatsX);
      var LRuleStr := StringOfChar(CGlyphHRule, LRuleWidth);
      ACanvas.WriteAt(LStatsX, LSevY, LRuleStr, LDimStyle);
      Inc(LSevY);
    end;

    // Total row
    if LSevY < LInner.Bottom then
      DrawSevRow(ACanvas, LStatsX, LSevY, CSevTotal,
        FModel.Severities.Total, CColorSevTotal);
  finally
    ACanvas.PopClip;
  end;
end;

end.
