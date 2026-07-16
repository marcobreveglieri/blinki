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
{   Unit:        Blinki.UnitTests.Core.Unicode.pas               }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   DUnitX test fixture for the Blinki.Core.Unicode unit: code point
///   iteration over UTF-16 strings, emoji-aware grapheme segmentation,
///   and terminal column width rules under both emoji levels.
/// </summary>
unit Blinki.UnitTests.Core.Unicode;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  DUnitX.TestFramework;

type

{ TUnicodeTests }

  /// <summary>
  ///   Verifies TTuiUnicode: iteration, segmentation and widths.
  /// </summary>
  [TestFixture]
  TUnicodeTests = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   NextCodePoint reads a BMP character and advances by one unit.
    /// </summary>
    [Test]
    procedure NextCodePoint_Bmp_AdvancesByOne;
    /// <summary>
    ///   NextCodePoint combines a surrogate pair and advances by two units.
    /// </summary>
    [Test]
    procedure NextCodePoint_SurrogatePair_CombinesAndAdvancesByTwo;
    /// <summary>
    ///   An unpaired surrogate is returned as-is and never derails iteration.
    /// </summary>
    [Test]
    procedure NextCodePoint_LoneSurrogate_ReturnedAsIs;
    /// <summary>
    ///   CodePointToString round-trips BMP and supplementary code points.
    /// </summary>
    [Test]
    procedure CodePointToString_RoundTrips;

    /// <summary>
    ///   A plain ASCII character forms a cluster of one code unit.
    /// </summary>
    [Test]
    procedure Grapheme_Ascii_LengthOne;
    /// <summary>
    ///   An astral emoji forms a cluster of two code units.
    /// </summary>
    [Test]
    procedure Grapheme_AstralEmoji_LengthTwo;
    /// <summary>
    ///   A ZWJ family sequence forms a single cluster (GB11).
    /// </summary>
    [Test]
    procedure Grapheme_ZwjFamily_SingleCluster;
    /// <summary>
    ///   An emoji with skin tone modifier forms a single cluster.
    /// </summary>
    [Test]
    procedure Grapheme_SkinTone_SingleCluster;
    /// <summary>
    ///   Two flags split into two clusters of two RI pairs (GB12/13).
    /// </summary>
    [Test]
    procedure Grapheme_TwoFlags_TwoClusters;
    /// <summary>
    ///   A VS16 sequence and a keycap sequence stay in one cluster.
    /// </summary>
    [Test]
    procedure Grapheme_Vs16AndKeycap_SingleCluster;
    /// <summary>
    ///   A combining accent stays attached to its base (GB9).
    /// </summary>
    [Test]
    procedure Grapheme_CombiningMark_SingleCluster;
    /// <summary>
    ///   CRLF is one cluster (GB3); other controls break (GB4).
    /// </summary>
    [Test]
    procedure Grapheme_CrLf_SingleCluster;
    /// <summary>
    ///   Next/PrevGraphemeBoundary round-trip across a mixed string.
    /// </summary>
    [Test]
    procedure GraphemeBoundaries_RoundTrip;

    /// <summary>
    ///   CodePointWidth: ASCII 1, CJK 2, emoji 2, ZWJ/VS 0, skin tone 2.
    /// </summary>
    [Test]
    procedure CodePointWidth_Basics;
    /// <summary>
    ///   With elFull, families, flags and VS16 sequences measure 2 columns.
    /// </summary>
    [Test]
    procedure ClusterWidth_Full_SequencesMeasureTwo;
    /// <summary>
    ///   With elBasic, a cluster measures the sum of its visible parts.
    /// </summary>
    [Test]
    procedure ClusterWidth_Basic_SumOfParts;
    /// <summary>
    ///   VS15 demotes an emoji-capable base to text presentation width.
    /// </summary>
    [Test]
    procedure ClusterWidth_Vs15_TextPresentation;
    /// <summary>
    ///   StringWidth sums the widths of the clusters in the string.
    /// </summary>
    [Test]
    procedure StringWidth_MixedContent;
  end;

implementation

uses
  Blinki.Core.Unicode;

const
  // 👨‍👩‍👧 man + ZWJ + woman + ZWJ + girl (8 UTF-16 units)
  Family = #$D83D#$DC68#$200D#$D83D#$DC69#$200D#$D83D#$DC67;
  // 👍🏽 thumbs up + medium skin tone (4 units)
  ThumbsTone = #$D83D#$DC4D#$D83C#$DFFD;
  // 🇮🇹 Italy flag (4 units)
  FlagIt = #$D83C#$DDEE#$D83C#$DDF9;
  // 🇩🇪 Germany flag (4 units)
  FlagDe = #$D83C#$DDE9#$D83C#$DDEA;
  // ☀️ sun with VS16 (2 units)
  SunVs16 = #$2600#$FE0F;
  // 1️⃣ keycap one: digit + VS16 + combining enclosing keycap (3 units)
  KeycapOne = '1'#$FE0F#$20E3;
  // 😀 grinning face (2 units)
  Grinning = #$D83D#$DE00;

{ TUnicodeTests }

procedure TUnicodeTests.Setup;
begin
  TTuiUnicode.EmojiLevel := elFull;
end;

procedure TUnicodeTests.TearDown;
begin
  TTuiUnicode.EmojiLevel := elFull;
end;

procedure TUnicodeTests.NextCodePoint_Bmp_AdvancesByOne;
begin
  var LIndex := 1;
  var LCp := TTuiUnicode.NextCodePoint('abc', LIndex);
  Assert.AreEqual(Integer(Ord('a')), Integer(LCp), 'Code point should be "a"');
  Assert.AreEqual(2, LIndex, 'Index should advance by one unit');
end;

procedure TUnicodeTests.NextCodePoint_SurrogatePair_CombinesAndAdvancesByTwo;
begin
  var LIndex := 2;
  var LCp := TTuiUnicode.NextCodePoint('a' + Grinning + 'b', LIndex);
  Assert.AreEqual(Integer($1F600), Integer(LCp), 'Pair should combine to U+1F600');
  Assert.AreEqual(4, LIndex, 'Index should advance by two units');
end;

procedure TUnicodeTests.NextCodePoint_LoneSurrogate_ReturnedAsIs;
begin
  var LIndex := 1;
  var LCp := TTuiUnicode.NextCodePoint(#$D83D'x', LIndex);
  Assert.AreEqual(Integer($D83D), Integer(LCp), 'Lone high surrogate returned as-is');
  Assert.AreEqual(2, LIndex, 'Index should advance by one unit');
end;

procedure TUnicodeTests.CodePointToString_RoundTrips;
begin
  Assert.AreEqual('A', TTuiUnicode.CodePointToString($41));
  Assert.AreEqual(Grinning, TTuiUnicode.CodePointToString($1F600));
  var LIndex := 1;
  var LCp := TTuiUnicode.NextCodePoint(TTuiUnicode.CodePointToString($1FAF8), LIndex);
  Assert.AreEqual(Integer($1FAF8), Integer(LCp), 'Encode/decode should round-trip');
end;

procedure TUnicodeTests.Grapheme_Ascii_LengthOne;
begin
  Assert.AreEqual(1, TTuiUnicode.GraphemeLengthAt('abc', 2));
  Assert.AreEqual(0, TTuiUnicode.GraphemeLengthAt('abc', 4), 'Out of range gives 0');
end;

procedure TUnicodeTests.Grapheme_AstralEmoji_LengthTwo;
begin
  Assert.AreEqual(2, TTuiUnicode.GraphemeLengthAt('a' + Grinning, 2));
end;

procedure TUnicodeTests.Grapheme_ZwjFamily_SingleCluster;
begin
  Assert.AreEqual(8, TTuiUnicode.GraphemeLengthAt(Family, 1),
    'The whole ZWJ sequence should be one cluster');
end;

procedure TUnicodeTests.Grapheme_SkinTone_SingleCluster;
begin
  Assert.AreEqual(4, TTuiUnicode.GraphemeLengthAt(ThumbsTone, 1),
    'Base + skin tone modifier should be one cluster');
end;

procedure TUnicodeTests.Grapheme_TwoFlags_TwoClusters;
begin
  var LText := FlagIt + FlagDe;
  Assert.AreEqual(4, TTuiUnicode.GraphemeLengthAt(LText, 1),
    'A flag pairs exactly two regional indicators');
  Assert.AreEqual(4, TTuiUnicode.GraphemeLengthAt(LText, 5),
    'The second flag starts its own cluster');
end;

procedure TUnicodeTests.Grapheme_Vs16AndKeycap_SingleCluster;
begin
  Assert.AreEqual(2, TTuiUnicode.GraphemeLengthAt(SunVs16, 1));
  Assert.AreEqual(3, TTuiUnicode.GraphemeLengthAt(KeycapOne, 1));
end;

procedure TUnicodeTests.Grapheme_CombiningMark_SingleCluster;
begin
  Assert.AreEqual(2, TTuiUnicode.GraphemeLengthAt('e'#$0301'x', 1),
    'e + combining acute should be one cluster');
end;

procedure TUnicodeTests.Grapheme_CrLf_SingleCluster;
begin
  Assert.AreEqual(2, TTuiUnicode.GraphemeLengthAt(#13#10'a', 1), 'CR x LF (GB3)');
  Assert.AreEqual(1, TTuiUnicode.GraphemeLengthAt(#10#13, 1), 'LF alone breaks');
end;

procedure TUnicodeTests.GraphemeBoundaries_RoundTrip;
begin
  var LText := 'a' + Family + FlagIt + 'z';
  // Expected cluster starts: 1 ('a'), 2 (family), 10 (flag), 14 ('z')
  Assert.AreEqual(2, TTuiUnicode.NextGraphemeBoundary(LText, 1));
  Assert.AreEqual(10, TTuiUnicode.NextGraphemeBoundary(LText, 2));
  Assert.AreEqual(14, TTuiUnicode.NextGraphemeBoundary(LText, 10));
  Assert.AreEqual(15, TTuiUnicode.NextGraphemeBoundary(LText, 14));
  Assert.AreEqual(14, TTuiUnicode.PrevGraphemeBoundary(LText, 15));
  Assert.AreEqual(10, TTuiUnicode.PrevGraphemeBoundary(LText, 14));
  Assert.AreEqual(2, TTuiUnicode.PrevGraphemeBoundary(LText, 10));
  Assert.AreEqual(1, TTuiUnicode.PrevGraphemeBoundary(LText, 2));
  Assert.AreEqual(2, TTuiUnicode.PrevGraphemeBoundary(LText, 5),
    'An index inside a cluster snaps to the cluster start');
end;

procedure TUnicodeTests.CodePointWidth_Basics;
begin
  Assert.AreEqual(1, TTuiUnicode.CodePointWidth(Ord('A')));
  Assert.AreEqual(2, TTuiUnicode.CodePointWidth($4E2D), 'CJK is wide');
  Assert.AreEqual(2, TTuiUnicode.CodePointWidth($1F600), 'Emoji presentation is wide');
  Assert.AreEqual(2, TTuiUnicode.CodePointWidth($2615), 'Hot beverage is wide');
  Assert.AreEqual(1, TTuiUnicode.CodePointWidth($2600), 'Text-default sun is narrow');
  Assert.AreEqual(0, TTuiUnicode.CodePointWidth($200D), 'ZWJ is zero width');
  Assert.AreEqual(0, TTuiUnicode.CodePointWidth($FE0F), 'VS16 is zero width');
  Assert.AreEqual(0, TTuiUnicode.CodePointWidth($0301), 'Combining mark is zero width');
  Assert.AreEqual(2, TTuiUnicode.CodePointWidth($1F3FD), 'Skin tone alone is wide');
end;

procedure TUnicodeTests.ClusterWidth_Full_SequencesMeasureTwo;
begin
  Assert.AreEqual(2, TTuiUnicode.ClusterWidthAt(Family, 1, Length(Family)),
    'ZWJ family should measure 2 with elFull');
  Assert.AreEqual(2, TTuiUnicode.ClusterWidthAt(FlagIt, 1, 4),
    'Flag should measure 2 with elFull');
  Assert.AreEqual(2, TTuiUnicode.ClusterWidthAt(SunVs16, 1, 2),
    'VS16 promotes the sun to 2 columns');
  Assert.AreEqual(2, TTuiUnicode.ClusterWidthAt(KeycapOne, 1, 3),
    'Keycap should measure 2');
  Assert.AreEqual(2, TTuiUnicode.ClusterWidthAt(ThumbsTone, 1, 4),
    'Skin tone sequence should measure 2');
  Assert.AreEqual(1, TTuiUnicode.ClusterWidthAt('e'#$0301, 1, 2),
    'Accented letter stays narrow');
end;

procedure TUnicodeTests.ClusterWidth_Basic_SumOfParts;
begin
  TTuiUnicode.EmojiLevel := elBasic;
  Assert.AreEqual(6, TTuiUnicode.ClusterWidthAt(Family, 1, Length(Family)),
    'Family = 3 visible emoji with elBasic');
  Assert.AreEqual(4, TTuiUnicode.ClusterWidthAt(FlagIt, 1, 4),
    'Flag = 2 visible regional indicators with elBasic');
  Assert.AreEqual(4, TTuiUnicode.ClusterWidthAt(ThumbsTone, 1, 4),
    'Thumbs + tone drawn separately with elBasic');
  Assert.AreEqual(1, TTuiUnicode.ClusterWidthAt(SunVs16, 1, 2),
    'Narrow sun stays narrow when VS16 is not honoured');
end;

procedure TUnicodeTests.ClusterWidth_Vs15_TextPresentation;
begin
  // ✉︎ envelope + VS15: forced text presentation, EAW width of the base
  Assert.AreEqual(1, TTuiUnicode.ClusterWidthAt(#$2709#$FE0E, 1, 2));
end;

procedure TUnicodeTests.StringWidth_MixedContent;
begin
  Assert.AreEqual(0, TTuiUnicode.StringWidth(''));
  Assert.AreEqual(4, TTuiUnicode.StringWidth('Hi' + Grinning));
  Assert.AreEqual(6, TTuiUnicode.StringWidth('a' + Family + FlagIt + 'z'),
    '1 (a) + 2 (family) + 2 (flag) + 1 (z) columns');
end;

end.
