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
{   Unit:        TeamChat.Consts.pas                             }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TeamChatConsts -- Compile-time constants for TeamChatDemo: bot messages, authors,
///   and UI hint text.
/// </summary>
unit TeamChat.Consts;

{$APPTYPE CONSOLE}

interface

const
  // bot messages for channel 0 (#general)
  CBotMsgs0: array[0..7] of string = (
    'Anyone seen yesterday''s client report?',
    'I pushed the latest fix to the feature/chat branch',
    'Meeting pushed to 3:30 PM, are you in?',
    'Build complete, all green!',
    'Who''s coming to lunch?',
    'Reminder: daily stand-up in ten minutes',
    'I updated the shared document',
    'Finally fixed the renderer issue'
  );
  // bot messages for channel 1 (#random)
  CBotMsgs1: array[0..5] of string = (
    'Did you hear a new place is opening near the office?',
    'Great article on Hacker News today',
    'Anyone up for online chess?',
    'The coffee machine is broken again',
    'Any good sci-fi book recommendations?',
    'Have a great weekend, everyone!'
  );
  // bot messages for channel 2 (#development)
  CBotMsgs2: array[0..5] of string = (
    'Fixed the bug in the layout solver, tests green',
    'Updated CLAUDE.md with the new conventions',
    'Opened a PR for the canvas refactoring',
    'Great review, thanks!',
    'Smoke tests all green on Windows Terminal',
    'Added new unit Blinki.Widgets.Badge'
  );
  // generic DM replies
  CDMReplies: array[0..4] of string = (
    'Sure, see you later!',
    'Got it, thanks for the update',
    'Perfect, I''ll take a look right away',
    'OK, I''ll let you know',
    'Great idea, let''s go ahead!'
  );

  CBotAuthors0: array[0..2] of string = ('alice', 'bob', 'carlo');
  CBotAuthors1: array[0..1] of string = ('bob', 'carlo');
  CBotAuthors2: array[0..1] of string = ('alice', 'carlo');

  CHintText = ' Click activates  |  Tab focus  |  Up/Down scroll  |  End=tail  |  Enter sends  |  T theme  |  Q quit';

implementation

end.
