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
{   Unit:        Blinki.Core.Console.Posix.pas                   }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   POSIX stub of the console backend for the Blinki library.
///   All methods raise ETuiConsoleError with an explanatory message.
///   This file documents the cross-platform architectural intent and ensures
///   that the factory compiles on non-Windows platforms as well.
/// </summary>
/// <remarks>
///   The full implementation (termios raw mode, non-blocking read(), ioctl TIOCGWINSZ)
///   will be provided in a future release.
/// </remarks>
unit Blinki.Core.Console.Posix;

interface

{$IFNDEF MSWINDOWS}

uses
  System.Types,
  Blinki.Core.Console,
  Blinki.Core.Event,
  Blinki.Core.Input;

type

{ TTuiPosixConsoleBackend }

  /// <summary>
  /// POSIX stub of ITuiConsoleBackend. All methods raise ETuiConsoleError.
  /// The full implementation will be provided in a future release.
  /// </summary>
  TTuiPosixConsoleBackend = class(TInterfacedObject, ITuiConsoleBackend)
  public
    procedure Open;
    procedure Close;
    procedure Flush;
    function GetSize: TSize;
    function TryReadEvent(ATimeoutMs: Integer; out AEvent: TTuiEvent): Boolean;
    function TryReadKey(ATimeoutMs: Integer; out AKey: TTuiKeyEvent): Boolean;
    procedure Write(const AText: string);
  end;

{$ENDIF}

implementation

{$IFNDEF MSWINDOWS}

const
  NotImplementedMessage =
    'Blinki''s POSIX backend is not yet implemented. ' +
    'Linux/macOS support will be available in a future release.';

{ TTuiPosixConsoleBackend }

procedure TTuiPosixConsoleBackend.Open;
begin
  raise ETuiConsoleError.Create(NotImplementedMessage);
end;

procedure TTuiPosixConsoleBackend.Close;
begin
  raise ETuiConsoleError.Create(NotImplementedMessage);
end;

procedure TTuiPosixConsoleBackend.Flush;
begin
  raise ETuiConsoleError.Create(NotImplementedMessage);
end;

function TTuiPosixConsoleBackend.GetSize: TSize;
begin
  raise ETuiConsoleError.Create(NotImplementedMessage);
end;

function TTuiPosixConsoleBackend.TryReadEvent(ATimeoutMs: Integer;
  out AEvent: TTuiEvent): Boolean;
begin
  raise ETuiConsoleError.Create(NotImplementedMessage);
end;

function TTuiPosixConsoleBackend.TryReadKey(ATimeoutMs: Integer;
  out AKey: TTuiKeyEvent): Boolean;
begin
  raise ETuiConsoleError.Create(NotImplementedMessage);
end;

procedure TTuiPosixConsoleBackend.Write(const AText: string);
begin
  raise ETuiConsoleError.Create(NotImplementedMessage);
end;

{$ENDIF}

end.
