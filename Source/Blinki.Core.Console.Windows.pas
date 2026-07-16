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
{   Unit:        Blinki.Core.Console.Windows.pas                 }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Windows implementation of the console backend for the Blinki library.
///   Uses ENABLE_VIRTUAL_TERMINAL_PROCESSING, ReadConsoleInputW with timeout
///   via WaitForSingleObject, and WriteConsoleW for Unicode output.
/// </summary>
/// <remarks>
///   Do not use SetConsoleTextAttribute or SetConsoleCursorPosition: all
///   rendering and cursor control is performed via ANSI sequences written
///   through Write.
/// </remarks>
unit Blinki.Core.Console.Windows;

interface

{$IFDEF MSWINDOWS}

uses
  System.SysUtils,
  System.Types,
  Winapi.Windows,
  Blinki.Core.Console,
  Blinki.Core.Event,
  Blinki.Core.Input,
  Blinki.Core.Unicode;

type
  // Explicit layout to avoid incompatibilities across Delphi versions.
  // The layout of TInputRecord varies between Delphi 10.x, 11.x, 12.x.

{ TTuiWinKeyEvent }

  TTuiWinKeyEvent = packed record
    bKeyDown: BOOL;
    wRepeatCount: Word;
    wVirtualKeyCode: Word;
    wVirtualScanCode: Word;
    UnicodeChar: WideChar;
    dwControlKeyState: DWORD;
  end;

{ TTuiWinMouseEvent }

  // Layout matches MOUSE_EVENT_RECORD (16 bytes):
  //   COORD dwMousePosition = SHORT X + SHORT Y (4 bytes)
  //   DWORD dwButtonState, dwControlKeyState, dwEventFlags
  TTuiWinMouseEvent = packed record
    PosX: SmallInt;
    PosY: SmallInt;
    dwButtonState: DWORD;
    dwControlKeyState: DWORD;
    dwEventFlags: DWORD;
  end;

{ TTuiWinInputRecord }

  // Variant record matching INPUT_RECORD layout (20 bytes):
  //   WORD EventType + WORD padding at offset 0
  //   Union of event records at offset 4 (both KEY_EVENT_RECORD and
  //   MOUSE_EVENT_RECORD are 16 bytes, so the total size is unchanged).
  TTuiWinInputRecord = packed record
    EventType: Word;
    Padding: Word;
    case Integer of
      0: (KeyEvent: TTuiWinKeyEvent);
      1: (MouseEvent: TTuiWinMouseEvent);
  end;

{ TTuiWindowsConsoleBackend }

  /// <summary>
  ///   Windows implementation of ITuiConsoleBackend.
  ///   Handles VT100, raw input mode, UTF-8, and non-blocking input via
  ///   WaitForSingleObject + ReadConsoleInputW.
  /// </summary>
  TTuiWindowsConsoleBackend = class(TInterfacedObject, ITuiConsoleBackend)
  strict private
    // Tracks the previous raw button state for press/release transition detection.
    FLastButtonState: DWORD;
    // High surrogate waiting for its low half: the console delivers a
    // supplementary-plane character (emoji) as two consecutive key events.
    FPendingHighSurrogate: Char;
    FOriginalOutMode: DWORD;
    FOriginalInMode: DWORD;
    FOriginalOutputCodePage: UINT;
    FOriginalInputCodePage: UINT;
    FOpened: Boolean;
    FStdOut: THandle;
    FStdIn: THandle;
    function DecodeInputRecord(const ARec: TTuiWinInputRecord;
      out AKey: TTuiKeyEvent): Boolean;
    function DecodeMouseRecord(const ARec: TTuiWinInputRecord;
      out AMouse: TTuiMouseEvent): Boolean;
  public
    constructor Create;
    /// <inheritdoc/>
    destructor Destroy; override;
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

{$IFDEF MSWINDOWS}

const
  // Defined with a local name to avoid collisions if already present in Winapi.Windows
  // on Delphi versions that include it (Delphi 12+).
  BLINKI_VT_PROCESSING      = $0004;  // ENABLE_VIRTUAL_TERMINAL_PROCESSING
  BLINKI_ENABLE_MOUSE_INPUT  = $0010;  // ENABLE_MOUSE_INPUT
  BLINKI_ENABLE_EXTENDED     = $0080;  // ENABLE_EXTENDED_FLAGS (required to suppress quick-edit)
  BLINKI_MOUSE_EVENT         = 2;      // INPUT_RECORD.EventType for mouse events
  // Mouse event flag bits (dwEventFlags)
  BLINKI_MOUSE_MOVED         = $0001;
  BLINKI_MOUSE_WHEELED       = $0004;
  // Mouse button state bits (dwButtonState, low 3 bits)
  BLINKI_BTN_LEFT            = $0001;  // FROM_LEFT_1ST_BUTTON_PRESSED
  BLINKI_BTN_RIGHT           = $0002;  // RIGHTMOST_BUTTON_PRESSED
  BLINKI_BTN_MIDDLE          = $0004;  // FROM_LEFT_2ND_BUTTON_PRESSED
  BLINKI_BTN_MASK            = $0007;  // mask covering the three buttons above

function WinReadConsoleInput(hConsoleInput: THandle;
  var lpBuffer: TTuiWinInputRecord; nLength: DWORD;
  var lpNumberOfEventsRead: DWORD): BOOL; stdcall;
  external kernel32 name 'ReadConsoleInputW';

function WinPeekConsoleInput(hConsoleInput: THandle;
  var lpBuffer: TTuiWinInputRecord; nLength: DWORD;
  var lpNumberOfEventsRead: DWORD): BOOL; stdcall;
  external kernel32 name 'PeekConsoleInputW';

// Weak (non-ref-counted) reference to the last opened instance,
// used by the Ctrl+C handler running on a separate thread.
var
  GCtrlCBackend: TTuiWindowsConsoleBackend = nil;

function CtrlCHandler(dwCtrlType: DWORD): BOOL; stdcall;
begin
  if Assigned(GCtrlCBackend) then
  begin
    GCtrlCBackend.Close;
    GCtrlCBackend := nil;
  end;
  Result := False; // continue with the default handler (terminates the process)
end;

{ TTuiWindowsConsoleBackend }

constructor TTuiWindowsConsoleBackend.Create;
begin
  inherited;
  FStdOut := INVALID_HANDLE_VALUE;
  FStdIn := INVALID_HANDLE_VALUE;
end;

destructor TTuiWindowsConsoleBackend.Destroy;
begin
  Close;
  inherited;
end;

procedure TTuiWindowsConsoleBackend.Open;
begin
  if FOpened then
    Exit;

  FStdOut := GetStdHandle(STD_OUTPUT_HANDLE);
  FStdIn := GetStdHandle(STD_INPUT_HANDLE);

  if (FStdOut = INVALID_HANDLE_VALUE) or (FStdIn = INVALID_HANDLE_VALUE) then
    raise ETuiConsoleError.Create('Unable to obtain the console handles. ' +
      'Make sure the program is started in a console (not the IDE).');

  // Save original modes for restoration in Close
  GetConsoleMode(FStdOut, FOriginalOutMode);
  GetConsoleMode(FStdIn, FOriginalInMode);
  FOriginalOutputCodePage := GetConsoleOutputCP;
  FOriginalInputCodePage := GetConsoleCP;

  // Enable VT100/ANSI processing on output.
  // Preserve existing flags and add ENABLE_VIRTUAL_TERMINAL_PROCESSING.
  var LMode: DWORD;
  GetConsoleMode(FStdOut, LMode);
  if not SetConsoleMode(FStdOut, LMode or BLINKI_VT_PROCESSING) then
    raise ETuiConsoleError.Create(
      'ENABLE_VIRTUAL_TERMINAL_PROCESSING is not available. ' +
      'Requires Windows 10 version 10.0.10586 or later.');

  // Raw input mode: keep ENABLE_PROCESSED_INPUT for Ctrl+C, disable line
  // buffering and echo.  ENABLE_MOUSE_INPUT enables mouse events in the queue;
  // ENABLE_EXTENDED_FLAGS without ENABLE_QUICK_EDIT_MODE is required so the
  // console delivers mouse events instead of intercepting them for text selection.
  if not SetConsoleMode(FStdIn,
    ENABLE_PROCESSED_INPUT or BLINKI_ENABLE_MOUSE_INPUT or BLINKI_ENABLE_EXTENDED) then
    raise ETuiConsoleError.Create('Unable to set raw input mode.');

  // UTF-8 code page: required for box drawing and Unicode characters
  SetConsoleOutputCP(CP_UTF8);
  SetConsoleCP(CP_UTF8);

  // Detect the emoji capability of the host: Windows Terminal (WT_SESSION)
  // and WezTerm (the one TERM_PROGRAM host with a Windows build) merge emoji
  // grapheme clusters into one glyph; legacy conhost draws the parts
  // separately, so widths must be measured as the sum of the parts. An
  // explicit application assignment to TTuiUnicode.EmojiLevel always wins
  // over this detection, whether it happens before or after Open.
  if (GetEnvironmentVariable('WT_SESSION') <> '') or
     SameText(GetEnvironmentVariable('TERM_PROGRAM'), 'WezTerm') then
    TTuiUnicode.ApplyDetectedEmojiLevel(elFull)
  else
    TTuiUnicode.ApplyDetectedEmojiLevel(elBasic);

  // Install the Ctrl+C handler for guaranteed cleanup
  GCtrlCBackend := Self;
  SetConsoleCtrlHandler(@CtrlCHandler, True);

  FOpened := True;
end;

procedure TTuiWindowsConsoleBackend.Close;
begin
  if not FOpened then
    Exit;
  FOpened := False;

  // Remove the Ctrl+C handler
  SetConsoleCtrlHandler(@CtrlCHandler, False);
  if GCtrlCBackend = Self then
    GCtrlCBackend := nil;

  // Restore original code pages
  try
    SetConsoleOutputCP(FOriginalOutputCodePage);
    SetConsoleCP(FOriginalInputCodePage);
  except
    // Ignore: in cleanup, do not propagate exceptions
  end;

  // Restore original console modes
  try
    SetConsoleMode(FStdOut, FOriginalOutMode);
    SetConsoleMode(FStdIn, FOriginalInMode);
  except
    // Ignore: in cleanup, do not propagate exceptions
  end;
end;

procedure TTuiWindowsConsoleBackend.Flush;
begin
  // WriteConsoleW is synchronous on Windows; no explicit flush needed.
end;

function TTuiWindowsConsoleBackend.GetSize: TSize;
begin
  var LInfo: TConsoleScreenBufferInfo;
  if not GetConsoleScreenBufferInfo(FStdOut, LInfo) then
  begin
    Result.cx := 80;
    Result.cy := 24;
    Exit;
  end;
  Result.cx := LInfo.srWindow.Right - LInfo.srWindow.Left + 1;
  Result.cy := LInfo.srWindow.Bottom - LInfo.srWindow.Top + 1;
end;

function TTuiWindowsConsoleBackend.DecodeInputRecord(const ARec: TTuiWinInputRecord;
  out AKey: TTuiKeyEvent): Boolean;
begin
  Result := False;
  // KEY_EVENT is defined in Winapi.Windows
  if (ARec.EventType <> KEY_EVENT) or not ARec.KeyEvent.bKeyDown then
    Exit;

  var LModifiers: TTuiKeyModifiers := [];
  // LEFT_CTRL_PRESSED, RIGHT_CTRL_PRESSED, SHIFT_PRESSED, LEFT_ALT_PRESSED,
  // RIGHT_ALT_PRESSED are all defined in Winapi.Windows.
  var LState := ARec.KeyEvent.dwControlKeyState;
  if (LState and (LEFT_CTRL_PRESSED or RIGHT_CTRL_PRESSED)) <> 0 then
    Include(LModifiers, kmCtrl);
  if (LState and SHIFT_PRESSED) <> 0 then
    Include(LModifiers, kmShift);
  if (LState and (LEFT_ALT_PRESSED or RIGHT_ALT_PRESSED)) <> 0 then
    Include(LModifiers, kmAlt);

  case ARec.KeyEvent.wVirtualKeyCode of
    VK_RETURN:
      AKey := TTuiKeyEvent.Make(kcEnter, #0, LModifiers);
    VK_ESCAPE:
      AKey := TTuiKeyEvent.Make(kcEscape, #0, LModifiers);
    VK_BACK:
       AKey := TTuiKeyEvent.Make(kcBackspace, #0, LModifiers);
    VK_TAB:
      AKey := TTuiKeyEvent.Make(kcTab, #0, LModifiers);
    VK_UP:
      AKey := TTuiKeyEvent.Make(kcUp, #0, LModifiers);
    VK_DOWN:
      AKey := TTuiKeyEvent.Make(kcDown, #0, LModifiers);
    VK_LEFT:
      AKey := TTuiKeyEvent.Make(kcLeft, #0, LModifiers);
    VK_RIGHT:
      AKey := TTuiKeyEvent.Make(kcRight, #0, LModifiers);
    VK_HOME:
      AKey := TTuiKeyEvent.Make(kcHome, #0, LModifiers);
    VK_END:
      AKey := TTuiKeyEvent.Make(kcEnd, #0, LModifiers);
    VK_PRIOR:
      AKey := TTuiKeyEvent.Make(kcPageUp, #0, LModifiers);
    VK_NEXT:
      AKey := TTuiKeyEvent.Make(kcPageDown, #0, LModifiers);
    VK_INSERT:
      AKey := TTuiKeyEvent.Make(kcInsert, #0, LModifiers);
    VK_DELETE:
      AKey := TTuiKeyEvent.Make(kcDelete, #0, LModifiers);
    VK_SPACE:
      AKey := TTuiKeyEvent.Make(kcSpace, ' ', LModifiers);
    VK_F1..VK_F12:
      AKey := TTuiKeyEvent.Make(
        TTuiKeyCode(Ord(kcF1) + (ARec.KeyEvent.wVirtualKeyCode - VK_F1)),
        #0, LModifiers);
  else
    if ARec.KeyEvent.UnicodeChar <> #0 then
    begin
      var LChar := ARec.KeyEvent.UnicodeChar;
      if TTuiUnicode.IsHighSurrogate(LChar) then
      begin
        // First half of a supplementary-plane character: stash it and keep
        // draining until the matching low surrogate arrives.
        FPendingHighSurrogate := LChar;
        Exit;
      end;
      if TTuiUnicode.IsLowSurrogate(LChar) then
      begin
        if FPendingHighSurrogate = #0 then
          Exit; // orphan low surrogate: drop it
        AKey := TTuiKeyEvent.MakeCodePoint(kcChar,
          TTuiUnicode.CombineSurrogates(FPendingHighSurrogate, LChar), LModifiers);
        FPendingHighSurrogate := #0;
      end
      else
      begin
        // A BMP character invalidates any stashed half (orphan high surrogate).
        FPendingHighSurrogate := #0;
        AKey := TTuiKeyEvent.Make(kcChar, LChar, LModifiers);
      end;
    end
    else
      Exit; // unmapped key (e.g. standalone modifier key)
  end;
  // A completed non-character key (Enter, arrows, ...) invalidates any
  // stashed surrogate half from a malformed earlier sequence, so a stale
  // high surrogate can never pair with a low surrogate typed much later.
  if AKey.Code <> kcChar then
    FPendingHighSurrogate := #0;
  Result := True;
end;

function TTuiWindowsConsoleBackend.TryReadEvent(ATimeoutMs: Integer;
  out AEvent: TTuiEvent): Boolean;
begin
  Result := False;

  var LWaitResult := WaitForSingleObject(FStdIn, ATimeoutMs);
  if LWaitResult = WAIT_TIMEOUT then
    Exit;
  if LWaitResult <> WAIT_OBJECT_0 then
    Exit;

  // Drain the queue looking for the first useful keyboard or mouse event
  repeat
    var LNumEvents: DWORD;
    GetNumberOfConsoleInputEvents(FStdIn, LNumEvents);
    if LNumEvents = 0 then
      Exit;

    var LRec: TTuiWinInputRecord;
    var LNumRead: DWORD;

    WinPeekConsoleInput(FStdIn, LRec, 1, LNumRead);
    if LNumRead = 0 then
      Exit;

    var LKey: TTuiKeyEvent;
    var LMouse: TTuiMouseEvent;
    if DecodeInputRecord(LRec, LKey) then
    begin
      WinReadConsoleInput(FStdIn, LRec, 1, LNumRead);
      AEvent := TTuiEvent.MakeKey(LKey);
      Result := True;
      Exit;
    end
    else if DecodeMouseRecord(LRec, LMouse) then
    begin
      WinReadConsoleInput(FStdIn, LRec, 1, LNumRead);
      AEvent := TTuiEvent.MakeMouse(LMouse);
      Result := True;
      Exit;
    end
    else begin
      // Non-useful event (key-up, focus change, window event, discarded move): consume and continue
      WinReadConsoleInput(FStdIn, LRec, 1, LNumRead);
    end;
  until False;
end;

function TTuiWindowsConsoleBackend.TryReadKey(ATimeoutMs: Integer;
  out AKey: TTuiKeyEvent): Boolean;
begin
  Result := False;

  var LWaitResult := WaitForSingleObject(FStdIn, ATimeoutMs);
  if LWaitResult = WAIT_TIMEOUT then
    Exit;
  if LWaitResult <> WAIT_OBJECT_0 then
    Exit;

  // Events are available; find the first useful keyboard event
  repeat
    var LNumEvents: DWORD;
    GetNumberOfConsoleInputEvents(FStdIn, LNumEvents);
    if LNumEvents = 0 then
      Exit;

    var LRec: TTuiWinInputRecord;

    var LNumRead: DWORD;
    WinPeekConsoleInput(FStdIn, LRec, 1, LNumRead);
    if LNumRead = 0 then
      Exit;

    if DecodeInputRecord(LRec, AKey) then
    begin
      // Consume the event from the queue
      WinReadConsoleInput(FStdIn, LRec, 1, LNumRead);
      Result := True;
      Exit;
    end
    else
      // Non-keyboard event or key-up: discard and continue
      WinReadConsoleInput(FStdIn, LRec, 1, LNumRead);
  until False;
end;

function TTuiWindowsConsoleBackend.DecodeMouseRecord(const ARec: TTuiWinInputRecord;
  out AMouse: TTuiMouseEvent): Boolean;
begin
  Result := False;
  if ARec.EventType <> BLINKI_MOUSE_EVENT then
    Exit;

  // Decode keyboard modifiers from the mouse record
  var LModifiers: TTuiKeyModifiers := [];
  var LState := ARec.MouseEvent.dwControlKeyState;
  if (LState and (LEFT_CTRL_PRESSED or RIGHT_CTRL_PRESSED)) <> 0 then
    Include(LModifiers, kmCtrl);
  if (LState and SHIFT_PRESSED) <> 0 then
    Include(LModifiers, kmShift);
  if (LState and (LEFT_ALT_PRESSED or RIGHT_ALT_PRESSED)) <> 0 then
    Include(LModifiers, kmAlt);

  var LPosX := ARec.MouseEvent.PosX;
  var LPosY := ARec.MouseEvent.PosY;

  // Wheel event
  if (ARec.MouseEvent.dwEventFlags and BLINKI_MOUSE_WHEELED) <> 0 then
  begin
    // High word of dwButtonState holds the signed wheel delta (WHEEL_DELTA units)
    var LWheelDelta: Integer;
    var LRaw := Integer(ARec.MouseEvent.dwButtonState) shr 16;
    if LRaw >= $8000 then
      LRaw := LRaw - $10000;  // sign-extend 16-bit value to 32-bit
    if LRaw > 0 then
      LWheelDelta := 1
    else if LRaw < 0 then
      LWheelDelta := -1
    else
      LWheelDelta := 0;
    AMouse := TTuiMouseEvent.Make(LPosX, LPosY, mbNone, mekWheel, LWheelDelta, LModifiers);
    Result := True;
    Exit;
  end;

  // Discard pure move events (no button state change) to avoid flooding the queue
  if (ARec.MouseEvent.dwEventFlags and BLINKI_MOUSE_MOVED) <> 0 then
  begin
    // Update tracking state even for discarded move events
    FLastButtonState := ARec.MouseEvent.dwButtonState;
    Exit;
  end;

  // Button state change event (dwEventFlags = 0)
  var LCurrButtons := ARec.MouseEvent.dwButtonState and BLINKI_BTN_MASK;
  var LChanged := LCurrButtons xor (FLastButtonState and BLINKI_BTN_MASK);
  FLastButtonState := ARec.MouseEvent.dwButtonState;

  if LChanged = 0 then
    Exit;

  // Identify the first changed button (priority: left, right, middle)
  var LButton: TTuiMouseButton;
  if (LChanged and BLINKI_BTN_LEFT) <> 0 then
    LButton := mbLeft
  else if (LChanged and BLINKI_BTN_RIGHT) <> 0 then
    LButton := mbRight
  else if (LChanged and BLINKI_BTN_MIDDLE) <> 0 then
    LButton := mbMiddle
  else
    Exit;

  // Bit newly set = press; bit newly cleared = release
  var LBit := BLINKI_BTN_LEFT;
  case LButton of
    mbLeft:
      LBit := BLINKI_BTN_LEFT;
    mbRight:
      LBit := BLINKI_BTN_RIGHT;
    mbMiddle:
      LBit := BLINKI_BTN_MIDDLE;
  end;

  var LKind: TTuiMouseEventKind;
  if (LCurrButtons and LBit) <> 0 then
    LKind := mekDown
  else
    LKind := mekUp;

  AMouse := TTuiMouseEvent.Make(LPosX, LPosY, LButton, LKind, 0, LModifiers);
  Result := True;
end;

procedure TTuiWindowsConsoleBackend.Write(const AText: string);
begin
  var LWritten: DWORD;
  WriteConsoleW(FStdOut, PChar(AText), Length(AText), LWritten, nil);
end;

{$ENDIF}

end.
