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
{   Unit:        Tetris.Model.pas                                }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TetrisDemo -- Pure game logic: TTetrisGame manages the board, active piece,
///   hold slot, next-bag, scoring, levels, and gravity ticks.
/// </summary>
unit Tetris.Model;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  Tetris.Consts;

type
  /// <summary>
  ///   Notable game actions that TTetrisGame notifies via its OnEvent callback.
  /// </summary>
  TGameEvent = (geRotate, geHold, geDrop, geLock, geGameOver);

  /// <summary>
  ///   Callback type for game event notifications (compatible with method references).
  /// </summary>
  TGameEventProc = reference to procedure(AEvent: TGameEvent);

  /// <summary>
  ///   Tracks whether the game is running, paused, or over.
  /// </summary>
  TGameState = (gsPlaying, gsPaused, gsGameOver);

  /// <summary>
  ///   Self-contained Tetris game model.  Call NewGame to start, then Tick on
  ///   every frame and the movement/action methods in response to key events.
  /// </summary>
  TTetrisGame = class
  strict private
    // Board: FGrid[row, col] = the locked kind, tkNone means empty
    FGrid: array[0..CBoardRows - 1, 0..CBoardCols - 1] of TTetrominoKind;
    FCurrentKind: TTetrominoKind;
    FCurrentRot: Integer;    // 0..3
    FCurrentX: Integer;      // left column of the bounding box
    FCurrentY: Integer;      // top row of the bounding box
    FGravityAccumMs: Integer;
    FHoldKind: TTetrominoKind;
    FHoldUsed: Boolean;
    FLevel: Integer;
    FLines: Integer;
    FNextBag: array[0..6] of TTetrominoKind;
    FNextBagIdx: Integer;
    FScore: Integer;
    FState: TGameState;
    FOnEvent: TGameEventProc;
    // Private helpers
    function CanPlace(AKind: TTetrominoKind; ARot, AX, AY: Integer): Boolean;
    function ClearFullLines: Integer;
    function GetNextKind: TTetrominoKind;
    function GravityIntervalMs: Integer;
    procedure LockPiece;
    procedure Notify(AEvent: TGameEvent);
    procedure RefillBag;
    procedure SpawnNext;
  public
    constructor Create;
    /// <summary>
    ///   Resets all state and starts a fresh game.
    /// </summary>
    procedure NewGame;
    // Movement and actions -- all are no-ops when state is not gsPlaying
    /// <summary>
    ///   Moves the active piece one column to the left.
    /// </summary>
    procedure MoveLeft;
    /// <summary>
    ///   Moves the active piece one column to the right.
    /// </summary>
    procedure MoveRight;
    /// <summary>
    ///   Drops the active piece one row; awards 1 point and locks on collision.
    /// </summary>
    procedure SoftDrop;
    /// <summary>
    ///   Instantly drops the active piece to the ghost row; awards 2 pts per row.
    /// </summary>
    procedure HardDrop;
    /// <summary>
    ///   Rotates the active piece clockwise with basic wall-kick fallback.
    /// </summary>
    procedure RotateCW;
    /// <summary>
    ///   Rotates the active piece counter-clockwise with basic wall-kick fallback.
    /// </summary>
    procedure RotateCCW;
    /// <summary>
    ///   Swaps the active piece with the hold slot (once per piece).
    /// </summary>
    procedure Hold;
    /// <summary>
    ///   Toggles between gsPlaying and gsPaused.
    /// </summary>
    procedure TogglePause;
    /// <summary>
    ///   Advances gravity by AElapsedMs milliseconds; auto-drops or locks the piece.
    /// </summary>
    procedure Tick(AElapsedMs: Integer);
    // Board queries
    /// <summary>
    ///   Returns the locked kind at (ARow, ACol), or tkNone when the cell is empty.
    /// </summary>
    function CellAt(ARow, ACol: Integer): TTetrominoKind;
    /// <summary>
    ///   Returns the absolute (X=col, Y=row) positions of the four active cells.
    /// </summary>
    function CurrentCells: TShapeCells;
    /// <summary>
    ///   Returns the lowest row at which the active piece can be placed (ghost).
    /// </summary>
    function GhostRow: Integer;
    property CurrentKind: TTetrominoKind read FCurrentKind;
    property CurrentRot: Integer read FCurrentRot;
    property CurrentX: Integer read FCurrentX;
    property CurrentY: Integer read FCurrentY;
    property HoldKind: TTetrominoKind read FHoldKind;
    property Level: Integer read FLevel;
    property Lines: Integer read FLines;
    /// <summary>
    ///   The kind of the next piece to be spawned.
    /// </summary>
    property NextKind: TTetrominoKind read GetNextKind;
    property Score: Integer read FScore;
    property State: TGameState read FState;
    /// <summary>
    ///   Optional callback fired when a notable game action occurs.
    ///   Assign a TTetrisAudio.HandleGameEvent (or any TGameEventProc) to play sounds.
    /// </summary>
    property OnEvent: TGameEventProc read FOnEvent write FOnEvent;
  end;

implementation

uses
  System.Math,
  System.Types;

{ TTetrisGame }

constructor TTetrisGame.Create;
begin
  inherited Create;
  FState := gsGameOver;
end;

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

function TTetrisGame.CanPlace(AKind: TTetrominoKind; ARot, AX, AY: Integer): Boolean;
begin
  var LShape := CShapes[AKind][ARot];
  for var LI := 0 to 3 do
  begin
    var LCol := LShape[LI].X + AX;
    var LRow := LShape[LI].Y + AY;
    if (LCol < 0) or (LCol >= CBoardCols) or
       (LRow < 0) or (LRow >= CBoardRows) then
      Exit(False);
    if FGrid[LRow, LCol] <> tkNone then
      Exit(False);
  end;
  Result := True;
end;

function TTetrisGame.ClearFullLines: Integer;
begin
  Result := 0;
  var LRow := CBoardRows - 1;
  while LRow >= 0 do
  begin
    // Check whether this row is completely filled
    var LFull := True;
    for var LCol := 0 to CBoardCols - 1 do
    begin
      if FGrid[LRow, LCol] = tkNone then
      begin
        LFull := False;
        Break;
      end;
    end;
    if LFull then
    begin
      // Shift every row above down by one
      for var LSrc := LRow - 1 downto 0 do
        FGrid[LSrc + 1] := FGrid[LSrc];
      // Clear the topmost row
      for var LCol := 0 to CBoardCols - 1 do
        FGrid[0, LCol] := tkNone;
      Inc(Result);
      // Do not decrement LRow: the same row index now holds the row that was
      // above, so we must re-check it.
    end
    else
      Dec(LRow);
  end;
  if Result > 0 then
  begin
    Inc(FLines, Result);
    var LClampedLines := Min(Result, 4);
    Inc(FScore, CLineScore[LClampedLines] * (FLevel + 1));
    FLevel := Min(FLines div 10, 20);
  end;
end;

function TTetrisGame.GetNextKind: TTetrominoKind;
begin
  Result := FNextBag[FNextBagIdx];
end;

function TTetrisGame.GravityIntervalMs: Integer;
begin
  Result := CGravityMs[Min(FLevel, 20)];
end;

procedure TTetrisGame.Notify(AEvent: TGameEvent);
begin
  if Assigned(FOnEvent) then
    FOnEvent(AEvent);
end;

procedure TTetrisGame.LockPiece;
begin
  var LCells := CurrentCells;
  for var LI := 0 to 3 do
    FGrid[LCells[LI].Y, LCells[LI].X] := FCurrentKind;
  ClearFullLines;
  Notify(geLock);
  SpawnNext;
end;

procedure TTetrisGame.RefillBag;
begin
  // Fill bag with the seven standard kinds
  FNextBag[0] := tkI;
  FNextBag[1] := tkJ;
  FNextBag[2] := tkL;
  FNextBag[3] := tkO;
  FNextBag[4] := tkS;
  FNextBag[5] := tkT;
  FNextBag[6] := tkZ;
  // Fisher-Yates shuffle
  for var LI := 6 downto 1 do
  begin
    var LJ := Random(LI + 1);
    var LTmp := FNextBag[LI];
    FNextBag[LI] := FNextBag[LJ];
    FNextBag[LJ] := LTmp;
  end;
  FNextBagIdx := 0;
end;

procedure TTetrisGame.SpawnNext;
begin
  FCurrentKind := FNextBag[FNextBagIdx];
  Inc(FNextBagIdx);
  if FNextBagIdx >= 7 then
    RefillBag;
  FCurrentRot := 0;
  FCurrentX := 3;
  FCurrentY := 0;
  FHoldUsed := False;
  if not CanPlace(FCurrentKind, FCurrentRot, FCurrentX, FCurrentY) then
  begin
    FState := gsGameOver;
    Notify(geGameOver);
  end;
end;

// ---------------------------------------------------------------------------
// Public interface
// ---------------------------------------------------------------------------

procedure TTetrisGame.NewGame;
begin
  // Zero the board
  for var LRow := 0 to CBoardRows - 1 do
    for var LCol := 0 to CBoardCols - 1 do
      FGrid[LRow, LCol] := tkNone;
  FScore := 0;
  FLevel := 0;
  FLines := 0;
  FGravityAccumMs := 0;
  FHoldKind := tkNone;
  FHoldUsed := False;
  FState := gsPlaying;
  RefillBag;
  // Pre-fill a second bag so NextKind always has a valid lookahead
  SpawnNext;
end;

procedure TTetrisGame.MoveLeft;
begin
  if FState <> gsPlaying then
    Exit;
  if CanPlace(FCurrentKind, FCurrentRot, FCurrentX - 1, FCurrentY) then
    Dec(FCurrentX);
end;

procedure TTetrisGame.MoveRight;
begin
  if FState <> gsPlaying then
    Exit;
  if CanPlace(FCurrentKind, FCurrentRot, FCurrentX + 1, FCurrentY) then
    Inc(FCurrentX);
end;

procedure TTetrisGame.SoftDrop;
begin
  if FState <> gsPlaying then
    Exit;
  if CanPlace(FCurrentKind, FCurrentRot, FCurrentX, FCurrentY + 1) then
  begin
    Inc(FCurrentY);
    Inc(FScore);
  end
  else
    LockPiece;
end;

procedure TTetrisGame.HardDrop;
begin
  if FState <> gsPlaying then
    Exit;
  var LTarget := GhostRow;
  var LDelta := LTarget - FCurrentY;
  FCurrentY := LTarget;
  Inc(FScore, LDelta * 2);
  Notify(geDrop);
  LockPiece;
end;

procedure TTetrisGame.RotateCW;
begin
  if FState <> gsPlaying then
    Exit;
  var LOldRot := FCurrentRot;
  var LNewRot := (FCurrentRot + 1) mod 4;
  // Try natural position, then wall-kick offsets
  if CanPlace(FCurrentKind, LNewRot, FCurrentX, FCurrentY) then
    FCurrentRot := LNewRot
  else if CanPlace(FCurrentKind, LNewRot, FCurrentX + 1, FCurrentY) then
  begin
    FCurrentRot := LNewRot;
    Inc(FCurrentX);
  end
  else if CanPlace(FCurrentKind, LNewRot, FCurrentX - 1, FCurrentY) then
  begin
    FCurrentRot := LNewRot;
    Dec(FCurrentX);
  end
  else if CanPlace(FCurrentKind, LNewRot, FCurrentX + 2, FCurrentY) then
  begin
    FCurrentRot := LNewRot;
    Inc(FCurrentX, 2);
  end
  else if CanPlace(FCurrentKind, LNewRot, FCurrentX - 2, FCurrentY) then
  begin
    FCurrentRot := LNewRot;
    Dec(FCurrentX, 2);
  end;
  if FCurrentRot <> LOldRot then
    Notify(geRotate);
end;

procedure TTetrisGame.RotateCCW;
begin
  if FState <> gsPlaying then
    Exit;
  var LOldRot := FCurrentRot;
  var LNewRot := (FCurrentRot + 3) mod 4;
  // Try natural position, then wall-kick offsets
  if CanPlace(FCurrentKind, LNewRot, FCurrentX, FCurrentY) then
    FCurrentRot := LNewRot
  else if CanPlace(FCurrentKind, LNewRot, FCurrentX + 1, FCurrentY) then
  begin
    FCurrentRot := LNewRot;
    Inc(FCurrentX);
  end
  else if CanPlace(FCurrentKind, LNewRot, FCurrentX - 1, FCurrentY) then
  begin
    FCurrentRot := LNewRot;
    Dec(FCurrentX);
  end
  else if CanPlace(FCurrentKind, LNewRot, FCurrentX + 2, FCurrentY) then
  begin
    FCurrentRot := LNewRot;
    Inc(FCurrentX, 2);
  end
  else if CanPlace(FCurrentKind, LNewRot, FCurrentX - 2, FCurrentY) then
  begin
    FCurrentRot := LNewRot;
    Dec(FCurrentX, 2);
  end;
  if FCurrentRot <> LOldRot then
    Notify(geRotate);
end;

procedure TTetrisGame.Hold;
begin
  if FState <> gsPlaying then
    Exit;
  if FHoldUsed then
    Exit;
  if FHoldKind = tkNone then
  begin
    // No held piece yet: stash current and spawn the next from the bag
    FHoldKind := FCurrentKind;
    SpawnNext;
  end
  else
  begin
    // Swap current with hold and respawn the held piece
    var LSwap := FCurrentKind;
    FCurrentKind := FHoldKind;
    FHoldKind := LSwap;
    FCurrentRot := 0;
    FCurrentX := 3;
    FCurrentY := 0;
    if not CanPlace(FCurrentKind, FCurrentRot, FCurrentX, FCurrentY) then
    begin
      FState := gsGameOver;
      Notify(geGameOver);
    end;
  end;
  FHoldUsed := True;
  if FState = gsPlaying then
    Notify(geHold);
end;

procedure TTetrisGame.TogglePause;
begin
  if FState = gsPlaying then
    FState := gsPaused
  else if FState = gsPaused then
    FState := gsPlaying;
end;

procedure TTetrisGame.Tick(AElapsedMs: Integer);
begin
  if FState <> gsPlaying then
    Exit;
  Inc(FGravityAccumMs, AElapsedMs);
  var LInterval := GravityIntervalMs;
  while FGravityAccumMs >= LInterval do
  begin
    Dec(FGravityAccumMs, LInterval);
    if CanPlace(FCurrentKind, FCurrentRot, FCurrentX, FCurrentY + 1) then
      Inc(FCurrentY)
    else
    begin
      LockPiece;
      // After locking, FState may have changed to gsGameOver; stop the loop
      if FState <> gsPlaying then
        Break;
    end;
  end;
end;

function TTetrisGame.CellAt(ARow, ACol: Integer): TTetrominoKind;
begin
  Result := FGrid[ARow, ACol];
end;

function TTetrisGame.CurrentCells: TShapeCells;
begin
  var LShape := CShapes[FCurrentKind][FCurrentRot];
  for var LI := 0 to 3 do
    Result[LI] := TPoint.Create(LShape[LI].X + FCurrentX, LShape[LI].Y + FCurrentY);
end;

function TTetrisGame.GhostRow: Integer;
begin
  Result := FCurrentY;
  while CanPlace(FCurrentKind, FCurrentRot, FCurrentX, Result + 1) do
    Inc(Result);
end;

end.
