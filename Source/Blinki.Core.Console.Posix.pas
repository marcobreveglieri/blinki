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
  System.SysUtils,
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
  /// <summary>
  ///   Result of a bounded wait on stdin: distinguishing a real timeout from
  ///   an interrupted poll matters because only a genuine quiet period may
  ///   resolve a pending lone ESC into the Escape key.
  /// </summary>
  TTuiWaitResult = (
    /// <summary>
    ///   The full wait elapsed with no input.
    /// </summary>
    twrTimeout,
    /// <summary>
    ///   Input (or EOF) is available for reading.
    /// </summary>
    twrReadable,
    /// <summary>
    ///   The wait was interrupted early (EINTR) or failed transiently.
    /// </summary>
    twrInterrupted
  );

  TTuiPosixConsoleBackend = class(TInterfacedObject, ITuiConsoleBackend)
  strict private
    FDecoder: TTuiSequenceDecoder;
    FOpened: Boolean;
    FOutBuffer: TBytes;
    FOutCount: Integer;
    FStdinEof: Boolean;
    function  ReadPendingBytes: Boolean;
    function  WaitForInput(ATimeoutMs: Integer): TTuiWaitResult;
  public
    constructor Create;
    /// <inheritdoc/>
    destructor Destroy; override;
    /// <inheritdoc/>
    procedure Open;
    /// <inheritdoc/>
    procedure Close;
    /// <inheritdoc/>
    procedure Flush;
    /// <inheritdoc/>
    function GetSize: TSize;
    /// <inheritdoc/>
    function TryReadEvent(ATimeoutMs: Integer; out AEvent: TTuiEvent): Boolean;
    /// <inheritdoc/>
    function TryReadKey(ATimeoutMs: Integer; out AKey: TTuiKeyEvent): Boolean;
    /// <inheritdoc/>
    procedure Write(const AText: string);
  end;

{$ENDIF}

implementation

{$IFNDEF MSWINDOWS}

// This backend targets Linux only: the BLINKI_* ioctl/signal constants below
// are Linux values and must be ported before enabling other POSIX platforms
// (e.g. TIOCGWINSZ is $40087468 on macOS/BSD). Fail loudly instead of
// compiling a silently broken backend.
{$IFNDEF LINUX}
  {$MESSAGE Error 'TTuiPosixConsoleBackend supports Linux only (port the BLINKI_* constants first)'}
{$ENDIF}

uses
  System.Diagnostics,
  Posix.Base,
  Posix.Termios,
  Posix.Unistd,
  Blinki.Core.Ansi,
  Blinki.Core.Unicode;

const
  // Declared locally (like TTuiWinInputRecord in the Windows backend) to
  // avoid depending on RTL declarations that drifted between releases.
  BLINKI_TIOCGWINSZ = $5413;  // TIOCGWINSZ, asm-generic/ioctls.h (Linux)
  BLINKI_POLLIN     = $0001;  // POLLIN, poll.h
  BLINKI_POLLOUT    = $0004;  // POLLOUT, poll.h
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

var
  // Emergency terminal restore, encoded once at unit initialization from the
  // TTuiAnsi single source of truth (mouse off, leave the alternate buffer,
  // show the cursor, SGR reset). The signal handler only reads these bytes,
  // so it stays async-signal-safe.
  GRestoreBytes: TBytes;

  // State shared with the signal handler. Written only while installing the
  // handler (single-threaded event loop), read from the handler context.
  // GBackendOwner is a weak reference to the instance that owns the saved
  // terminal state, like GCtrlCBackend in the Windows backend.
  GBackendOwner: TTuiPosixConsoleBackend = nil;
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
  if Length(GRestoreBytes) > 0 then
    __write(STDOUT_FILENO, @GRestoreBytes[0], Length(GRestoreBytes));
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

  // The saved termios and signal dispositions are process-wide state: a
  // second concurrently open backend would capture the already-raw settings
  // as "original" and every restore path would then re-enter raw mode,
  // leaving the user's shell without echo. Fail fast instead.
  if GBackendOwner <> nil then
    raise ETuiConsoleError.Create('Another console backend is already open: ' +
      'the terminal state can be owned by one backend at a time.');

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

  GBackendOwner := Self;
  GOldSigInt := tui_signal(BLINKI_SIGINT, TuiPosixSignalHandler);
  GOldSigTerm := tui_signal(BLINKI_SIGTERM, TuiPosixSignalHandler);

  // Emoji capability heuristic shared by all backends; an explicit
  // application assignment to TTuiUnicode.EmojiLevel always wins.
  TTuiUnicode.ApplyDetectedEmojiLevel(TTuiUnicode.DetectEmojiLevel);

  // SGR mouse reporting: button presses/releases with unambiguous coordinates
  Write(TTuiAnsi.MouseTrackingOn);
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
    Write(TTuiAnsi.MouseTrackingOff);
    Flush;
  except
    // Ignore: in cleanup, do not propagate exceptions
  end;

  // Restore terminal attributes and signal dispositions, but only when this
  // instance owns the saved process-wide state.
  if GBackendOwner = Self then
  begin
    try
      if GTermiosSaved then
        tcsetattr(STDIN_FILENO, TCSAFLUSH, GOriginalTermios);
    except
      // Ignore: in cleanup, do not propagate exceptions
    end;
    tui_signal(BLINKI_SIGINT, GOldSigInt);
    tui_signal(BLINKI_SIGTERM, GOldSigTerm);
    GBackendOwner := nil;
  end;
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

function TTuiPosixConsoleBackend.WaitForInput(ATimeoutMs: Integer): TTuiWaitResult;
begin
  var LFd: TTuiPollFd;
  LFd.fd := STDIN_FILENO;
  LFd.events := BLINKI_POLLIN;
  LFd.revents := 0;
  var LReady := tui_poll(@LFd, 1, ATimeoutMs);
  if LReady > 0 then
    // POLLIN, or POLLHUP/POLLERR: read(2) resolves either case (EOF sets
    // FStdinEof in ReadPendingBytes, so a closed stdin never poll-spins).
    Exit(twrReadable);
  if LReady = 0 then
    Exit(twrTimeout);
  // EINTR or transient error: NOT a timeout — the caller must not resolve a
  // pending lone ESC on this result, or a signal landing between the ESC and
  // the rest of an arrow-key burst would fabricate an Escape keypress.
  Result := twrInterrupted;
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
  if ATimeoutMs < 0 then
    ATimeoutMs := 0;
  if not FOpened then
  begin
    // Closed backend: honor the pacing timeout (several callers use this
    // call as their tick sleep) instead of busy-returning.
    if ATimeoutMs > 0 then
      tui_poll(nil, 0, ATimeoutMs);
    Exit;
  end;

  var LWatch := TStopwatch.StartNew;
  repeat
    if FDecoder.TryGetEvent(AEvent) then
      Exit(True);

    var LRemaining := ATimeoutMs - Integer(LWatch.ElapsedMilliseconds);
    if LRemaining < 0 then
      LRemaining := 0;

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

    // A lone ESC (or partial sequence) pending: wait only a short grace
    // period for the rest of the burst. With no budget left, LWait = 0 still
    // performs one non-blocking check so a 0 timeout drains pending input
    // exactly like the Windows backend does.
    var LWait := LRemaining;
    if FDecoder.HasPendingPrefix and
       (LWait > TTuiSequenceDecoder.DefaultEscTimeoutMs) then
      LWait := TTuiSequenceDecoder.DefaultEscTimeoutMs;

    case WaitForInput(LWait) of
      twrReadable:
        ReadPendingBytes;
      twrTimeout:
        begin
          if FDecoder.HasPendingPrefix then
          begin
            // A genuine quiet period elapsed: the pending ESC is a real
            // Escape keypress (or a truncated fragment to drop).
            FDecoder.FlushPending;
            if LWait < LRemaining then
              Continue; // budget remains: pick up the resolved event
            if FDecoder.TryGetEvent(AEvent) then
              Exit(True);
          end;
          Exit; // the full remaining budget elapsed
        end;
      twrInterrupted:
        // EINTR: recompute the remaining budget and retry; never resolve a
        // pending prefix here (it was not a real quiet period).
        if LRemaining <= 0 then
          Exit;
    end;
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
  // partial writes, EINTR and EAGAIN without ever hanging or hot-spinning.
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
        Break; // ~1s of stalls: the terminal is gone, dropping beats hanging
      // EAGAIN (tty buffer full, e.g. stdout inherited with O_NONBLOCK) or
      // EINTR: wait briefly for writability instead of spinning hot.
      var LFd: TTuiPollFd;
      LFd.fd := STDOUT_FILENO;
      LFd.events := BLINKI_POLLOUT;
      LFd.revents := 0;
      tui_poll(@LFd, 1, 10);
    end;
  end;
  FOutCount := 0;
end;

initialization
  // Pre-encode the emergency restore sequence from the TTuiAnsi single
  // source of truth, long before any signal handler can run.
  GRestoreBytes := TEncoding.UTF8.GetBytes(
    TTuiAnsi.MouseTrackingOff + TTuiAnsi.AlternateBufferOff +
    TTuiAnsi.CursorShow + TTuiAnsi.Reset);

{$ENDIF}

end.
