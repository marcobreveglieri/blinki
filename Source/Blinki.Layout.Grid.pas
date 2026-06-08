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
{   Unit:        Blinki.Layout.Grid.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Grid layout container for the Blinki library.
///   TTuiGrid arranges children in an ARows x ACols grid using
///   TTuiLayoutSolver for rows and columns. Supports row/col span via Place().
///   Children without an explicit Place() call are assigned automatically
///   in row-major order.
/// </summary>
unit Blinki.Layout.Grid;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Geometry,
  Blinki.Core.Widget;

type

{ TTuiGridPlacement }

  /// <summary>
  ///   Position and size of a child widget within a TTuiGrid.
  ///   Row and Col are 0-based. RowSpan and ColSpan must be >= 1.
  /// </summary>
  TTuiGridPlacement = record
  public
    Row: Integer;
    Col: Integer;
    RowSpan: Integer;
    ColSpan: Integer;
    /// <summary>
    ///   Creates a placement with optional span (default 1x1).
    /// </summary>
    class function Make(ARow, ACol: Integer;
      ARowSpan: Integer = 1; AColSpan: Integer = 1): TTuiGridPlacement; static;
  end;

{ TTuiGrid }

  /// <summary>
  ///   ARows x ACols grid container. Row and column constraints (default Fill(1))
  ///   are configurable via SetRowConstraint and SetColConstraint.
  ///   Children added with Place() occupy the specified cells with optional span.
  ///   Children added without Place() (via Create(Grid) or AddChild) are
  ///   positioned in row-major order in the first available cells.
  /// </summary>
  TTuiGrid = class(TTuiWidget)
  strict private
    FRows: Integer;
    FCols: Integer;
    FRowConstraints: TArray<TTuiLayoutConstraint>;
    FColConstraints: TArray<TTuiLayoutConstraint>;
    FPlacements: TDictionary<TTuiWidget, TTuiGridPlacement>;
    function ComputeAutoPlacement(AChildIndex: Integer): TTuiGridPlacement;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Creates an ARows x ACols grid. All row and column constraints
    ///   are initialized to Fill(1). The parent is optional.
    /// </summary>
    constructor Create(ARows, ACols: Integer; AParent: TTuiWidget = nil);
    /// <inheritdoc/>
    destructor Destroy; override;
    /// <summary>
    ///   Sets the sizing constraint for row ARow (0-based).
    /// </summary>
    procedure SetRowConstraint(ARow: Integer;
      const AConstraint: TTuiLayoutConstraint);
    /// <summary>
    ///   Sets the sizing constraint for column ACol (0-based).
    /// </summary>
    procedure SetColConstraint(ACol: Integer;
      const AConstraint: TTuiLayoutConstraint);
    /// <summary>
    ///   Assigns AChild to position APlacement within the grid.
    ///   AChild must already be a child of this grid (added via Create(Grid)
    ///   or AddChild). Overwrites any previously assigned placement.
    /// </summary>
    procedure Place(AChild: TTuiWidget; const APlacement: TTuiGridPlacement);
    /// <summary>
    ///   Number of rows in the grid.
    /// </summary>
    property Rows: Integer read FRows;
    /// <summary>
    ///   Number of columns in the grid.
    /// </summary>
    property Cols: Integer read FCols;
  end;

implementation

uses
  System.SysUtils,
  Blinki.Layout.Solver;

{ TTuiGridPlacement }

class function TTuiGridPlacement.Make(ARow, ACol: Integer;
  ARowSpan: Integer; AColSpan: Integer): TTuiGridPlacement;
begin
  Result.Row := ARow;
  Result.Col := ACol;
  Result.RowSpan := ARowSpan;
  Result.ColSpan := AColSpan;
end;

{ TTuiGrid }

constructor TTuiGrid.Create(ARows, ACols: Integer; AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FRows := ARows;
  FCols := ACols;
  SetLength(FRowConstraints, ARows);
  for var LIndex := 0 to ARows - 1 do
    FRowConstraints[LIndex] := TTuiLayoutConstraint.Fill(1);
  SetLength(FColConstraints, ACols);
  for var LIndex := 0 to ACols - 1 do
    FColConstraints[LIndex] := TTuiLayoutConstraint.Fill(1);
  FPlacements := TDictionary<TTuiWidget, TTuiGridPlacement>.Create;
end;

destructor TTuiGrid.Destroy;
begin
  if Assigned(FPlacements) then
    FreeAndNil(FPlacements);
  inherited Destroy;
end;

procedure TTuiGrid.SetRowConstraint(ARow: Integer;
  const AConstraint: TTuiLayoutConstraint);
begin
  if (ARow >= 0) and (ARow < FRows) then
  begin
    FRowConstraints[ARow] := AConstraint;
    Invalidate;
  end;
end;

procedure TTuiGrid.SetColConstraint(ACol: Integer;
  const AConstraint: TTuiLayoutConstraint);
begin
  if (ACol >= 0) and (ACol < FCols) then
  begin
    FColConstraints[ACol] := AConstraint;
    Invalidate;
  end;
end;

procedure TTuiGrid.Place(AChild: TTuiWidget;
  const APlacement: TTuiGridPlacement);
begin
  FPlacements.AddOrSetValue(AChild, APlacement);
  Invalidate;
end;

function TTuiGrid.ComputeAutoPlacement(AChildIndex: Integer): TTuiGridPlacement;
begin
  // row-major: fill cells left-to-right, then next row
  Result := TTuiGridPlacement.Make(
    AChildIndex div FCols,
    AChildIndex mod FCols);
end;

procedure TTuiGrid.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if (FRows = 0) or (FCols = 0) then
    Exit;

  // Resolves row and column sizes
  var LRowSizes := TTuiLayoutSolver.Solve(ARect.Height, FRowConstraints);
  var LColSizes := TTuiLayoutSolver.Solve(ARect.Width,  FColConstraints);

  // Precomputes cumulative origins (top for rows, left for columns)
  var LRowTops: TArray<Integer>;
  var LColLefts: TArray<Integer>;
  SetLength(LRowTops,  FRows);
  SetLength(LColLefts, FCols);

  var LAccum := ARect.Top;
  for var LIndex := 0 to FRows - 1 do
  begin
    LRowTops[LIndex] := LAccum;
    Inc(LAccum, LRowSizes[LIndex]);
  end;
  LAccum := ARect.Left;
  for var LIndex := 0 to FCols - 1 do
  begin
    LColLefts[LIndex] := LAccum;
    Inc(LAccum, LColSizes[LIndex]);
  end;

  // Renders each child
  for var LIndex := 0 to ChildCount - 1 do
  begin
    var LWidget := Children[LIndex];

    var LRow, LCol: Integer;
    var LR2, LC2: Integer;

    var LPlacement: TTuiGridPlacement;
    if FPlacements.TryGetValue(LWidget, LPlacement) then
    begin
      LRow := LPlacement.Row;
      LCol := LPlacement.Col;
      LR2 := LRow + LPlacement.RowSpan - 1;
      LC2 := LCol + LPlacement.ColSpan - 1;
    end
    else
    begin
      LPlacement := ComputeAutoPlacement(LIndex);
      LRow := LPlacement.Row;
      LCol := LPlacement.Col;
      LR2 := LRow;
      LC2 := LCol;
    end;

    // Checks that the cell is within grid bounds
    if (LRow < 0) or (LRow >= FRows) or (LCol < 0) or (LCol >= FCols) then
      Continue;
    if LR2 >= FRows then
      LR2 := FRows - 1;
    if LC2 >= FCols then
      LC2 := FCols - 1;

    // Computes the overall TRect of the cell (possibly spanning multiple rows/cols)
    var LCellRect := TRect.Create(
      LColLefts[LCol],
      LRowTops[LRow],
      LColLefts[LC2] + LColSizes[LC2],
      LRowTops[LR2] + LRowSizes[LR2]
    );

    if not LCellRect.IsEmpty then
      LWidget.Render(ACanvas, LCellRect);
  end;
end;

end.
