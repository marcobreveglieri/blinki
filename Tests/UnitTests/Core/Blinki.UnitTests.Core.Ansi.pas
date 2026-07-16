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
{   Unit:        Blinki.UnitTests.Core.Ansi.pas                  }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   DUnitX test fixture for the grapheme-aware string metrics of
///   Blinki.Core.Ansi: VisibleLength, TruncateToWidth and WrapText with
///   emoji, CJK and ANSI escape sequences.
/// </summary>
unit Blinki.UnitTests.Core.Ansi;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  DUnitX.TestFramework;

type

{ TAnsiMetricsTests }

  /// <summary>
  ///   Verifies the column-based string metrics of TTuiAnsi.
  /// </summary>
  [TestFixture]
  TAnsiMetricsTests = class
  public
    [Setup]
    procedure Setup;

    /// <summary>
    ///   Plain ASCII measures one column per character.
    /// </summary>
    [Test]
    procedure VisibleLength_Ascii;
    /// <summary>
    ///   Emoji and CJK measure two columns; escapes measure zero.
    /// </summary>
    [Test]
    procedure VisibleLength_EmojiCjkAndEscapes;
    /// <summary>
    ///   A ZWJ family measures as one 2-column glyph.
    /// </summary>
    [Test]
    procedure VisibleLength_ZwjFamily;
    /// <summary>
    ///   TruncateToWidth never splits a surrogate pair.
    /// </summary>
    [Test]
    procedure TruncateToWidth_NeverSplitsSurrogates;
    /// <summary>
    ///   TruncateToWidth never strands a VS16 or half a cluster.
    /// </summary>
    [Test]
    procedure TruncateToWidth_NeverSplitsClusters;
    /// <summary>
    ///   WrapText wraps by columns, not by UTF-16 units (CJK fix).
    /// </summary>
    [Test]
    procedure WrapText_MeasuresColumns;
  end;

implementation

uses
  Blinki.Core.Ansi,
  Blinki.Core.Unicode;

const
  Esc = #27;
  // 😀 grinning face (2 units)
  Grinning = #$D83D#$DE00;
  // ☂️ umbrella with VS16 (2 units)
  UmbrellaVs16 = #$2602#$FE0F;
  // 👨‍👩‍👧 family ZWJ sequence (8 units)
  Family = #$D83D#$DC68#$200D#$D83D#$DC69#$200D#$D83D#$DC67;

{ TAnsiMetricsTests }

procedure TAnsiMetricsTests.Setup;
begin
  TTuiUnicode.EmojiLevel := elFull;
end;

procedure TAnsiMetricsTests.VisibleLength_Ascii;
begin
  Assert.AreEqual(5, TTuiAnsi.VisibleLength('Hello'));
  Assert.AreEqual(0, TTuiAnsi.VisibleLength(''));
end;

procedure TAnsiMetricsTests.VisibleLength_EmojiCjkAndEscapes;
begin
  Assert.AreEqual(4, TTuiAnsi.VisibleLength('Hi' + Grinning));
  Assert.AreEqual(4, TTuiAnsi.VisibleLength(#$4F60#$597D), 'CJK "ni hao"');
  Assert.AreEqual(2, TTuiAnsi.VisibleLength(UmbrellaVs16), 'VS16 promotes to wide');
  Assert.AreEqual(2, TTuiAnsi.VisibleLength(Esc + '[31m' + Grinning + Esc + '[0m'),
    'CSI sequences contribute no columns');
end;

procedure TAnsiMetricsTests.VisibleLength_ZwjFamily;
begin
  Assert.AreEqual(2, TTuiAnsi.VisibleLength(Family));
  TTuiUnicode.EmojiLevel := elBasic;
  Assert.AreEqual(6, TTuiAnsi.VisibleLength(Family),
    'elBasic measures the sum of the parts');
  TTuiUnicode.EmojiLevel := elFull;
end;

procedure TAnsiMetricsTests.TruncateToWidth_NeverSplitsSurrogates;
begin
  Assert.AreEqual(Grinning, TTuiAnsi.TruncateToWidth(Grinning + Grinning, 3),
    'The second emoji does not fit in the remaining single column');
  Assert.AreEqual(Grinning, TTuiAnsi.TruncateToWidth(Grinning + Grinning, 2));
  Assert.AreEqual('', TTuiAnsi.TruncateToWidth(Grinning, 1),
    'A 2-column glyph cannot fit one column');
  Assert.AreEqual('', TTuiAnsi.TruncateToWidth('abc', 0));
end;

procedure TAnsiMetricsTests.TruncateToWidth_NeverSplitsClusters;
begin
  Assert.AreEqual('a' + UmbrellaVs16, TTuiAnsi.TruncateToWidth('a' + UmbrellaVs16 + 'x', 3),
    'The VS16 travels with its base');
  Assert.AreEqual('a', TTuiAnsi.TruncateToWidth('a' + Family, 2),
    'The whole family cluster is dropped when it does not fit');
  Assert.AreEqual('a' + Family, TTuiAnsi.TruncateToWidth('a' + Family + 'b', 3),
    'The family cluster travels whole');
end;

procedure TAnsiMetricsTests.WrapText_MeasuresColumns;
begin
  // Two CJK words of 4 columns each (2 units each): with the old unit-based
  // measure they fitted a width of 5 on one line; column-based they must wrap.
  var LLines := TTuiAnsi.WrapText(#$4F60#$597D' '#$4E16#$754C, 5);
  Assert.AreEqual(2, Length(LLines), 'CJK words must wrap by columns');

  LLines := TTuiAnsi.WrapText('go ' + Grinning + Grinning, 5);
  Assert.AreEqual(2, Length(LLines), '"go" (2) + space + emoji word (4) > 5');
  Assert.AreEqual('go', LLines[0]);
  Assert.AreEqual(Grinning + Grinning, LLines[1]);
end;

end.
