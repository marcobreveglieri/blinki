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
{   Unit:        Tetris.Helpers.pas                              }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TetrisDemo -- Utility functions: maps a TTetrominoKind to its TTuiColor.
/// </summary>
unit Tetris.Helpers;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  Blinki.Core.Style,
  Tetris.Consts;

/// <summary>
///   Returns a fully-saturated RGB colour for the given hue value.
///   AHue is in [0..1) (values outside are wrapped). The mapping follows
///   the standard HSV wheel with S=1, V=1.
/// </summary>
function HueColor(AHue: Single): TTuiColor;

/// <summary>
///   Returns the classic Tetris RGB colour for the given tetromino kind.
/// </summary>
function KindColor(AKind: TTetrominoKind): TTuiColor;

implementation

uses
  System.Math;

function HueColor(AHue: Single): TTuiColor;
begin
  var LH: Single := AHue - Floor(AHue); // wrap to [0..1)
  var LS: Single := LH * 6;
  var LI: Integer := Trunc(LS);
  var LF: Single := LS - LI;
  var LT := Byte(Round(LF * 255));
  var LQ := Byte(Round((1.0 - LF) * 255));
  case LI mod 6 of
    0: Result := TTuiColor.RGB(255, LT, 0);
    1: Result := TTuiColor.RGB(LQ, 255, 0);
    2: Result := TTuiColor.RGB(0, 255, LT);
    3: Result := TTuiColor.RGB(0, LQ, 255);
    4: Result := TTuiColor.RGB(LT, 0, 255);
  else
    Result := TTuiColor.RGB(255, 0, LQ);
  end;
end;

function KindColor(AKind: TTetrominoKind): TTuiColor;
begin
  var LC := CKindColors[AKind];
  Result := TTuiColor.RGB(LC.R, LC.G, LC.B);
end;

end.
