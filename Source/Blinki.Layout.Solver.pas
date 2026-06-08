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
{   Unit:        Blinki.Layout.Solver.pas                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Constraint-based solver for the Blinki layout engine.
///   TTuiLayoutSolver.Solve distributes ATotalCells across an array of
///   TTuiLayoutConstraint using three passes: Fixed/Percentage, Fill/Min/Max,
///   and remainder assignment (off-by-one prevention).
/// </summary>
unit Blinki.Layout.Solver;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Blinki.Core.Geometry;

type

{ TTuiLayoutSolver }

  /// <summary>
  ///   Static solver that converts an array of TTuiLayoutConstraint into
  ///   integer sizes. Stateless: call Solve once per frame.
  /// </summary>
  TTuiLayoutSolver = class sealed
  public
    /// <summary>
    ///   Resolves AConstraints by distributing ATotal cells among children.
    ///   Returns a TArray{Integer} of the same length as AConstraints.
    ///   Guarantees that the sum of results equals exactly ATotal when at
    ///   least one Fill/Min/Max element is present to absorb the remainder.
    ///   If the sum of Fixed+Percentage exceeds ATotal, the excess cells are
    ///   trimmed from the last element.
    /// </summary>
    class function Solve(ATotal: Integer;
      const AConstraints: TArray<TTuiLayoutConstraint>): TArray<Integer>; static;
  end;

implementation

uses
  System.Math;

{ TTuiLayoutSolver }

class function TTuiLayoutSolver.Solve(ATotal: Integer;
  const AConstraints: TArray<TTuiLayoutConstraint>): TArray<Integer>;
begin
  var LCount := Length(AConstraints);
  if LCount = 0 then
  begin
    Result := nil;
    Exit;
  end;

  var LResult: TArray<Integer>;
  SetLength(LResult, LCount);
  var LFixedUsed := 0;
  var LLastFlex  := -1;

  // ---- Pass 1: Fixed + Percentage ----
  for var LIndex := 0 to LCount - 1 do
  begin
    var LC := AConstraints[LIndex];
    case LC.Kind of
      lckFixed:
        begin
          LResult[LIndex] := LC.Value;
          Inc(LFixedUsed, LC.Value);
        end;
      lckPercentage:
        begin
          LResult[LIndex] := Max(0, Round(ATotal * LC.Value / 100));
          Inc(LFixedUsed, LResult[LIndex]);
        end;
    end;
  end;

  // ---- Pass 2: remaining space distribution to Fill/Min/Max ----
  var LRemaining := Max(0, ATotal - LFixedUsed);

  // computes total weight of flex elements
  var LTotWeight := 0;
  for var LIndex := 0 to LCount - 1 do
  begin
    var LC := AConstraints[LIndex];
    case LC.Kind of
      lckFill:
        Inc(LTotWeight, LC.Value);
      lckMin, lckMax:
        Inc(LTotWeight, 1);
    end;
  end;

  var LShare: Integer;
  if LTotWeight > 0 then
  begin
    for var LIndex := 0 to LCount - 1 do
    begin
      var LC := AConstraints[LIndex];
      case LC.Kind of
        lckFill:
          begin
            LShare := (LRemaining * LC.Value) div LTotWeight;
            LResult[LIndex] := LShare;
            LLastFlex := LIndex;
          end;
        lckMin:
          begin
            LShare := (LRemaining * 1) div LTotWeight;
            LResult[LIndex] := Max(LC.Value, LShare);
            LLastFlex := LIndex;
          end;
        lckMax:
          begin
            LShare := (LRemaining * 1) div LTotWeight;
            LResult[LIndex] := Min(LC.Value, LShare);
            LLastFlex := LIndex;
          end;
      end;
    end;

    // ---- Pass 3: remainder to the last flex (off-by-one prevention) ----
    if LLastFlex >= 0 then
    begin
      LShare := 0;
      for var LIndex := 0 to LCount - 1 do
        Inc(LShare, LResult[LIndex]);
      if LShare < ATotal then
        Inc(LResult[LLastFlex], ATotal - LShare)
      else if LShare > ATotal then
        // trims excess from the last flex (Min case with high bound)
        Dec(LResult[LLastFlex], LShare - ATotal);
    end;
  end
  else
  begin
    // No flex elements: Fixed+Percentage only. If they exceed ATotal, trims the last.
    if LFixedUsed > ATotal then
    begin
      var LIndex := LCount - 1;
      LResult[LIndex] := Max(0, LResult[LIndex] - (LFixedUsed - ATotal));
    end;
  end;

  // Final clamp: no element below 0
  for var LIndex := 0 to LCount - 1 do
    if LResult[LIndex] < 0 then
      LResult[LIndex] := 0;

  Result := LResult;
end;

end.
