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
{   Unit:        Blinki.Core.Theme.pas                           }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Semantic theme system for the Blinki library.
///   Defines TTuiTheme with a semantic colour palette (Primary, Secondary, Success,
///   Warning, Error, Background, Surface, Text, TextDim, Border) and the Dark and
///   Light presets.
/// </summary>
unit Blinki.Core.Theme;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Blinki.Core.Style;

type

{ TTuiTheme }

  /// <summary>
  ///   Semantic colour palette for the application.
  ///   Every feedback widget reads colours from the theme assigned by TTuiApp.
  ///   Use the static constructors Dark, Light, or Default to obtain the presets.
  /// </summary>
  TTuiTheme = record
  public
    /// <summary>
    /// Main application colour (accent).
    /// </summary>
    Primary: TTuiColor;
    /// <summary>
    /// Secondary colour (alternative accent).
    /// </summary>
    Secondary: TTuiColor;
    /// <summary>
    /// Colour for success states.
    /// </summary>
    Success: TTuiColor;
    /// <summary>
    /// Colour for warnings.
    /// </summary>
    Warning: TTuiColor;
    /// <summary>
    /// Colour for errors and critical states.
    /// </summary>
    Error: TTuiColor;
    /// <summary>
    /// Global application background colour.
    /// </summary>
    Background: TTuiColor;
    /// <summary>
    /// Background colour for panels, boxes, and elevated surfaces.
    /// </summary>
    Surface: TTuiColor;
    /// <summary>
    /// Primary text colour.
    /// </summary>
    Text: TTuiColor;
    /// <summary>
    /// Secondary or dimmed text colour.
    /// </summary>
    TextDim: TTuiColor;
    /// <summary>
    /// Default colour for borders and separators.
    /// </summary>
    Border: TTuiColor;
    /// <summary>
    /// Default theme (alias for Dark).
    /// </summary>
    class function Default: TTuiTheme; static;
    /// <summary>
    /// Dark preset inspired by VS Code Dark+.
    /// </summary>
    class function Dark: TTuiTheme; static;
    /// <summary>
    /// Light preset.
    /// </summary>
    class function Light: TTuiTheme; static;
    /// <inheritdoc/>
    class operator Equal(const A, B: TTuiTheme): Boolean;
    /// <inheritdoc/>
    class operator NotEqual(const A, B: TTuiTheme): Boolean;
  end;

implementation

{ TTuiTheme }

class function TTuiTheme.Default: TTuiTheme;
begin
  Result := Dark;
end;

class function TTuiTheme.Dark: TTuiTheme;
begin
  Result.Primary := TTuiColor.RGB($56, $9C, $D6);
  Result.Secondary := TTuiColor.RGB($C5, $86, $C0);
  Result.Success := TTuiColor.RGB($4E, $C9, $B0);
  Result.Warning := TTuiColor.RGB($DC, $DC, $AA);
  Result.Error := TTuiColor.RGB($F4, $47, $47);
  Result.Background := TTuiColor.RGB($1E, $1E, $1E);
  Result.Surface := TTuiColor.RGB($25, $25, $26);
  Result.Text := TTuiColor.RGB($D4, $D4, $D4);
  Result.TextDim := TTuiColor.RGB($80, $80, $80);
  Result.Border := TTuiColor.RGB($3F, $3F, $46);
end;

class function TTuiTheme.Light: TTuiTheme;
begin
  Result.Primary := TTuiColor.RGB($00, $66, $CC);
  Result.Secondary := TTuiColor.RGB($7B, $3A, $A1);
  Result.Success := TTuiColor.RGB($10, $7C, $10);
  Result.Warning := TTuiColor.RGB($99, $6F, $00);
  Result.Error := TTuiColor.RGB($C5, $0F, $1F);
  Result.Background := TTuiColor.RGB($FF, $FF, $FF);
  Result.Surface := TTuiColor.RGB($F3, $F3, $F3);
  Result.Text := TTuiColor.RGB($1F, $1F, $1F);
  Result.TextDim := TTuiColor.RGB($6E, $6E, $6E);
  Result.Border := TTuiColor.RGB($D0, $D0, $D0);
end;

class operator TTuiTheme.Equal(const A, B: TTuiTheme): Boolean;
begin
  Result := (A.Primary = B.Primary)
    and (A.Secondary = B.Secondary)
    and (A.Success = B.Success)
    and (A.Warning = B.Warning)
    and (A.Error = B.Error)
    and (A.Background = B.Background)
    and (A.Surface = B.Surface)
    and (A.Text = B.Text)
    and (A.TextDim = B.TextDim)
    and (A.Border = B.Border);
end;

class operator TTuiTheme.NotEqual(const A, B: TTuiTheme): Boolean;
begin
  Result := not (A = B);
end;

end.
