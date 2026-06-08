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
{   Unit:        TaskManager.Consts.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TaskManagerDemo -- Compile-time constants: process names, core count,
///   footer hint strings, and panel titles.
/// </summary>
unit TaskManager.Consts;

{$APPTYPE CONSOLE}

interface

const

  // Number of simulated CPU cores
  CCoreCount = 8;

  // Pool of process names used to populate the simulated process list
  CProcessNames: array[0..29] of string = (
    'svchost.exe',
    'chrome.exe',
    'delphi32.exe',
    'explorer.exe',
    'notepad.exe',
    'code.exe',
    'slack.exe',
    'teams.exe',
    'outlook.exe',
    'firefox.exe',
    'conhost.exe',
    'csrss.exe',
    'lsass.exe',
    'winlogon.exe',
    'dwm.exe',
    'taskmgr.exe',
    'msedge.exe',
    'wsl.exe',
    'git.exe',
    'nvcontainer.exe',
    'audiodg.exe',
    'SearchHost.exe',
    'RuntimeBroker.exe',
    'WmiPrvSE.exe',
    'spoolsv.exe',
    'OneDrive.exe',
    'Discord.exe',
    'Zoom.exe',
    'python.exe',
    'node.exe'
  );

  // Footer hint shown when the Processes tab is active
  CHintProcesses =
    ' Tab focus  |  ↑↓ navigate  |  ←→+S sort  |  P pause  |  T theme  |  Q quit';

  // Footer hint shown when the Performance tab is active
  CHintPerf = ' Tab focus  |  P pause/resume updates  |  T toggle theme  |  Q quit';

  // Hint appended to the header when updates are paused
  CHintPaused = '  [PAUSED]';

implementation

end.
