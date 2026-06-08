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
{   Unit:        Tetris.View.pas                                 }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TetrisDemo -- Custom widgets: TTetrisBoardView (game grid, ghost, active
///   piece, overlays), TTetrisPreviewView (Next/Hold preview),
///   TTetrisStatsView (Score/Level/Lines display), and TTetrisTitleView
///   (animated rainbow ASCII art title).
/// </summary>
unit Tetris.View;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Widget,
  Tetris.Model;

type

{ TPreviewKind }

  /// <summary>
  ///   Selects whether TTetrisPreviewView shows the next piece or the held piece.
  /// </summary>
  TPreviewKind = (pkNext, pkHold);

{ TTetrisBoardView }

  /// <summary>
  ///   Main game board widget.  Renders the locked grid, ghost piece, and active
  ///   piece every frame; drives gravity via DoTick; and handles all player input.
  ///   This is the only focusable widget in the Tetris demo.
  /// </summary>
  TTetrisBoardView = class(TTuiWidget)
  strict private
    FGame: TTetrisGame; // non-owning reference
  protected
    procedure DoInit; override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Binds the widget to a game model instance (non-owning).
    /// </summary>
    procedure SetGame(AGame: TTetrisGame);
  end;

{ TTetrisPreviewView }

  /// <summary>
  ///   Displays a single tetromino preview (Next or Hold) centered inside the
  ///   assigned rectangle, using rotation 0.
  /// </summary>
  TTetrisPreviewView = class(TTuiWidget)
  strict private
    FGame: TTetrisGame;    // non-owning reference
    FKind: TPreviewKind;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create(AKind: TPreviewKind; AParent: TTuiWidget = nil);
    /// <summary>
    ///   Binds the widget to a game model instance (non-owning).
    /// </summary>
    procedure SetGame(AGame: TTetrisGame);
  end;

{ TTetrisStatsView }

  /// <summary>
  ///   Displays Score, Level, and Lines counters read from the game model.
  /// </summary>
  TTetrisStatsView = class(TTuiWidget)
  strict private
    FGame: TTetrisGame; // non-owning reference
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Binds the widget to a game model instance (non-owning).
    /// </summary>
    procedure SetGame(AGame: TTetrisGame);
  end;

{ TTetrisTitleView }

  /// <summary>
  ///   Animated title widget: renders "TETRIS" in 5x5 block characters with a
  ///   scrolling rainbow gradient and a one-row vertical stagger per letter.
  ///   Purely decorative -- not focusable.
  /// </summary>
  TTetrisTitleView = class(TTuiWidget)
  strict private
    FPhaseMs: Single;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    constructor Create(AParent: TTuiWidget = nil);
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Tetris.Consts,
  Tetris.Helpers;

type
  TTitleLetterRows = array[0..4] of string;

const
  // Animation period for the scrolling rainbow gradient (milliseconds)
  CTitleAnimPeriodMs = 3000.0;

  // Block-pixel patterns for "T E T R I S" (5 rows each, variable column width).
  // '█' = filled cell, ' ' = empty cell.
  CTitleLetters: array[0..5] of TTitleLetterRows = (
    // T  (5 wide)
    ('█████', '  █  ', '  █  ', '  █  ', '  █  '),
    // E  (4 wide)
    ('████', '█   ', '███ ', '█   ', '████'),
    // T  (5 wide)
    ('█████', '  █  ', '  █  ', '  █  ', '  █  '),
    // R  (4 wide)
    ('███ ', '█  █', '███ ', '█ █ ', '█  █'),
    // I  (3 wide)
    ('███', ' █ ', ' █ ', ' █ ', '███'),
    // S  (4 wide)
    ('████', '█   ', '███ ', '   █', '████')
  );

{ TTetrisBoardView }

constructor TTetrisBoardView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
end;

procedure TTetrisBoardView.DoInit;
begin
  SetFocusable(True);
end;

procedure TTetrisBoardView.DoTick(AElapsedMs: Integer);
begin
  if FGame = nil then
    Exit;
  if FGame.State = gsPlaying then
  begin
    FGame.Tick(AElapsedMs);
    Invalidate;
  end;
end;

function TTetrisBoardView.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  if FGame = nil then
    Exit;
  case AEvent.Key.Code of
    kcLeft:
    begin
      if FGame.State = gsPlaying then
      begin
        FGame.MoveLeft;
        Invalidate;
        Result := True;
      end;
    end;
    kcRight:
    begin
      if FGame.State = gsPlaying then
      begin
        FGame.MoveRight;
        Invalidate;
        Result := True;
      end;
    end;
    kcDown:
    begin
      if FGame.State = gsPlaying then
      begin
        FGame.SoftDrop;
        Invalidate;
        Result := True;
      end;
    end;
    kcUp:
    begin
      if FGame.State = gsPlaying then
      begin
        FGame.RotateCW;
        Invalidate;
        Result := True;
      end;
    end;
    kcSpace:
    begin
      if FGame.State = gsPlaying then
      begin
        FGame.HardDrop;
        Invalidate;
        Result := True;
      end;
    end;
    kcEscape:
    begin
      FGame.TogglePause;
      Invalidate;
      Result := True;
    end;
    kcChar:
    begin
      case UpCase(AEvent.Key.Character) of
        'Z':
        begin
          if FGame.State = gsPlaying then
          begin
            FGame.RotateCCW;
            Invalidate;
            Result := True;
          end;
        end;
        'X':
        begin
          if FGame.State = gsPlaying then
          begin
            FGame.RotateCW;
            Invalidate;
            Result := True;
          end;
        end;
        'C':
        begin
          if FGame.State = gsPlaying then
          begin
            FGame.Hold;
            Invalidate;
            Result := True;
          end;
        end;
        'P':
        begin
          FGame.TogglePause;
          Invalidate;
          Result := True;
        end;
        'R':
        begin
          FGame.NewGame;
          Invalidate;
          Result := True;
        end;
      end;
    end;
  end;
end;

procedure TTetrisBoardView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  if FGame = nil then
  begin
    ACanvas.FillRect(ARect, ' ', TTuiStyle.Default);
    Exit;
  end;

  // Fill background
  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(TTuiColor.Default, Theme.Surface));

  // Cell origin: X starts at the left edge; Y is anchored to the bottom of the
  // area so row 0 is at the top and row CBoardRows-1 lands on the last line.
  // TTuiBox already strips the 1-cell border before passing ARect to us, so
  // we must not inflate inward a second time.
  var LOriginX := ARect.Left;
  var LOriginY := ARect.Bottom - CBoardRows;

  ACanvas.PushClip(ARect);

  // Draw locked cells
  for var LRow := 0 to CBoardRows - 1 do
  begin
    for var LCol := 0 to CBoardCols - 1 do
    begin
      var LKind := FGame.CellAt(LRow, LCol);
      if LKind <> tkNone then
      begin
        var LX := LOriginX + LCol * CCellWidth;
        var LY := LOriginY + LRow;
        var LCellRect := TRect.Create(LX, LY, LX + CCellWidth, LY + 1);
        ACanvas.FillRect(LCellRect, ' ', TTuiStyle.Create(KindColor(LKind), KindColor(LKind)));
      end;
    end;
  end;

  // Draw ghost piece (only when the ghost is not at the same row as the active piece)
  var LGhostRow := FGame.GhostRow;
  if LGhostRow <> FGame.CurrentY then
  begin
    var LCurrentShape := CShapes[FGame.CurrentKind][FGame.CurrentRot];
    for var LI := 0 to 3 do
    begin
      var LGCol := LCurrentShape[LI].X + FGame.CurrentX;
      var LGRow := LGhostRow + LCurrentShape[LI].Y;
      var LX := LOriginX + LGCol * CCellWidth;
      var LY := LOriginY + LGRow;
      var LCellRect := TRect.Create(LX, LY, LX + CCellWidth, LY + 1);
      ACanvas.FillRect(LCellRect, '░',
        TTuiStyle.Create(KindColor(FGame.CurrentKind), Theme.Surface, [taDim]));
    end;
  end;

  // Draw active piece
  var LActiveCells := FGame.CurrentCells;
  for var LI := 0 to 3 do
  begin
    var LX := LOriginX + LActiveCells[LI].X * CCellWidth;
    var LY := LOriginY + LActiveCells[LI].Y;
    var LCellRect := TRect.Create(LX, LY, LX + CCellWidth, LY + 1);
    ACanvas.FillRect(LCellRect, ' ',
      TTuiStyle.Create(KindColor(FGame.CurrentKind), KindColor(FGame.CurrentKind)));
  end;

  ACanvas.PopClip;

  // State overlays
  if FGame.State = gsPaused then
  begin
    var LText := '  PAUSED  ';
    var LX := ARect.Left + (ARect.Width - Length(LText)) div 2;
    var LY := ARect.Top + ARect.Height div 2;
    ACanvas.WriteAt(LX, LY, LText, TTuiStyle.Create(Theme.Background, Theme.Warning, [taBold]));
  end
  else if FGame.State = gsGameOver then
  begin
    var LText1 := ' GAME OVER ';
    var LText2 := '  R Restart ';
    var LX1 := ARect.Left + (ARect.Width - Length(LText1)) div 2;
    var LX2 := ARect.Left + (ARect.Width - Length(LText2)) div 2;
    var LY := ARect.Top + ARect.Height div 2 - 1;
    ACanvas.WriteAt(LX1, LY, LText1, TTuiStyle.Create(Theme.Background, Theme.Error, [taBold]));
    ACanvas.WriteAt(LX2, LY + 1, LText2, TTuiStyle.Create(Theme.Text, Theme.Surface));
  end;
end;

procedure TTetrisBoardView.SetGame(AGame: TTetrisGame);
begin
  FGame := AGame;
  Invalidate;
end;

{ TTetrisPreviewView }

constructor TTetrisPreviewView.Create(AKind: TPreviewKind; AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FKind := AKind;
end;

procedure TTetrisPreviewView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  // Fill background
  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(TTuiColor.Default, Theme.Surface));

  if FGame = nil then
    Exit;

  // Determine which kind to show
  var LKind: TTetrominoKind;
  if FKind = pkNext then
    LKind := FGame.NextKind
  else
    LKind := FGame.HoldKind;

  if LKind = tkNone then
    Exit;

  // Use rotation 0 for the preview
  var LShape := CShapes[LKind][0];

  // Compute bounding box of the shape to center it
  var LMinX := LShape[0].X;
  var LMaxX := LShape[0].X;
  var LMinY := LShape[0].Y;
  var LMaxY := LShape[0].Y;
  for var LI := 1 to 3 do
  begin
    if LShape[LI].X < LMinX then
      LMinX := LShape[LI].X;
    if LShape[LI].X > LMaxX then
      LMaxX := LShape[LI].X;
    if LShape[LI].Y < LMinY then
      LMinY := LShape[LI].Y;
    if LShape[LI].Y > LMaxY then
      LMaxY := LShape[LI].Y;
  end;

  var LPieceW := (LMaxX - LMinX + 1) * CCellWidth;
  var LPieceH := LMaxY - LMinY + 1;
  var LOffX := ARect.Left + (ARect.Width - LPieceW) div 2;
  var LOffY := ARect.Top + (ARect.Height - LPieceH) div 2;

  // Draw each cell of the preview piece
  for var LI := 0 to 3 do
  begin
    var LX := LOffX + (LShape[LI].X - LMinX) * CCellWidth;
    var LY := LOffY + (LShape[LI].Y - LMinY);
    var LCellRect := TRect.Create(LX, LY, LX + CCellWidth, LY + 1);
    ACanvas.FillRect(LCellRect, ' ', TTuiStyle.Create(KindColor(LKind), KindColor(LKind)));
  end;
end;

procedure TTetrisPreviewView.SetGame(AGame: TTetrisGame);
begin
  FGame := AGame;
  Invalidate;
end;

{ TTetrisStatsView }

constructor TTetrisStatsView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
end;

procedure TTetrisStatsView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  // Fill background
  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(TTuiColor.Default, Theme.Surface));

  if FGame = nil then
    Exit;

  var LLabelStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
  var LValueStyle := TTuiStyle.Create(Theme.Text, Theme.Surface, [taBold]);

  var LY := ARect.Top + 1;
  ACanvas.WriteAt(ARect.Left + 1, LY, 'Score', LLabelStyle);
  Inc(LY);
  ACanvas.WriteAt(ARect.Left + 1, LY, IntToStr(FGame.Score), LValueStyle);
  Inc(LY, 2);
  ACanvas.WriteAt(ARect.Left + 1, LY, 'Level', LLabelStyle);
  Inc(LY);
  ACanvas.WriteAt(ARect.Left + 1, LY, IntToStr(FGame.Level + 1), LValueStyle);
  Inc(LY, 2);
  ACanvas.WriteAt(ARect.Left + 1, LY, 'Lines', LLabelStyle);
  Inc(LY);
  ACanvas.WriteAt(ARect.Left + 1, LY, IntToStr(FGame.Lines), LValueStyle);
end;

procedure TTetrisStatsView.SetGame(AGame: TTetrisGame);
begin
  FGame := AGame;
  Invalidate;
end;

{ TTetrisTitleView }

constructor TTetrisTitleView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
end;

procedure TTetrisTitleView.DoTick(AElapsedMs: Integer);
begin
  FPhaseMs := FPhaseMs + AElapsedMs;
  if FPhaseMs >= CTitleAnimPeriodMs then
    FPhaseMs := FPhaseMs - CTitleAnimPeriodMs;
  Invalidate;
end;

procedure TTetrisTitleView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  var LBg := Theme.Surface;
  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(TTuiColor.Default, LBg));

  // Compute total width: sum of letter widths + one gap between each pair
  var LTotalW := 0;
  for var LLetter := 0 to High(CTitleLetters) do
  begin
    Inc(LTotalW, Length(CTitleLetters[LLetter][0]));
    if LLetter < High(CTitleLetters) then
      Inc(LTotalW, 1);
  end;

  // Center horizontally; anchor vertically to the top of ARect
  var LOrigX := ARect.Left + (ARect.Width - LTotalW) div 2;
  var LOrigY := ARect.Top;

  var LPenX := LOrigX;
  for var LLetter := 0 to High(CTitleLetters) do
  begin
    var LLetterW := Length(CTitleLetters[LLetter][0]);
    var LVOffset := LLetter mod 2; // stagger: even letters at row 0, odd at row 1

    for var LRow := 0 to 4 do
    begin
      var LLine := CTitleLetters[LLetter][LRow];
      for var LCol := 1 to Length(LLine) do
      begin
        if LLine[LCol] = '█' then
        begin
          // Hue depends on the horizontal position + scrolling phase
          var LGlobalX := LPenX + LCol - 1 - LOrigX;
          var LHue := Single(LGlobalX) / LTotalW + FPhaseMs / CTitleAnimPeriodMs;
          var LFg := HueColor(LHue);
          ACanvas.WriteAt(LPenX + LCol - 1, LOrigY + LVOffset + LRow,
            '█', TTuiStyle.Create(LFg, LBg, [taBold]));
        end;
      end;
    end;

    Inc(LPenX, LLetterW + 1);
  end;
end;

end.
