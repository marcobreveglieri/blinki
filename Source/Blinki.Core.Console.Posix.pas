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
///   POSIX (Linux) implementation of the console backend for the Blinki
///   library. Puts the tty into raw mode via termios, waits for input with
///   poll(2) honoring the event-loop timeout, feeds raw bytes into the
///   platform-neutral TTuiSequenceDecoder (Blinki.Core.Console.Sequences),
///   writes buffered UTF-8 output with write(2), and reads the terminal
///   size with ioctl(TIOCGWINSZ). SGR mouse reporting is enabled while the
///   backend is open.
/// </summary>
/// <remarks>
///   Ctrl+C policy mirrors the Windows backend ("restore the terminal, then
///   die"): ISIG stays enabled and a SIGINT/SIGTERM handler emits a static
///   restore sequence, restores the saved termios and re-raises the signal,
///   so no code path ever leaves the tty in raw mode. Targeted and verified
///   on Delphi Linux64; other POSIX platforms may need different ioctl
///   constants (see BLINKI_TIOCGWINSZ).
/// </remarks>
unit Blinki.Core.Console.Posix;

interface

{$IFNDEF MSWINDOWS}

uses
  System.Types,
  Blinki.Core.Console,
  Blinki.Core.Console.Sequences,
  Blinki.Core.Event,
  Blinki.Core.Input;

type

{ TTuiPosixConsoleBackend }

  /// <summary>
  ///   POSIX implementation of ITuiConsoleBackend built on termios raw mode,
  ///   poll(2)-based non-blocking input and an escape-sequence decoder.
  /// </summary>
  TTuiPosixConsoleBackend = class(TInterfacedObject, ITuiConsoleBackend)
  strict private
    FDecoder: TTuiSequenceDecoder;
    FOpened: Boolean;
    FOutBuffer: TBytes;
    FOutCount: Integer;
    FStdinEof: Boolean;
    procedure DetectEmojiLevel;
    function  ReadPendingBytes: Boolean;
    function  WaitForInput(ATimeoutMs: Integer): Boolean;
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

{$IFNDEF MSWINDOWS}

uses
  System.Diagnostics,
  System.SysUtils,
  Posix.Base,
  Posix.Termios,
  Posix.Unistd,
  Blinki.Core.Unicode;

const
  // Declared locally (like TTuiWinInputRecord in the Windows backend) to
  // avoid depending on RTL declarations that drifted between releases.
  BLINKI_TIOCGWINSZ = $5413;  // TIOCGWINSZ, asm-generic/ioctls.h (Linux)
  BLINKI_POLLIN     = $0001;  // POLLIN, poll.h
  BLINKI_SIGINT     = 2;      // SIGINT, signal.h
  BLINKI_SIGTERM    = 15;     // SIGTERM, signal.h

type
  // struct winsize — not declared by the Delphi RTL
  TTuiWinSize = packed record
    ws_row: Word;
    ws_col: Word;
    ws_xpixel: Word;
    ws_ypixel: Word;
  end;

  // struct pollfd — there is no Posix.Poll unit
  TTuiPollFd = record
    fd: Integer;
    events: SmallInt;
    revents: SmallInt;
  end;

  TTuiSignalHandler = procedure(ASigNum: Integer); cdecl;

// Direct libc bindings: poll takes milliseconds natively (no fd_set macro
// games), the typed 3-argument ioctl avoids the varargs RTL import, and
// signal/kill/getpid keep the handler installation self-contained.
function tui_poll(AFds: Pointer; ANFds: NativeUInt; ATimeoutMs: Integer): Integer;
  cdecl; external libc name 'poll';
function tui_ioctl(AFd: Integer; ARequest: NativeUInt; AArg: Pointer): Integer;
  cdecl; external libc name 'ioctl';
function tui_signal(ASigNum: Integer; AHandler: TTuiSignalHandler): TTuiSignalHandler;
  cdecl; external libc name 'signal';
function tui_kill(APid: Integer; ASigNum: Integer): Integer;
  cdecl; external libc name 'kill';
function tui_getpid: Integer;
  cdecl; external libc name 'getpid';

const
  // Emergency terminal restore, pre-encoded so the signal handler needs no
  // heap or string conversions (async-signal-safe):
  // ESC[?1000;1006l (mouse off)  ESC[?1049l (leave alt buffer)
  // ESC[?25h (show cursor)  ESC[0m (SGR reset)
  GRestoreSequence: array[0..30] of Byte = (
    $1B, $5B, $3F, $31, $30, $30, $30, $3B, $31, $30, $30, $36, $6C,
    $1B, $5B, $3F, $31, $30, $34, $39, $6C,
    $1B, $5B, $3F, $32, $35, $68,
    $1B, $5B, $30, $6D
  );

var
  // State shared with the signal handler. Written only while installing the
  // handler (single-threaded event loop), read from the handler context.
  GOriginalTermios: termios;
  GTermiosSaved: Boolean;
  GOldSigInt: TTuiSignalHandler;
  GOldSigTerm: TTuiSignalHandler;

procedure TuiPosixSignalHandler(ASigNum: Integer); cdecl;
begin
  // Async-signal-safe calls only: write(2), tcsetattr(2), signal(2), kill(2).
  // The App's try/finally teardown never runs when a signal kills the
  // process, so the terminal is restored right here, then the signal is
  // re-raised with its default disposition (die by signal, Windows parity).
  __write(STDOUT_FILENO, @GRestoreSequence[0], Length(GRestoreSequence));
  if GTermiosSaved then
    tcsetattr(STDIN_FILENO, TCSAFLUSH, GOriginalTermios);
  tui_signal(ASigNum, nil); // nil = SIG_DFL on Linux
  tui_kill(tui_getpid, ASigNum);
end;

{ TTuiPosixConsoleBackend }

constructor TTuiPosixConsoleBackend.Create;
begin
  inherited Create;
  FDecoder := TTuiSequenceDecoder.Create;
end;

destructor TTuiPosixConsoleBackend.Destroy;
begin
  Close;
  if Assigned(FDecoder) then
    FreeAndNil(FDecoder);
  inherited Destroy;
end;

procedure TTuiPosixConsoleBackend.Open;
begin
  if FOpened then
    Exit;

  if (isatty(STDIN_FILENO) = 0) or (isatty(STDOUT_FILENO) = 0) then
    raise ETuiConsoleError.Create('Blinki requires an interactive terminal: ' +
      'stdin/stdout must be a tty, not a redirected file or pipe.');

  if tcgetattr(STDIN_FILENO, GOriginalTermios) <> 0 then
    raise ETuiConsoleError.Create('Unable to read the terminal attributes.');
  GTermiosSaved := True;

  // Raw-ish mode: no line buffering, no echo, no extended processing, no
  // flow control, no CR translation. ISIG stays ON so Ctrl+C still raises
  // SIGINT: the handler restores the terminal before the process dies,
  // mirroring the Windows backend's Ctrl+C behavior.
  var LRaw := GOriginalTermios;
  LRaw.c_lflag := LRaw.c_lflag and not (ICANON or ECHO or IEXTEN);
  LRaw.c_iflag := LRaw.c_iflag and not (IXON or ICRNL or BRKINT or INPCK or ISTRIP);
  LRaw.c_cc[VMIN] := 0;  // poll(2) drives all waiting
  LRaw.c_cc[VTIME] := 0;
  if tcsetattr(STDIN_FILENO, TCSAFLUSH, LRaw) <> 0 then
    raise ETuiConsoleError.Create('Unable to switch the terminal to raw mode.');

  GOldSigInt := tui_signal(BLINKI_SIGINT, TuiPosixSignalHandler);
  GOldSigTerm := tui_signal(BLINKI_SIGTERM, TuiPosixSignalHandler);

  DetectEmojiLevel;

  // SGR mouse reporting: button presses/releases with unambiguous coordinates
  Write(#$1B'[?1000;1006h');
  Flush;

  FOpened := True;
end;

procedure TTuiPosixConsoleBackend.Close;
begin
  if not FOpened then
    Exit;
  FOpened := False;

  // Disable mouse reporting
  try
    Write(#$1B'[?1000;1006l');
    Flush;
  except
    // Ignore: in cleanup, do not propagate exceptions
  end;

  // Restore original terminal attributes
  try
    if GTermiosSaved then
      tcsetattr(STDIN_FILENO, TCSAFLUSH, GOriginalTermios);
  except
    // Ignore: in cleanup, do not propagate exceptions
  end;

  // Restore previous signal dispositions
  tui_signal(BLINKI_SIGINT, GOldSigInt);
  tui_signal(BLINKI_SIGTERM, GOldSigTerm);
end;

procedure TTuiPosixConsoleBackend.DetectEmojiLevel;
begin
  // Conservative policy: a false positive breaks column alignment (layout
  // corruption), a false negative only renders emoji sequences as their
  // parts. An explicit application assignment always wins over this.
  var LLevel := elBasic;
  var LTerm := GetEnvironmentVariable('TERM');
  var LTermProgram := GetEnvironmentVariable('TERM_PROGRAM');
  if (GetEnvironmentVariable('WT_SESSION') <> '') or   // WSL under Windows Terminal
     SameText(LTermProgram, 'WezTerm') or
     SameText(LTermProgram, 'iTerm.app') or
     SameText(LTermProgram, 'ghostty') or
     SameText(LTermProgram, 'contour') or
     SameText(LTermProgram, 'rio') or
     SameText(LTerm, 'xterm-kitty') or
     SameText(LTerm, 'xterm-ghostty') or
     LTerm.StartsWith('foot') or
     (GetEnvironmentVariable('KONSOLE_VERSION') <> '') or
     (StrToIntDef(GetEnvironmentVariable('VTE_VERSION'), 0) >= 5000) then
    LLevel := elFull;
  // Terminal multiplexers do their own width math and merge clusters
  // unreliably; Apple Terminal draws ZWJ members separately.
  if (GetEnvironmentVariable('TMUX') <> '') or
     LTerm.StartsWith('screen') or
     LTerm.StartsWith('tmux') or
     SameText(LTermProgram, 'Apple_Terminal') then
    LLevel := elBasic;
  TTuiUnicode.ApplyDetectedEmojiLevel(LLevel);
end;

function TTuiPosixConsoleBackend.GetSize: TSize;
begin
  var LWinSize: TTuiWinSize;
  if (tui_ioctl(STDOUT_FILENO, BLINKI_TIOCGWINSZ, @LWinSize) = 0) and
     (LWinSize.ws_col > 0) and (LWinSize.ws_row > 0) then
  begin
    Result.cx := LWinSize.ws_col;
    Result.cy := LWinSize.ws_row;
  end
  else
  begin
    Result.cx := 80;
    Result.cy := 24;
  end;
end;

function TTuiPosixConsoleBackend.WaitForInput(ATimeoutMs: Integer): Boolean;
begin
  var LFd: TTuiPollFd;
  LFd.fd := STDIN_FILENO;
  LFd.events := BLINKI_POLLIN;
  LFd.revents := 0;
  var LReady := tui_poll(@LFd, 1, ATimeoutMs);
  if LReady <= 0 then
    Exit(False); // timeout, or EINTR/error treated as "no data this round"
  if (LFd.revents and BLINKI_POLLIN) = 0 then
  begin
    // POLLHUP/POLLERR without data: stdin is gone
    FStdinEof := True;
    Exit(False);
  end;
  Result := True;
end;

function TTuiPosixConsoleBackend.ReadPendingBytes: Boolean;
begin
  var LBuffer: array[0..255] of Byte;
  var LRead := Integer(__read(STDIN_FILENO, @LBuffer[0], SizeOf(LBuffer)));
  if LRead > 0 then
  begin
    FDecoder.PutBytes(LBuffer, LRead);
    Exit(True);
  end;
  if LRead = 0 then
    FStdinEof := True; // EOF: never poll-spin on a closed stdin
  Result := False;     // -1 (EINTR or error): caller re-loops within the deadline
end;

function TTuiPosixConsoleBackend.TryReadEvent(ATimeoutMs: Integer;
  out AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  AEvent := TTuiEvent.None;
  if not FOpened then
    Exit;
  if ATimeoutMs < 0 then
    ATimeoutMs := 0;

  var LWatch := TStopwatch.StartNew;
  repeat
    if FDecoder.TryGetEvent(AEvent) then
      Exit(True);

    var LRemaining := ATimeoutMs - Integer(LWatch.ElapsedMilliseconds);

    if FStdinEof then
    begin
      // Stdin is closed: resolve any stalled prefix, then just honor the
      // pacing timeout so the event loop does not spin.
      FDecoder.FlushPending;
      if FDecoder.TryGetEvent(AEvent) then
        Exit(True);
      if LRemaining > 0 then
        tui_poll(nil, 0, LRemaining); // pure sleep
      Exit;
    end;

    var LWait: Integer;
    if FDecoder.HasPendingPrefix then
    begin
      // A lone ESC (or partial sequence) is pending: wait briefly for the
      // rest of the burst, then resolve it as a real Escape key.
      if LRemaining <= 0 then
      begin
        FDecoder.FlushPending;
        if FDecoder.TryGetEvent(AEvent) then
          Exit(True);
        Exit;
      end;
      LWait := TTuiSequenceDecoder.DefaultEscTimeoutMs;
      if LRemaining < LWait then
        LWait := LRemaining;
    end
    else
    begin
      if LRemaining <= 0 then
        Exit;
      LWait := LRemaining;
    end;

    if WaitForInput(LWait) then
      ReadPendingBytes
    else if FDecoder.HasPendingPrefix then
      FDecoder.FlushPending;
  until False;
end;

function TTuiPosixConsoleBackend.TryReadKey(ATimeoutMs: Integer;
  out AKey: TTuiKeyEvent): Boolean;
begin
  Result := False;
  AKey := TTuiKeyEvent.Make(kcNone, #0, []);
  if ATimeoutMs < 0 then
    ATimeoutMs := 0;

  var LWatch := TStopwatch.StartNew;
  repeat
    var LRemaining := ATimeoutMs - Integer(LWatch.ElapsedMilliseconds);
    if LRemaining < 0 then
      LRemaining := 0;
    var LEvent: TTuiEvent;
    if not TryReadEvent(LRemaining, LEvent) then
      Exit;
    if LEvent.Kind = ekKey then
    begin
      AKey := LEvent.Key;
      Exit(True);
    end;
    // Mouse event: discard and keep looking within the deadline
  until False;
end;

procedure TTuiPosixConsoleBackend.Write(const AText: string);
begin
  if AText = '' then
    Exit;
  var LBytes := TEncoding.UTF8.GetBytes(AText);
  if FOutCount + Length(LBytes) > Length(FOutBuffer) then
    SetLength(FOutBuffer, (FOutCount + Length(LBytes)) * 2 + 1024);
  Move(LBytes[0], FOutBuffer[FOutCount], Length(LBytes));
  Inc(FOutCount, Length(LBytes));
end;

procedure TTuiPosixConsoleBackend.Flush;
begin
  // Drain the whole frame in as few write(2) calls as possible, resisting
  // partial writes and transient EINTR without ever hanging.
  var LOffset := 0;
  var LStall := 0;
  while LOffset < FOutCount do
  begin
    var LWritten := Integer(__write(STDOUT_FILENO, @FOutBuffer[LOffset],
      FOutCount - LOffset));
    if LWritten > 0 then
    begin
      Inc(LOffset, LWritten);
      LStall := 0;
    end
    else
    begin
      Inc(LStall);
      if LStall > 100 then
        Break; // the terminal is gone: dropping the frame beats hanging
    end;
  end;
  FOutCount := 0;
end;

{$ENDIF}

end.
