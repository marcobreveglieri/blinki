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
///   TTuiCell represents a single terminal cell (character + style).
///   TTuiFrameBuffer manages a row-major grid of TTuiCell.
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
  System.SysUtils,
  Blinki.Core.Style;

type

{ ETuiRenderError }

  /// <summary>
  /// Exception raised for out-of-bounds accesses on the frame buffer.
  /// </summary>
  ETuiRenderError = class(Exception);

{ TTuiCell }

  /// <summary>
  ///   Represents a single terminal cell: a Unicode character and its style.
  ///   Value type with equality operators for the diff renderer of TTuiCanvas.
  /// </summary>
  TTuiCell = record
  public
    /// <summary>
    /// Character to display in the cell.
    /// </summary>
    Character: Char;
    /// <summary>
    /// Style (foreground, background, attributes) of the cell.
    /// </summary>
    Style: TTuiStyle;
    /// <summary>
    /// Creates a cell with the given character and style.
    /// </summary>
    class function Make(ACharacter: Char; const AStyle: TTuiStyle): TTuiCell; static; inline;
    /// <summary>
    /// Blank cell: a space character with the terminal's default style.
    /// </summary>
    class function Blank: TTuiCell; static; inline;
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

{ TTuiCell }

class function TTuiCell.Make(ACharacter: Char; const AStyle: TTuiStyle): TTuiCell;
begin
  Result.Character := ACharacter;
  Result.Style := AStyle;
end;

class function TTuiCell.Blank: TTuiCell;
begin
  Result.Character := ' ';
  Result.Style := TTuiStyle.Default;
end;

class operator TTuiCell.Equal(const A, B: TTuiCell): Boolean;
begin
  Result := (A.Character = B.Character) and (A.Style = B.Style);
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

end.
