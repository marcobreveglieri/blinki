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
{   Unit:        Blinki.Core.Event.pas                           }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Unified event model for the Blinki library.
///   TTuiEvent abstracts input sources into a discriminated record
///   consumed by TTuiWidget.HandleEvent and by TTuiApp callbacks.
/// </summary>
unit Blinki.Core.Event;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Input;

type

{ TTuiEventKind }

  /// <summary>
  ///   Discriminator for the Blinki event kind.
  /// </summary>
  TTuiEventKind = (
    /// <summary>
    ///   Sentinel event: no valid event.
    /// </summary>
    ekNone,
    /// <summary>
    ///   Key press event; read the Key field.
    /// </summary>
    ekKey,
    /// <summary>
    ///   Mouse event (button press/release, move, or wheel); read the Mouse field.
    /// </summary>
    ekMouse,
    /// <summary>
    ///   Terminal resize event; read the Size field.
    /// </summary>
    ekResize,
    /// <summary>
    ///   TTuiApp timer tick; read the ElapsedMs field.
    /// </summary>
    ekTimer,
    /// <summary>
    ///   Application close request.
    /// </summary>
    ekQuit
  );

{ TTuiEvent }

  /// <summary>
  ///   Input event delivered to TTuiWidget.HandleEvent and to TTuiApp callbacks.
  ///   Discriminated record: the valid field depends on Kind.
  ///   Use the static constructors MakeKey, MakeResize, MakeTimer, MakeQuit, and None.
  /// </summary>
  TTuiEvent = record
  public
    /// <summary>
    ///   Event kind; determines which field is valid.
    /// </summary>
    Kind: TTuiEventKind;
    /// <summary>
    ///   Details of the key press. Valid only when Kind = ekKey.
    /// </summary>
    Key: TTuiKeyEvent;
    /// <summary>
    ///   New terminal dimensions. Valid only when Kind = ekResize.
    /// </summary>
    Size: TSize;
    /// <summary>
    ///   Milliseconds elapsed since the previous iteration. Valid only when Kind = ekTimer.
    /// </summary>
    ElapsedMs: Integer;
    /// <summary>
    ///   Mouse event details. Valid only when Kind = ekMouse.
    /// </summary>
    Mouse: TTuiMouseEvent;
    /// <summary>
    ///   Creates an ekKey event with the given TTuiKeyEvent.
    /// </summary>
    class function MakeKey(const AKey: TTuiKeyEvent): TTuiEvent; static; inline;
    /// <summary>
    ///   Creates an ekMouse event with the given TTuiMouseEvent.
    /// </summary>
    class function MakeMouse(const AMouse: TTuiMouseEvent): TTuiEvent; static; inline;
    /// <summary>
    ///   Creates an ekQuit event.
    /// </summary>
    class function MakeQuit: TTuiEvent; static; inline;
    /// <summary>
    ///   Creates an ekResize event with the given dimensions.
    /// </summary>
    class function MakeResize(const ASize: TSize): TTuiEvent; static; inline;
    /// <summary>
    ///   Creates an ekTimer event with the milliseconds elapsed since the previous iteration.
    /// </summary>
    class function MakeTimer(AElapsedMs: Integer): TTuiEvent; static; inline;
    /// <summary>
    ///   Creates an ekNone sentinel event.
    /// </summary>
    class function None: TTuiEvent; static; inline;
  end;

implementation

{ TTuiEvent }

class function TTuiEvent.MakeKey(const AKey: TTuiKeyEvent): TTuiEvent;
begin
  Result := Default(TTuiEvent);
  Result.Kind := ekKey;
  Result.Key := AKey;
end;

class function TTuiEvent.MakeMouse(const AMouse: TTuiMouseEvent): TTuiEvent;
begin
  Result := Default(TTuiEvent);
  Result.Kind := ekMouse;
  Result.Mouse := AMouse;
end;

class function TTuiEvent.MakeQuit: TTuiEvent;
begin
  Result := Default(TTuiEvent);
  Result.Kind := ekQuit;
end;

class function TTuiEvent.MakeResize(const ASize: TSize): TTuiEvent;
begin
  Result := Default(TTuiEvent);
  Result.Kind := ekResize;
  Result.Size := ASize;
end;

class function TTuiEvent.MakeTimer(AElapsedMs: Integer): TTuiEvent;
begin
  Result := Default(TTuiEvent);
  Result.Kind := ekTimer;
  Result.ElapsedMs := AElapsedMs;
end;

class function TTuiEvent.None: TTuiEvent;
begin
  Result := Default(TTuiEvent);
  Result.Kind := ekNone;
  Result.Key := TTuiKeyEvent.Make(kcNone, #0, []);
end;

end.
