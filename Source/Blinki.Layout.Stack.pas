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
{   Unit:        Blinki.Layout.Stack.pas                         }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Stack layout container for the Blinki library.
///   TTuiStack distributes TRect areas to children along an axis (horizontal or vertical)
///   using TTuiLayoutSolver and the TTuiLayoutConstraint of each child.
///   TTuiHStack and TTuiVStack are the two concrete specialisations.
/// </summary>
unit Blinki.Layout.Stack;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Widget;

type

{ TTuiStackOrientation }

  /// <summary>
  ///   Orientation of TTuiStack: horizontal (X axis) or vertical (Y axis).
  /// </summary>
  TTuiStackOrientation = (soHorizontal, soVertical);

{ TTuiStack }

  /// <summary>
  ///   Container that distributes children along an axis using their LayoutConstraint.
  ///   Not focusable: does not handle keyboard events directly.
  ///   Children are rendered in the order they were added.
  ///   On terminal resize, DoRender automatically recalculates all TRect areas.
  /// </summary>
  TTuiStack = class abstract(TTuiWidget)
  strict private
    FOrientation: TTuiStackOrientation;
  protected
    /// <summary>
    ///   Resolves children constraints and delegates Render to each one
    ///   with the computed TRect.
    ///   Main axis: Width for soHorizontal, Height for soVertical.
    ///   Cross axis: occupies the full extent of ARect.
    /// </summary>
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create(AOrientation: TTuiStackOrientation;
      AParent: TTuiWidget = nil);
    /// <summary>
    ///   Distribution axis for the children.
    /// </summary>
    property Orientation: TTuiStackOrientation read FOrientation;
  end;

{ TTuiHStack }

  /// <summary>
  ///   Horizontal stack: children are laid out side by side from left to right.
  /// </summary>
  TTuiHStack = class(TTuiStack)
  public
    constructor Create(AParent: TTuiWidget = nil);
  end;

{ TTuiVStack }

  /// <summary>
  ///   Vertical stack: children are stacked from top to bottom.
  /// </summary>
  TTuiVStack = class(TTuiStack)
  public
    constructor Create(AParent: TTuiWidget = nil);
  end;

implementation

uses
  System.Generics.Collections,
  Blinki.Core.Geometry,
  Blinki.Layout.Solver;

{ TTuiStack }

constructor TTuiStack.Create(AOrientation: TTuiStackOrientation;
  AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FOrientation := AOrientation;
end;

procedure TTuiStack.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ChildCount = 0 then
    Exit;

  // Collects constraints from children
  var LConstraints: TArray<TTuiLayoutConstraint>;
  SetLength(LConstraints, ChildCount);
  for var LIndex := 0 to ChildCount - 1 do
    LConstraints[LIndex] := Children[LIndex].LayoutConstraint;

  // Resolves constraints along the main axis
  var LTotal: Integer;
  if FOrientation = soHorizontal then
    LTotal := ARect.Width
  else
    LTotal := ARect.Height;

  var LSizes := TTuiLayoutSolver.Solve(LTotal, LConstraints);

  // Delegates rendering to each child with the computed TRect
  var LOffset := 0;
  var LChildRect: TRect;
  for var LIndex := 0 to ChildCount - 1 do
  begin
    if FOrientation = soHorizontal then
      LChildRect := TRect.Create(
        ARect.Left + LOffset,
        ARect.Top,
        ARect.Left + LOffset + LSizes[LIndex],
        ARect.Bottom)
    else
      LChildRect := TRect.Create(
        ARect.Left,
        ARect.Top + LOffset,
        ARect.Right,
        ARect.Top + LOffset + LSizes[LIndex]);

    if not LChildRect.IsEmpty then
      Children[LIndex].Render(ACanvas, LChildRect);

    Inc(LOffset, LSizes[LIndex]);
  end;
end;

{ TTuiHStack }

constructor TTuiHStack.Create(AParent: TTuiWidget);
begin
  inherited Create(soHorizontal, AParent);
end;

{ TTuiVStack }

constructor TTuiVStack.Create(AParent: TTuiWidget);
begin
  inherited Create(soVertical, AParent);
end;

end.
