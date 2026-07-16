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
{   Unit:        Blinki.UnitTests.Core.Render.pas                }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   DUnitX test fixture for the emoji-capable cell model of
///   Blinki.Core.Render (TTuiCell, TTuiClusterPool, TTuiFrameBuffer) and for
///   the cluster-aware canvas pipeline of Blinki.Core.Canvas, exercised
///   through a capturing fake console backend.
/// </summary>
unit Blinki.UnitTests.Core.Render;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Types,
  DUnitX.TestFramework,
  Blinki.Core.Console,
  Blinki.Core.Event,
  Blinki.Core.Input;

type

{ TFakeConsoleBackend }

  /// <summary>
  ///   Minimal ITuiConsoleBackend that captures Write payloads for golden
  ///   string assertions. Fixed 20x5 size, no input.
  /// </summary>
  TFakeConsoleBackend = class(TInterfacedObject, ITuiConsoleBackend)
  strict private
    FOutput: string;
    FWriteCount: Integer;
  public
    procedure Open;
    procedure Close;
    procedure Flush;
    function GetSize: TSize;
    function TryReadEvent(ATimeoutMs: Integer; out AEvent: TTuiEvent): Boolean;
    function TryReadKey(ATimeoutMs: Integer; out AKey: TTuiKeyEvent): Boolean;
    procedure Write(const AText: string);
    /// <summary>
    ///   Concatenation of everything written so far.
    /// </summary>
    property Output: string read FOutput;
    /// <summary>
    ///   Number of Write calls received.
    /// </summary>
    property WriteCount: Integer read FWriteCount;
    /// <summary>
    ///   Clears the captured output.
    /// </summary>
    procedure ResetCapture;
  end;

{ TRenderTests }

  /// <summary>
  ///   Verifies TTuiCell, TTuiClusterPool and TTuiFrameBuffer.
  /// </summary>
  [TestFixture]
  TRenderTests = class
  public
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Make produces a plain cell with no cluster id.
    /// </summary>
    [Test]
    procedure Cell_Make_PlainCell;
    /// <summary>
    ///   MakeCluster normalizes single-unit input to a plain cell and interns
    ///   multi-unit clusters.
    /// </summary>
    [Test]
    procedure Cell_MakeCluster_InternsSequences;
    /// <summary>
    ///   Text and Width reflect the cluster content.
    /// </summary>
    [Test]
    procedure Cell_TextAndWidth;
    /// <summary>
    ///   Equality covers Character, ClusterId and Style.
    /// </summary>
    [Test]
    procedure Cell_Equality_CoversClusterId;
    /// <summary>
    ///   Continuation cells are recognized and distinct from blanks.
    /// </summary>
    [Test]
    procedure Cell_Continuation;
    /// <summary>
    ///   TTuiCell must stay unmanaged: the frame buffer copies it with Move.
    /// </summary>
    [Test]
    procedure Cell_IsUnmanaged;
    /// <summary>
    ///   Interning the same cluster twice yields the same id.
    /// </summary>
    [Test]
    procedure Pool_Intern_Deduplicates;
    /// <summary>
    ///   CopyFrom preserves cluster cells across buffers.
    /// </summary>
    [Test]
    procedure FrameBuffer_CopyFrom_PreservesClusters;
  end;

{ TCanvasEmojiTests }

  /// <summary>
  ///   Verifies the cluster-aware canvas write and flush pipeline through a
  ///   capturing fake backend.
  /// </summary>
  [TestFixture]
  TCanvasEmojiTests = class
  public
    [Setup]
    procedure Setup;

    /// <summary>
    ///   An emoji is flushed as one surrogate pair; continuation cells emit
    ///   nothing (no #0 ever reaches the terminal).
    /// </summary>
    [Test]
    procedure Flush_Emoji_EmitsWholeClusterOnce;
    /// <summary>
    ///   An unchanged frame flushes nothing.
    /// </summary>
    [Test]
    procedure Flush_UnchangedFrame_EmitsNothing;
    /// <summary>
    ///   Overwriting the continuation column blanks the orphaned head
    ///   (split repair).
    /// </summary>
    [Test]
    procedure Flush_OverwriteContinuation_RepairsHead;
    /// <summary>
    ///   After a cluster cell the flush forces an explicit CursorTo resync.
    /// </summary>
    [Test]
    procedure Flush_AfterCluster_ForcesCursorResync;
  end;

implementation

uses
  System.SysUtils,
  Blinki.Core.Ansi,
  Blinki.Core.Canvas,
  Blinki.Core.Render,
  Blinki.Core.Style,
  Blinki.Core.Unicode;

const
  // 😀 grinning face (2 units)
  Grinning = #$D83D#$DE00;
  // 👨‍👩‍👧 family ZWJ sequence (8 units)
  Family = #$D83D#$DC68#$200D#$D83D#$DC69#$200D#$D83D#$DC67;

{ TFakeConsoleBackend }

procedure TFakeConsoleBackend.Open;
begin
end;

procedure TFakeConsoleBackend.Close;
begin
end;

procedure TFakeConsoleBackend.Flush;
begin
end;

function TFakeConsoleBackend.GetSize: TSize;
begin
  Result.cx := 20;
  Result.cy := 5;
end;

function TFakeConsoleBackend.TryReadEvent(ATimeoutMs: Integer;
  out AEvent: TTuiEvent): Boolean;
begin
  Result := False;
end;

function TFakeConsoleBackend.TryReadKey(ATimeoutMs: Integer;
  out AKey: TTuiKeyEvent): Boolean;
begin
  Result := False;
end;

procedure TFakeConsoleBackend.Write(const AText: string);
begin
  FOutput := FOutput + AText;
  Inc(FWriteCount);
end;

procedure TFakeConsoleBackend.ResetCapture;
begin
  FOutput := '';
  FWriteCount := 0;
end;

{ TRenderTests }

procedure TRenderTests.Setup;
begin
  TTuiUnicode.EmojiLevel := elFull;
end;

procedure TRenderTests.Cell_Make_PlainCell;
begin
  var LCell := TTuiCell.Make('A', TTuiStyle.Default);
  Assert.AreEqual('A', string(LCell.Character));
  Assert.AreEqual(Integer(0), Integer(LCell.ClusterId));
  Assert.IsFalse(LCell.IsContinuation);
end;

procedure TRenderTests.Cell_MakeCluster_InternsSequences;
begin
  var LPlain := TTuiCell.MakeCluster('A', TTuiStyle.Default);
  Assert.AreEqual(Integer(0), Integer(LPlain.ClusterId),
    'Single-unit input should stay a plain cell');

  var LCluster := TTuiCell.MakeCluster(Grinning, TTuiStyle.Default);
  Assert.IsTrue(LCluster.ClusterId <> 0, 'Multi-unit input should intern');

  var LEmpty := TTuiCell.MakeCluster('', TTuiStyle.Default);
  Assert.AreEqual(' ', string(LEmpty.Character), 'Empty input degrades to a blank');
end;

procedure TRenderTests.Cell_TextAndWidth;
begin
  var LCell := TTuiCell.MakeCluster(Grinning, TTuiStyle.Default);
  Assert.AreEqual(Grinning, LCell.Text);
  Assert.AreEqual(2, LCell.Width);

  var LWide := TTuiCell.Make(#$4E2D, TTuiStyle.Default);
  Assert.AreEqual(2, LWide.Width, 'CJK plain cell is wide');

  var LNarrow := TTuiCell.Make('x', TTuiStyle.Default);
  Assert.AreEqual(1, LNarrow.Width);
end;

procedure TRenderTests.Cell_Equality_CoversClusterId;
begin
  var LPlain := TTuiCell.Make(Grinning[1], TTuiStyle.Default);
  var LCluster := TTuiCell.MakeCluster(Grinning, TTuiStyle.Default);
  Assert.IsTrue(LPlain <> LCluster,
    'Same first code unit but different ClusterId must differ');
  var LSame := TTuiCell.MakeCluster(Grinning, TTuiStyle.Default);
  Assert.IsTrue(LCluster = LSame, 'Interning makes identical clusters equal');
end;

procedure TRenderTests.Cell_Continuation;
begin
  var LCont := TTuiCell.Continuation(TTuiStyle.Default);
  Assert.IsTrue(LCont.IsContinuation);
  Assert.IsFalse(TTuiCell.Blank.IsContinuation);
  Assert.IsTrue(LCont <> TTuiCell.Blank);
end;

procedure TRenderTests.Cell_IsUnmanaged;
begin
  // TTuiFrameBuffer.CopyFrom moves cells with Move: a managed field (string,
  // interface) in TTuiCell would corrupt reference counts.
  Assert.IsFalse(IsManagedType(TTuiCell), 'TTuiCell must remain unmanaged');
end;

procedure TRenderTests.Pool_Intern_Deduplicates;
begin
  var LFirst := TTuiClusterPool.Intern(Family);
  var LSecond := TTuiClusterPool.Intern(Family);
  Assert.AreEqual(Integer(LFirst), Integer(LSecond));
  Assert.AreEqual(Family, TTuiClusterPool.Resolve(LFirst));
  Assert.AreEqual(2, TTuiClusterPool.WidthOf(LFirst), 'Family is 2 wide in elFull');
  Assert.AreEqual(Integer(0), Integer(TTuiClusterPool.Intern('')),
    'Empty cluster maps to id 0');
  Assert.AreEqual('', TTuiClusterPool.Resolve(0));
end;

procedure TRenderTests.FrameBuffer_CopyFrom_PreservesClusters;
begin
  var LSource := TTuiFrameBuffer.Create(4, 2);
  var LTarget := TTuiFrameBuffer.Create(4, 2);
  try
    LSource[0, 0] := TTuiCell.MakeCluster(Grinning, TTuiStyle.Default);
    LSource[1, 0] := TTuiCell.Continuation(TTuiStyle.Default);
    LTarget.CopyFrom(LSource);
    Assert.IsTrue(LTarget[0, 0] = LSource[0, 0]);
    Assert.AreEqual(Grinning, LTarget[0, 0].Text);
    Assert.IsTrue(LTarget[1, 0].IsContinuation);
  finally
    LTarget.Free;
    LSource.Free;
  end;
end;

{ TCanvasEmojiTests }

procedure TCanvasEmojiTests.Setup;
begin
  TTuiUnicode.EmojiLevel := elFull;
end;

procedure TCanvasEmojiTests.Flush_Emoji_EmitsWholeClusterOnce;
begin
  var LFake := TFakeConsoleBackend.Create;
  var LBackend: ITuiConsoleBackend := LFake;
  var LCanvas := TTuiCanvas.Create(LBackend);
  try
    LCanvas.WriteAt(0, 0, Grinning, TTuiStyle.Default);
    LCanvas.Flush;
    Assert.IsTrue(Pos(Grinning, LFake.Output) > 0, 'Emoji should be emitted whole');
    Assert.AreEqual(0, Pos(#0, LFake.Output), 'No continuation #0 must leak out');
    // The pair appears exactly once
    var LFirst := Pos(Grinning, LFake.Output);
    Assert.AreEqual(0, Pos(Grinning, LFake.Output, LFirst + 1),
      'The cluster must be emitted exactly once');
  finally
    LCanvas.Free;
  end;
end;

procedure TCanvasEmojiTests.Flush_UnchangedFrame_EmitsNothing;
begin
  var LFake := TFakeConsoleBackend.Create;
  var LBackend: ITuiConsoleBackend := LFake;
  var LCanvas := TTuiCanvas.Create(LBackend);
  try
    LCanvas.WriteAt(0, 0, Grinning + 'ab', TTuiStyle.Default);
    LCanvas.Flush;
    LFake.ResetCapture;
    // Redraw exactly the same content: the diff must emit nothing.
    LCanvas.WriteAt(0, 0, Grinning + 'ab', TTuiStyle.Default);
    LCanvas.Flush;
    Assert.AreEqual('', LFake.Output, 'Identical frame must not re-emit');
  finally
    LCanvas.Free;
  end;
end;

procedure TCanvasEmojiTests.Flush_OverwriteContinuation_RepairsHead;
begin
  var LFake := TFakeConsoleBackend.Create;
  var LBackend: ITuiConsoleBackend := LFake;
  var LCanvas := TTuiCanvas.Create(LBackend);
  try
    LCanvas.WriteAt(0, 0, Grinning, TTuiStyle.Default);
    LCanvas.Flush;
    LFake.ResetCapture;
    // Overwrite only the second column of the glyph: the head must be
    // blanked (split repair) and the emoji must disappear from the output.
    LCanvas.WriteAt(1, 0, 'x', TTuiStyle.Default);
    LCanvas.Flush;
    Assert.AreEqual(0, Pos(Grinning, LFake.Output),
      'The half-overwritten emoji must not be re-emitted');
    Assert.IsTrue(Pos(' x', LFake.Output) > 0,
      'Head blanked to space, then the new character');
  finally
    LCanvas.Free;
  end;
end;

procedure TCanvasEmojiTests.Flush_AfterCluster_ForcesCursorResync;
begin
  var LFake := TFakeConsoleBackend.Create;
  var LBackend: ITuiConsoleBackend := LFake;
  var LCanvas := TTuiCanvas.Create(LBackend);
  try
    LCanvas.WriteAt(0, 0, Grinning + 'ab', TTuiStyle.Default);
    LCanvas.Flush;
    Assert.IsTrue(Pos(TTuiAnsi.CursorTo(1, 3), LFake.Output) > 0,
      'An explicit CursorTo must follow the emoji cluster');
  finally
    LCanvas.Free;
  end;
end;

end.
