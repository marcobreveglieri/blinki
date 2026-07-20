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
{   Unit:        Blinki.FX.Gradient.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Helper for RGB gradient effects on text in the Blinki canvas.
/// </summary>
unit Blinki.FX.Gradient;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  Blinki.Core.Canvas,
  Blinki.Core.Style,
  Blinki.Core.Unicode;

type

{ ETuiFX }

  /// <summary>
  ///   Exception raised when the supplied colors are not of kind ckRGB.
  /// </summary>
  ETuiFX = class(Exception);

{ Functions }

  /// <summary>
  ///   Linearly interpolates between two RGB colors.
  /// </summary>
  /// <param name="AFrom">Starting color (must be ckRGB).</param>
  /// <param name="ATo">Ending color (must be ckRGB).</param>
  /// <param name="AT">Interpolation factor in [0.0 .. 1.0] (0 = AFrom, 1 = ATo).</param>
  /// <returns>The interpolated TTuiColor of kind ckRGB.</returns>
  /// <exception cref="ETuiFX">Raised if AFrom or ATo is not ckRGB.</exception>
  function LerpColor(const AFrom, ATo: TTuiColor; AT: Double): TTuiColor;

  /// <summary>
  ///   Draws AText on ACanvas at position (AX, AY) with the foreground color
  ///   linearly interpolated from AFrom to ATo across each character.
  /// </summary>
  /// <param name="ACanvas">Target canvas.</param>
  /// <param name="AX">Left column (0-based) where drawing begins.</param>
  /// <param name="AY">Row (0-based) where the text is drawn.</param>
  /// <param name="AText">Text string to render.</param>
  /// <param name="AFrom">Starting foreground color (must be ckRGB).</param>
  /// <param name="ATo">Ending foreground color (must be ckRGB).</param>
  /// <param name="ABg">Uniform background color applied to all characters.</param>
  /// <param name="AAttrs">Optional ANSI text attributes (e.g. [taBold]).</param>
  /// <exception cref="ETuiFX">Raised if AFrom or ATo is not ckRGB.</exception>
  procedure DrawGradient(const ACanvas: TTuiCanvas; AX, AY: Integer;
    const AText: string; const AFrom, ATo: TTuiColor; const ABg: TTuiColor;
    AAttrs: TTuiTextAttrs = []);

implementation

{ Functions }

function LerpColor(const AFrom, ATo: TTuiColor; AT: Double): TTuiColor;
begin
  if AFrom.Kind <> ckRGB then
    raise ETuiFX.Create('LerpColor: AFrom must be ckRGB');
  if ATo.Kind <> ckRGB then
    raise ETuiFX.Create('LerpColor: ATo must be ckRGB');
  var LT: Double;
  if AT < 0.0 then
    LT := 0.0
  else if AT > 1.0 then
    LT := 1.0
  else
    LT := AT;
  Result := TTuiColor.RGB(
    Round(AFrom.R + (ATo.R - AFrom.R) * LT),
    Round(AFrom.G + (ATo.G - AFrom.G) * LT),
    Round(AFrom.B + (ATo.B - AFrom.B) * LT)
  );
end;

procedure DrawGradient(const ACanvas: TTuiCanvas; AX, AY: Integer;
  const AText: string; const AFrom, ATo: TTuiColor; const ABg: TTuiColor;
  AAttrs: TTuiTextAttrs);
begin
  if AFrom.Kind <> ckRGB then
    raise ETuiFX.Create('DrawGradient: AFrom must be ckRGB');
  if ATo.Kind <> ckRGB then
    raise ETuiFX.Create('DrawGradient: ATo must be ckRGB');
  // Iterate grapheme clusters and interpolate on terminal columns, so wide
  // glyphs (CJK, emoji) keep their head+continuation pair intact and the
  // gradient stays linear on screen.
  var LTotalWidth := TTuiUnicode.StringWidth(AText);
  if LTotalWidth = 0 then
    Exit;
  var LIndex := 1;
  var LCol := 0;
  while LIndex <= Length(AText) do
  begin
    var LLen := TTuiUnicode.GraphemeLengthAt(AText, LIndex);
    var LWidth := TTuiUnicode.ClusterWidthAt(AText, LIndex, LLen);
    if LWidth < 1 then
      LWidth := 1;
    var LT: Double;
    if LTotalWidth = 1 then
      LT := 0.0
    else
      LT := LCol / (LTotalWidth - 1);
    var LFg := LerpColor(AFrom, ATo, LT);
    ACanvas.WriteAt(AX + LCol, AY, Copy(AText, LIndex, LLen),
      TTuiStyle.Create(LFg, ABg, AAttrs));
    Inc(LCol, LWidth);
    Inc(LIndex, LLen);
  end;
end;

end.
