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
{   Unit:        WorldCup.Consts.pas                             }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   WorldCupDemo -- String constants, Unicode glyphs, layout dimensions,
///   and timer configuration used across all demo units.
/// </summary>
unit WorldCup.Consts;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

const

  /// <summary>
  ///   Gradient title shown in the banner row.
  /// </summary>
  CAppTitle = ' WORLD CUP 2026 ';

  /// <summary>
  ///   Keyboard hint shown in the footer label.
  /// </summary>
  CFooterHint = ' [<] [>] Group   B Bracket   T Theme   Q Quit ';

  /// <summary>
  ///   Number of groups in the tournament (A..H).
  /// </summary>
  CGroupCount = 8;

  // ---- Glyph constants ----

  /// <summary>
  ///   Filled circle used as a live-match indicator.
  /// </summary>
  CGlyphLive = #$25CF;

  /// <summary>
  ///   Check mark used to flag qualified teams.
  /// </summary>
  CGlyphQual = #$2713;

  /// <summary>
  ///   Filled square used for card events.
  /// </summary>
  CGlyphCard = #$25A0;

  /// <summary>
  ///   Football used in the header.
  /// </summary>
  CGlyphBall = #$26BD;

  // ---- Panel titles ----

  /// <summary>
  ///   Title of the live-matches panel.
  /// </summary>
  CLivePanelTitle = ' LIVE MATCHES ';

  /// <summary>
  ///   Prefix for the group standings panel title (group letter appended at run time).
  /// </summary>
  CGroupPanelPrefix = ' GROUP ';

  /// <summary>
  ///   Title of the top-scorers panel.
  /// </summary>
  CScorersPanelTitle = ' TOP SCORERS ';

  /// <summary>
  ///   Title of the schedule / results panel.
  /// </summary>
  CSchedulePanelTitle = ' SCHEDULE / RESULTS ';

  /// <summary>
  ///   Title of the knockout-bracket view.
  /// </summary>
  CBracketTitle = ' KNOCKOUT BRACKET ';

  // ---- Layout ----

  /// <summary>
  ///   Height in rows of the top banner (title + subtitle).
  /// </summary>
  CBannerHeight = 2;

  /// <summary>
  ///   Height in rows of the schedule / results panel at the bottom.
  /// </summary>
  CScheduleHeight = 9;

  // ---- Timer ----

  /// <summary>
  ///   Milliseconds between live-data ticks (accumulator threshold in the main loop).
  /// </summary>
  CTickIntervalMs = 1200;

implementation

end.
