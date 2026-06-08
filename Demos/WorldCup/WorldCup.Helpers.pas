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
{   Unit:        WorldCup.Helpers.pas                            }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   WorldCupDemo -- Pure formatting and colour-mapping helpers.
///   All functions are free-standing; no class wrappers.
///   Depends only on WorldCup.Model and Blinki.Core.Style/Theme.
/// </summary>
unit WorldCup.Helpers;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  Blinki.Core.Style,
  Blinki.Core.Theme,
  WorldCup.Model;

/// <summary>
///   Formats a match score as 'H-A', e.g. '2-1'.
/// </summary>
function FormatScore(AHome, AAway: Integer): string;

/// <summary>
///   Formats a match minute for display: '67''' for live, 'FT' for finished,
///   and empty string for scheduled matches.
/// </summary>
function FormatMinute(AMinute: Integer; AStatus: TMatchStatus): string;

/// <summary>
///   Returns a short status badge string: 'FT', '●' + minute, or kickoff label.
/// </summary>
function StatusBadge(const AMatch: TMatch): string;

/// <summary>
///   Returns the foreground colour that represents a match result for a team:
///   Success for win, Error for loss, Warning for draw.
/// </summary>
function ResultColor(const ATheme: TTuiTheme; ATeamScore,
  AOtherScore: Integer): TTuiColor;

/// <summary>
///   Returns a fixed-width team name string truncated or padded to AWidth.
/// </summary>
function PadTeamName(const AName: string; AWidth: Integer): string;

/// <summary>
///   Returns a right-aligned integer string padded to AWidth characters.
/// </summary>
function PadInt(AValue, AWidth: Integer): string;

implementation

uses
  System.SysUtils,
  WorldCup.Consts;

function FormatScore(AHome, AAway: Integer): string;
begin
  Result := IntToStr(AHome) + '-' + IntToStr(AAway);
end;

function FormatMinute(AMinute: Integer; AStatus: TMatchStatus): string;
begin
  case AStatus of
    msLive:     Result := IntToStr(AMinute) + #$27;  // trailing apostrophe
    msFinished: Result := 'FT';
  else
    Result := '';
  end;
end;

function StatusBadge(const AMatch: TMatch): string;
begin
  case AMatch.Status of
    msLive:     Result := CGlyphLive + ' ' + IntToStr(AMatch.Minute) + #$27;
    msFinished: Result := 'FT';
  else
    Result := AMatch.KickoffLabel;
  end;
end;

function ResultColor(const ATheme: TTuiTheme; ATeamScore,
  AOtherScore: Integer): TTuiColor;
begin
  if ATeamScore > AOtherScore then
    Result := ATheme.Success
  else if ATeamScore < AOtherScore then
    Result := ATheme.Error
  else
    Result := ATheme.Warning;
end;

function PadTeamName(const AName: string; AWidth: Integer): string;
begin
  if Length(AName) >= AWidth then
    Result := Copy(AName, 1, AWidth)
  else
    Result := AName + StringOfChar(' ', AWidth - Length(AName));
end;

function PadInt(AValue, AWidth: Integer): string;
begin
  Result := IntToStr(AValue);
  while Length(Result) < AWidth do
    Result := ' ' + Result;
end;

end.
