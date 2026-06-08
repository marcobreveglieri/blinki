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
{   Unit:        Blinki.Core.Style.pas                           }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Color and text-style system for the Blinki library.
///   Defines TTuiColor (16/256/RGB colors), TTuiStyle (foreground + background + attributes)
///   and TTuiColors (predefined constants for the 16 standard ANSI colors).
/// </summary>
unit Blinki.Core.Style;

interface

type

{ TTuiColorKind }

  /// <summary>
  ///   Discriminator for the ANSI color kind.
  /// </summary>
  TTuiColorKind = (
    /// <summary>
    ///   Terminal default color (no SGR code is emitted).
    /// </summary>
    ckDefault,
    /// <summary>
    ///   One of the 16 standard ANSI colors (index 0-15).
    /// </summary>
    ck16,
    /// <summary>
    ///   One of the 256 colors in the xterm palette (index 0-255).
    /// </summary>
    ck256,
    /// <summary>
    ///   24-bit True Color RGB.
    /// </summary>
    ckRGB
  );

{ TTuiColor }

  /// <summary>
  ///   Represents a terminal color: default, 16-color palette, 256-color palette, or 24-bit RGB.
  ///   Use the static constructors (Default, Standard, Palette, RGB) to create instances.
  /// </summary>
  /// <remarks>
  ///   Internal layout: R acts as the color index for ck16 and ck256 kinds.
  ///   For ckRGB, R/G/B hold the True Color components.
  ///   Always use Kind to determine which field is valid.
  /// </remarks>
  TTuiColor = record
  public
    Kind: TTuiColorKind;
    /// <summary>
    ///   Red component (ckRGB) or palette index (ck16 / ck256).
    ///   For ck16 the value is in the range 0-15; for ck256 in the range 0-255.
    /// </summary>
    R: Byte;
    /// <summary>
    ///   Green component. Valid only when Kind = ckRGB; ignored otherwise.
    /// </summary>
    G: Byte;
    /// <summary>
    ///   Blue component. Valid only when Kind = ckRGB; ignored otherwise.
    /// </summary>
    B: Byte;
    /// <summary>
    ///   Terminal default color (no SGR code is emitted).
    /// </summary>
    class function Default: TTuiColor; static; inline;
    /// <summary>
    ///   One of the 16 standard ANSI colors.
    ///   AIndex: 0=Black, 1=Red, 2=Green, 3=Yellow, 4=Blue, 5=Magenta, 6=Cyan, 7=White,
    ///           8=BrightBlack, 9=BrightRed, 10=BrightGreen, 11=BrightYellow,
    ///           12=BrightBlue, 13=BrightMagenta, 14=BrightCyan, 15=BrightWhite.
    /// </summary>
    class function Standard(AIndex: Byte): TTuiColor; static; inline;
    /// <summary>
    ///   One of the 256 colors in the extended xterm palette (index 0-255).
    /// </summary>
    class function Palette(AIndex: Byte): TTuiColor; static; inline;
    /// <summary>
    ///   24-bit True Color RGB.
    /// </summary>
    class function RGB(AR, AG, AB: Byte): TTuiColor; static; inline;
    /// <inheritdoc/>
    class operator Equal(const A, B: TTuiColor): Boolean;
    /// <inheritdoc/>
    class operator NotEqual(const A, B: TTuiColor): Boolean;
  end;

{ TTuiTextAttr }

  /// <summary>
  ///   ANSI text-style attributes. Can be combined into a TTuiTextAttrs set.
  /// </summary>
  TTuiTextAttr = (
    /// <summary>
    ///   Bold.
    /// </summary>
    taBold,
    /// <summary>
    ///   Dimmed (faint) text.
    /// </summary>
    taDim,
    /// <summary>
    ///   Italic.
    /// </summary>
    taItalic,
    /// <summary>
    ///   Underlined.
    /// </summary>
    taUnderline,
    /// <summary>
    ///   Blinking.
    /// </summary>
    taBlink,
    /// <summary>
    ///   Reversed colors (foreground &lt;-&gt; background).
    /// </summary>
    taInverse,
    /// <summary>
    ///   Strikethrough.
    /// </summary>
    taStrikethrough
  );

{ TTuiTextAttrs }

  /// <summary>
  ///   Set of combinable text-style attributes.
  /// </summary>
  TTuiTextAttrs = set of TTuiTextAttr;

{ TTuiStyle }

  /// <summary>
  ///   Complete text style: foreground color, background color, and attributes.
  ///   Used by TCanvas.WriteAt and TTuiAnsi.ApplyStyle to control text appearance.
  /// </summary>
  TTuiStyle = record
  public
    /// <summary>
    ///   Text (foreground) color.
    /// </summary>
    Foreground: TTuiColor;
    /// <summary>
    ///   Background color.
    /// </summary>
    Background: TTuiColor;
    /// <summary>
    ///   Text formatting attributes.
    /// </summary>
    Attributes: TTuiTextAttrs;
    /// <summary>
    ///   Default style: terminal default colors, no attributes.
    /// </summary>
    class function Default: TTuiStyle; static; inline;
    /// <summary>
    ///   Creates a style with the specified values.
    /// </summary>
    class function Create(const AForeground, ABackground: TTuiColor;
      AAttributes: TTuiTextAttrs = []): TTuiStyle; static; inline;
    /// <inheritdoc/>
    class operator Equal(const A, B: TTuiStyle): Boolean;
    /// <inheritdoc/>
    class operator NotEqual(const A, B: TTuiStyle): Boolean;
  end;

{ TTuiColors }

  /// <summary>
  ///   Predefined constants for the 16 standard ANSI colors.
  ///   Use as: TTuiColors.Red, TTuiColors.BrightCyan, etc.
  /// </summary>
  /// <remarks>
  ///   Avoids name collisions with VCL/FMX constants (clRed, clBlack, etc.).
  /// </remarks>
  TTuiColors = record
  public
    class function Black: TTuiColor; static; inline;
    class function Red: TTuiColor; static; inline;
    class function Green: TTuiColor; static; inline;
    class function Yellow: TTuiColor; static; inline;
    class function Blue: TTuiColor; static; inline;
    class function Magenta: TTuiColor; static; inline;
    class function Cyan: TTuiColor; static; inline;
    class function White: TTuiColor; static; inline;
    class function BrightBlack: TTuiColor; static; inline;
    class function BrightRed: TTuiColor; static; inline;
    class function BrightGreen: TTuiColor; static; inline;
    class function BrightYellow: TTuiColor; static; inline;
    class function BrightBlue: TTuiColor; static; inline;
    class function BrightMagenta: TTuiColor; static; inline;
    class function BrightCyan: TTuiColor; static; inline;
    class function BrightWhite: TTuiColor; static; inline;
  end;

implementation

{ TTuiColor }

class function TTuiColor.Default: TTuiColor;
begin
  Result.Kind := ckDefault;
  Result.R := 0;
  Result.G := 0;
  Result.B := 0;
end;

class function TTuiColor.Standard(AIndex: Byte): TTuiColor;
begin
  Result.Kind := ck16;
  Result.R := AIndex;
  Result.G := 0;
  Result.B := 0;
end;

class function TTuiColor.Palette(AIndex: Byte): TTuiColor;
begin
  Result.Kind := ck256;
  Result.R := AIndex;
  Result.G := 0;
  Result.B := 0;
end;

class function TTuiColor.RGB(AR, AG, AB: Byte): TTuiColor;
begin
  Result.Kind := ckRGB;
  Result.R := AR;
  Result.G := AG;
  Result.B := AB;
end;

class operator TTuiColor.Equal(const A, B: TTuiColor): Boolean;
begin
  if A.Kind <> B.Kind then
    Exit(False);
  case A.Kind of
    ckDefault:
      Result := True;
    ck16:
      Result := A.R = B.R;
    ck256:
      Result := A.R = B.R;
    ckRGB:
      Result := (A.R = B.R) and (A.G = B.G) and (A.B = B.B);
  else
    Result := False;
  end;
end;

class operator TTuiColor.NotEqual(const A, B: TTuiColor): Boolean;
begin
  Result := not (A = B);
end;

{ TTuiStyle }

class function TTuiStyle.Default: TTuiStyle;
begin
  Result.Foreground := TTuiColor.Default;
  Result.Background := TTuiColor.Default;
  Result.Attributes := [];
end;

class function TTuiStyle.Create(const AForeground, ABackground: TTuiColor;
  AAttributes: TTuiTextAttrs): TTuiStyle;
begin
  Result.Foreground := AForeground;
  Result.Background := ABackground;
  Result.Attributes := AAttributes;
end;

class operator TTuiStyle.Equal(const A, B: TTuiStyle): Boolean;
begin
  Result := (A.Foreground = B.Foreground)
    and (A.Background = B.Background)
    and (A.Attributes = B.Attributes);
end;

class operator TTuiStyle.NotEqual(const A, B: TTuiStyle): Boolean;
begin
  Result := not (A = B);
end;

{ TTuiColors }

class function TTuiColors.Black: TTuiColor;
begin
  Result := TTuiColor.Standard(0);
end;

class function TTuiColors.Red: TTuiColor;
begin
  Result := TTuiColor.Standard(1);
end;

class function TTuiColors.Green: TTuiColor;
begin
  Result := TTuiColor.Standard(2);
end;

class function TTuiColors.Yellow: TTuiColor;
begin
  Result := TTuiColor.Standard(3);
end;

class function TTuiColors.Blue: TTuiColor;
begin
  Result := TTuiColor.Standard(4);
end;

class function TTuiColors.Magenta: TTuiColor;
begin
  Result := TTuiColor.Standard(5);
end;

class function TTuiColors.Cyan: TTuiColor;
begin
  Result := TTuiColor.Standard(6);
end;

class function TTuiColors.White: TTuiColor;
begin
  Result := TTuiColor.Standard(7);
end;

class function TTuiColors.BrightBlack: TTuiColor;
begin
  Result := TTuiColor.Standard(8);
end;

class function TTuiColors.BrightRed: TTuiColor;
begin
  Result := TTuiColor.Standard(9);
end;

class function TTuiColors.BrightGreen: TTuiColor;
begin
  Result := TTuiColor.Standard(10);
end;

class function TTuiColors.BrightYellow: TTuiColor;
begin
  Result := TTuiColor.Standard(11);
end;

class function TTuiColors.BrightBlue: TTuiColor;
begin
  Result := TTuiColor.Standard(12);
end;

class function TTuiColors.BrightMagenta: TTuiColor;
begin
  Result := TTuiColor.Standard(13);
end;

class function TTuiColors.BrightCyan: TTuiColor;
begin
  Result := TTuiColor.Standard(14);
end;

class function TTuiColors.BrightWhite: TTuiColor;
begin
  Result := TTuiColor.Standard(15);
end;

end.
