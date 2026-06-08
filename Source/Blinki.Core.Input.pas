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
{   Unit:        Blinki.Core.Input.pas                           }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Keyboard input model for the Blinki library.
///   Defines TTuiKeyCode (key codes), TTuiKeyModifiers (modifiers),
///   and TTuiKeyEvent (keyboard event with character and modifiers).
/// </summary>
unit Blinki.Core.Input;

interface

type

{ TTuiKeyCode }

  /// <summary>
  ///   Logical key code of the pressed key, platform-independent.
  ///   kcChar indicates a printable Unicode character; all other values
  ///   represent special or navigation keys.
  /// </summary>
  TTuiKeyCode = (
    /// <summary>
    ///   No key detected (used as a sentinel value).
    /// </summary>
    kcNone,
    /// <summary>
    ///   Printable Unicode character; read the Character field of TTuiKeyEvent.
    /// </summary>
    kcChar,
    /// <summary>
    ///   Enter (Return) key.
    /// </summary>
    kcEnter,
    /// <summary>
    ///   Escape key.
    /// </summary>
    kcEscape,
    /// <summary>
    ///   Backspace key.
    /// </summary>
    kcBackspace,
    /// <summary>
    ///   Tab key.
    /// </summary>
    kcTab,
    /// <summary>
    ///   Space bar.
    /// </summary>
    kcSpace,
    /// <summary>
    ///   Up arrow key.
    /// </summary>
    kcUp,
    /// <summary>
    ///   Down arrow key.
    /// </summary>
    kcDown,
    /// <summary>
    ///   Left arrow key.
    /// </summary>
    kcLeft,
    /// <summary>
    ///   Right arrow key.
    /// </summary>
    kcRight,
    /// <summary>
    ///   Home key.
    /// </summary>
    kcHome,
    /// <summary>
    ///   End key.
    /// </summary>
    kcEnd,
    /// <summary>
    ///   Page Up key.
    /// </summary>
    kcPageUp,
    /// <summary>
    ///   Page Down key.
    /// </summary>
    kcPageDown,
    /// <summary>
    ///   Insert key.
    /// </summary>
    kcInsert,
    /// <summary>
    ///   Delete key.
    /// </summary>
    kcDelete,
    /// <summary>
    ///   Function key F1.
    /// </summary>
    kcF1,
    /// <summary>
    ///   Function key F2.
    /// </summary>
    kcF2,
    /// <summary>
    ///   Function key F3.
    /// </summary>
    kcF3,
    /// <summary>
    ///   Function key F4.
    /// </summary>
    kcF4,
    /// <summary>
    ///   Function key F5.
    /// </summary>
    kcF5,
    /// <summary>
    ///   Function key F6.
    /// </summary>
    kcF6,
    /// <summary>
    ///   Function key F7.
    /// </summary>
    kcF7,
    /// <summary>
    ///   Function key F8.
    /// </summary>
    kcF8,
    /// <summary>
    ///   Function key F9.
    /// </summary>
    kcF9,
    /// <summary>
    ///   Function key F10.
    /// </summary>
    kcF10,
    /// <summary>
    ///   Function key F11.
    /// </summary>
    kcF11,
    /// <summary>
    ///   Function key F12.
    /// </summary>
    kcF12
  );

{ TTuiKeyModifier }

  /// <summary>
  ///   Key modifier: Shift, Ctrl, or Alt.
  /// </summary>
  TTuiKeyModifier = (
    /// <summary>
    ///   Shift key held down.
    /// </summary>
    kmShift,
    /// <summary>
    ///   Ctrl key held down.
    /// </summary>
    kmCtrl,
    /// <summary>
    ///   Alt key held down.
    /// </summary>
    kmAlt
  );

{ TTuiKeyModifiers }

  /// <summary>
  ///   Set of key modifiers that can be combined freely.
  /// </summary>
  TTuiKeyModifiers = set of TTuiKeyModifier;

{ TTuiKeyEvent }

  /// <summary>
  ///   Keyboard event: describes a pressed key with its logical code,
  ///   the Unicode character (if printable), and the active modifiers.
  /// </summary>
  TTuiKeyEvent = record
  public
    /// <summary>
    ///   Logical code of the pressed key.
    /// </summary>
    Code: TTuiKeyCode;

    /// <summary>
    ///   Unicode character of the key. Valid only when Code = kcChar.
    ///   For all other codes the value is #0.
    /// </summary>
    Character: Char;

    /// <summary>
    ///   Modifiers active at the time the key was pressed.
    /// </summary>
    Modifiers: TTuiKeyModifiers;

    /// <summary>
    ///   Returns True if the key corresponds to a printable character.
    /// </summary>
    function IsPrintable: Boolean;

    /// <summary>
    ///   Textual representation of the event, useful for diagnostics.
    ///   Examples: "Ctrl+Shift+F5", "Esc", "Enter", "'a'", "Ctrl+'c'".
    /// </summary>
    function ToString: string;

    /// <summary>
    ///   Creates a TTuiKeyEvent with the specified values.
    /// </summary>
    class function Make(ACode: TTuiKeyCode; ACharacter: Char;
      AModifiers: TTuiKeyModifiers): TTuiKeyEvent; static; inline;
  end;

{ TTuiMouseButton }

  /// <summary>
  ///   Mouse button identifier used in TTuiMouseEvent.
  /// </summary>
  TTuiMouseButton = (
    /// <summary>
    ///   No button (used for move and wheel events).
    /// </summary>
    mbNone,
    /// <summary>
    ///   Left mouse button.
    /// </summary>
    mbLeft,
    /// <summary>
    ///   Right mouse button.
    /// </summary>
    mbRight,
    /// <summary>
    ///   Middle mouse button.
    /// </summary>
    mbMiddle
  );

{ TTuiMouseEventKind }

  /// <summary>
  ///   Kind of mouse interaction reported by TTuiMouseEvent.
  /// </summary>
  TTuiMouseEventKind = (
    /// <summary>
    ///   A mouse button was pressed.
    /// </summary>
    mekDown,
    /// <summary>
    ///   A mouse button was released.
    /// </summary>
    mekUp,
    /// <summary>
    ///   The mouse cursor moved.
    /// </summary>
    mekMove,
    /// <summary>
    ///   The scroll wheel was rotated. Read WheelDelta for direction.
    /// </summary>
    mekWheel
  );

{ TTuiMouseEvent }

  /// <summary>
  ///   Mouse event: position, button, kind, wheel delta, and keyboard modifiers
  ///   active at the time the event occurred.
  /// </summary>
  TTuiMouseEvent = record
  public
    /// <summary>
    ///   0-based column of the cell under the cursor at the time of the event.
    /// </summary>
    X: Integer;
    /// <summary>
    ///   0-based row of the cell under the cursor at the time of the event.
    /// </summary>
    Y: Integer;
    /// <summary>
    ///   Button involved in the event. mbNone for mekMove and mekWheel events.
    /// </summary>
    Button: TTuiMouseButton;
    /// <summary>
    ///   Kind of mouse event (press, release, move, wheel).
    /// </summary>
    Kind: TTuiMouseEventKind;
    /// <summary>
    ///   Scroll direction for mekWheel events: +1 = scroll up, -1 = scroll down.
    ///   Zero for all other event kinds.
    /// </summary>
    WheelDelta: Integer;
    /// <summary>
    ///   Keyboard modifiers (Shift, Ctrl, Alt) active at the time of the event.
    /// </summary>
    Modifiers: TTuiKeyModifiers;
    /// <summary>
    ///   Creates a TTuiMouseEvent with the specified values.
    /// </summary>
    class function Make(AX, AY: Integer; AButton: TTuiMouseButton;
      AKind: TTuiMouseEventKind; AWheelDelta: Integer;
      AModifiers: TTuiKeyModifiers): TTuiMouseEvent; static; inline;
  end;

implementation

uses
  System.SysUtils;

const
  KeyCodeNames: array[TTuiKeyCode] of string = (
    'None', 'Char', 'Enter', 'Esc', 'Backspace', 'Tab', 'Space',
    'Up', 'Down', 'Left', 'Right', 'Home', 'End', 'PageUp', 'PageDown',
    'Insert', 'Delete',
    'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'
  );

{ TTuiKeyEvent }

function TTuiKeyEvent.IsPrintable: Boolean;
begin
  Result := (Code = kcChar) and (Character >= ' ');
end;

function TTuiKeyEvent.ToString: string;
begin
  var LPrefix := '';
  if kmCtrl in Modifiers then
    LPrefix := LPrefix + 'Ctrl+';
  if kmAlt in Modifiers then
    LPrefix := LPrefix + 'Alt+';
  if kmShift in Modifiers then
    LPrefix := LPrefix + 'Shift+';
  if Code = kcChar then
    Result := LPrefix + '''' + Character + ''''
  else
    Result := LPrefix + KeyCodeNames[Code];
end;

class function TTuiKeyEvent.Make(ACode: TTuiKeyCode; ACharacter: Char;
  AModifiers: TTuiKeyModifiers): TTuiKeyEvent;
begin
  Result.Code := ACode;
  Result.Character := ACharacter;
  Result.Modifiers := AModifiers;
end;

{ TTuiMouseEvent }

class function TTuiMouseEvent.Make(AX, AY: Integer; AButton: TTuiMouseButton;
  AKind: TTuiMouseEventKind; AWheelDelta: Integer;
  AModifiers: TTuiKeyModifiers): TTuiMouseEvent;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Button := AButton;
  Result.Kind := AKind;
  Result.WheelDelta := AWheelDelta;
  Result.Modifiers := AModifiers;
end;

end.
