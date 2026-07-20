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
{   Unit:        Blinki.Core.Render.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Frame-buffer data model for Blinki's double-buffered rendering.
///   TTuiCell represents a single terminal cell (character or grapheme
///   cluster + style). TTuiFrameBuffer manages a row-major grid of TTuiCell.
///   TTuiClusterPool interns multi-code-unit grapheme clusters (emoji ZWJ
///   sequences, flags, skin tones) so that cells stay small unmanaged records.
/// </summary>
/// <remarks>
///   No I/O dependency: this unit is pure data structure.
///   Used by TTuiCanvas (Blinki.Core.Canvas) for the front and back buffers.
/// </remarks>
unit Blinki.Core.Render;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  Blinki.Core.Style,
  Blinki.Core.Unicode;

type

{ ETuiRenderError }

  /// <summary>
  /// Exception raised for out-of-bounds accesses on the frame buffer.
  /// </summary>
  ETuiRenderError = class(Exception);

{ TTuiClusterPool }

  /// <summary>
  ///   Process-wide interning pool for multi-code-unit grapheme clusters
  ///   displayed in terminal cells. A cell stores a 32-bit id into this pool,
  ///   which keeps TTuiCell an unmanaged record (safe for Move-based buffer
  ///   copies) while supporting emoji sequences of any length.
  /// </summary>
  /// <remarks>
  ///   Not thread-safe: like TTuiCanvas, it must be used from the event-loop
  ///   thread only. Entries are never evicted; growth is bounded by the number
  ///   of distinct clusters ever displayed (typically dozens).
  /// </remarks>
  TTuiClusterPool = class sealed
  strict private
    class var FClusters: TList<string>;
    class var FIds: TDictionary<string, UInt32>;
    class var FWidths: TList<Integer>;
    class var FWidthsLevel: TTuiEmojiLevel;
  public
    /// <summary>
    ///   Returns the id of ACluster, adding it to the pool on first use.
    ///   Passing an empty string returns 0 (the "no cluster" id).
    /// </summary>
    class function Intern(const ACluster: string): UInt32; static;
    /// <summary>
    ///   Returns the cluster text for AId, or an empty string for id 0 and
    ///   any id outside the pool.
    /// </summary>
    class function Resolve(AId: UInt32): string; static;
    /// <summary>
    ///   Frees the pool storage. Called from unit finalization.
    /// </summary>
    class procedure Shutdown; static;
    /// <summary>
    ///   Terminal width in columns of the cluster AId, measured with the
    ///   current TTuiUnicode.EmojiLevel (cached; recomputed lazily when the
    ///   level changes). At least 1.
    /// </summary>
    class function WidthOf(AId: UInt32): Integer; static;
  end;

{ TTuiCell }

  /// <summary>
  ///   Represents a single terminal cell: a Unicode character (or an interned
  ///   grapheme cluster) and its style. Value type with equality operators for
  ///   the diff renderer of TTuiCanvas. Multi-column glyphs occupy one head
  ///   cell followed by continuation cells (Character = #0) that are never
  ///   emitted to the terminal.
  /// </summary>
  TTuiCell = record
  strict private const
    // Reserved ClusterId marking a continuation cell. Unreachable by the
    // pool: interned ids grow from 1 and can never plausibly hit High(UInt32).
    CContinuationId = High(UInt32);
  public
    /// <summary>
    ///   Character to display in the cell. #0 for continuation cells.
    /// </summary>
    Character: Char;
    /// <summary>
    ///   Id of the grapheme cluster in TTuiClusterPool, 0 when the cell
    ///   holds the single code unit in Character, or the reserved sentinel
    ///   marking a continuation cell (the column covered by the multi-column
    ///   glyph on its left).
    /// </summary>
    ClusterId: UInt32;
    /// <summary>
    /// Style (foreground, background, attributes) of the cell.
    /// </summary>
    Style: TTuiStyle;
    /// <summary>
    /// Creates a cell with the given character and style.
    /// </summary>
    class function Make(ACharacter: Char; const AStyle: TTuiStyle): TTuiCell; static; inline;
    /// <summary>
    ///   Creates a cell holding a whole grapheme cluster (e.g. an emoji ZWJ
    ///   sequence). Single-code-unit input produces a plain character cell;
    ///   empty input produces a blank cell with the given style.
    /// </summary>
    class function MakeCluster(const ACluster: string; const AStyle: TTuiStyle): TTuiCell; static;
    /// <summary>
    ///   Creates a continuation cell: a placeholder for the second and
    ///   following columns of a multi-column glyph.
    /// </summary>
    class function Continuation(const AStyle: TTuiStyle): TTuiCell; static; inline;
    /// <summary>
    /// Blank cell: a space character with the terminal's default style.
    /// </summary>
    class function Blank: TTuiCell; static; inline;
    /// <summary>
    ///   True when this cell is a continuation placeholder of the
    ///   multi-column glyph that starts on its left.
    /// </summary>
    function IsContinuation: Boolean; inline;
    /// <summary>
    ///   The text this cell emits to the terminal: the interned cluster when
    ///   ClusterId is set, the single character otherwise.
    /// </summary>
    function Text: string;
    /// <summary>
    ///   Number of terminal columns this cell's glyph occupies (at least 1).
    ///   Continuation cells report 1 but are skipped by the flush.
    /// </summary>
    function Width: Integer;
    /// <inheritdoc/>
    class operator Equal(const A, B: TTuiCell): Boolean; inline;
    /// <inheritdoc/>
    class operator NotEqual(const A, B: TTuiCell): Boolean; inline;
  end;

{ TTuiFrameBuffer }

  /// <summary>
  ///   Row-major TTuiCell buffer of Width x Height dimensions.
  ///   The internal index is Y * Width + X (row-layout, cache-friendly for diffing).
  ///   Used as the front buffer (last content emitted to the terminal) and the back
  ///   buffer (current drawing buffer) by TTuiCanvas.
  /// </summary>
  TTuiFrameBuffer = class
  strict private
    FWidth: Integer;
    FHeight: Integer;
    FCells: TArray<TTuiCell>;
    function  GetCell(AX, AY: Integer): TTuiCell; inline;
    procedure SetCell(AX, AY: Integer; const AValue: TTuiCell); inline;
    procedure RaiseIfOutOfBounds(AX, AY: Integer);
  public
    /// <summary>
    /// Creates a buffer of AWidth x AHeight dimensions, initialised with Blank cells.
    /// </summary>
    constructor Create(AWidth, AHeight: Integer);
    /// <summary>
    ///   Resizes the buffer to ANewWidth x ANewHeight.
    ///   The existing content is not preserved: all cells are reinitialised with Blank.
    /// </summary>
    procedure Resize(ANewWidth, ANewHeight: Integer);
    /// <summary>
    /// Overwrites every cell in the buffer with ACell.
    /// </summary>
    procedure Clear(const ACell: TTuiCell);
    /// <summary>
    ///   Copies the content of ASource into this buffer. The dimensions must match;
    ///   raises ETuiRenderError otherwise.
    /// </summary>
    procedure CopyFrom(ASource: TTuiFrameBuffer);
    /// <summary>
    /// Number of columns in the buffer.
    /// </summary>
    property Width: Integer read FWidth;
    /// <summary>
    /// Number of rows in the buffer.
    /// </summary>
    property Height: Integer read FHeight;
    /// <summary>
    ///   Read/write access to cells by 0-based coordinates (X = column, Y = row).
    ///   Raises ETuiRenderError if the coordinates are out of bounds.
    /// </summary>
    property Cells[AX, AY: Integer]: TTuiCell read GetCell write SetCell; default;
  end;

implementation

{ TTuiClusterPool }

class function TTuiClusterPool.Intern(const ACluster: string): UInt32;
begin
  if ACluster = '' then
    Exit(0);
  if not Assigned(FIds) then
  begin
    FIds := TDictionary<string, UInt32>.Create;
    FClusters := TList<string>.Create;
    FWidths := TList<Integer>.Create;
    FWidthsLevel := TTuiUnicode.EmojiLevel;
  end;
  if FIds.TryGetValue(ACluster, Result) then
    Exit;
  FClusters.Add(ACluster);
  FWidths.Add(-1); // width computed lazily by WidthOf
  Result := UInt32(FClusters.Count); // ids are 1-based; 0 = no cluster
  FIds.Add(ACluster, Result);
end;

class function TTuiClusterPool.Resolve(AId: UInt32): string;
begin
  // Unsigned comparison also rejects the continuation sentinel (High(UInt32)).
  if (AId = 0) or not Assigned(FClusters) or (AId > UInt32(FClusters.Count)) then
    Exit('');
  Result := FClusters[Integer(AId) - 1];
end;

class procedure TTuiClusterPool.Shutdown;
begin
  if Assigned(FIds) then
    FreeAndNil(FIds);
  if Assigned(FClusters) then
    FreeAndNil(FClusters);
  if Assigned(FWidths) then
    FreeAndNil(FWidths);
end;

class function TTuiClusterPool.WidthOf(AId: UInt32): Integer;
begin
  if (AId = 0) or not Assigned(FClusters) or (AId > UInt32(FClusters.Count)) then
    Exit(1);
  // The cached widths depend on the emoji level: invalidate them lazily when
  // the level changes (normally only once, at backend Open).
  if FWidthsLevel <> TTuiUnicode.EmojiLevel then
  begin
    for var LIndex := 0 to FWidths.Count - 1 do
      FWidths[LIndex] := -1;
    FWidthsLevel := TTuiUnicode.EmojiLevel;
  end;
  Result := FWidths[Integer(AId) - 1];
  if Result < 0 then
  begin
    var LCluster := FClusters[Integer(AId) - 1];
    Result := TTuiUnicode.ClusterWidthAt(LCluster, 1, Length(LCluster));
    if Result < 1 then
      Result := 1;
    FWidths[Integer(AId) - 1] := Result;
  end;
end;

{ TTuiCell }

class function TTuiCell.Make(ACharacter: Char; const AStyle: TTuiStyle): TTuiCell;
begin
  Result.Character := ACharacter;
  Result.ClusterId := 0;
  Result.Style := AStyle;
end;

class function TTuiCell.MakeCluster(const ACluster: string;
  const AStyle: TTuiStyle): TTuiCell;
begin
  if ACluster = '' then
    Exit(Make(' ', AStyle));
  if Length(ACluster) = 1 then
    Exit(Make(ACluster[1], AStyle));
  Result.Character := ACluster[1];
  Result.ClusterId := TTuiClusterPool.Intern(ACluster);
  Result.Style := AStyle;
end;

class function TTuiCell.Continuation(const AStyle: TTuiStyle): TTuiCell;
begin
  Result.Character := #0;
  Result.ClusterId := CContinuationId;
  Result.Style := AStyle;
end;

class function TTuiCell.Blank: TTuiCell;
begin
  Result.Character := ' ';
  Result.ClusterId := 0;
  Result.Style := TTuiStyle.Default;
end;

function TTuiCell.IsContinuation: Boolean;
begin
  Result := ClusterId = CContinuationId;
end;

function TTuiCell.Text: string;
begin
  if IsContinuation then
    Result := ''
  else if ClusterId <> 0 then
    Result := TTuiClusterPool.Resolve(ClusterId)
  else
    Result := Character;
end;

function TTuiCell.Width: Integer;
begin
  if IsContinuation then
    Result := 1
  else if ClusterId <> 0 then
    Result := TTuiClusterPool.WidthOf(ClusterId)
  else if TTuiUnicode.CodePointWidth(Ord(Character)) = 2 then
    Result := 2
  else
    Result := 1;
end;

class operator TTuiCell.Equal(const A, B: TTuiCell): Boolean;
begin
  Result := (A.Character = B.Character) and (A.ClusterId = B.ClusterId) and
    (A.Style = B.Style);
end;

class operator TTuiCell.NotEqual(const A, B: TTuiCell): Boolean;
begin
  Result := not (A = B);
end;

{ TTuiFrameBuffer }

constructor TTuiFrameBuffer.Create(AWidth, AHeight: Integer);
begin
  inherited Create;
  Resize(AWidth, AHeight);
end;

procedure TTuiFrameBuffer.Resize(ANewWidth, ANewHeight: Integer);
begin
  FWidth := ANewWidth;
  FHeight := ANewHeight;
  SetLength(FCells, FWidth * FHeight);
  for var LIndex := 0 to High(FCells) do
    FCells[LIndex] := TTuiCell.Blank;
end;

procedure TTuiFrameBuffer.Clear(const ACell: TTuiCell);
begin
  for var LIndex := 0 to High(FCells) do
    FCells[LIndex] := ACell;
end;

procedure TTuiFrameBuffer.CopyFrom(ASource: TTuiFrameBuffer);
begin
  var LLen := Length(FCells);
  if LLen <> Length(ASource.FCells) then
    raise ETuiRenderError.Create('TTuiFrameBuffer.CopyFrom: the buffer sizes do not match');
  if LLen > 0 then
    Move(ASource.FCells[0], FCells[0], LLen * SizeOf(TTuiCell));
end;

function TTuiFrameBuffer.GetCell(AX, AY: Integer): TTuiCell;
begin
  RaiseIfOutOfBounds(AX, AY);
  Result := FCells[AY * FWidth + AX];
end;

procedure TTuiFrameBuffer.SetCell(AX, AY: Integer; const AValue: TTuiCell);
begin
  RaiseIfOutOfBounds(AX, AY);
  FCells[AY * FWidth + AX] := AValue;
end;

procedure TTuiFrameBuffer.RaiseIfOutOfBounds(AX, AY: Integer);
begin
  if (AX < 0) or (AX >= FWidth) or (AY < 0) or (AY >= FHeight) then
  begin
    raise ETuiRenderError.CreateFmt(
      'TTuiFrameBuffer: coordinates (%d, %d) out of bounds (%d x %d)',
      [AX, AY, FWidth, FHeight]
    );
  end;
end;

initialization

finalization
  TTuiClusterPool.Shutdown;

end.
