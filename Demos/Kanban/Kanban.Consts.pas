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
{   Unit:        Kanban.Consts.pas                               }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   KanbanDemo -- Shared string constants: glyphs, hints, and app title.
/// </summary>
unit Kanban.Consts;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

const
  /// <summary>
  ///   Number of Kanban columns.
  /// </summary>
  CKanbanColumnCount = 4;

  /// <summary>
  ///   Glyph for the priority dot (U+25CF BLACK CIRCLE).
  /// </summary>
  CGlyphDot = '●';

  /// <summary>
  ///   Footer hint line shown at the bottom of the screen.
  /// </summary>
  CFooterHint = 'n new  ·  e edit  ·  p priority  ·  k kind  ·  d delete  ·  ←→ nav  ·  Shift+←→ move  ·  t theme  ·  q quit';

  /// <summary>
  ///   Application title displayed in the header bar.
  /// </summary>
  CAppTitle = 'K A N B A N';

implementation

end.
