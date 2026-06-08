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
{   Unit:        TeamChat.Helpers.pas                            }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TeamChatDemo -- Utility functions: greedy word-wrap and deterministic author colour.
/// </summary>
unit TeamChat.Helpers;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  Blinki.Core.Style;

/// <summary>
///   Splits AText into lines of at most AMaxWidth characters (greedy word-wrap).
/// </summary>
function SplitIntoLines(const AText: string; AMaxWidth: Integer): TArray<string>;

/// <summary>
///   Returns a deterministic RGB colour for an author name (hash-based).
///   Produces well-distinct tones on both dark and light backgrounds.
/// </summary>
function AuthorColor(const AAuthor: string): TTuiColor;

implementation

uses
  System.SysUtils,
  Blinki.Core.Ansi;

function SplitIntoLines(const AText: string; AMaxWidth: Integer): TArray<string>;
begin
  // Delegate to the canonical framework implementation.
  Result := TTuiAnsi.WrapText(AText, AMaxWidth);
end;

function AuthorColor(const AAuthor: string): TTuiColor;
begin
  var LHash: Cardinal := 5381;
  {$OVERFLOWCHECKS OFF}
  for var LI := 1 to Length(AAuthor) do
    LHash := (LHash shl 5) + LHash + Cardinal(Ord(AAuthor[LI]));
  {$OVERFLOWCHECKS ON}
  case LHash mod 5 of
    0: Result := TTuiColor.RGB(86, 182, 234);  // sky blue
    1: Result := TTuiColor.RGB(230, 159, 0);   // amber
    2: Result := TTuiColor.RGB(204, 121, 167); // pink
    3: Result := TTuiColor.RGB(0, 158, 115);   // teal
  else Result := TTuiColor.RGB(213, 188, 50);  // gold
  end;
end;

end.
