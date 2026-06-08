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
{   Unit:        Blinki.Core.Geometry.pas                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Geometric and layout types for the Blinki library.
///   Provides TTuiLayoutConstraint for specifying widget sizing constraints,
///   and re-exports the Delphi RTL geometric types (TPoint, TSize, TRect).
/// </summary>
unit Blinki.Core.Geometry;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Types;

type

{ TTuiLayoutConstraintKind }

  /// <summary>
  ///   Specifies the type of layout constraint to apply to a child widget.
  /// </summary>
  TTuiLayoutConstraintKind = (
    /// <summary>
    ///   Fixed size in columns or rows.
    /// </summary>
    lckFixed,
    /// <summary>
    ///   Minimum size; the widget may be larger but not smaller.
    /// </summary>
    lckMin,
    /// <summary>
    ///   Maximum size; the widget may be smaller but not larger.
    /// </summary>
    lckMax,
    /// <summary>
    ///   Fills the remaining available space. Value is the relative weight (default 1).
    /// </summary>
    lckFill,
    /// <summary>
    ///   Percentage of the available space (0-100).
    /// </summary>
    lckPercentage
  );

{ TTuiLayoutConstraint }

  /// <summary>
  ///   Specifies how a child widget should be sized within a container.
  ///   Used by THStack, TVStack, TGrid, and TScrollable to compute the TRect of each child.
  /// </summary>
  /// <remarks>
  ///   Use the static constructors (Fixed, Min, Max, Fill, Percentage) instead of
  ///   accessing fields directly, to ensure consistency between Kind and Value.
  /// </remarks>
  TTuiLayoutConstraint = record
  strict private
    FKind: TTuiLayoutConstraintKind;
    FValue: Integer;
  public
    /// <summary>
    ///   The constraint kind.
    /// </summary>
    property Kind: TTuiLayoutConstraintKind read FKind;

    /// <summary>
    ///   The constraint value. Its meaning depends on Kind:
    ///   Fixed/Min/Max = columns or rows; Fill = relative weight (default 1);
    ///   Percentage = value from 0 to 100.
    /// </summary>
    property Value: Integer read FValue;

    /// <summary>
    ///   Creates a fixed-size constraint.
    /// </summary>
    class function Fixed(AColumns: Integer): TTuiLayoutConstraint; static;

    /// <summary>
    ///   Creates a minimum-size constraint.
    /// </summary>
    class function Min(AColumns: Integer): TTuiLayoutConstraint; static;

    /// <summary>
    ///   Creates a maximum-size constraint.
    /// </summary>
    class function Max(AColumns: Integer): TTuiLayoutConstraint; static;

    /// <summary>
    ///   Creates a Fill constraint with unit weight (1).
    ///   Multiple Fill widgets share the remaining space according to their relative weight.
    /// </summary>
    class function Fill: TTuiLayoutConstraint; overload; static;

    /// <summary>
    ///   Creates a Fill constraint with the specified weight.
    ///   A widget with weight 2 receives twice the space of a widget with weight 1.
    /// </summary>
    class function Fill(AWeight: Integer): TTuiLayoutConstraint; overload; static;

    /// <summary>
    ///   Creates a percentage constraint (0-100) relative to the available space.
    /// </summary>
    class function Percentage(APercent: Integer): TTuiLayoutConstraint; static;
  end;

{ TTuiLayoutConstraintArray }

  /// <summary>
  ///   Array of layout constraints for defining the columns or rows of a container.
  /// </summary>
  TTuiLayoutConstraintArray = TArray<TTuiLayoutConstraint>;

{ TTuiRectHelper }

  /// <summary>
  ///   Record helper for TRect providing convenience operations for TUI widget layout.
  /// </summary>
  TTuiRectHelper = record helper for TRect
    /// <summary>
    ///   Shrinks the rectangle by ABy cells on each side.
    /// </summary>
    function Shrink(ABy: Integer): TRect;
    /// <summary>
    ///   Returns the rectangle inset by 1 cell on each side (equivalent to Shrink(1)).
    /// </summary>
    function Interior: TRect;
  end;

implementation

{ TTuiLayoutConstraint }

class function TTuiLayoutConstraint.Fixed(AColumns: Integer): TTuiLayoutConstraint;
begin
  Result.FKind := lckFixed;
  Result.FValue := AColumns;
end;

class function TTuiLayoutConstraint.Min(AColumns: Integer): TTuiLayoutConstraint;
begin
  Result.FKind := lckMin;
  Result.FValue := AColumns;
end;

class function TTuiLayoutConstraint.Max(AColumns: Integer): TTuiLayoutConstraint;
begin
  Result.FKind := lckMax;
  Result.FValue := AColumns;
end;

class function TTuiLayoutConstraint.Fill: TTuiLayoutConstraint;
begin
  Result.FKind := lckFill;
  Result.FValue := 1;
end;

class function TTuiLayoutConstraint.Fill(AWeight: Integer): TTuiLayoutConstraint;
begin
  Result.FKind := lckFill;
  Result.FValue := AWeight;
end;

class function TTuiLayoutConstraint.Percentage(APercent: Integer): TTuiLayoutConstraint;
begin
  Result.FKind := lckPercentage;
  Result.FValue := APercent;
end;

{ TTuiRectHelper }

function TTuiRectHelper.Shrink(ABy: Integer): TRect;
begin
  Result := TRect.Create(
    Left + ABy,
    Top + ABy,
    Right - ABy,
    Bottom - ABy
  );
end;

function TTuiRectHelper.Interior: TRect;
begin
  Result := Shrink(1);
end;

end.
