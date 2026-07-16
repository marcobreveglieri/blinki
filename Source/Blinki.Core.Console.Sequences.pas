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
{   Unit:        Blinki.Core.Console.Sequences.pas               }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Terminal input sequence decoder for the Blinki library: a pure state
///   machine that turns the raw byte stream of a POSIX tty (UTF-8 text,
///   CSI/SS3 escape sequences, SGR mouse reports) into TTuiEvent values.
///   No syscalls, no I/O, no platform dependencies: the unit compiles on
///   every platform so the whole decoding logic is unit-testable from the
///   Windows DUnitX suite, while the POSIX backend stays thin plumbing.
/// </summary>
/// <remarks>
///   Feed raw bytes with PutBytes as they arrive from read(); pull decoded
///   events with TryGetEvent. A byte sequence may be split at any point
///   across PutBytes calls (short reads): the decoder simply waits for the
///   missing bytes. A lone ESC is ambiguous (Escape key vs the start of a
///   sequence): when HasPendingPrefix is True the caller should wait up to
///   DefaultEscTimeoutMs for more bytes and then call FlushPending, which
///   resolves a stalled lone ESC into the Escape key. Unknown or malformed
///   sequences are swallowed silently so garbage never reaches widgets.
/// </remarks>
unit Blinki.Core.Console.Sequences;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  Blinki.Core.Event,
  Blinki.Core.Input;

type

{ TTuiSequenceDecoder }

  /// <summary>
  ///   Incremental decoder from a terminal byte stream to keyboard and mouse
  ///   events. Not thread-safe: like the console backends, it must be used
  ///   from the event-loop thread only.
  /// </summary>
  TTuiSequenceDecoder = class
  public const
    /// <summary>
    ///   Suggested time the backend should wait for more bytes after a lone
    ///   ESC before calling FlushPending to resolve it as the Escape key.
    ///   Escape sequences arrive as a burst, so 30 ms is generous for any
    ///   remote terminal while staying imperceptible to the user.
    /// </summary>
    DefaultEscTimeoutMs = 30;
  strict private
    FBuffer: TBytes;
    FCount: Integer;
    FEvents: TQueue<TTuiEvent>;
    class function DecodeModifiers(AParam: Integer): TTuiKeyModifiers; static;
    procedure Discard(ACount: Integer);
    class function KeyFromLetter(AFinal: Byte; AModifiers: TTuiKeyModifiers;
      out AEvent: TTuiEvent): Boolean; static;
    class function KeyFromTilde(AParam: Integer; AModifiers: TTuiKeyModifiers;
      out AEvent: TTuiEvent): Boolean; static;
    class procedure ParseCsi(const ABuffer: TBytes; ACount: Integer;
      out AConsumed: Integer; out AEvent: TTuiEvent; out AHasEvent: Boolean;
      out ANeedMore: Boolean); static;
    class procedure ParseEscape(const ABuffer: TBytes; ACount: Integer;
      out AConsumed: Integer; out AEvent: TTuiEvent; out AHasEvent: Boolean;
      out ANeedMore: Boolean); static;
    class procedure ParseOne(const ABuffer: TBytes; ACount: Integer;
      out AConsumed: Integer; out AEvent: TTuiEvent; out AHasEvent: Boolean;
      out ANeedMore: Boolean); static;
    class procedure ParseSgrMouse(const AParams: array of Integer;
      AParamCount: Integer; AFinal: Byte; out AEvent: TTuiEvent;
      out AHasEvent: Boolean); static;
    class procedure ParseSs3(const ABuffer: TBytes; ACount: Integer;
      out AConsumed: Integer; out AEvent: TTuiEvent; out AHasEvent: Boolean;
      out ANeedMore: Boolean); static;
    class procedure ParseUtf8(const ABuffer: TBytes; ACount: Integer;
      out AConsumed: Integer; out AEvent: TTuiEvent; out AHasEvent: Boolean;
      out ANeedMore: Boolean); static;
    procedure Pump;
  public
    /// <summary>
    ///   Creates an empty decoder.
    /// </summary>
    constructor Create;
    /// <inheritdoc/>
    destructor Destroy; override;

    /// <summary>
    ///   Resolves an input prefix stalled at the buffer head: a lone ESC
    ///   becomes the Escape key; a truncated sequence or UTF-8 fragment that
    ///   never completed is dropped. Call after DefaultEscTimeoutMs elapses
    ///   with HasPendingPrefix still True and no new bytes.
    /// </summary>
    procedure FlushPending;

    /// <summary>
    ///   True when the buffer ends with an incomplete prefix (a lone ESC, a
    ///   partial escape sequence or a truncated UTF-8 character) that more
    ///   bytes — or a FlushPending timeout — must resolve.
    /// </summary>
    function HasPendingPrefix: Boolean;

    /// <summary>
    ///   Appends ACount raw bytes to the decoder and decodes as many
    ///   complete events as possible.
    /// </summary>
    procedure PutBytes(const ABytes: array of Byte; ACount: Integer);

    /// <summary>
    ///   Drops all buffered bytes and queued events.
    /// </summary>
    procedure Reset;

    /// <summary>
    ///   Pops the next decoded event. Returns False when no complete event
    ///   is available yet.
    /// </summary>
    function TryGetEvent(out AEvent: TTuiEvent): Boolean;
  end;

implementation

const
  BEsc = $1B;

{ TTuiSequenceDecoder }

constructor TTuiSequenceDecoder.Create;
begin
  inherited Create;
  FEvents := TQueue<TTuiEvent>.Create;
end;

destructor TTuiSequenceDecoder.Destroy;
begin
  if Assigned(FEvents) then
    FreeAndNil(FEvents);
  inherited Destroy;
end;

procedure TTuiSequenceDecoder.Discard(ACount: Integer);
begin
  if ACount >= FCount then
  begin
    FCount := 0;
    Exit;
  end;
  Move(FBuffer[ACount], FBuffer[0], FCount - ACount);
  Dec(FCount, ACount);
end;

procedure TTuiSequenceDecoder.PutBytes(const ABytes: array of Byte; ACount: Integer);
begin
  if ACount <= 0 then
    Exit;
  if FCount + ACount > Length(FBuffer) then
    SetLength(FBuffer, (FCount + ACount) * 2 + 16);
  Move(ABytes[0], FBuffer[FCount], ACount);
  Inc(FCount, ACount);
  Pump;
end;

function TTuiSequenceDecoder.TryGetEvent(out AEvent: TTuiEvent): Boolean;
begin
  Result := FEvents.Count > 0;
  if Result then
    AEvent := FEvents.Dequeue
  else
    AEvent := TTuiEvent.None;
end;

function TTuiSequenceDecoder.HasPendingPrefix: Boolean;
begin
  // Pump runs after every PutBytes and drains everything parseable, so any
  // leftover bytes are by construction a stalled incomplete prefix.
  Result := FCount > 0;
end;

procedure TTuiSequenceDecoder.Reset;
begin
  FCount := 0;
  FEvents.Clear;
end;

procedure TTuiSequenceDecoder.FlushPending;
begin
  // Resolve whatever incomplete prefix is stalled at the buffer head. Each
  // iteration either consumes bytes or empties the buffer, so it terminates.
  Pump; // ensure everything parseable is parsed before resolving the tail
  while FCount > 0 do
  begin
    if FBuffer[0] = BEsc then
    begin
      // A lone ESC that never grew into a sequence IS the Escape key; the
      // bytes after it (if any) re-parse as ordinary input.
      FEvents.Enqueue(TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcEscape, #0, [])));
      Discard(1);
      Pump;
    end
    else
      // A truncated UTF-8 fragment with no continuation coming: drop it.
      FCount := 0;
  end;
end;

procedure TTuiSequenceDecoder.Pump;
begin
  while FCount > 0 do
  begin
    var LConsumed: Integer;
    var LEvent: TTuiEvent;
    var LHasEvent, LNeedMore: Boolean;
    ParseOne(FBuffer, FCount, LConsumed, LEvent, LHasEvent, LNeedMore);
    if LNeedMore then
      Break; // incomplete prefix at the head: wait for more bytes
    if LConsumed <= 0 then
      LConsumed := 1; // defensive: always make progress
    if LHasEvent then
      FEvents.Enqueue(LEvent);
    Discard(LConsumed);
  end;
end;

class function TTuiSequenceDecoder.DecodeModifiers(AParam: Integer): TTuiKeyModifiers;
begin
  // xterm modifier parameter: value - 1 is a bit mask (1=Shift 2=Alt 4=Ctrl),
  // e.g. ESC[1;5A is Ctrl+Up, ESC[1;2Z would be Shift variants.
  Result := [];
  if AParam < 2 then
    Exit;
  var LBits := AParam - 1;
  if (LBits and 1) <> 0 then
    Include(Result, kmShift);
  if (LBits and 2) <> 0 then
    Include(Result, kmAlt);
  if (LBits and 4) <> 0 then
    Include(Result, kmCtrl);
end;

class function TTuiSequenceDecoder.KeyFromTilde(AParam: Integer;
  AModifiers: TTuiKeyModifiers; out AEvent: TTuiEvent): Boolean;
begin
  // CSI <n> ~ : legacy function/navigation keys (vt220/xterm numbering).
  var LCode := kcNone;
  case AParam of
    1, 7: LCode := kcHome;
    2: LCode := kcInsert;
    3: LCode := kcDelete;
    4, 8: LCode := kcEnd;
    5: LCode := kcPageUp;
    6: LCode := kcPageDown;
    11..15: LCode := TTuiKeyCode(Ord(kcF1) + (AParam - 11));
    17..21: LCode := TTuiKeyCode(Ord(kcF6) + (AParam - 17));
    23: LCode := kcF11;
    24: LCode := kcF12;
  end;
  Result := LCode <> kcNone;
  if Result then
    AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(LCode, #0, AModifiers));
end;

class function TTuiSequenceDecoder.KeyFromLetter(AFinal: Byte;
  AModifiers: TTuiKeyModifiers; out AEvent: TTuiEvent): Boolean;
begin
  // Letter finals shared by CSI and SS3: arrows, Home/End, F1..F4.
  var LCode := kcNone;
  case AFinal of
    Ord('A'): LCode := kcUp;
    Ord('B'): LCode := kcDown;
    Ord('C'): LCode := kcRight;
    Ord('D'): LCode := kcLeft;
    Ord('H'): LCode := kcHome;
    Ord('F'): LCode := kcEnd;
    Ord('P'): LCode := kcF1;
    Ord('Q'): LCode := kcF2;
    Ord('R'): LCode := kcF3;
    Ord('S'): LCode := kcF4;
  end;
  Result := LCode <> kcNone;
  if Result then
    AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(LCode, #0, AModifiers));
end;

class procedure TTuiSequenceDecoder.ParseSgrMouse(const AParams: array of Integer;
  AParamCount: Integer; AFinal: Byte; out AEvent: TTuiEvent; out AHasEvent: Boolean);
begin
  // SGR mouse report: ESC [ < b ; x ; y (M = press/wheel, m = release).
  AHasEvent := False;
  if AParamCount < 3 then
    Exit;
  var LB := AParams[0];
  var LX := AParams[1] - 1; // SGR coordinates are 1-based
  var LY := AParams[2] - 1;
  if LX < 0 then
    LX := 0;
  if LY < 0 then
    LY := 0;
  if (LB and 32) <> 0 then
    Exit; // motion report: the framework never consumes mekMove

  var LModifiers: TTuiKeyModifiers := [];
  if (LB and 4) <> 0 then
    Include(LModifiers, kmShift);
  if (LB and 8) <> 0 then
    Include(LModifiers, kmAlt);
  if (LB and 16) <> 0 then
    Include(LModifiers, kmCtrl);

  if (LB and 64) <> 0 then
  begin
    // Vertical wheel only: 64 = up, 65 = down. 66/67 are horizontal wheel
    // events, which no widget consumes: reporting them as vertical would
    // scroll lists during horizontal touchpad gestures.
    var LDelta: Integer;
    case LB and 3 of
      0: LDelta := 1;
      1: LDelta := -1;
    else
      Exit;
    end;
    AEvent := TTuiEvent.MakeMouse(
      TTuiMouseEvent.Make(LX, LY, mbNone, mekWheel, LDelta, LModifiers));
    AHasEvent := True;
    Exit;
  end;

  var LButton: TTuiMouseButton;
  case LB and 3 of
    0: LButton := mbLeft;
    1: LButton := mbMiddle;
    2: LButton := mbRight;
  else
    Exit; // 3 = "no button" in legacy encodings: nothing to report
  end;

  var LKind := mekDown;
  if AFinal = Ord('m') then
    LKind := mekUp;
  AEvent := TTuiEvent.MakeMouse(
    TTuiMouseEvent.Make(LX, LY, LButton, LKind, 0, LModifiers));
  AHasEvent := True;
end;

class procedure TTuiSequenceDecoder.ParseCsi(const ABuffer: TBytes; ACount: Integer;
  out AConsumed: Integer; out AEvent: TTuiEvent; out AHasEvent: Boolean;
  out ANeedMore: Boolean);
begin
  // ABuffer[0..1] = ESC [ ; ACount >= 2.
  AConsumed := 0;
  AHasEvent := False;
  ANeedMore := False;

  if ACount < 3 then
  begin
    ANeedMore := True;
    Exit;
  end;

  // Linux console function keys: ESC [ [ A..E = F1..F5
  if ABuffer[2] = Ord('[') then
  begin
    if ACount < 4 then
    begin
      ANeedMore := True;
      Exit;
    end;
    AConsumed := 4;
    if (ABuffer[3] >= Ord('A')) and (ABuffer[3] <= Ord('E')) then
    begin
      AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(
        TTuiKeyCode(Ord(kcF1) + (ABuffer[3] - Ord('A'))), #0, []));
      AHasEvent := True;
    end;
    Exit;
  end;

  // Legacy X10 mouse: ESC [ M followed by 3 payload bytes. We only enable
  // SGR mode, but swallow X10 defensively for terminals that ignore 1006.
  if ABuffer[2] = Ord('M') then
  begin
    if ACount < 6 then
    begin
      ANeedMore := True;
      Exit;
    end;
    AConsumed := 6;
    Exit;
  end;

  // General CSI: parameters ($30..$3F), intermediates ($20..$2F), final ($40..$7E)
  var LIndex := 2;
  var LIsSgrMouse := False;
  var LIsPrivate := False;
  if ABuffer[LIndex] = Ord('<') then
  begin
    LIsSgrMouse := True;
    Inc(LIndex);
  end
  else if (ABuffer[LIndex] = Ord('?')) or (ABuffer[LIndex] = Ord('>')) or
          (ABuffer[LIndex] = Ord('=')) then
  begin
    LIsPrivate := True;
    Inc(LIndex);
  end;

  // Collect up to 4 numeric parameters separated by ';'
  var LParams: array[0..3] of Integer;
  for var LInit := 0 to High(LParams) do
    LParams[LInit] := 0;
  var LParamCount := 0;
  var LCurrent := 0;
  var LHasDigits := False;
  var LInSubparam := False;
  while (LIndex < ACount) and (ABuffer[LIndex] >= $30) and (ABuffer[LIndex] <= $3F) do
  begin
    var LByte := ABuffer[LIndex];
    if (LByte >= Ord('0')) and (LByte <= Ord('9')) then
    begin
      // Digits after a ':' belong to a subparameter (kitty protocol, event
      // types): keep only the primary value, never concatenate across ':'.
      if not LInSubparam then
      begin
        LCurrent := LCurrent * 10 + (LByte - Ord('0'));
        if LCurrent > 65535 then
          LCurrent := 65535; // clamp: params are small; avoid overflow on garbage
        LHasDigits := True;
      end;
    end
    else if LByte = Ord(';') then
    begin
      if LParamCount <= High(LParams) then
      begin
        LParams[LParamCount] := LCurrent;
        Inc(LParamCount);
      end;
      LCurrent := 0;
      LHasDigits := False;
      LInSubparam := False;
    end
    else if LByte = Ord(':') then
      LInSubparam := True;
    // Other parameter bytes ('<', '=', '>', '?') are skipped
    Inc(LIndex);
  end;
  if LHasDigits and (LParamCount <= High(LParams)) then
  begin
    LParams[LParamCount] := LCurrent;
    Inc(LParamCount);
  end;

  // Skip intermediates
  while (LIndex < ACount) and (ABuffer[LIndex] >= $20) and (ABuffer[LIndex] <= $2F) do
    Inc(LIndex);

  if LIndex >= ACount then
  begin
    ANeedMore := True;
    Exit;
  end;

  var LFinal := ABuffer[LIndex];
  if (LFinal < $40) or (LFinal > $7E) then
  begin
    // Malformed CSI: swallow it, but never eat an ESC — it starts the NEXT
    // sequence (VT parsers abort on ESC without consuming it).
    if LFinal = BEsc then
      AConsumed := LIndex
    else
      AConsumed := LIndex + 1;
    Exit;
  end;
  AConsumed := LIndex + 1;

  if LIsSgrMouse then
  begin
    if (LFinal = Ord('M')) or (LFinal = Ord('m')) then
      ParseSgrMouse(LParams, LParamCount, LFinal, AEvent, AHasEvent);
    Exit;
  end;
  if LIsPrivate then
    Exit; // private modes (e.g. ESC[?2004h): swallow

  // Modifier parameter: for letter finals it is the second parameter
  // (ESC[1;5A); for tilde keys as well (ESC[3;5~).
  var LModifiers: TTuiKeyModifiers := [];
  if LParamCount >= 2 then
    LModifiers := DecodeModifiers(LParams[1]);

  case LFinal of
    Ord('A'), Ord('B'), Ord('C'), Ord('D'),
    Ord('H'), Ord('F'),
    Ord('P'), Ord('Q'), Ord('R'), Ord('S'):
      AHasEvent := KeyFromLetter(LFinal, LModifiers, AEvent);
    Ord('Z'):
      begin
        // CSI Z = backtab: the framework expects Shift+Tab for reverse focus
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcTab, #0, [kmShift]));
        AHasEvent := True;
      end;
    Ord('~'):
      if LParamCount >= 1 then
        AHasEvent := KeyFromTilde(LParams[0], LModifiers, AEvent);
  end;
  // Every other final (h, l, u, c, R, ...) is swallowed silently.
end;

class procedure TTuiSequenceDecoder.ParseSs3(const ABuffer: TBytes; ACount: Integer;
  out AConsumed: Integer; out AEvent: TTuiEvent; out AHasEvent: Boolean;
  out ANeedMore: Boolean);
begin
  // ABuffer[0..1] = ESC O ; application cursor mode and xterm F1..F4.
  AConsumed := 0;
  AHasEvent := False;
  ANeedMore := False;
  if ACount < 3 then
  begin
    ANeedMore := True;
    Exit;
  end;
  AConsumed := 3;
  AHasEvent := KeyFromLetter(ABuffer[2], [], AEvent);
end;

class procedure TTuiSequenceDecoder.ParseUtf8(const ABuffer: TBytes; ACount: Integer;
  out AConsumed: Integer; out AEvent: TTuiEvent; out AHasEvent: Boolean;
  out ANeedMore: Boolean);
begin
  // ABuffer[0] >= $80: decode one UTF-8 encoded code point.
  AConsumed := 0;
  AHasEvent := False;
  ANeedMore := False;

  var LLead := ABuffer[0];
  var LLength: Integer;
  var LCodePoint: Cardinal;
  if (LLead >= $C2) and (LLead <= $DF) then
  begin
    LLength := 2;
    LCodePoint := LLead and $1F;
  end
  else if (LLead >= $E0) and (LLead <= $EF) then
  begin
    LLength := 3;
    LCodePoint := LLead and $0F;
  end
  else if (LLead >= $F0) and (LLead <= $F4) then
  begin
    LLength := 4;
    LCodePoint := LLead and $07;
  end
  else
  begin
    // Invalid lead (stray continuation, overlong $C0/$C1, $F5..$FF):
    // drop one byte and resync on the next.
    AConsumed := 1;
    Exit;
  end;

  if ACount < LLength then
  begin
    ANeedMore := True;
    Exit;
  end;

  for var LIndex := 1 to LLength - 1 do
  begin
    var LByte := ABuffer[LIndex];
    if (LByte < $80) or (LByte > $BF) then
    begin
      // Broken continuation: drop the lead byte only and resync.
      AConsumed := 1;
      Exit;
    end;
    LCodePoint := (LCodePoint shl 6) or (LByte and $3F);
  end;
  AConsumed := LLength;

  // Reject overlong encodings, surrogates and out-of-range values.
  if ((LLength = 3) and (LCodePoint < $800)) or
     ((LLength = 4) and (LCodePoint < $10000)) or
     ((LCodePoint >= $D800) and (LCodePoint <= $DFFF)) or
     (LCodePoint > $10FFFF) then
    Exit;

  AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.MakeCodePoint(kcChar, LCodePoint, []));
  AHasEvent := True;
end;

class procedure TTuiSequenceDecoder.ParseEscape(const ABuffer: TBytes; ACount: Integer;
  out AConsumed: Integer; out AEvent: TTuiEvent; out AHasEvent: Boolean;
  out ANeedMore: Boolean);
begin
  // ABuffer[0] = ESC.
  AConsumed := 0;
  AHasEvent := False;
  ANeedMore := False;

  if ACount < 2 then
  begin
    // A lone ESC is ambiguous: Escape key or the start of a sequence.
    // The backend resolves it after DefaultEscTimeoutMs via FlushPending.
    ANeedMore := True;
    Exit;
  end;

  case ABuffer[1] of
    Ord('['):
      ParseCsi(ABuffer, ACount, AConsumed, AEvent, AHasEvent, ANeedMore);
    Ord('O'):
      ParseSs3(ABuffer, ACount, AConsumed, AEvent, AHasEvent, ANeedMore);
    BEsc:
      begin
        // ESC ESC: the first is a real Escape key; the second re-parses.
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcEscape, #0, []));
        AHasEvent := True;
        AConsumed := 1;
      end;
    $7F, $08:
      begin
        // Meta/Alt + Backspace
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcBackspace, #0, [kmAlt]));
        AHasEvent := True;
        AConsumed := 2;
      end;
    $0D, $0A:
      begin
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcEnter, #0, [kmAlt]));
        AHasEvent := True;
        AConsumed := 2;
      end;
    $09:
      begin
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcTab, #0, [kmAlt]));
        AHasEvent := True;
        AConsumed := 2;
      end;
    $01..$07, $0B, $0C, $0E..$1A:
      begin
        // Alt+Ctrl+letter: keep the control byte like the Windows backend does
        AEvent := TTuiEvent.MakeKey(
          TTuiKeyEvent.Make(kcChar, Chr(ABuffer[1]), [kmCtrl, kmAlt]));
        AHasEvent := True;
        AConsumed := 2;
      end;
    Ord(' '):
      begin
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcSpace, ' ', [kmAlt]));
        AHasEvent := True;
        AConsumed := 2;
      end;
    // Printable ASCII except 'O' ($4F) and '[' ($5B), which are the SS3/CSI
    // introducers handled above: Pascal case labels must not overlap.
    $21..$4E, $50..$5A, $5C..$7E:
      begin
        // Meta/Alt prefix on a printable ASCII key
        AEvent := TTuiEvent.MakeKey(
          TTuiKeyEvent.Make(kcChar, Chr(ABuffer[1]), [kmAlt]));
        AHasEvent := True;
        AConsumed := 2;
      end;
  else
    // ESC followed by a byte we do not understand (e.g. a UTF-8 lead):
    // emit the Escape key and let the rest re-parse standalone.
    AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcEscape, #0, []));
    AHasEvent := True;
    AConsumed := 1;
  end;
end;

class procedure TTuiSequenceDecoder.ParseOne(const ABuffer: TBytes; ACount: Integer;
  out AConsumed: Integer; out AEvent: TTuiEvent; out AHasEvent: Boolean;
  out ANeedMore: Boolean);
begin
  AConsumed := 0;
  AHasEvent := False;
  ANeedMore := False;

  var LB0 := ABuffer[0];
  if LB0 = BEsc then
  begin
    ParseEscape(ABuffer, ACount, AConsumed, AEvent, AHasEvent, ANeedMore);
    Exit;
  end;
  if LB0 >= $80 then
  begin
    ParseUtf8(ABuffer, ACount, AConsumed, AEvent, AHasEvent, ANeedMore);
    Exit;
  end;

  AConsumed := 1;
  case LB0 of
    $0D, $0A:
      begin
        // Enter arrives as CR in raw mode (ICRNL cleared); Ctrl+J maps here too
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcEnter, #0, []));
        AHasEvent := True;
      end;
    $09:
      begin
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcTab, #0, []));
        AHasEvent := True;
      end;
    $08, $7F:
      begin
        // Both BS and DEL map to Backspace: terminals disagree on which one
        // the Backspace key sends.
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcBackspace, #0, []));
        AHasEvent := True;
      end;
    Ord(' '):
      begin
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcSpace, ' ', []));
        AHasEvent := True;
      end;
    $01..$07, $0B, $0C, $0E..$1A:
      begin
        // Ctrl+letter: deliver the control byte itself with kmCtrl, exactly
        // like the Windows backend (demos test AKey.Character = #17 etc.).
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcChar, Chr(LB0), [kmCtrl]));
        AHasEvent := True;
      end;
    $21..$7E:
      begin
        AEvent := TTuiEvent.MakeKey(TTuiKeyEvent.Make(kcChar, Chr(LB0), []));
        AHasEvent := True;
      end;
  else
    // Remaining C0 bytes ($00, $1C..$1F): swallowed
  end;
end;

end.
