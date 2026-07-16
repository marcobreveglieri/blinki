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
{   Unit:        Blinki.Widgets.WaveAnimation.pas                }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiWaveAnimation: text whose characters cycle through colors in a
///   per-character sinusoidal wave.
/// </summary>
unit Blinki.Widgets.WaveAnimation;

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

{ TTuiWaveAnimation }

  /// <summary>
  ///   Non-focusable widget that renders a string with per-character colors
  ///   oscillating in a sinusoidal wave from BaseColor to PeakColor.
  ///   The wave advances via DoTick.
  ///   BaseColor and PeakColor must be of kind ckRGB for RGB interpolation.
  ///   Background: TTuiColor.Default or an RGB color.
  /// </summary>
  TTuiWaveAnimation = class(TTuiWidget)
  strict private
    FText: string;
    FBaseColor: TTuiColor;
    FPeakColor: TTuiColor;
    FBgColor: TTuiColor;
    FSpeed: Single;
    FPhase: Single;
    FAttrs: TTuiTextAttrs;
    procedure SetText(const AValue: string);
    procedure SetBaseColor(const AValue: TTuiColor);
    procedure SetPeakColor(const AValue: TTuiColor);
    procedure SetBgColor(const AValue: TTuiColor);
    procedure SetSpeed(AValue: Single);
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    /// <summary>
    ///   Creates the widget. Set BaseColor and PeakColor immediately after creation.
    ///   Default Speed: 1.0 cycle/second. Default Attrs: [taBold].
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    /// Text to animate.
    /// </summary>
    property Text: string read FText write SetText;
    /// <summary>
    /// Minimum (trough) wave color. Must be of kind ckRGB.
    /// </summary>
    property BaseColor: TTuiColor read FBaseColor write SetBaseColor;
    /// <summary>
    /// Maximum (peak) wave color. Must be of kind ckRGB.
    /// </summary>
    property PeakColor: TTuiColor read FPeakColor write SetPeakColor;
    /// <summary>
    /// Background color. Default: TTuiColor.Default.
    /// </summary>
    property BgColor: TTuiColor read FBgColor write SetBgColor;
    /// <summary>
    /// Wave speed in cycles per second. Default: 1.0.
    /// </summary>
    property Speed: Single read FSpeed write SetSpeed;
    /// <summary>
    /// Additional ANSI text attributes applied to every character. Default: [taBold].
    /// </summary>
    property Attrs: TTuiTextAttrs read FAttrs write FAttrs;
  end;

implementation

uses
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Event,
  Blinki.Core.Unicode,
  Blinki.FX.Gradient;

{ TTuiWaveAnimation }

constructor TTuiWaveAnimation.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FSpeed := 1.0;
  FAttrs := [taBold];
  FBgColor := TTuiColor.Default;
  // Safe non-RGB default colors; the caller should override them with ckRGB values
  FBaseColor := TTuiColor.Default;
  FPeakColor := TTuiColor.Default;
end;

procedure TTuiWaveAnimation.DoApplyTheme(const ATheme: TTuiTheme);
begin
  // Colors are managed by the caller via properties; the theme does not override them
end;

procedure TTuiWaveAnimation.DoTick(AElapsedMs: Integer);
begin
  FPhase := FPhase + (AElapsedMs / 1000.0) * FSpeed * 2.0 * Pi;
  // Keep FPhase in [0, 2*Pi) to prevent overflow in long-running sessions
  while FPhase >= 2.0 * Pi do
    FPhase := FPhase - 2.0 * Pi;
  Invalidate;
end;

procedure TTuiWaveAnimation.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  ACanvas.FillRect(ARect, ' ',
    TTuiStyle.Create(TTuiColor.Default, FBgColor));

  // Truncate by columns so a wide glyph (CJK, emoji) is never cut in half.
  var LText := TTuiAnsi.TruncateToWidth(FText, ARect.Width);
  if LText = '' then
    Exit;

  // Non-RGB colors: fall back to plain rendering without gradient
  if (FBaseColor.Kind <> ckRGB) or (FPeakColor.Kind <> ckRGB) then
  begin
    ACanvas.WriteAt(ARect.Left, ARect.Top, LText,
      TTuiStyle.Create(TTuiColor.Default, FBgColor, FAttrs));
    Exit;
  end;

  // Iterate grapheme clusters; the wave phase advances per terminal column.
  var LIndex := 1;
  var LCol := 0;
  while LIndex <= Length(LText) do
  begin
    var LLen := TTuiUnicode.GraphemeLengthAt(LText, LIndex);
    var LWidth := TTuiUnicode.ClusterWidthAt(LText, LIndex, LLen);
    if LWidth < 1 then
      LWidth := 1;
    // Phase offset of 0.3 rad per column to create the wave
    var LT := (Sin(FPhase + LCol * 0.3) + 1.0) / 2.0;
    var LFg := LerpColor(FBaseColor, FPeakColor, LT);
    ACanvas.WriteAt(ARect.Left + LCol, ARect.Top, Copy(LText, LIndex, LLen),
      TTuiStyle.Create(LFg, FBgColor, FAttrs));
    Inc(LCol, LWidth);
    Inc(LIndex, LLen);
  end;
end;

procedure TTuiWaveAnimation.SetText(const AValue: string);
begin
  if FText = AValue then
    Exit;
  FText := AValue;
  Invalidate;
end;

procedure TTuiWaveAnimation.SetBaseColor(const AValue: TTuiColor);
begin
  if FBaseColor = AValue then
    Exit;
  FBaseColor := AValue;
  Invalidate;
end;

procedure TTuiWaveAnimation.SetPeakColor(const AValue: TTuiColor);
begin
  if FPeakColor = AValue then
    Exit;
  FPeakColor := AValue;
  Invalidate;
end;

procedure TTuiWaveAnimation.SetBgColor(const AValue: TTuiColor);
begin
  if FBgColor = AValue then
    Exit;
  FBgColor := AValue;
  Invalidate;
end;

procedure TTuiWaveAnimation.SetSpeed(AValue: Single);
begin
  if AValue < 0.0 then
    AValue := 0.0;
  if Abs(FSpeed - AValue) < 0.0001 then
    Exit;
  FSpeed := AValue;
end;

end.
