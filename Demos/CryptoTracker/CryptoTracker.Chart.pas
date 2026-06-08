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
{   Unit:        CryptoTracker.Chart.pas                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   CryptoTrackerDemo -- TCryptoChart: candlestick chart widget that renders
///   OHLC candles with Unicode block characters, a Y-axis price label column,
///   and a one-row trend mini-histogram at the bottom.
/// </summary>
unit CryptoTracker.Chart;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Geometry,
  Blinki.Core.Widget,
  CryptoTracker.Model;

type

{ TCryptoChart }

  /// <summary>
  ///   Full-area candlestick chart widget.
  ///   Call SetData to push a new title and candle array; the widget redraws
  ///   on the next frame. VisibleCandleCount returns how many candles fit in
  ///   the current widget area so callers can request the right slice.
  /// </summary>
  TCryptoChart = class(TTuiWidget)
  strict private
    FCandles: TArray<TCryptoCandle>;
    FTitle: string;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Updates the chart title and replaces the current candle series,
    ///   then invalidates the widget so it redraws on the next frame.
    /// </summary>
    procedure SetData(const ATitle: string;
      const ACandles: TArray<TCryptoCandle>);
    /// <summary>
    ///   Returns the number of candles that fit in the current widget area.
    ///   Before the first render this returns CDefaultCandleCount as a fallback.
    /// </summary>
    function VisibleCandleCount: Integer;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  Blinki.Core.Ansi,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  CryptoTracker.Consts,
  CryptoTracker.Helpers;

const
  // Unicode block characters for the trend bar (U+2581..U+2588)
  CTrendChars: array[0..7] of Char = (
    #$2581, #$2582, #$2583, #$2584, #$2585, #$2586, #$2587, #$2588);

// Maps a price value to a 0-based row index within the chart area.
// Row 0 = top (highest price), ARows-1 = bottom (lowest price).
function PriceToRow(APrice, AMin, AMax: Double; ARows: Integer): Integer;
begin
  if (AMax <= AMin) or (ARows <= 1) then
  begin
    Result := ARows div 2;
    Exit;
  end;
  Result := ARows - 1 - Round((APrice - AMin) / (AMax - AMin) * (ARows - 1));
  if Result < 0 then
    Result := 0;
  if Result >= ARows then
    Result := ARows - 1;
end;

{ TCryptoChart }

procedure TCryptoChart.SetData(const ATitle: string;
  const ACandles: TArray<TCryptoCandle>);
begin
  FTitle := ATitle;
  FCandles := ACandles;
  Invalidate;
end;

function TCryptoChart.VisibleCandleCount: Integer;
begin
  if LastRect.IsEmpty then
    Result := CDefaultCandleCount
  else
    Result := Max(10, LastRect.Width - 2 - CPriceLabelWidth);
end;

procedure TCryptoChart.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
var
  LBorderStyle, LAxisStyle: TTuiStyle;
  LInner: TRect;
  LCandleRows, LVisibleCount, LStartIdx: Integer;
  LMin, LMax, LMid, LRange: Double;
  LTrendY, LCandleAreaLeft, LCandleAreaTop: Integer;
  LI: Integer;
begin
  // Draw the rounded border with the asset title
  if Focused then
    LBorderStyle := TTuiStyle.Create(Theme.Primary, Theme.Background)
  else
    LBorderStyle := TTuiStyle.Create(Theme.Border, Theme.Background);
  var LDisplayTitle: string;
  if FTitle <> '' then
    LDisplayTitle := ' ' + FTitle + ' '
  else
    LDisplayTitle := '';
  ACanvas.DrawBox(ARect, bsRounded, LDisplayTitle, LBorderStyle);

  if Length(FCandles) = 0 then
    Exit;

  LInner := ARect.Interior;
  if (LInner.Width < CPriceLabelWidth + 2) or (LInner.Height < 3) then
    Exit;

  ACanvas.PushClip(LInner);
  try
    LAxisStyle := TTuiStyle.Create(Theme.TextDim, Theme.Background);

    // Bottom row is the Trend strip; everything above it is the candle area
    LTrendY := LInner.Bottom - 1;
    LCandleRows := LInner.Height - 1;
    LCandleAreaLeft := LInner.Left + CPriceLabelWidth;
    LCandleAreaTop := LInner.Top;
    LVisibleCount := LInner.Width - CPriceLabelWidth;
    if LVisibleCount < 1 then
      LVisibleCount := 1;

    // Pick the visible slice (most recent on the right)
    LStartIdx := Length(FCandles) - LVisibleCount;
    if LStartIdx < 0 then
      LStartIdx := 0;

    // Price range from all visible candles
    LMin := FCandles[LStartIdx].Low;
    LMax := FCandles[LStartIdx].High;
    for LI := LStartIdx + 1 to Length(FCandles) - 1 do
    begin
      if FCandles[LI].High > LMax then
        LMax := FCandles[LI].High;
      if FCandles[LI].Low < LMin then
        LMin := FCandles[LI].Low;
    end;
    // Add 5% margin so candles do not touch the border
    LRange := LMax - LMin;
    if LRange < 1e-10 then
      LRange := 1.0;
    LMax := LMax + LRange * 0.05;
    LMin := LMin - LRange * 0.05;
    if LMin < 0 then
      LMin := 0;
    LMid := (LMax + LMin) * 0.5;

    // Y-axis price labels (top / mid / bottom of candle area)
    var LMaxStr := FormatChartPrice(LMax).PadLeft(CPriceLabelWidth - 1);
    ACanvas.WriteAt(LInner.Left, LCandleAreaTop,
      Copy(LMaxStr, 1, CPriceLabelWidth - 1), LAxisStyle);
    if LCandleRows > 2 then
    begin
      var LMidStr := FormatChartPrice(LMid).PadLeft(CPriceLabelWidth - 1);
      ACanvas.WriteAt(LInner.Left, LCandleAreaTop + LCandleRows div 2,
        Copy(LMidStr, 1, CPriceLabelWidth - 1), LAxisStyle);
    end;
    if LCandleRows > 1 then
    begin
      var LMinStr := FormatChartPrice(LMin).PadLeft(CPriceLabelWidth - 1);
      ACanvas.WriteAt(LInner.Left, LCandleAreaTop + LCandleRows - 1,
        Copy(LMinStr, 1, CPriceLabelWidth - 1), LAxisStyle);
    end;

    // Candles — one column per candle
    for var LCol := 0 to LVisibleCount - 1 do
    begin
      var LCandleIdx := LStartIdx + LCol;
      if LCandleIdx >= Length(FCandles) then
        Break;
      var LCandle := FCandles[LCandleIdx];
      var LIsBullish := LCandle.Close >= LCandle.Open;
      var LCandleStyle: TTuiStyle;
      if LIsBullish then
        LCandleStyle := TTuiStyle.Create(Theme.Success, Theme.Background)
      else
        LCandleStyle := TTuiStyle.Create(Theme.Error, Theme.Background);

      var LHighRow := PriceToRow(LCandle.High, LMin, LMax, LCandleRows);
      var LLowRow := PriceToRow(LCandle.Low, LMin, LMax, LCandleRows);
      var LTopBody := PriceToRow(Max(LCandle.Open, LCandle.Close), LMin, LMax, LCandleRows);
      var LBotBody := PriceToRow(Min(LCandle.Open, LCandle.Close), LMin, LMax, LCandleRows);
      var LX := LCandleAreaLeft + LCol;

      for var LRow := 0 to LCandleRows - 1 do
      begin
        var LCh: Char;
        if (LRow >= LTopBody) and (LRow <= LBotBody) then
          LCh := #$2588    // █ full block = candle body
        else if (LRow >= LHighRow) and (LRow <= LLowRow) then
          LCh := #$2502    // │ light vertical = wick
        else
          LCh := ' ';
        if LCh <> ' ' then
          ACanvas.WriteAt(LX, LCandleAreaTop + LRow, LCh, LCandleStyle);
      end;
    end;

    // Trend label in the price column
    ACanvas.WriteAt(LInner.Left, LTrendY, CTrendLabel, LAxisStyle);

    // Trend bar: one block character per candle, scaled by body range
    var LTotalBody := 0.0;
    for LI := LStartIdx to Length(FCandles) - 1 do
      LTotalBody := LTotalBody + Abs(FCandles[LI].Close - FCandles[LI].Open);
    var LAvgBody := LTotalBody / Max(1, Length(FCandles) - LStartIdx);

    for var LCol := 0 to LVisibleCount - 1 do
    begin
      var LCandleIdx := LStartIdx + LCol;
      if LCandleIdx >= Length(FCandles) then
        Break;
      var LCandle := FCandles[LCandleIdx];
      var LBodyRange := Abs(LCandle.Close - LCandle.Open);
      var LBarIdx := Min(7, Max(0, Round(LBodyRange / Max(1e-10, LAvgBody) * 3.5)));
      var LBarChar := CTrendChars[LBarIdx];
      var LBarColor: TTuiColor;
      if LCandle.Close >= LCandle.Open then
        LBarColor := Theme.Success
      else
        LBarColor := Theme.Error;
      var LBarStyle := TTuiStyle.Create(LBarColor, Theme.Background);
      ACanvas.WriteAt(LCandleAreaLeft + LCol, LTrendY, LBarChar, LBarStyle);
    end;

  finally
    ACanvas.PopClip;
  end;
end;

end.
