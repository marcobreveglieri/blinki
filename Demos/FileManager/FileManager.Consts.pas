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
{   Unit:        FileManager.Consts.pas                       }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   FileManagerDemo — compile-time constants.
/// </summary>
unit FileManager.Consts;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  CMinTerminalWidth = 60;
  CMinTerminalHeight = 16;

  CTitleName = 'File Manager';
  CTitleCommands = '[Tab] Switch panel  [F2] Rename  [F5] Copy  [F6] Move  [F7] New folder  [F8] Delete  [F10] Quit';
  CSmallTerminalMsg = ' Terminal too small (minimum 60x16). Resize to continue. ';

implementation

end.
