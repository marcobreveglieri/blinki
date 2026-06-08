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
{   Unit:        Tetris.Consts.pas                               }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TetrisDemo -- Compile-time constants: board dimensions, tetromino shapes
///   (SRS), colours, gravity table, scoring, and hint text.
/// </summary>
unit Tetris.Consts;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types;

type
  /// <summary>
  ///   Four cell offsets describing one rotation of a tetromino.
  /// </summary>
  TShapeCells = array[0..3] of TPoint;

  /// <summary>
  ///   The four rotations (0..3) of a tetromino.
  /// </summary>
  TShapeRotations = array[0..3] of TShapeCells;

  /// <summary>
  ///   Identifies each of the seven standard tetrominoes plus the empty sentinel.
  /// </summary>
  TTetrominoKind = (tkNone, tkI, tkO, tkT, tkS, tkZ, tkJ, tkL);

const
  // Board geometry
  CBoardCols = 10;
  CBoardRows = 21;
  CCellWidth = 2; // terminal columns per cell (keeps cells square)

  // Classic Tetris RGB colours for each kind (tkNone is a black placeholder)
  CKindColors: array[TTetrominoKind] of record R, G, B: Byte end = (
    (R: 0;   G: 0;   B: 0  ),  // tkNone  -- black / empty
    (R: 0;   G: 255; B: 255),  // tkI     -- Cyan
    (R: 255; G: 255; B: 0  ),  // tkO     -- Yellow
    (R: 160; G: 0;   B: 200),  // tkT     -- Purple
    (R: 0;   G: 200; B: 0  ),  // tkS     -- Green
    (R: 220; G: 0;   B: 0  ),  // tkZ     -- Red
    (R: 0;   G: 0;   B: 200),  // tkJ     -- Blue
    (R: 255; G: 140; B: 0  )   // tkL     -- Orange
  );

  // SRS tetromino shapes.
  // CShapes[kind][rotation] = 4 cells (X=col, Y=row) relative to bounding-box
  // origin (top-left).  I uses a 4x4 box; all others use 3x3.
  CShapes: array[TTetrominoKind] of TShapeRotations = (
    // tkNone -- placeholder, never spawned
    (
      ((X: 0; Y: 0), (X: 0; Y: 0), (X: 0; Y: 0), (X: 0; Y: 0)),
      ((X: 0; Y: 0), (X: 0; Y: 0), (X: 0; Y: 0), (X: 0; Y: 0)),
      ((X: 0; Y: 0), (X: 0; Y: 0), (X: 0; Y: 0), (X: 0; Y: 0)),
      ((X: 0; Y: 0), (X: 0; Y: 0), (X: 0; Y: 0), (X: 0; Y: 0))
    ),
    // tkI -- 4x4 bounding box
    (
      ((X: 0; Y: 1), (X: 1; Y: 1), (X: 2; Y: 1), (X: 3; Y: 1)),  // rot 0
      ((X: 2; Y: 0), (X: 2; Y: 1), (X: 2; Y: 2), (X: 2; Y: 3)),  // rot 1
      ((X: 0; Y: 2), (X: 1; Y: 2), (X: 2; Y: 2), (X: 3; Y: 2)),  // rot 2
      ((X: 1; Y: 0), (X: 1; Y: 1), (X: 1; Y: 2), (X: 1; Y: 3))   // rot 3
    ),
    // tkO -- 3x3 bounding box (all rotations identical)
    (
      ((X: 1; Y: 0), (X: 2; Y: 0), (X: 1; Y: 1), (X: 2; Y: 1)),
      ((X: 1; Y: 0), (X: 2; Y: 0), (X: 1; Y: 1), (X: 2; Y: 1)),
      ((X: 1; Y: 0), (X: 2; Y: 0), (X: 1; Y: 1), (X: 2; Y: 1)),
      ((X: 1; Y: 0), (X: 2; Y: 0), (X: 1; Y: 1), (X: 2; Y: 1))
    ),
    // tkT -- 3x3 bounding box
    (
      ((X: 1; Y: 0), (X: 0; Y: 1), (X: 1; Y: 1), (X: 2; Y: 1)),  // rot 0
      ((X: 1; Y: 0), (X: 1; Y: 1), (X: 2; Y: 1), (X: 1; Y: 2)),  // rot 1
      ((X: 0; Y: 1), (X: 1; Y: 1), (X: 2; Y: 1), (X: 1; Y: 2)),  // rot 2
      ((X: 1; Y: 0), (X: 0; Y: 1), (X: 1; Y: 1), (X: 1; Y: 2))   // rot 3
    ),
    // tkS -- 3x3 bounding box
    (
      ((X: 1; Y: 0), (X: 2; Y: 0), (X: 0; Y: 1), (X: 1; Y: 1)),  // rot 0
      ((X: 1; Y: 0), (X: 1; Y: 1), (X: 2; Y: 1), (X: 2; Y: 2)),  // rot 1
      ((X: 1; Y: 1), (X: 2; Y: 1), (X: 0; Y: 2), (X: 1; Y: 2)),  // rot 2
      ((X: 0; Y: 0), (X: 0; Y: 1), (X: 1; Y: 1), (X: 1; Y: 2))   // rot 3
    ),
    // tkZ -- 3x3 bounding box
    (
      ((X: 0; Y: 0), (X: 1; Y: 0), (X: 1; Y: 1), (X: 2; Y: 1)),  // rot 0
      ((X: 2; Y: 0), (X: 1; Y: 1), (X: 2; Y: 1), (X: 1; Y: 2)),  // rot 1
      ((X: 0; Y: 1), (X: 1; Y: 1), (X: 1; Y: 2), (X: 2; Y: 2)),  // rot 2
      ((X: 1; Y: 0), (X: 0; Y: 1), (X: 1; Y: 1), (X: 0; Y: 2))   // rot 3
    ),
    // tkJ -- 3x3 bounding box
    (
      ((X: 0; Y: 0), (X: 0; Y: 1), (X: 1; Y: 1), (X: 2; Y: 1)),  // rot 0
      ((X: 1; Y: 0), (X: 2; Y: 0), (X: 1; Y: 1), (X: 1; Y: 2)),  // rot 1
      ((X: 0; Y: 1), (X: 1; Y: 1), (X: 2; Y: 1), (X: 2; Y: 2)),  // rot 2
      ((X: 1; Y: 0), (X: 1; Y: 1), (X: 0; Y: 2), (X: 1; Y: 2))   // rot 3
    ),
    // tkL -- 3x3 bounding box
    (
      ((X: 2; Y: 0), (X: 0; Y: 1), (X: 1; Y: 1), (X: 2; Y: 1)),  // rot 0
      ((X: 1; Y: 0), (X: 1; Y: 1), (X: 1; Y: 2), (X: 2; Y: 2)),  // rot 1
      ((X: 0; Y: 1), (X: 1; Y: 1), (X: 2; Y: 1), (X: 0; Y: 2)),  // rot 2
      ((X: 0; Y: 0), (X: 1; Y: 0), (X: 1; Y: 1), (X: 1; Y: 2))   // rot 3
    )
  );

  // Gravity interval in milliseconds per level (index = level, capped at 20)
  CGravityMs: array[0..20] of Integer = (
    800, 720, 630, 550, 470, 380, 300, 215, 130, 100,
     83,  83,  83,  67,  67,  67,  50,  50,  50,  33, 17
  );

  // Base score for clearing n lines in one drop (multiply by level+1)
  CLineScore: array[1..4] of Integer = (100, 300, 500, 800);

  // Hint bar text shown at the bottom of the play field
  CHintText =
    ' ←→ Move  ↑ Rotate  ↓ Soft drop  Space Hard drop' +
    '  Enter/C Hold  Z/X Rotate  P Pause  R Restart  Q Quit';

implementation

end.
