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
{   Unit:        Blinki.Widgets.Sparkline.pas                    }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiSparkline: numeric series displayed as a single-row inline mini-chart.
///   Uses Unicode vertical block characters (U+2581..U+2588) to represent levels.
/// </summary>
unit Blinki.Widgets.Sparkline;

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

{ TTuiSparkline }

  /// <summary>
  ///   Single-row mini-chart that displays a series of numeric values.
  ///   Points are stored in a ring buffer of MaxPoints elements;
  ///   the most recent ones occupy the rightmost cells. Can be updated in
  ///   real time by calling AddPoint from the application's OnTimer handler.
  ///   Not focusable; does not handle input.
  /// </summary>
  TTuiSparkline = class(TTuiWidget)
  strict private
    FData: array of Double;
    FCount: Integer;
    FHead: Integer;
    FMaxPoints: Integer;
    FColor: TTuiColor;
    FColorOverride: Boolean;
    FAutoScale: Boolean;
    FMinValue: Double;
    FMaxValue: Double;
    procedure SetMaxPoints(AValue: Integer);
    procedure SetColor(const AValue: TTuiColor);
    procedure SetAutoScale(AValue: Boolean);
    procedure SetMinValue(AValue: Double);
    procedure SetMaxValue(AValue: Double);
    function  GetPoint(AIndexFromOldest: Integer): Double;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    /// Creates the sparkline. MaxPoints: 60; AutoScale: True; Color: Theme.Primary.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    /// Adds a point to the ring buffer; the oldest points are overwritten.
    /// </summary>
    procedure AddPoint(AValue: Double);
    /// <summary>
    /// Replaces all data with the supplied array (truncated to MaxPoints).
    /// </summary>
    procedure SetData(const AValues: array of Double);
    /// <summary>
    /// Clears the data buffer.
    /// </summary>
    procedure Clear;
    /// <summary>
    /// Maximum capacity of the ring buffer. Default: 60.
    /// </summary>
    property MaxPoints: Integer   read FMaxPoints  write SetMaxPoints;
    /// <summary>
    ///   Glyph color. Once set explicitly, the theme no longer overrides it.
    /// </summary>
    property Color: TTuiColor read FColor write SetColor;
    /// <summary>
    /// When True (default), the min/max scale is computed automatically from the data.
    /// </summary>
    property AutoScale: Boolean read FAutoScale write SetAutoScale;
    /// <summary>
    /// Minimum value for manual scaling (used only when AutoScale = False).
    /// </summary>
    property MinValue: Double read FMinValue write SetMinValue;
    /// <summary>
    /// Maximum value for manual scaling (used only when AutoScale = False).
    /// </summary>
    property MaxValue: Double read FMaxValue write SetMaxValue;
  end;

implementation

uses
  System.Math;

const

  // Vertical blocks U+2581..U+2588 — increasing height from 1/8 to 8/8
  CBlocksVert: array[0..7] of string = (
    #$2581, #$2582, #$2583, #$2584,
    #$2585, #$2586, #$2587, #$2588);

{ TTuiSparkline }

constructor TTuiSparkline.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FMaxPoints := 60;
  FAutoScale := True;
  FMaxValue := 1.0;
  FColor := Theme.Primary;
  SetLength(FData, FMaxPoints);
end;

procedure TTuiSparkline.DoApplyTheme(const ATheme: TTuiTheme);
begin
  if not FColorOverride then
    FColor := ATheme.Primary;
end;

function TTuiSparkline.GetPoint(AIndexFromOldest: Integer): Double;
begin
  Result := FData[(FHead - FCount + AIndexFromOldest + FMaxPoints * 2) mod FMaxPoints];
end;

procedure TTuiSparkline.AddPoint(AValue: Double);
begin
  if FMaxPoints = 0 then
    Exit;
  FData[FHead] := AValue;
  FHead := (FHead + 1) mod FMaxPoints;
  if FCount < FMaxPoints then
    Inc(FCount);
  Invalidate;
end;

procedure TTuiSparkline.SetData(const AValues: array of Double);
begin
  FCount := 0;
  FHead := 0;
  for var LIndex := 0 to Length(AValues) - 1 do
    AddPoint(AValues[LIndex]);
end;

procedure TTuiSparkline.Clear;
begin
  FCount := 0;
  FHead := 0;
  Invalidate;
end;

procedure TTuiSparkline.SetMaxPoints(AValue: Integer);
begin
  if AValue < 1 then
    AValue := 1;
  if FMaxPoints = AValue then
    Exit;
  var LCount := Min(FCount, AValue);
  // Save the most recent points before resizing the buffer
  var LSaved: array of Double;
  SetLength(LSaved, LCount);
  for var LIndex := 0 to LCount - 1 do
    LSaved[LIndex] := GetPoint(FCount - LCount + LIndex);
  SetLength(FData, AValue);
  for var LIndex := 0 to LCount - 1 do
    FData[LIndex] := LSaved[LIndex];
  FMaxPoints := AValue;
  FCount := LCount;
  FHead := LCount mod AValue;
  Invalidate;
end;

procedure TTuiSparkline.SetColor(const AValue: TTuiColor);
begin
  if FColor = AValue then
    Exit;
  FColor := AValue;
  FColorOverride := True;
  Invalidate;
end;

procedure TTuiSparkline.SetAutoScale(AValue: Boolean);
begin
  if FAutoScale = AValue then
    Exit;
  FAutoScale := AValue;
  Invalidate;
end;

procedure TTuiSparkline.SetMinValue(AValue: Double);
begin
  if FMinValue = AValue then
    Exit;
  FMinValue := AValue;
  Invalidate;
end;

procedure TTuiSparkline.SetMaxValue(AValue: Double);
begin
  if FMaxValue = AValue then
    Exit;
  FMaxValue := AValue;
  Invalidate;
end;

procedure TTuiSparkline.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  var LBgStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  ACanvas.FillRect(ARect, ' ', LBgStyle);

  if FCount = 0 then
    Exit;

  var LStyle := TTuiStyle.Create(FColor, Theme.Surface);

  var LMin: Double;
  var LMax: Double;
  if FAutoScale then
  begin
    LMin := GetPoint(0);
    LMax := LMin;
    for var LIndex := 1 to FCount - 1 do
    begin
      var LV := GetPoint(LIndex);
      if LV < LMin then
        LMin := LV;
      if LV > LMax then
        LMax := LV;
    end;
  end
  else
  begin
    LMin := FMinValue;
    LMax := FMaxValue;
  end;

  var LRange := LMax - LMin;
  if LRange = 0 then
    LRange := 1;

  var LWidth := ARect.Width;
  var LVisible := Min(FCount, LWidth);
  var LOffset := FCount - LVisible;

  for var LX := 0 to LVisible - 1 do
  begin
    var LV := GetPoint(LOffset + LX);
    var LBlockIdx := Round((LV - LMin) / LRange * 7);
    if LBlockIdx < 0 then
      LBlockIdx := 0;
    if LBlockIdx > 7 then
      LBlockIdx := 7;
    ACanvas.WriteAt(ARect.Left + (LWidth - LVisible) + LX, ARect.Top,
      CBlocksVert[LBlockIdx], LStyle);
  end;
end;

end.
