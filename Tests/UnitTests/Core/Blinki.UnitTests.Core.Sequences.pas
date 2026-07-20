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
{   Unit:        Blinki.UnitTests.Core.Sequences.pas             }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   DUnitX test fixture for the terminal input sequence decoder of
///   Blinki.Core.Console.Sequences: keyboard escape sequences, UTF-8 text,
///   SGR mouse reports, split reads and lone-ESC disambiguation. Runs on
///   Windows: the decoder is platform-neutral by design.
/// </summary>
unit Blinki.UnitTests.Core.Sequences;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Blinki.Core.Console.Sequences,
  Blinki.Core.Event,
  Blinki.Core.Input;

type

{ TSequenceDecoderTests }

  /// <summary>
  ///   Verifies TTuiSequenceDecoder byte-stream decoding.
  /// </summary>
  [TestFixture]
  TSequenceDecoderTests = class
  strict private
    FDecoder: TTuiSequenceDecoder;
    procedure AssertNoEvent(const AMessage: string);
    procedure Feed(const ABytes: array of Byte);
    procedure FeedText(const AText: RawByteString);
    function  NextKey: TTuiKeyEvent;
    function  NextMouse: TTuiMouseEvent;
  public
    /// <summary>
    ///   Creates a fresh decoder for each test.
    /// </summary>
    [Setup]
    procedure Setup;
    /// <summary>
    ///   Frees the decoder.
    /// </summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   Printable ASCII, space, Enter (CR and LF), Tab, both Backspace
    ///   encodings and Ctrl+letter control bytes.
    /// </summary>
    [Test]
    procedure PlainKeys;
    /// <summary>
    ///   CSI arrows and both Home/End encodings (letter and tilde form).
    /// </summary>
    [Test]
    procedure CsiNavigation;
    /// <summary>
    ///   CSI modifier parameters set kmShift/kmAlt/kmCtrl.
    /// </summary>
    [Test]
    procedure CsiModifiers;
    /// <summary>
    ///   CSI Z (backtab) must decode as Tab with exactly [kmShift].
    /// </summary>
    [Test]
    procedure CsiBacktab_IsShiftTab;
    /// <summary>
    ///   F1..F12 via SS3 letters, CSI tilde codes and Linux console form;
    ///   unassigned tilde codes are swallowed.
    /// </summary>
    [Test]
    procedure FunctionKeys;
    /// <summary>
    ///   SS3 (application cursor mode) arrows and Home/End.
    /// </summary>
    [Test]
    procedure Ss3Arrows;
    /// <summary>
    ///   Alt-prefixed keys: ESC + printable, ESC + DEL, ESC + ESC.
    /// </summary>
    [Test]
    procedure AltPrefix;
    /// <summary>
    ///   A lone ESC yields no event until FlushPending resolves it as the
    ///   Escape key; a sequence split across PutBytes yields one event.
    /// </summary>
    [Test]
    procedure LoneEscape_AndSplitSequences;
    /// <summary>
    ///   UTF-8 decoding: 2/3/4-byte characters, split across PutBytes,
    ///   invalid-lead resync, overlong rejection, truncated tail dropped
    ///   by FlushPending.
    /// </summary>
    [Test]
    procedure Utf8Decoding;
    /// <summary>
    ///   SGR mouse: press/release/wheel, modifier bits, motion dropped,
    ///   0-based coordinates.
    /// </summary>
    [Test]
    procedure SgrMouse;
    /// <summary>
    ///   Unknown sequences are swallowed without producing garbage events.
    /// </summary>
    [Test]
    procedure UnknownSequences_AreSwallowed;
    /// <summary>
    ///   A pasted burst produces ordered events; Reset clears everything.
    /// </summary>
    [Test]
    procedure BurstAndReset;
  end;

implementation

{ TSequenceDecoderTests }

procedure TSequenceDecoderTests.Setup;
begin
  FDecoder := TTuiSequenceDecoder.Create;
end;

procedure TSequenceDecoderTests.TearDown;
begin
  FDecoder.Free;
end;

procedure TSequenceDecoderTests.Feed(const ABytes: array of Byte);
begin
  FDecoder.PutBytes(ABytes, Length(ABytes));
end;

procedure TSequenceDecoderTests.FeedText(const AText: RawByteString);
begin
  // BytesOf(RawByteString) preserves bytes verbatim (no codepage conversion)
  var LBytes := BytesOf(AText);
  FDecoder.PutBytes(LBytes, Length(LBytes));
end;

function TSequenceDecoderTests.NextKey: TTuiKeyEvent;
begin
  var LEvent: TTuiEvent;
  Assert.IsTrue(FDecoder.TryGetEvent(LEvent), 'Expected a decoded event');
  Assert.AreEqual(Ord(ekKey), Ord(LEvent.Kind), 'Expected a key event');
  Result := LEvent.Key;
end;

function TSequenceDecoderTests.NextMouse: TTuiMouseEvent;
begin
  var LEvent: TTuiEvent;
  Assert.IsTrue(FDecoder.TryGetEvent(LEvent), 'Expected a decoded event');
  Assert.AreEqual(Ord(ekMouse), Ord(LEvent.Kind), 'Expected a mouse event');
  Result := LEvent.Mouse;
end;

procedure TSequenceDecoderTests.AssertNoEvent(const AMessage: string);
begin
  var LEvent: TTuiEvent;
  Assert.IsFalse(FDecoder.TryGetEvent(LEvent), AMessage);
end;

procedure TSequenceDecoderTests.PlainKeys;
begin
  FeedText('a');
  var LKey := NextKey;
  Assert.AreEqual(Ord(kcChar), Ord(LKey.Code));
  Assert.AreEqual('a', string(LKey.Character));
  Assert.IsTrue(LKey.Modifiers = [], 'No modifiers on a plain key');

  Feed([$20]);
  Assert.AreEqual(Ord(kcSpace), Ord(NextKey.Code));

  Feed([$0D]);
  Assert.AreEqual(Ord(kcEnter), Ord(NextKey.Code), 'CR is Enter');
  Feed([$0A]);
  Assert.AreEqual(Ord(kcEnter), Ord(NextKey.Code), 'LF is Enter');

  Feed([$09]);
  var LTab := NextKey;
  Assert.AreEqual(Ord(kcTab), Ord(LTab.Code));
  Assert.IsTrue(LTab.Modifiers = [], 'Plain Tab has no modifiers');

  Feed([$7F]);
  Assert.AreEqual(Ord(kcBackspace), Ord(NextKey.Code), 'DEL is Backspace');
  Feed([$08]);
  Assert.AreEqual(Ord(kcBackspace), Ord(NextKey.Code), 'BS is Backspace');

  // Ctrl+Q arrives as byte $11: delivered as the control char with kmCtrl,
  // matching the Windows backend (demos test Character = #17).
  Feed([$11]);
  var LCtrl := NextKey;
  Assert.AreEqual(Ord(kcChar), Ord(LCtrl.Code));
  Assert.AreEqual(#17, LCtrl.Character);
  Assert.IsTrue(LCtrl.Modifiers = [kmCtrl], 'Ctrl modifier expected');

  AssertNoEvent('No extra events');
end;

procedure TSequenceDecoderTests.CsiNavigation;
begin
  FeedText(#$1B'[A'#$1B'[B'#$1B'[C'#$1B'[D');
  Assert.AreEqual(Ord(kcUp), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcDown), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcRight), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcLeft), Ord(NextKey.Code));

  // Home/End: letter finals and all tilde variants
  FeedText(#$1B'[H'#$1B'[F'#$1B'[1~'#$1B'[7~'#$1B'[4~'#$1B'[8~');
  Assert.AreEqual(Ord(kcHome), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcEnd), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcHome), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcHome), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcEnd), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcEnd), Ord(NextKey.Code));

  FeedText(#$1B'[2~'#$1B'[3~'#$1B'[5~'#$1B'[6~');
  Assert.AreEqual(Ord(kcInsert), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcDelete), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcPageUp), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcPageDown), Ord(NextKey.Code));

  AssertNoEvent('No extra events');
end;

procedure TSequenceDecoderTests.CsiModifiers;
begin
  FeedText(#$1B'[1;2A'); // Shift+Up
  var LKey := NextKey;
  Assert.AreEqual(Ord(kcUp), Ord(LKey.Code));
  Assert.IsTrue(LKey.Modifiers = [kmShift]);

  FeedText(#$1B'[1;3B'); // Alt+Down
  LKey := NextKey;
  Assert.AreEqual(Ord(kcDown), Ord(LKey.Code));
  Assert.IsTrue(LKey.Modifiers = [kmAlt]);

  FeedText(#$1B'[1;5C'); // Ctrl+Right
  LKey := NextKey;
  Assert.AreEqual(Ord(kcRight), Ord(LKey.Code));
  Assert.IsTrue(LKey.Modifiers = [kmCtrl]);

  FeedText(#$1B'[1;6D'); // Ctrl+Shift+Left
  LKey := NextKey;
  Assert.AreEqual(Ord(kcLeft), Ord(LKey.Code));
  Assert.IsTrue(LKey.Modifiers = [kmShift, kmCtrl]);

  FeedText(#$1B'[3;5~'); // Ctrl+Delete
  LKey := NextKey;
  Assert.AreEqual(Ord(kcDelete), Ord(LKey.Code));
  Assert.IsTrue(LKey.Modifiers = [kmCtrl]);

  // Kitty-style ':' subparameters must not concatenate into the modifier
  // value: ESC[1;5:3A is Ctrl+Up (event type 3), not modifier 53.
  FeedText(#$1B'[1;5:3A');
  LKey := NextKey;
  Assert.AreEqual(Ord(kcUp), Ord(LKey.Code));
  Assert.IsTrue(LKey.Modifiers = [kmCtrl],
    'Subparameter digits must not merge into the modifier');

  AssertNoEvent('No extra events');
end;

procedure TSequenceDecoderTests.CsiBacktab_IsShiftTab;
begin
  FeedText(#$1B'[Z');
  var LKey := NextKey;
  Assert.AreEqual(Ord(kcTab), Ord(LKey.Code),
    'Backtab must arrive as Tab for the focus ring');
  Assert.IsTrue(LKey.Modifiers = [kmShift],
    'Backtab must carry exactly the Shift modifier');
  AssertNoEvent('No extra events');
end;

procedure TSequenceDecoderTests.FunctionKeys;
begin
  // xterm SS3 form: F1..F4
  FeedText(#$1B'OP'#$1B'OQ'#$1B'OR'#$1B'OS');
  Assert.AreEqual(Ord(kcF1), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcF2), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcF3), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcF4), Ord(NextKey.Code));

  // vt220 tilde form: F1..F12 (11..15, 17..21, 23, 24)
  FeedText(#$1B'[11~'#$1B'[15~'#$1B'[17~'#$1B'[21~'#$1B'[23~'#$1B'[24~');
  Assert.AreEqual(Ord(kcF1), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcF5), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcF6), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcF10), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcF11), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcF12), Ord(NextKey.Code));

  // Gap codes 16 and 22 are unassigned: swallowed, no event
  FeedText(#$1B'[16~'#$1B'[22~');
  AssertNoEvent('Unassigned tilde codes must be swallowed');

  // Modified function key: Shift+F1 (xterm CSI form)
  FeedText(#$1B'[1;2P');
  var LKey := NextKey;
  Assert.AreEqual(Ord(kcF1), Ord(LKey.Code));
  Assert.IsTrue(LKey.Modifiers = [kmShift]);

  // Linux console form: ESC [ [ A..E = F1..F5
  FeedText(#$1B'[[A'#$1B'[[E');
  Assert.AreEqual(Ord(kcF1), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcF5), Ord(NextKey.Code));

  AssertNoEvent('No extra events');
end;

procedure TSequenceDecoderTests.Ss3Arrows;
begin
  FeedText(#$1B'OA'#$1B'OB'#$1B'OC'#$1B'OD'#$1B'OH'#$1B'OF');
  Assert.AreEqual(Ord(kcUp), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcDown), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcRight), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcLeft), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcHome), Ord(NextKey.Code));
  Assert.AreEqual(Ord(kcEnd), Ord(NextKey.Code));
  AssertNoEvent('No extra events');
end;

procedure TSequenceDecoderTests.AltPrefix;
begin
  FeedText(#$1B'b'); // Alt+b
  var LKey := NextKey;
  Assert.AreEqual(Ord(kcChar), Ord(LKey.Code));
  Assert.AreEqual('b', string(LKey.Character));
  Assert.IsTrue(LKey.Modifiers = [kmAlt]);

  Feed([$1B, $7F]); // Alt+Backspace
  LKey := NextKey;
  Assert.AreEqual(Ord(kcBackspace), Ord(LKey.Code));
  Assert.IsTrue(LKey.Modifiers = [kmAlt]);

  Feed([$1B, $1B, Ord('x')]); // ESC ESC x: Escape, then Alt is consumed? No:
  // first ESC resolves as Escape; the second ESC + 'x' is Alt+x.
  Assert.AreEqual(Ord(kcEscape), Ord(NextKey.Code));
  LKey := NextKey;
  Assert.AreEqual(Ord(kcChar), Ord(LKey.Code));
  Assert.AreEqual('x', string(LKey.Character));
  Assert.IsTrue(LKey.Modifiers = [kmAlt]);

  AssertNoEvent('No extra events');
end;

procedure TSequenceDecoderTests.LoneEscape_AndSplitSequences;
begin
  // A lone ESC produces nothing until the timeout policy resolves it
  Feed([$1B]);
  AssertNoEvent('Lone ESC must stay pending');
  Assert.IsTrue(FDecoder.HasPendingPrefix, 'Lone ESC is a pending prefix');
  FDecoder.FlushPending;
  Assert.AreEqual(Ord(kcEscape), Ord(NextKey.Code),
    'FlushPending resolves a lone ESC as the Escape key');
  Assert.IsFalse(FDecoder.HasPendingPrefix);

  // The same sequence split across three PutBytes yields exactly one event
  Feed([$1B]);
  Assert.IsTrue(FDecoder.HasPendingPrefix);
  Feed([Ord('[')]);
  Assert.IsTrue(FDecoder.HasPendingPrefix, 'ESC[ still needs its final byte');
  AssertNoEvent('Partial CSI must not emit');
  Feed([Ord('A')]);
  Assert.AreEqual(Ord(kcUp), Ord(NextKey.Code), 'Split ESC[A is one Up key');

  // ESC + '[' stalled forever: FlushPending emits Escape and re-parses '['
  Feed([$1B, Ord('[')]);
  FDecoder.FlushPending;
  Assert.AreEqual(Ord(kcEscape), Ord(NextKey.Code));
  var LKey := NextKey;
  Assert.AreEqual(Ord(kcChar), Ord(LKey.Code));
  Assert.AreEqual('[', string(LKey.Character));

  AssertNoEvent('No extra events');
end;

procedure TSequenceDecoderTests.Utf8Decoding;
begin
  // 2-byte: é (U+00E9)
  Feed([$C3, $A9]);
  var LKey := NextKey;
  Assert.AreEqual(Ord(kcChar), Ord(LKey.Code));
  Assert.AreEqual(Integer($E9), Integer(LKey.CodePoint));

  // 3-byte: € (U+20AC)
  Feed([$E2, $82, $AC]);
  Assert.AreEqual(Integer($20AC), Integer(NextKey.CodePoint));

  // 4-byte: 😀 (U+1F600); CharText must be the surrogate pair
  Feed([$F0, $9F, $98, $80]);
  LKey := NextKey;
  Assert.AreEqual(Integer($1F600), Integer(LKey.CodePoint));
  Assert.AreEqual(#$D83D#$DE00, LKey.CharText);

  // Split across reads: emoji delivered one byte at a time
  Feed([$F0]);
  AssertNoEvent('Truncated UTF-8 must not emit');
  Assert.IsTrue(FDecoder.HasPendingPrefix);
  Feed([$9F]);
  Feed([$98]);
  Feed([$81]);
  Assert.AreEqual(Integer($1F601), Integer(NextKey.CodePoint));

  // Invalid lead byte: dropped, following key still decodes
  Feed([$FF, Ord('a')]);
  Assert.AreEqual('a', string(NextKey.Character));

  // Stray continuation byte: dropped
  Feed([$80, Ord('b')]);
  Assert.AreEqual('b', string(NextKey.Character));

  // Overlong encoding of '/' ($E0 $80 $AF): rejected, no event
  Feed([$E0, $80, $AF]);
  AssertNoEvent('Overlong encodings must be rejected');

  // Truncated tail with no continuation coming: dropped by FlushPending
  Feed([$E2, $82]);
  Assert.IsTrue(FDecoder.HasPendingPrefix);
  FDecoder.FlushPending;
  AssertNoEvent('Truncated UTF-8 tail must be dropped');
  Assert.IsFalse(FDecoder.HasPendingPrefix);
end;

procedure TSequenceDecoderTests.SgrMouse;
begin
  // Left press at column 5, row 3 (1-based in the protocol)
  FeedText(#$1B'[<0;5;3M');
  var LMouse := NextMouse;
  Assert.AreEqual(Ord(mbLeft), Ord(LMouse.Button));
  Assert.AreEqual(Ord(mekDown), Ord(LMouse.Kind));
  Assert.AreEqual(4, LMouse.X, 'Coordinates are 0-based in Blinki');
  Assert.AreEqual(2, LMouse.Y);

  // Release of the same button
  FeedText(#$1B'[<0;5;3m');
  LMouse := NextMouse;
  Assert.AreEqual(Ord(mekUp), Ord(LMouse.Kind));

  // Right press with Ctrl (bit 16)
  FeedText(#$1B'[<18;1;1M');
  LMouse := NextMouse;
  Assert.AreEqual(Ord(mbRight), Ord(LMouse.Button));
  Assert.IsTrue(LMouse.Modifiers = [kmCtrl]);
  Assert.AreEqual(0, LMouse.X);
  Assert.AreEqual(0, LMouse.Y);

  // Wheel up / wheel down
  FeedText(#$1B'[<64;2;2M');
  LMouse := NextMouse;
  Assert.AreEqual(Ord(mekWheel), Ord(LMouse.Kind));
  Assert.AreEqual(1, LMouse.WheelDelta);
  FeedText(#$1B'[<65;2;2M');
  Assert.AreEqual(-1, NextMouse.WheelDelta);

  // Horizontal wheel (66 = left, 67 = right): no widget consumes it, and
  // reporting it as vertical would scroll during horizontal gestures
  FeedText(#$1B'[<66;2;2M');
  FeedText(#$1B'[<67;2;2M');
  AssertNoEvent('Horizontal wheel must be ignored');

  // Motion report (bit 32): dropped
  FeedText(#$1B'[<32;4;4M');
  AssertNoEvent('Motion reports must be dropped');

  // Legacy X10 report (ESC[M + 3 bytes): swallowed defensively
  Feed([$1B, Ord('['), Ord('M'), $20, $21, $21]);
  AssertNoEvent('X10 mouse bytes must be swallowed');
end;

procedure TSequenceDecoderTests.UnknownSequences_AreSwallowed;
begin
  // Private mode set (bracketed paste enable echo), device status, etc.
  FeedText(#$1B'[?2004h');
  FeedText(#$1B'[?1049l');
  FeedText(#$1B'[200~');
  FeedText(#$1B'[6c');
  AssertNoEvent('Unknown CSI sequences must be swallowed');

  // Unknown SS3 final
  FeedText(#$1B'Oz');
  AssertNoEvent('Unknown SS3 finals must be swallowed');

  // A key right after garbage still decodes
  FeedText(#$1B'[?9999x'#$1B'[A');
  Assert.AreEqual(Ord(kcUp), Ord(NextKey.Code));

  // A CSI aborted by the next ESC must not eat that ESC: the truncated
  // 'ESC[1' is swallowed, the following ESC[A still decodes as Up.
  FeedText(#$1B'[1'#$1B'[A');
  Assert.AreEqual(Ord(kcUp), Ord(NextKey.Code),
    'The aborting ESC starts the next sequence');
  AssertNoEvent('No extra events');
end;

procedure TSequenceDecoderTests.BurstAndReset;
begin
  // A pasted burst: three chars arrive in one read, ordered events out
  FeedText('abc');
  Assert.AreEqual('a', string(NextKey.Character));
  Assert.AreEqual('b', string(NextKey.Character));
  Assert.AreEqual('c', string(NextKey.Character));
  AssertNoEvent('Burst fully consumed');

  // Reset drops buffered bytes and queued events
  FeedText('xy');
  Feed([$1B]);
  FDecoder.Reset;
  AssertNoEvent('Reset must clear queued events');
  Assert.IsFalse(FDecoder.HasPendingPrefix, 'Reset must clear pending bytes');
end;

end.
