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
{   Unit:        Blinki.Tests.Geometry.pas                       }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   DUnitX test fixture for the Blinki.Core.Geometry unit.
///   Exercises the TTuiLayoutConstraint static constructors and the
///   TTuiRectHelper record helper, both pure value types testable
///   without a real console backend.
/// </summary>
unit Blinki.UnitTests.Core.Geometry;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  DUnitX.TestFramework;

type

{ TGeometryTests }

  /// <summary>
  ///   Verifies the geometric value types of Blinki.Core.Geometry.
  /// </summary>
  [TestFixture]
  TGeometryTests = class
  public
    /// <summary>
    ///   Fixed builds an lckFixed constraint carrying the column count.
    /// </summary>
    [Test]
    procedure Constraint_Fixed_StoresKindAndValue;
    /// <summary>
    ///   Min builds an lckMin constraint carrying the column count.
    /// </summary>
    [Test]
    procedure Constraint_Min_StoresKindAndValue;
    /// <summary>
    ///   Max builds an lckMax constraint carrying the column count.
    /// </summary>
    [Test]
    procedure Constraint_Max_StoresKindAndValue;
    /// <summary>
    ///   The parameterless Fill defaults to unit weight (1).
    /// </summary>
    [Test]
    procedure Constraint_FillDefault_HasWeightOne;
    /// <summary>
    ///   The weighted Fill stores the supplied weight.
    /// </summary>
    [Test]
    procedure Constraint_FillWeight_StoresWeight;
    /// <summary>
    ///   Percentage builds an lckPercentage constraint carrying the percent.
    /// </summary>
    [Test]
    procedure Constraint_Percentage_StoresKindAndValue;
    /// <summary>
    ///   Shrink insets the rectangle by the given amount on every side.
    /// </summary>
    [Test]
    procedure Rect_Shrink_InsetsAllSides;
    /// <summary>
    ///   Interior is equivalent to Shrink(1).
    /// </summary>
    [Test]
    procedure Rect_Interior_EqualsShrinkByOne;
  end;

implementation

uses
  System.Types,
  Blinki.Core.Geometry;

{ TGeometryTests }

procedure TGeometryTests.Constraint_Fixed_StoresKindAndValue;
begin
  var LConstraint := TTuiLayoutConstraint.Fixed(10);
  Assert.AreEqual(Ord(lckFixed), Ord(LConstraint.Kind), 'Kind should be lckFixed');
  Assert.AreEqual(10, LConstraint.Value, 'Value should be the column count');
end;

procedure TGeometryTests.Constraint_Min_StoresKindAndValue;
begin
  var LConstraint := TTuiLayoutConstraint.Min(4);
  Assert.AreEqual(Ord(lckMin), Ord(LConstraint.Kind), 'Kind should be lckMin');
  Assert.AreEqual(4, LConstraint.Value, 'Value should be the column count');
end;

procedure TGeometryTests.Constraint_Max_StoresKindAndValue;
begin
  var LConstraint := TTuiLayoutConstraint.Max(80);
  Assert.AreEqual(Ord(lckMax), Ord(LConstraint.Kind), 'Kind should be lckMax');
  Assert.AreEqual(80, LConstraint.Value, 'Value should be the column count');
end;

procedure TGeometryTests.Constraint_FillDefault_HasWeightOne;
begin
  var LConstraint := TTuiLayoutConstraint.Fill;
  Assert.AreEqual(Ord(lckFill), Ord(LConstraint.Kind), 'Kind should be lckFill');
  Assert.AreEqual(1, LConstraint.Value, 'Default Fill weight should be 1');
end;

procedure TGeometryTests.Constraint_FillWeight_StoresWeight;
begin
  var LConstraint := TTuiLayoutConstraint.Fill(3);
  Assert.AreEqual(Ord(lckFill), Ord(LConstraint.Kind), 'Kind should be lckFill');
  Assert.AreEqual(3, LConstraint.Value, 'Fill weight should be preserved');
end;

procedure TGeometryTests.Constraint_Percentage_StoresKindAndValue;
begin
  var LConstraint := TTuiLayoutConstraint.Percentage(50);
  Assert.AreEqual(Ord(lckPercentage), Ord(LConstraint.Kind), 'Kind should be lckPercentage');
  Assert.AreEqual(50, LConstraint.Value, 'Value should be the percentage');
end;

procedure TGeometryTests.Rect_Shrink_InsetsAllSides;
begin
  var LRect := TRect.Create(2, 3, 12, 9);
  var LShrunk := LRect.Shrink(2);
  Assert.AreEqual(4, LShrunk.Left, 'Left should move inward by 2');
  Assert.AreEqual(5, LShrunk.Top, 'Top should move inward by 2');
  Assert.AreEqual(10, LShrunk.Right, 'Right should move inward by 2');
  Assert.AreEqual(7, LShrunk.Bottom, 'Bottom should move inward by 2');
end;

procedure TGeometryTests.Rect_Interior_EqualsShrinkByOne;
begin
  var LRect := TRect.Create(0, 0, 20, 10);
  var LInterior := LRect.Interior;
  var LExpected := LRect.Shrink(1);
  Assert.AreEqual(LExpected.Left, LInterior.Left, 'Left should match Shrink(1)');
  Assert.AreEqual(LExpected.Top, LInterior.Top, 'Top should match Shrink(1)');
  Assert.AreEqual(LExpected.Right, LInterior.Right, 'Right should match Shrink(1)');
  Assert.AreEqual(LExpected.Bottom, LInterior.Bottom, 'Bottom should match Shrink(1)');
end;

initialization
  TDUnitX.RegisterTestFixture(TGeometryTests);

end.
