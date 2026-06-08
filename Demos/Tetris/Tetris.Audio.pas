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
{   Unit:        Tetris.Audio.pas                                }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TetrisDemo -- Sound player that maps TGameEvent values to MP3 files via
///   the Windows MCI API (mciSendString / Winapi.MMSystem).
///   Each play closes the previous alias, reopens the file from scratch, and
///   immediately plays it.  This guarantees a clean device state on every
///   trigger -- avoiding stale seek/play issues on short sound effects.
///   All MCI errors are silently ignored -- the game runs fine even if the
///   Sounds\ folder is missing or a file cannot be opened.
/// </summary>
unit Tetris.Audio;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

{$IFDEF MSWINDOWS}

uses
  Tetris.Model;

type
  /// <summary>
  ///   Opens the five Tetris MP3 files as MCI aliases and plays the correct
  ///   one whenever HandleGameEvent is called.
  ///   Assign HandleGameEvent to TTetrisGame.OnEvent to activate audio.
  /// </summary>
  TTetrisAudio = class
  strict private
    FSoundsFolder: string;
    procedure CloseAlias(const AAlias: string);
    procedure PlayAlias(const AAlias, AFilename: string);
  public
    constructor Create(const ASoundsFolder: string);
    destructor Destroy; override;
    /// <summary>
    ///   Plays the MP3 associated with AEvent.
    ///   Signature is compatible with TGameEventProc for direct assignment
    ///   to TTetrisGame.OnEvent.
    /// </summary>
    procedure HandleGameEvent(AEvent: TGameEvent);
  end;

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

uses
  Winapi.MMSystem,
  System.SysUtils;

const
  CAliasRotate   = 'tetris_rotate';
  CAliasHold     = 'tetris_hold';
  CAliasDrop     = 'tetris_drop';
  CAliasLock     = 'tetris_lock';
  CAliasGameOver = 'tetris_gameover';

{ TTetrisAudio }

procedure TTetrisAudio.CloseAlias(const AAlias: string);
begin
  mciSendString(PChar('close ' + AAlias), nil, 0, 0);
end;

procedure TTetrisAudio.PlayAlias(const AAlias, AFilename: string);
begin
  // Close any previous instance, reopen fresh, then play.
  // This guarantees a clean device state so rapid triggers always audible.
  mciSendString(PChar('close ' + AAlias), nil, 0, 0);
  mciSendString(PChar('open "' + FSoundsFolder + AFilename +
    '" type mpegvideo alias ' + AAlias), nil, 0, 0);
  mciSendString(PChar('play ' + AAlias), nil, 0, 0);
end;

constructor TTetrisAudio.Create(const ASoundsFolder: string);
begin
  inherited Create;
  FSoundsFolder := ASoundsFolder;
end;

destructor TTetrisAudio.Destroy;
begin
  CloseAlias(CAliasRotate);
  CloseAlias(CAliasHold);
  CloseAlias(CAliasDrop);
  CloseAlias(CAliasLock);
  CloseAlias(CAliasGameOver);
  inherited Destroy;
end;

procedure TTetrisAudio.HandleGameEvent(AEvent: TGameEvent);
begin
  case AEvent of
    geRotate:   PlayAlias(CAliasRotate,   'rotate.mp3');
    geHold:     PlayAlias(CAliasHold,     'hold.mp3');
    geDrop:     PlayAlias(CAliasDrop,     'drop.mp3');
    geLock:     PlayAlias(CAliasLock,     'lock.mp3');
    geGameOver: PlayAlias(CAliasGameOver, 'game-over.mp3');
  end;
end;

{$ENDIF}

end.
