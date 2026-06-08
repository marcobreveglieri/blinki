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
{   Unit:        Blinki.Widgets.Gauge.pas                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TTuiGauge widget: progress bar with dynamic colour and optional animation.
///   The colour transitions from Success to Warning to Error based on configurable
///   thresholds.
/// </summary>
unit Blinki.Widgets.Gauge;

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

{ TTuiGauge }

  /// <summary>
  ///   Progress bar with dynamic colour and animated transition toward the target value.
  ///   The colour varies based on the current value: Success below ThresholdWarn,
  ///   Warning between ThresholdWarn and ThresholdError, Error above ThresholdError.
  ///   Uses the same horizontal partial-block glyphs as TTuiProgressBar (U+258F..U+2588).
  ///   Not focusable; does not handle input.
  /// </summary>
  TTuiGauge = class(TTuiWidget)
  strict private
    FTargetValue: Double;
    FDisplayValue: Double;
    FAnimated: Boolean;
    FAnimDurMs: Integer;
    FAnimRemainMs: Integer;
    FShowPercent: Boolean;
    FThresholdWarn: Double;
    FThresholdError: Double;
    FLastDisplayed: Double;
    procedure SetValue(AValue: Double);
    procedure SetAnimated(AValue: Boolean);
    procedure SetAnimDurMs(AValue: Integer);
    procedure SetShowPercent(AValue: Boolean);
    procedure SetThresholdWarn(AValue: Double);
    procedure SetThresholdError(AValue: Double);
    function  ColorForValue(AValue: Double): TTuiColor;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    /// <summary>
    ///   Creates the gauge. Initial Value: 0.0; Animated: True; AnimDurationMs: 300;
    ///   ThresholdWarn: 0.5; ThresholdError: 0.8; ShowPercent: True.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Target value (0.0..1.0). If Animated, the displayed value converges
    ///   gradually; otherwise it updates immediately.
    /// </summary>
    property Value: Double read FTargetValue write SetValue;
    /// <summary>
    /// If True (default), enables the animated transition toward Value.
    /// </summary>
    property Animated: Boolean read FAnimated write SetAnimated;
    /// <summary>
    /// Duration of the transition in milliseconds. Default: 300.
    /// </summary>
    property AnimDurationMs: Integer read FAnimDurMs write SetAnimDurMs;
    /// <summary>
    /// If True (default), shows the percentage to the right of the bar.
    /// </summary>
    property ShowPercent: Boolean read FShowPercent write SetShowPercent;
    /// <summary>
    /// Threshold for the colour change Success to Warning. Default: 0.5.
    /// </summary>
    property ThresholdWarn: Double read FThresholdWarn write SetThresholdWarn;
    /// <summary>
    /// Threshold for the colour change Warning to Error. Default: 0.8.
    /// </summary>
    property ThresholdError: Double read FThresholdError write SetThresholdError;
  end;

implementation

uses
  System.Math;

const

  // Horizontal partial blocks U+258F (1/8) .. U+2588 (8/8)
  CBlocks: array[0..7] of string = (
    #$258F, #$258E, #$258D, #$258C,
    #$258B, #$258A, #$2589, #$2588);

{ TTuiGauge }

constructor TTuiGauge.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FLastDisplayed := -1;
  FAnimated := True;
  FAnimDurMs := 300;
  FShowPercent := True;
  FThresholdWarn := 0.5;
  FThresholdError := 0.8;
end;

function TTuiGauge.ColorForValue(AValue: Double): TTuiColor;
begin
  if AValue < FThresholdWarn then
    Result := Theme.Success
  else if AValue < FThresholdError then
    Result := Theme.Warning
  else
    Result := Theme.Error;
end;

procedure TTuiGauge.SetValue(AValue: Double);
begin
  if AValue < 0.0 then
    AValue := 0.0;
  if AValue > 1.0 then
    AValue := 1.0;
  if FTargetValue = AValue then
    Exit;
  FTargetValue := AValue;
  if FAnimated and (FAnimDurMs > 0) then
    FAnimRemainMs := FAnimDurMs
  else
  begin
    FDisplayValue := AValue;
    FAnimRemainMs := 0;
  end;
  Invalidate;
end;

procedure TTuiGauge.SetAnimated(AValue: Boolean);
begin
  if FAnimated = AValue then
    Exit;
  FAnimated := AValue;
end;

procedure TTuiGauge.SetAnimDurMs(AValue: Integer);
begin
  if AValue < 0 then
    AValue := 0;
  if FAnimDurMs = AValue then
    Exit;
  FAnimDurMs := AValue;
end;

procedure TTuiGauge.SetShowPercent(AValue: Boolean);
begin
  if FShowPercent = AValue then
    Exit;
  FShowPercent := AValue;
  Invalidate;
end;

procedure TTuiGauge.SetThresholdWarn(AValue: Double);
begin
  if FThresholdWarn = AValue then
    Exit;
  FThresholdWarn := AValue;
  Invalidate;
end;

procedure TTuiGauge.SetThresholdError(AValue: Double);
begin
  if FThresholdError = AValue then
    Exit;
  FThresholdError := AValue;
  Invalidate;
end;

procedure TTuiGauge.DoTick(AElapsedMs: Integer);
begin
  if (not FAnimated) or (FAnimRemainMs <= 0) then
    Exit;
  var LElapsed := Min(AElapsedMs, FAnimRemainMs);
  var LFrac := LElapsed / FAnimRemainMs;
  FDisplayValue := FDisplayValue + (FTargetValue - FDisplayValue) * LFrac;
  Dec(FAnimRemainMs, LElapsed);
  if FAnimRemainMs <= 0 then
    FDisplayValue := FTargetValue;
  // Invalidates only if the displayed value has changed by at least 0.5%
  // (avoids unnecessary repaints)
  if Abs(FDisplayValue - FLastDisplayed) >= 0.005 then
  begin
    FLastDisplayed := FDisplayValue;
    Invalidate;
  end;
end;

procedure TTuiGauge.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  var LFillColor := ColorForValue(FDisplayValue);
  var LFillStyle := TTuiStyle.Create(LFillColor, TTuiColor.Default);
  var LEmptyStyle := TTuiStyle.Create(Theme.Surface, TTuiColor.Default);
  var LTextStyle := TTuiStyle.Create(Theme.Text, TTuiColor.Default);

  var LPctStr: string;
  var LPctWidth: Integer;
  if FShowPercent then
  begin
    LPctStr := Format('%3d%%', [Round(FDisplayValue * 100)]);
    LPctWidth := Length(LPctStr) + 1;
  end
  else
  begin
    LPctStr := '';
    LPctWidth := 0;
  end;

  var LBarWidth := ARect.Width - LPctWidth;
  if LBarWidth < 1 then
    LBarWidth := 1;

  var LFilledEighths := Round(FDisplayValue * LBarWidth * 8);
  var LFullBlocks := LFilledEighths div 8;
  var LRemEighths := LFilledEighths mod 8;

  var LX := ARect.Left;
  while (LX < ARect.Left + LFullBlocks) and (LX < ARect.Left + LBarWidth) do
  begin
    ACanvas.WriteAt(LX, ARect.Top, CBlocks[7], LFillStyle);
    Inc(LX);
  end;

  if (LRemEighths > 0) and (LX < ARect.Left + LBarWidth) then
  begin
    ACanvas.WriteAt(LX, ARect.Top, CBlocks[LRemEighths - 1], LFillStyle);
    Inc(LX);
  end;

  while LX < ARect.Left + LBarWidth do
  begin
    ACanvas.WriteAt(LX, ARect.Top, ' ', LEmptyStyle);
    Inc(LX);
  end;

  if FShowPercent then
    ACanvas.WriteAt(ARect.Left + LBarWidth, ARect.Top, ' ' + LPctStr, LTextStyle);
end;

end.
