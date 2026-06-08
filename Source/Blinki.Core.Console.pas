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
{   Unit:        Blinki.Core.Console.pas                         }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Console I/O abstraction layer for the Blinki library.
///   Defines ITuiConsoleBackend (cross-platform interface), ETuiConsoleError,
///   and TTuiConsoleBackendFactory (factory that selects the implementation at compile time).
/// </summary>
/// <remarks>
///   No {$IFDEF} is visible above this layer.
///   All platform-specific code resides in Blinki.Core.Console.Windows and
///   Blinki.Core.Console.Posix.
/// </remarks>
unit Blinki.Core.Console;

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Event,
  Blinki.Core.Input;

type

{ ETuiConsoleError }

  /// <summary>
  ///   Exception raised on errors during console initialisation or use.
  /// </summary>
  ETuiConsoleError = class(Exception);

{ ITuiConsoleBackend }

  /// <summary>
  ///   Cross-platform abstraction for terminal I/O.
  ///   Implemented by TTuiWindowsConsoleBackend (Windows) and TTuiPosixConsoleBackend (POSIX stub).
  /// </summary>
  ITuiConsoleBackend = interface
    ['{9A2F8C41-7B3D-4E56-A1C9-0F82E5D73B4A}']

    /// <summary>
    ///   Configures the terminal for use with the Blinki library:
    ///   enables VT100/ANSI, raw input mode, UTF-8, and installs the Ctrl+C handler.
    ///   Saves the original state for restoration in Close. Idempotent.
    /// </summary>
    procedure Open;

    /// <summary>
    ///   Restores the terminal to its original state prior to Open.
    ///   Idempotent: may be called multiple times without adverse effects.
    ///   Called automatically by the destructor if not yet invoked.
    /// </summary>
    procedure Close;

    /// <summary>
    ///   Forces flushing of the output buffer to the terminal.
    ///   No-op on Windows (WriteConsoleW is already synchronous);
    ///   required on POSIX to guarantee that sequences are delivered.
    /// </summary>
    procedure Flush;

    /// <summary>
    ///   Returns the current terminal window dimensions (columns x rows).
    /// </summary>
    function GetSize: TSize;

    /// <summary>
    ///   Attempts to read a keyboard or mouse event within the specified timeout.
    ///   Returns True and populates AEvent (ekKey or ekMouse) if an event was
    ///   available, False if the timeout elapsed without relevant input.
    ///   Move-only mouse events without button changes may be discarded internally.
    /// </summary>
    function TryReadEvent(ATimeoutMs: Integer; out AEvent: TTuiEvent): Boolean;

    /// <summary>
    ///   Attempts to read a keyboard event within the specified timeout.
    ///   Returns True and populates AKey if a key was pressed,
    ///   False if the timeout elapsed without input.
    ///   Does not block indefinitely: the event loop can advance on every tick.
    ///   Kept for compatibility; prefer TryReadEvent for new code.
    /// </summary>
    function TryReadKey(ATimeoutMs: Integer; out AKey: TTuiKeyEvent): Boolean;

    /// <summary>
    ///   Writes a Unicode string to the terminal. Used to emit
    ///   ANSI sequences (built with TTuiAnsi) and UI text.
    /// </summary>
    procedure Write(const AText: string);
  end;

{ TTuiConsoleBackendFactory }

  /// <summary>
  ///   Factory that instantiates the correct console backend for the current platform.
  ///   Selects TTuiWindowsConsoleBackend on Windows and TTuiPosixConsoleBackend on POSIX
  ///   at compile time, via {$IFDEF MSWINDOWS} in the function body.
  /// </summary>
  TTuiConsoleBackendFactory = record
  public
    /// <summary>
    ///   Creates and returns the appropriate console backend for the platform.
    ///   The caller receives a reference-counted ITuiConsoleBackend;
    ///   the backend is destroyed automatically when the interface is released.
    /// </summary>
    class function CreateBackend: ITuiConsoleBackend; static;
  end;

implementation

uses
{$IFDEF MSWINDOWS}
  Blinki.Core.Console.Windows;
{$ELSE}
  Blinki.Core.Console.Posix;
{$ENDIF}

{ TTuiConsoleBackendFactory }

class function TTuiConsoleBackendFactory.CreateBackend: ITuiConsoleBackend;
begin
{$IFDEF MSWINDOWS}
  Result := TTuiWindowsConsoleBackend.Create;
{$ELSE}
  Result := TTuiPosixConsoleBackend.Create;
{$ENDIF}
end;

end.
