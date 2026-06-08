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
{   Unit:        Blinki.Widgets.BarChart.pas                     }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiBarChart: vertical bar chart using Unicode sub-cell block characters.
///   Auto-scaling Y axis, per-bar labels, optional title, True Color per bar.
/// </summary>
unit Blinki.Widgets.BarChart;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget;

type

{ TTuiBarChartBar }

  /// <summary>
  ///   Data for a single bar in the chart.
  /// </summary>
  TTuiBarChartBar = record
    /// <summary>
    ///   Text displayed below the bar (truncated to the bar width).
    /// </summary>
    Caption: string;
    /// <summary>
    ///   Bar value. Must be >= 0.
    /// </summary>
    Value: Double;
    /// <summary>
    ///   Custom bar color. Valid only when HasColor = True.
    /// </summary>
    Color: TTuiColor;
    /// <summary>
    ///   If True, uses Color instead of the theme color.
    /// </summary>
    HasColor: Boolean;
  end;

{ TTuiBarChart }

  /// <summary>
  ///   Vertical bar chart widget. Uses Unicode block characters U+2581..U+2588 for
  ///   the top row of each bar (1/8 sub-cell resolution). Lower rows use the full
  ///   block U+2588. The Y axis is scaled automatically to the maximum bar value
  ///   (or MaxValue when set). Not focusable; does not handle input.
  /// </summary>
  TTuiBarChart = class(TTuiWidget)
  strict private
    FBars: array of TTuiBarChartBar;
    FBarCount: Integer;
    FTitle: string;
    FShowYAxis: Boolean;
    FShowLabels: Boolean;
    FMaxValue: Double;
    FColorOverride: Boolean;
    FDefaultColor: TTuiColor;
    procedure SetTitle(const AValue: string);
    procedure SetShowYAxis(AValue: Boolean);
    procedure SetShowLabels(AValue: Boolean);
    procedure SetMaxValue(AValue: Double);
    procedure SetDefaultColor(const AValue: TTuiColor);
    function  GetEffectiveMax: Double;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the chart. ShowYAxis: True; ShowLabels: True; MaxValue: -1 (auto).
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Adds a bar using the theme color. Value must be >= 0.
    /// </summary>
    procedure AddBar(const ACaption: string; AValue: Double); overload;
    /// <summary>
    ///   Adds a bar with a custom color. Value must be >= 0.
    /// </summary>
    procedure AddBar(const ACaption: string; AValue: Double; const AColor: TTuiColor); overload;
    /// <summary>
    ///   Removes all bars.
    /// </summary>
    procedure Clear;
    /// <summary>
    ///   Chart title displayed at the top. Empty string means no title.
    /// </summary>
    property Title: string read FTitle write SetTitle;
    /// <summary>
    ///   If True (default), shows the Y axis with min/max values.
    /// </summary>
    property ShowYAxis: Boolean read FShowYAxis write SetShowYAxis;
    /// <summary>
    ///   If True (default), shows labels below the bars.
    /// </summary>
    property ShowLabels: Boolean read FShowLabels write SetShowLabels;
    /// <summary>
    ///   Maximum value for the Y axis scale. -1 = automatic calculation.
    ///   Useful for comparing different charts on the same scale.
    /// </summary>
    property MaxValue: Double read FMaxValue write SetMaxValue;
    /// <summary>
    ///   Default color for bars without a custom color. Once set explicitly,
    ///   the theme no longer overrides it.
    /// </summary>
    property DefaultColor: TTuiColor read FDefaultColor write SetDefaultColor;
  end;

implementation

uses
  System.Math;

{ Constants }

const

  // Vertical blocks U+2581..U+2588 — increasing height from 1/8 to 8/8
  CBlocksVert: array[0..7] of string = (
    #$2581, #$2582, #$2583, #$2584,
    #$2585, #$2586, #$2587, #$2588);

  CYAxisWidth = 6;  // e.g. "100.0 " — 5 digits + separator

{ TTuiBarChart }

constructor TTuiBarChart.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FShowYAxis := True;
  FShowLabels := True;
  FMaxValue := -1;
  FDefaultColor := Theme.Primary;
end;

procedure TTuiBarChart.DoApplyTheme(const ATheme: TTuiTheme);
begin
  if not FColorOverride then
    FDefaultColor := ATheme.Primary;
end;

function TTuiBarChart.GetEffectiveMax: Double;
begin
  if FMaxValue >= 0 then
  begin
    Result := FMaxValue;
    Exit;
  end;
  if FBarCount = 0 then
  begin
    Result := 1;
    Exit;
  end;
  Result := FBars[0].Value;
  for var LIndex := 1 to FBarCount - 1 do
    if FBars[LIndex].Value > Result then
      Result := FBars[LIndex].Value;
  if Result = 0 then
    Result := 1;
end;

procedure TTuiBarChart.AddBar(const ACaption: string; AValue: Double);
begin
  if AValue < 0 then
    AValue := 0;
  var LBar: TTuiBarChartBar;
  LBar.Caption := ACaption;
  LBar.Value := AValue;
  LBar.HasColor := False;
  LBar.Color := FDefaultColor;
  if FBarCount >= Length(FBars) then
    SetLength(FBars, Max(8, FBarCount * 2));
  FBars[FBarCount] := LBar;
  Inc(FBarCount);
  Invalidate;
end;

procedure TTuiBarChart.AddBar(const ACaption: string; AValue: Double;
  const AColor: TTuiColor);
begin
  if AValue < 0 then
    AValue := 0;
  var LBar: TTuiBarChartBar;
  LBar.Caption := ACaption;
  LBar.Value := AValue;
  LBar.HasColor := True;
  LBar.Color := AColor;
  if FBarCount >= Length(FBars) then
    SetLength(FBars, Max(8, FBarCount * 2));
  FBars[FBarCount] := LBar;
  Inc(FBarCount);
  Invalidate;
end;

procedure TTuiBarChart.Clear;
begin
  FBarCount := 0;
  Invalidate;
end;

procedure TTuiBarChart.SetTitle(const AValue: string);
begin
  if FTitle = AValue then
    Exit;
  FTitle := AValue;
  Invalidate;
end;

procedure TTuiBarChart.SetShowYAxis(AValue: Boolean);
begin
  if FShowYAxis = AValue then
    Exit;
  FShowYAxis := AValue;
  Invalidate;
end;

procedure TTuiBarChart.SetShowLabels(AValue: Boolean);
begin
  if FShowLabels = AValue then
    Exit;
  FShowLabels := AValue;
  Invalidate;
end;

procedure TTuiBarChart.SetMaxValue(AValue: Double);
begin
  if FMaxValue = AValue then
    Exit;
  FMaxValue := AValue;
  Invalidate;
end;

procedure TTuiBarChart.SetDefaultColor(const AValue: TTuiColor);
begin
  if FDefaultColor = AValue then
    Exit;
  FDefaultColor := AValue;
  FColorOverride := True;
  Invalidate;
end;

procedure TTuiBarChart.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  var LBgStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  var LTextStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  var LDimStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
  ACanvas.FillRect(ARect, ' ', LBgStyle);

  if FBarCount = 0 then
    Exit;

  var LEffMax := GetEffectiveMax;

  // Y axis
  var LYAxisW: Integer;
  if FShowYAxis then
    LYAxisW := CYAxisWidth
  else
    LYAxisW := 0;

  var LContentX := ARect.Left + LYAxisW;
  var LContentW := ARect.Width - LYAxisW;

  // Title row
  var LTitleRow := ARect.Top;
  var LBarAreaTop: Integer;
  if FTitle <> '' then
  begin
    var LFmtStr := FTitle;
    if Length(LFmtStr) > ARect.Width then
      LFmtStr := Copy(LFmtStr, 1, ARect.Width);
    ACanvas.WriteAt(
      ARect.Left + (ARect.Width - Length(LFmtStr)) div 2,
      LTitleRow, LFmtStr, LTextStyle);
    LBarAreaTop := LTitleRow + 1;
  end
  else
    LBarAreaTop := LTitleRow;

  // Bar label row (last)
  var LLabelRow := ARect.Bottom - 1;
  var LBarAreaBottom: Integer;
  if FShowLabels then
    LBarAreaBottom := LLabelRow - 1
  else
    LBarAreaBottom := LLabelRow;

  var LBarH := LBarAreaBottom - LBarAreaTop + 1;
  if LBarH < 1 then
    Exit;

  // Bar width: N bars with 1 space between each
  // LBarW * N + (N-1) <= LContentW  =>  LBarW = (LContentW - N + 1) / N
  var LBarW: Integer;
  if FBarCount = 1 then
    LBarW := LContentW
  else
    LBarW := Max(1, (LContentW - (FBarCount - 1)) div FBarCount);
  var LSpacing := 1;

  // Y axis: write max at the top and 0 at the bottom of the axis column
  if FShowYAxis then
  begin
    // Maximum value
    var LFmtStr := Format('%-5s', [FormatFloat('0.##', LEffMax)]);
    if Length(LFmtStr) > LYAxisW - 1 then
      LFmtStr := Copy(LFmtStr, 1, LYAxisW - 1);
    ACanvas.WriteAt(ARect.Left, LBarAreaTop, LFmtStr, LDimStyle);
    // Zero value
    LFmtStr := Format('%-5s', ['0']);
    ACanvas.WriteAt(ARect.Left, LBarAreaBottom, LFmtStr, LDimStyle);
    // Vertical separator
    for var LRow := LBarAreaTop to LBarAreaBottom do
      ACanvas.WriteAt(ARect.Left + LYAxisW - 1, LRow, #$2502, LDimStyle);
  end;

  // Draw the bars
  for var LIndex := 0 to FBarCount - 1 do
  begin
    var LBarX := LContentX + LIndex * (LBarW + LSpacing);
    if LBarX >= ARect.Right then
      Break;

    var LBarColor: TTuiColor;
    if FBars[LIndex].HasColor then
      LBarColor := FBars[LIndex].Color
    else
      LBarColor := FDefaultColor;
    var LBarStyle := TTuiStyle.Create(LBarColor, Theme.Surface);

    // Total number of eighths for the bar
    var LEighths := Round(FBars[LIndex].Value / LEffMax * LBarH * 8);
    var LFullBlocks := LEighths div 8;
    var LRem := LEighths mod 8;

    // Draw each row of the bar area
    var LRowFromBottom: Integer;
    for var LRow := LBarAreaTop to LBarAreaBottom do
    begin
      // LRowFromBottom: 0 = bottom, LBarH-1 = top
      LRowFromBottom := LBarAreaBottom - LRow;

      if LRowFromBottom < LFullBlocks then
      begin
        // Full block: fills all columns of the bar
        for var LCol := 0 to Min(LBarW, ARect.Right - LBarX) - 1 do
          ACanvas.WriteAt(LBarX + LCol, LRow, CBlocksVert[7], LBarStyle);
      end
      else if (LRowFromBottom = LFullBlocks) and (LRem > 0) then
      begin
        // Partial row (top of the bar)
        for var LCol := 0 to Min(LBarW, ARect.Right - LBarX) - 1 do
          ACanvas.WriteAt(LBarX + LCol, LRow, CBlocksVert[LRem - 1], LBarStyle);
      end;
      // else: empty row (already covered by FillRect)
    end;

    // Label below the bar
    if FShowLabels and (LLabelRow < ARect.Bottom) then
    begin
      var LCaption := FBars[LIndex].Caption;
      if Length(LCaption) > LBarW then
        LCaption := Copy(LCaption, 1, LBarW);
      // Center within the bar width
      var LCol := (LBarW - Length(LCaption)) div 2;
      if (LBarX + LCol) < ARect.Right then
        ACanvas.WriteAt(LBarX + LCol, LLabelRow, LCaption, LDimStyle);
    end;
  end;
end;

end.
