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
{   Unit:        Kanban.Helpers.pas                              }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   KanbanDemo -- Pure mapping and formatting helpers.
///   No UI or database dependencies; depends only on Kanban.Model,
///   Blinki.Core.Style and Blinki.Core.Theme.
/// </summary>
unit Kanban.Helpers;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  Kanban.Model,
  Blinki.Core.Style,
  Blinki.Core.Theme;

/// <summary>
///   Returns the column header text for the given status, with spaces between
///   each letter (e.g. 'B A C K L O G').
/// </summary>
function StatusColumnTitle(AStatus: TKanbanStatus): string;

/// <summary>
///   Returns the short badge label text for the given kind.
///   kkAuto -> 'AUTO', kkPair -> 'PAIR'.
/// </summary>
function KindBadgeText(AKind: TKanbanKind): string;

/// <summary>
///   Returns the foreground color for a kind badge.
///   kkAuto -> Theme.Warning (gold), kkPair -> Theme.Secondary (blue/purple).
/// </summary>
function KindBadgeColor(AKind: TKanbanKind; const ATheme: TTuiTheme): TTuiColor;

/// <summary>
///   Returns the color for the priority indicator dot.
///   kpHigh -> Theme.Error (red), kpMedium -> Theme.Warning (yellow),
///   kpLow -> Theme.Success (green).
/// </summary>
function PriorityDotColor(APriority: TKanbanPriority; const ATheme: TTuiTheme): TTuiColor;

/// <summary>
///   Returns the accent color used for the column header background.
///   ksBacklog -> ATheme.Secondary, ksInProgress -> ATheme.Primary,
///   ksReview -> ATheme.Warning, ksDone -> ATheme.Success.
/// </summary>
function StatusAccentColor(AStatus: TKanbanStatus; const ATheme: TTuiTheme): TTuiColor;

/// <summary>
///   Returns a short human-readable status label used in logs and debug output.
///   'Backlog', 'In Progress', 'Review', 'Done'.
/// </summary>
function StatusText(AStatus: TKanbanStatus): string;

implementation

uses
  System.SysUtils;

function StatusColumnTitle(AStatus: TKanbanStatus): string;

  // Inserts a space between every character of the input string.
  function SpaceOut(const AText: string): string;
  begin
    var LBuilder := TStringBuilder.Create;
    try
      for var LIdx := 1 to Length(AText) do
      begin
        if LIdx > 1 then
          LBuilder.Append(' ');
        LBuilder.Append(AText[LIdx]);
      end;
      Result := LBuilder.ToString;
    finally
      LBuilder.Free;
    end;
  end;

begin
  case AStatus of
    ksBacklog: Result := SpaceOut('BACKLOG');
    ksInProgress: Result := SpaceOut('IN PROGRESS');
    ksReview: Result := SpaceOut('REVIEW');
    ksDone: Result := SpaceOut('DONE');
  else
    Result := '';
  end;
end;

function KindBadgeText(AKind: TKanbanKind): string;
begin
  case AKind of
    kkAuto: Result := 'AUTO';
    kkPair: Result := 'PAIR';
  else
    Result := '';
  end;
end;

function KindBadgeColor(AKind: TKanbanKind; const ATheme: TTuiTheme): TTuiColor;
begin
  case AKind of
    kkAuto: Result := ATheme.Warning;
    kkPair: Result := ATheme.Secondary;
  else
    Result := TTuiColor.Default;
  end;
end;

function PriorityDotColor(APriority: TKanbanPriority; const ATheme: TTuiTheme): TTuiColor;
begin
  case APriority of
    kpHigh: Result := ATheme.Error;
    kpMedium: Result := ATheme.Warning;
    kpLow: Result := ATheme.Success;
  else
    Result := TTuiColor.Default;
  end;
end;

function StatusAccentColor(AStatus: TKanbanStatus; const ATheme: TTuiTheme): TTuiColor;
begin
  case AStatus of
    ksBacklog: Result := ATheme.Secondary;
    ksInProgress: Result := ATheme.Primary;
    ksReview: Result := ATheme.Warning;
    ksDone: Result := ATheme.Success;
  else
    Result := TTuiColor.Default;
  end;
end;

function StatusText(AStatus: TKanbanStatus): string;
begin
  case AStatus of
    ksBacklog: Result := 'Backlog';
    ksInProgress: Result := 'In Progress';
    ksReview: Result := 'Review';
    ksDone: Result := 'Done';
  else
    Result := '';
  end;
end;

end.
