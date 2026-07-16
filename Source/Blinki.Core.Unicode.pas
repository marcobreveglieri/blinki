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
{   Unit:        Blinki.Core.Unicode.pas                         }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Unicode foundation for the Blinki library: UTF-16 code point iteration,
///   emoji-oriented grapheme cluster segmentation, and terminal column width
///   rules. This is the lowest-level text unit; it depends only on the RTL.
/// </summary>
/// <remarks>
///   The grapheme segmenter implements the emoji-relevant subset of UAX #29
///   (Unicode Text Segmentation): rules GB3 (CR x LF), GB4/GB5 (controls),
///   GB9 (x Extend, x ZWJ), GB11 (extended pictographic ZWJ sequences) and
///   GB12/GB13 (regional indicator pairs, assuming the scan starts on a
///   cluster boundary). Hangul conjoining rules (GB6..GB8) and SpacingMark
///   (GB9a) are intentionally omitted: Hangul text is precomposed in practice
///   and neither rule affects emoji sequences.
///   Property tables are a hand-embedded subset of Unicode 16.0 data files
///   (emoji-data.txt, EastAsianWidth.txt, DerivedCoreProperties.txt); see the
///   comments in the implementation section for regeneration notes.
/// </remarks>
unit Blinki.Core.Unicode;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

type

{ TTuiCodePoint }

  /// <summary>
  ///   A full Unicode code point (UCS-4), 0 .. $10FFFF.
  /// </summary>
  TTuiCodePoint = Cardinal;

{ TTuiEmojiLevel }

  /// <summary>
  ///   Emoji rendering capability of the host terminal. Drives how cluster
  ///   widths are measured so that Blinki layout matches what the terminal
  ///   actually draws.
  /// </summary>
  TTuiEmojiLevel = (
    /// <summary>
    ///   The terminal has no useful emoji support. Widths are measured like
    ///   elBasic; applications may use this value to avoid emitting emoji.
    /// </summary>
    elNone,
    /// <summary>
    ///   The terminal renders individual emoji code points but does not merge
    ///   ZWJ sequences or regional indicator pairs (e.g. legacy conhost).
    ///   A cluster is measured as the sum of the widths of its parts.
    /// </summary>
    elBasic,
    /// <summary>
    ///   The terminal understands grapheme clusters (e.g. Windows Terminal,
    ///   WezTerm, iTerm2). ZWJ sequences and flags measure 2 columns.
    /// </summary>
    elFull
  );

{ TTuiUnicode }

  /// <summary>
  ///   Static Unicode services: code point iteration over UTF-16 strings,
  ///   surrogate handling, emoji-aware grapheme segmentation and terminal
  ///   column width computation.
  /// </summary>
  /// <remarks>
  ///   All string indexes are 1-based UTF-16 code unit indexes, consistent
  ///   with Delphi string indexing. Segmentation functions assume the given
  ///   index lies on a cluster boundary; use PrevGraphemeBoundary to snap an
  ///   arbitrary index back to one.
  /// </remarks>
  TTuiUnicode = record
  strict private
    class var FEmojiLevel: TTuiEmojiLevel;
    class var FEmojiLevelExplicit: Boolean;
    class procedure SetEmojiLevel(AValue: TTuiEmojiLevel); static;
  public
    {$REGION 'Code point iteration'}
    /// <summary>
    ///   Combines a UTF-16 surrogate pair into the code point it encodes.
    /// </summary>
    class function CombineSurrogates(AHigh, ALow: Char): TTuiCodePoint; static; inline;

    /// <summary>
    ///   Encodes a code point as a UTF-16 string of one or two code units.
    /// </summary>
    class function CodePointToString(ACodePoint: TTuiCodePoint): string; static;

    /// <summary>
    ///   True for a UTF-16 high (leading) surrogate ($D800..$DBFF).
    /// </summary>
    class function IsHighSurrogate(ACh: Char): Boolean; static; inline;

    /// <summary>
    ///   True for a UTF-16 low (trailing) surrogate ($DC00..$DFFF).
    /// </summary>
    class function IsLowSurrogate(ACh: Char): Boolean; static; inline;

    /// <summary>
    ///   Reads the code point starting at AIndex (1-based) and advances
    ///   AIndex past it: by 2 code units for a valid surrogate pair, by 1
    ///   otherwise. An unpaired surrogate is returned as its own value so
    ///   that malformed input degrades gracefully instead of raising.
    /// </summary>
    class function NextCodePoint(const AText: string; var AIndex: Integer): TTuiCodePoint; static;
    {$ENDREGION}
    {$REGION 'Code point properties'}
    /// <summary>
    ///   True for code points with the Emoji_Presentation property: emoji
    ///   that render in colorful emoji style (2 columns) by default, without
    ///   requiring a variation selector.
    /// </summary>
    class function IsEmojiPresentation(ACodePoint: TTuiCodePoint): Boolean; static;

    /// <summary>
    ///   True for grapheme-extending code points: combining marks, variation
    ///   selectors, emoji skin tone modifiers, the combining enclosing keycap
    ///   and emoji tag characters. These never start a new cluster (GB9).
    /// </summary>
    class function IsExtend(ACodePoint: TTuiCodePoint): Boolean; static;

    /// <summary>
    ///   True for code points with the Extended_Pictographic property, the
    ///   anchor property of emoji ZWJ sequences (GB11).
    /// </summary>
    class function IsExtendedPictographic(ACodePoint: TTuiCodePoint): Boolean; static;

    /// <summary>
    ///   True for the regional indicator symbols $1F1E6..$1F1FF, combined in
    ///   pairs to form national flags (GB12/GB13).
    /// </summary>
    class function IsRegionalIndicator(ACodePoint: TTuiCodePoint): Boolean; static; inline;

    /// <summary>
    ///   True for U+FE0E VARIATION SELECTOR-15, which requests monochrome
    ///   text presentation (1 column) for the preceding character.
    /// </summary>
    class function IsVariationSelector15(ACodePoint: TTuiCodePoint): Boolean; static; inline;

    /// <summary>
    ///   True for U+FE0F VARIATION SELECTOR-16, which requests colorful emoji
    ///   presentation (2 columns) for the preceding character.
    /// </summary>
    class function IsVariationSelector16(ACodePoint: TTuiCodePoint): Boolean; static; inline;

    /// <summary>
    ///   True for U+200D ZERO WIDTH JOINER, the glue of emoji sequences.
    /// </summary>
    class function IsZWJ(ACodePoint: TTuiCodePoint): Boolean; static; inline;
    {$ENDREGION}
    {$REGION 'Grapheme segmentation'}
    /// <summary>
    ///   Returns the length in UTF-16 code units of the grapheme cluster
    ///   starting at AIndex (1-based). Returns 0 when AIndex is out of range.
    ///   AIndex must lie on a cluster boundary.
    /// </summary>
    class function GraphemeLengthAt(const AText: string; AIndex: Integer): Integer; static;

    /// <summary>
    ///   Returns the index of the first code unit of the next grapheme
    ///   cluster after the one starting at AIndex. Returns Length(AText) + 1
    ///   when the cluster at AIndex is the last one.
    /// </summary>
    class function NextGraphemeBoundary(const AText: string; AIndex: Integer): Integer; static;

    /// <summary>
    ///   Returns the start index of the grapheme cluster that ends right
    ///   before AIndex, scanning from the beginning of the string. Passing an
    ///   index inside a cluster snaps to that cluster's start. Returns 1 when
    ///   AIndex is at or before the first cluster.
    /// </summary>
    class function PrevGraphemeBoundary(const AText: string; AIndex: Integer): Integer; static;

    /// <summary>
    ///   Returns the largest cluster boundary at or before AIndex (1-based):
    ///   AIndex itself when it already lies on a boundary, otherwise the
    ///   start of the cluster containing it. The result is always in
    ///   [1, Length(AText) + 1]. Used by editing widgets to keep the cursor
    ///   from landing inside an emoji sequence.
    /// </summary>
    class function SnapToClusterStart(const AText: string; AIndex: Integer): Integer; static;
    {$ENDREGION}
    {$REGION 'Column width'}
    /// <summary>
    ///   Intrinsic terminal width of a single code point: 0 for zero-width
    ///   characters (ZWJ, variation selectors, combining marks, BOM), 2 for
    ///   East Asian Wide/Fullwidth characters and default emoji-presentation
    ///   emoji, 1 otherwise.
    /// </summary>
    class function CodePointWidth(ACodePoint: TTuiCodePoint): Integer; static;

    /// <summary>
    ///   Terminal width in columns of the grapheme cluster of ALen code units
    ///   starting at AIndex. With EmojiLevel = elFull a ZWJ sequence or flag
    ///   measures as a single glyph; with elBasic/elNone it measures as the
    ///   sum of its visible parts, matching terminals that cannot merge
    ///   clusters. VS16 promotes a narrow base to 2 columns, VS15 demotes an
    ///   emoji base to text presentation.
    /// </summary>
    class function ClusterWidthAt(const AText: string; AIndex, ALen: Integer): Integer; static;

    /// <summary>
    ///   Total terminal width in columns of AText, measured cluster by
    ///   cluster. The text must not contain ANSI escape sequences; use
    ///   TTuiAnsi.VisibleLength for styled text.
    /// </summary>
    class function StringWidth(const AText: string): Integer; static;
    {$ENDREGION}
    {$REGION 'Terminal capability'}
    /// <summary>
    ///   Applies a backend-detected emoji level unless the application has
    ///   already chosen one explicitly through the EmojiLevel property.
    ///   Console backends call this from Open so an application preset is
    ///   never silently overwritten.
    /// </summary>
    class procedure ApplyDetectedEmojiLevel(ALevel: TTuiEmojiLevel); static;

    /// <summary>
    ///   Emoji capability of the host terminal, detected by the console
    ///   backend during initialization and overridable by the application
    ///   at any time (an explicit assignment always wins over detection).
    ///   Defaults to elFull until a backend downgrades it.
    /// </summary>
    class property EmojiLevel: TTuiEmojiLevel read FEmojiLevel write SetEmojiLevel;
    {$ENDREGION}
  end;

implementation

type

{ TTuiCodePointRange }

  // Inclusive code point interval used by the binary-searched property tables.
  TTuiCodePointRange = record
    Lo: TTuiCodePoint;
    Hi: TTuiCodePoint;
  end;

const
  // --- East Asian Wide / Fullwidth (EAW = W or F), Unicode 16.0 -------------
  // Source: EastAsianWidth.txt. Most emoji-presentation ranges that are also
  // EAW=W (e.g. $231A..$231B, $1F300..) live only in EmojiPresentationRanges
  // below and are picked up by CodePointWidth through IsEmojiPresentation.
  // The Enclosed Ideographic rows ($1F200..) are kept here as well because
  // only part of that EAW=W block carries Emoji_Presentation: the two tables
  // intentionally overlap there and CodePointWidth ORs them.
  WideRanges: array[0..24] of TTuiCodePointRange = (
    (Lo: $1100; Hi: $115F),    // Hangul Jamo
    (Lo: $2329; Hi: $232A),    // Angle brackets
    (Lo: $2E80; Hi: $303F),    // CJK Radicals, Kangxi, CJK Symbols
    (Lo: $3040; Hi: $33FF),    // Hiragana, Katakana, Bopomofo, Hangul Compat.
    (Lo: $3400; Hi: $4DBF),    // CJK Ext-A
    (Lo: $4E00; Hi: $9FFF),    // CJK Unified Ideographs
    (Lo: $A000; Hi: $A4CF),    // Yi
    (Lo: $A960; Hi: $A97F),    // Hangul Jamo Extended-A
    (Lo: $AC00; Hi: $D7FF),    // Hangul Syllables + Jamo Ext-B
    (Lo: $F900; Hi: $FAFF),    // CJK Compatibility Ideographs
    (Lo: $FE10; Hi: $FE1F),    // Vertical Forms
    (Lo: $FE30; Hi: $FE6F),    // CJK Compat. Forms + Small Form Variants
    (Lo: $FF01; Hi: $FF60),    // Fullwidth Forms (EAW = F)
    (Lo: $FFE0; Hi: $FFE6),    // Fullwidth Signs (EAW = F)
    (Lo: $16FE0; Hi: $16FE4),  // Tangut/Khitan iteration marks
    (Lo: $16FF0; Hi: $16FF1),  // Vietnamese alternate reading marks
    (Lo: $17000; Hi: $187F7),  // Tangut
    (Lo: $18800; Hi: $18CD5),  // Tangut Components, Khitan Small Script
    (Lo: $18D00; Hi: $18D08),  // Tangut Supplement
    (Lo: $1AFF0; Hi: $1AFFE),  // Kana Extended-B
    (Lo: $1B000; Hi: $1B2FB),  // Kana Supplement/Extended-A, Small Kana, Nushu
    (Lo: $1F200; Hi: $1F251),  // Enclosed Ideographic Supplement (squared kana/CJK)
    (Lo: $1F260; Hi: $1F265),  // Rounded symbols
    (Lo: $20000; Hi: $2FFFD),  // CJK Ext-B..F, Compatibility Supplement (plane 2)
    (Lo: $30000; Hi: $3FFFD)   // CJK Ext-G..H (plane 3)
  );

  // --- Emoji_Presentation = Yes, Unicode 16.0 --------------------------------
  // Source: emoji-data.txt. These render as 2-column color emoji by default.
  EmojiPresentationRanges: array[0..79] of TTuiCodePointRange = (
    (Lo: $231A; Hi: $231B),    // watch, hourglass
    (Lo: $23E9; Hi: $23EC),    // fast forward/rewind/up/down
    (Lo: $23F0; Hi: $23F0),    // alarm clock
    (Lo: $23F3; Hi: $23F3),    // hourglass flowing
    (Lo: $25FD; Hi: $25FE),    // small squares
    (Lo: $2614; Hi: $2615),    // umbrella with rain, hot beverage
    (Lo: $2648; Hi: $2653),    // zodiac
    (Lo: $267F; Hi: $267F),    // wheelchair
    (Lo: $2693; Hi: $2693),    // anchor
    (Lo: $26A1; Hi: $26A1),    // high voltage
    (Lo: $26AA; Hi: $26AB),    // circles
    (Lo: $26BD; Hi: $26BE),    // soccer, baseball
    (Lo: $26C4; Hi: $26C5),    // snowman, sun behind cloud
    (Lo: $26CE; Hi: $26CE),    // ophiuchus
    (Lo: $26D4; Hi: $26D4),    // no entry
    (Lo: $26EA; Hi: $26EA),    // church
    (Lo: $26F2; Hi: $26F3),    // fountain, golf
    (Lo: $26F5; Hi: $26F5),    // sailboat
    (Lo: $26FA; Hi: $26FA),    // tent
    (Lo: $26FD; Hi: $26FD),    // fuel pump
    (Lo: $2705; Hi: $2705),    // check mark button
    (Lo: $270A; Hi: $270B),    // fists
    (Lo: $2728; Hi: $2728),    // sparkles
    (Lo: $274C; Hi: $274C),    // cross mark
    (Lo: $274E; Hi: $274E),    // cross mark button
    (Lo: $2753; Hi: $2755),    // question/exclamation marks
    (Lo: $2757; Hi: $2757),    // red exclamation
    (Lo: $2795; Hi: $2797),    // plus, minus, divide
    (Lo: $27B0; Hi: $27B0),    // curly loop
    (Lo: $27BF; Hi: $27BF),    // double curly loop
    (Lo: $2B1B; Hi: $2B1C),    // large squares
    (Lo: $2B50; Hi: $2B50),    // star
    (Lo: $2B55; Hi: $2B55),    // hollow red circle
    (Lo: $1F004; Hi: $1F004),  // mahjong red dragon
    (Lo: $1F0CF; Hi: $1F0CF),  // joker
    (Lo: $1F18E; Hi: $1F18E),  // AB button
    (Lo: $1F191; Hi: $1F19A),  // squared CL..VS
    (Lo: $1F1E6; Hi: $1F1FF),  // regional indicators
    (Lo: $1F201; Hi: $1F201),  // squared katakana koko
    (Lo: $1F21A; Hi: $1F21A),  // squared CJK "free of charge"
    (Lo: $1F22F; Hi: $1F22F),  // squared CJK "reserved"
    (Lo: $1F232; Hi: $1F236),  // squared CJK ideographs
    (Lo: $1F238; Hi: $1F23A),  // squared CJK ideographs
    (Lo: $1F250; Hi: $1F251),  // circled ideographs
    (Lo: $1F300; Hi: $1F320),  // weather, landscapes
    (Lo: $1F32D; Hi: $1F335),  // food, cactus
    (Lo: $1F337; Hi: $1F37C),  // plants, food, drink
    (Lo: $1F37E; Hi: $1F393),  // celebration, education
    (Lo: $1F3A0; Hi: $1F3CA),  // activities, sports
    (Lo: $1F3CF; Hi: $1F3D3),  // sports equipment
    (Lo: $1F3E0; Hi: $1F3F0),  // buildings
    (Lo: $1F3F4; Hi: $1F3F4),  // black flag
    (Lo: $1F3F8; Hi: $1F43E),  // badminton, animals
    (Lo: $1F440; Hi: $1F440),  // eyes
    (Lo: $1F442; Hi: $1F4FC),  // body parts, people, objects
    (Lo: $1F4FF; Hi: $1F53D),  // objects, symbols
    (Lo: $1F54B; Hi: $1F54E),  // religious buildings
    (Lo: $1F550; Hi: $1F567),  // clocks
    (Lo: $1F57A; Hi: $1F57A),  // man dancing
    (Lo: $1F595; Hi: $1F596),  // hand gestures
    (Lo: $1F5A4; Hi: $1F5A4),  // black heart
    (Lo: $1F5FB; Hi: $1F64F),  // places, smileys, gestures
    (Lo: $1F680; Hi: $1F6C5),  // transport
    (Lo: $1F6CC; Hi: $1F6CC),  // person in bed
    (Lo: $1F6D0; Hi: $1F6D2),  // place of worship, octagonal sign, cart
    (Lo: $1F6D5; Hi: $1F6D7),  // hindu temple, hut, elevator
    (Lo: $1F6DC; Hi: $1F6DF),  // wireless, playground, wheel, ring buoy
    (Lo: $1F6EB; Hi: $1F6EC),  // airplane departure/arrival
    (Lo: $1F6F4; Hi: $1F6FC),  // scooters, vehicles
    (Lo: $1F7E0; Hi: $1F7EB),  // colored circles and squares
    (Lo: $1F7F0; Hi: $1F7F0),  // heavy equals sign
    (Lo: $1F90C; Hi: $1F93A),  // hands, people
    (Lo: $1F93C; Hi: $1F945),  // sports
    (Lo: $1F947; Hi: $1F9FF),  // medals, people, animals, objects
    (Lo: $1FA70; Hi: $1FA7C),  // ballet shoes, medical
    (Lo: $1FA80; Hi: $1FA89),  // yo-yo, objects
    (Lo: $1FA8F; Hi: $1FAC6),  // shovel, animals, people
    (Lo: $1FACE; Hi: $1FADC),  // moose, food
    (Lo: $1FADF; Hi: $1FAE9),  // splatter, faces
    (Lo: $1FAF0; Hi: $1FAF8)   // hand gestures
  );

  // --- Extended_Pictographic, Unicode 16.0 -----------------------------------
  // Source: emoji-data.txt. Adjacent spec ranges separated only by unassigned
  // or same-block symbol code points are merged into supersets: harmless for
  // GB11 segmentation (such code points do not otherwise occur next to ZWJ)
  // and it keeps the table small.
  ExtendedPictographicRanges: array[0..50] of TTuiCodePointRange = (
    (Lo: $00A9; Hi: $00A9),    // copyright
    (Lo: $00AE; Hi: $00AE),    // registered
    (Lo: $203C; Hi: $203C),    // double exclamation
    (Lo: $2049; Hi: $2049),    // exclamation question
    (Lo: $2122; Hi: $2122),    // trade mark
    (Lo: $2139; Hi: $2139),    // information
    (Lo: $2194; Hi: $2199),    // arrows
    (Lo: $21A9; Hi: $21AA),    // hooked arrows
    (Lo: $231A; Hi: $231B),    // watch, hourglass
    (Lo: $2328; Hi: $2328),    // keyboard
    (Lo: $2388; Hi: $2388),    // helm symbol
    (Lo: $23CF; Hi: $23CF),    // eject
    (Lo: $23E9; Hi: $23F3),    // media controls
    (Lo: $23F8; Hi: $23FA),    // pause, stop, record
    (Lo: $24C2; Hi: $24C2),    // circled M
    (Lo: $25AA; Hi: $25AB),    // small squares
    (Lo: $25B6; Hi: $25B6),    // play
    (Lo: $25C0; Hi: $25C0),    // reverse play
    (Lo: $25FB; Hi: $25FE),    // squares
    (Lo: $2600; Hi: $2612),    // weather, symbols
    (Lo: $2614; Hi: $2685),    // misc symbols, zodiac, games
    (Lo: $2690; Hi: $2705),    // flags, tools, religious symbols
    (Lo: $2708; Hi: $2712),    // airplane, mail, hands, pencils
    (Lo: $2714; Hi: $2714),    // check mark
    (Lo: $2716; Hi: $2716),    // multiplication
    (Lo: $271D; Hi: $271D),    // latin cross
    (Lo: $2721; Hi: $2721),    // star of David
    (Lo: $2728; Hi: $2728),    // sparkles
    (Lo: $2733; Hi: $2734),    // asterisks
    (Lo: $2744; Hi: $2744),    // snowflake
    (Lo: $2747; Hi: $2747),    // sparkle
    (Lo: $274C; Hi: $274C),    // cross mark
    (Lo: $274E; Hi: $274E),    // cross mark button
    (Lo: $2753; Hi: $2755),    // question/exclamation
    (Lo: $2757; Hi: $2757),    // red exclamation
    (Lo: $2763; Hi: $2767),    // hearts, ornaments
    (Lo: $2795; Hi: $2797),    // math symbols
    (Lo: $27A1; Hi: $27A1),    // right arrow
    (Lo: $27B0; Hi: $27B0),    // curly loop
    (Lo: $27BF; Hi: $27BF),    // double curly loop
    (Lo: $2934; Hi: $2935),    // curved arrows
    (Lo: $2B05; Hi: $2B07),    // arrows
    (Lo: $2B1B; Hi: $2B1C),    // large squares
    (Lo: $2B50; Hi: $2B50),    // star
    (Lo: $2B55; Hi: $2B55),    // hollow red circle
    (Lo: $3030; Hi: $3030),    // wavy dash
    (Lo: $303D; Hi: $303D),    // part alternation mark
    (Lo: $3297; Hi: $3297),    // circled congratulations
    (Lo: $3299; Hi: $3299),    // circled secret
    (Lo: $1F000; Hi: $1F0FF),  // mahjong, dominoes, cards
    (Lo: $1F10D; Hi: $1FFFD)   // enclosed symbols + all emoji planes (merged)
  );

  // --- Grapheme extenders -----------------------------------------------------
  // Pragmatic subset of Grapheme_Cluster_Break = Extend (plus U+200C ZWNJ):
  // combining marks of common scripts, variation selectors, emoji skin tone
  // modifiers ($1F3FB..$1F3FF carry Emoji_Modifier and are Extend since
  // Unicode 11) and the tag characters of emoji tag sequences. Less common
  // Indic/SE-Asian combining classes are approximated by their main blocks.
  ExtendRanges: array[0..29] of TTuiCodePointRange = (
    (Lo: $0300; Hi: $036F),    // Combining Diacritical Marks
    (Lo: $0483; Hi: $0489),    // Cyrillic combining marks
    (Lo: $0591; Hi: $05BD),    // Hebrew points
    (Lo: $05BF; Hi: $05BF),    // Hebrew point rafe
    (Lo: $05C1; Hi: $05C2),    // Hebrew points
    (Lo: $05C4; Hi: $05C5),    // Hebrew marks
    (Lo: $05C7; Hi: $05C7),    // Hebrew point qamats qatan
    (Lo: $0610; Hi: $061A),    // Arabic signs
    (Lo: $064B; Hi: $065F),    // Arabic vowels
    (Lo: $0670; Hi: $0670),    // Arabic letter superscript alef
    (Lo: $06D6; Hi: $06DC),    // Arabic small high signs
    (Lo: $06DF; Hi: $06E4),    // Arabic small high signs
    (Lo: $06E7; Hi: $06E8),    // Arabic small high signs
    (Lo: $06EA; Hi: $06ED),    // Arabic small signs
    (Lo: $0711; Hi: $0711),    // Syriac letter superscript alaph
    (Lo: $0730; Hi: $074A),    // Syriac points
    (Lo: $07A6; Hi: $07B0),    // Thaana points
    (Lo: $07EB; Hi: $07F3),    // NKo combining tones
    (Lo: $0816; Hi: $0819),    // Samaritan marks
    (Lo: $0E31; Hi: $0E3A),    // Thai vowels/tones (approximate block)
    (Lo: $0E47; Hi: $0E4E),    // Thai tone marks
    (Lo: $1AB0; Hi: $1AFF),    // Combining Diacritical Marks Extended
    (Lo: $1DC0; Hi: $1DFF),    // Combining Diacritical Marks Supplement
    (Lo: $200C; Hi: $200C),    // zero width non-joiner
    (Lo: $20D0; Hi: $20FF),    // Combining Marks for Symbols (incl. keycap $20E3)
    (Lo: $2DE0; Hi: $2DFF),    // Cyrillic Extended-A
    (Lo: $FE00; Hi: $FE0F),    // Variation Selectors (VS1..VS16)
    (Lo: $FE20; Hi: $FE2F),    // Combining Half Marks
    (Lo: $1F3FB; Hi: $1F3FF),  // Emoji modifiers (skin tones)
    (Lo: $E0020; Hi: $E01EF)   // Tag characters + Variation Selectors Supplement
  );

  CpZeroWidthJoiner = $200D;
  CpVariationSelector15 = $FE0E;
  CpVariationSelector16 = $FE0F;
  CpCombiningEnclosingKeycap = $20E3;

// Binary search over a sorted, non-overlapping range table.
function InRanges(ACodePoint: TTuiCodePoint;
  const ARanges: array of TTuiCodePointRange): Boolean;
begin
  var LLow := 0;
  var LHigh := High(ARanges);
  while LLow <= LHigh do
  begin
    var LMid := (LLow + LHigh) div 2;
    if ACodePoint < ARanges[LMid].Lo then
      LHigh := LMid - 1
    else if ACodePoint > ARanges[LMid].Hi then
      LLow := LMid + 1
    else
      Exit(True);
  end;
  Result := False;
end;

{ TTuiUnicode }

class function TTuiUnicode.CombineSurrogates(AHigh, ALow: Char): TTuiCodePoint;
begin
  Result := ((TTuiCodePoint(Ord(AHigh)) - $D800) shl 10) +
    (TTuiCodePoint(Ord(ALow)) - $DC00) + $10000;
end;

class function TTuiUnicode.CodePointToString(ACodePoint: TTuiCodePoint): string;
begin
  if ACodePoint <= $FFFF then
    Result := Char(Word(ACodePoint))
  else
  begin
    var LOffset := ACodePoint - $10000;
    Result := Char(Word($D800 + (LOffset shr 10))) +
      Char(Word($DC00 + (LOffset and $3FF)));
  end;
end;

class function TTuiUnicode.IsHighSurrogate(ACh: Char): Boolean;
begin
  Result := (Ord(ACh) >= $D800) and (Ord(ACh) <= $DBFF);
end;

class function TTuiUnicode.IsLowSurrogate(ACh: Char): Boolean;
begin
  Result := (Ord(ACh) >= $DC00) and (Ord(ACh) <= $DFFF);
end;

class function TTuiUnicode.NextCodePoint(const AText: string;
  var AIndex: Integer): TTuiCodePoint;
begin
  var LChar := AText[AIndex];
  if IsHighSurrogate(LChar) and (AIndex < Length(AText)) and
     IsLowSurrogate(AText[AIndex + 1]) then
  begin
    Result := CombineSurrogates(LChar, AText[AIndex + 1]);
    Inc(AIndex, 2);
  end
  else
  begin
    // Unpaired surrogates fall through here: returned as-is, width 1,
    // so malformed input never derails iteration.
    Result := Ord(LChar);
    Inc(AIndex);
  end;
end;

class function TTuiUnicode.IsEmojiPresentation(ACodePoint: TTuiCodePoint): Boolean;
begin
  Result := InRanges(ACodePoint, EmojiPresentationRanges);
end;

class function TTuiUnicode.IsExtend(ACodePoint: TTuiCodePoint): Boolean;
begin
  Result := InRanges(ACodePoint, ExtendRanges);
end;

class function TTuiUnicode.IsExtendedPictographic(ACodePoint: TTuiCodePoint): Boolean;
begin
  Result := InRanges(ACodePoint, ExtendedPictographicRanges);
end;

class function TTuiUnicode.IsRegionalIndicator(ACodePoint: TTuiCodePoint): Boolean;
begin
  Result := (ACodePoint >= $1F1E6) and (ACodePoint <= $1F1FF);
end;

class function TTuiUnicode.IsVariationSelector15(ACodePoint: TTuiCodePoint): Boolean;
begin
  Result := ACodePoint = CpVariationSelector15;
end;

class function TTuiUnicode.IsVariationSelector16(ACodePoint: TTuiCodePoint): Boolean;
begin
  Result := ACodePoint = CpVariationSelector16;
end;

class function TTuiUnicode.IsZWJ(ACodePoint: TTuiCodePoint): Boolean;
begin
  Result := ACodePoint = CpZeroWidthJoiner;
end;

class function TTuiUnicode.GraphemeLengthAt(const AText: string;
  AIndex: Integer): Integer;
begin
  if (AIndex < 1) or (AIndex > Length(AText)) then
    Exit(0);

  // Fast path for the overwhelmingly common case: an ASCII/Latin-1 base
  // ($20..$A8, below the first Extended_Pictographic entry) not followed by
  // any possible extender (combining marks start at $0300; ZWJ and variation
  // selectors are higher) is always a single-unit cluster.
  var LFirstUnit := Ord(AText[AIndex]);
  if (LFirstUnit >= $0020) and (LFirstUnit < $00A9) and
     ((AIndex >= Length(AText)) or (Ord(AText[AIndex + 1]) < $0300)) then
    Exit(1);

  var LIndex := AIndex;
  var LBase := NextCodePoint(AText, LIndex);

  // GB3: CR x LF; GB4: break after other controls.
  if LBase = $000D then
  begin
    if (LIndex <= Length(AText)) and (AText[LIndex] = #$000A) then
      Inc(LIndex);
    Exit(LIndex - AIndex);
  end;
  if (LBase < $0020) or ((LBase >= $007F) and (LBase <= $009F)) then
    Exit(LIndex - AIndex);

  // GB12/GB13: a regional indicator pairs with exactly one following RI.
  // Assumes AIndex is a cluster boundary, so the pair always starts here.
  var LEmojiSequence := IsExtendedPictographic(LBase);
  if IsRegionalIndicator(LBase) and (LIndex <= Length(AText)) then
  begin
    var LPeek := LIndex;
    var LNext := NextCodePoint(AText, LPeek);
    if IsRegionalIndicator(LNext) then
    begin
      LIndex := LPeek;
      LEmojiSequence := True;
    end;
  end;

  // GB9: never break before Extend or ZWJ; GB11: an extended pictographic
  // glues across ZWJ only within an emoji sequence.
  while LIndex <= Length(AText) do
  begin
    var LPeek := LIndex;
    var LNext := NextCodePoint(AText, LPeek);
    if IsExtend(LNext) then
      LIndex := LPeek
    else if IsZWJ(LNext) then
    begin
      LIndex := LPeek;
      if LEmojiSequence and (LIndex <= Length(AText)) then
      begin
        var LAfter := LIndex;
        var LJoined := NextCodePoint(AText, LAfter);
        if IsExtendedPictographic(LJoined) then
          LIndex := LAfter
        else
          Break;
      end
      else
        Break;
    end
    else
      Break;
  end;
  Result := LIndex - AIndex;
end;

class function TTuiUnicode.NextGraphemeBoundary(const AText: string;
  AIndex: Integer): Integer;
begin
  var LLen := GraphemeLengthAt(AText, AIndex);
  if LLen = 0 then
    Result := Length(AText) + 1
  else
    Result := AIndex + LLen;
end;

class function TTuiUnicode.PrevGraphemeBoundary(const AText: string;
  AIndex: Integer): Integer;
begin
  Result := 1;
  if AIndex <= 1 then
    Exit;
  if AIndex > Length(AText) + 1 then
    AIndex := Length(AText) + 1;
  // Grapheme boundaries depend on left context, so scan forward from the
  // start. Strings handled by widgets are short; O(n) is acceptable.
  var LCurrent := 1;
  while LCurrent < AIndex do
  begin
    var LNext := NextGraphemeBoundary(AText, LCurrent);
    if LNext >= AIndex then
      Exit(LCurrent);
    LCurrent := LNext;
  end;
  Result := LCurrent;
end;

class function TTuiUnicode.SnapToClusterStart(const AText: string;
  AIndex: Integer): Integer;
begin
  if AIndex <= 1 then
    Exit(1);
  if AIndex > Length(AText) then
    Exit(Length(AText) + 1);
  var LBoundary := 1;
  while LBoundary < AIndex do
  begin
    var LNext := NextGraphemeBoundary(AText, LBoundary);
    if LNext > AIndex then
      Break;
    LBoundary := LNext;
  end;
  Result := LBoundary;
end;

class function TTuiUnicode.CodePointWidth(ACodePoint: TTuiCodePoint): Integer;
begin
  // Fast path: printable ASCII/Latin-1 below the first table entry ($A9).
  if (ACodePoint >= $0020) and (ACodePoint < $00A9) then
    Exit(1);
  // Zero-width: NUL, ZWJ, ZWSP..RLM, word joiner, BOM and grapheme extenders
  // except the emoji skin tone modifiers, which render as a 2-column swatch
  // when they appear alone.
  if (ACodePoint = 0) or (ACodePoint = CpZeroWidthJoiner) or
     ((ACodePoint >= $200B) and (ACodePoint <= $200F)) or
     (ACodePoint = $2060) or (ACodePoint = $FEFF) then
    Exit(0);
  if (ACodePoint >= $1F3FB) and (ACodePoint <= $1F3FF) then
    Exit(2);
  if IsExtend(ACodePoint) then
    Exit(0);
  if InRanges(ACodePoint, WideRanges) or IsEmojiPresentation(ACodePoint) then
    Exit(2);
  Result := 1;
end;

class function TTuiUnicode.ClusterWidthAt(const AText: string;
  AIndex, ALen: Integer): Integer;
begin
  if (ALen <= 0) or (AIndex < 1) or (AIndex > Length(AText)) then
    Exit(0);

  // Fast path: a single-unit cluster has the width of its only code point
  // under every emoji level.
  if ALen = 1 then
    Exit(CodePointWidth(Ord(AText[AIndex])));

  var LEnd := AIndex + ALen;
  if LEnd > Length(AText) + 1 then
    LEnd := Length(AText) + 1;

  var LIndex := AIndex;
  var LBase := NextCodePoint(AText, LIndex);
  var LBaseWidth := CodePointWidth(LBase);
  var LSumWidth := LBaseWidth;
  var LIsEmojiSequence := False;

  while LIndex < LEnd do
  begin
    var LNext := NextCodePoint(AText, LIndex);
    if IsVariationSelector16(LNext) or IsZWJ(LNext) then
      LIsEmojiSequence := True;
    Inc(LSumWidth, CodePointWidth(LNext));
  end;

  if FEmojiLevel = elFull then
  begin
    // A cluster-capable terminal draws the whole sequence as one glyph.
    // VS16 and ZWJ force emoji presentation (2 columns); everything else
    // (VS15, combining marks, regional indicator pairs whose base is
    // already wide) keeps the width of the base code point.
    if LIsEmojiSequence then
      Exit(2);
    Result := LBaseWidth;
  end
  else
    // elBasic/elNone: the terminal draws each part on its own; measure the
    // sum so layout matches the actual cursor advance.
    Result := LSumWidth;
end;

class procedure TTuiUnicode.ApplyDetectedEmojiLevel(ALevel: TTuiEmojiLevel);
begin
  if not FEmojiLevelExplicit then
    FEmojiLevel := ALevel;
end;

class procedure TTuiUnicode.SetEmojiLevel(AValue: TTuiEmojiLevel);
begin
  FEmojiLevel := AValue;
  FEmojiLevelExplicit := True;
end;

class function TTuiUnicode.StringWidth(const AText: string): Integer;
begin
  Result := 0;
  var LIndex := 1;
  while LIndex <= Length(AText) do
  begin
    var LLen := GraphemeLengthAt(AText, LIndex);
    if LLen = 0 then
      Break;
    Inc(Result, ClusterWidthAt(AText, LIndex, LLen));
    Inc(LIndex, LLen);
  end;
end;

initialization
  // Optimistic default: modern terminals merge clusters. Console backends
  // downgrade to elBasic when a legacy host is detected; an explicit
  // application assignment to EmojiLevel always wins over detection.
  TTuiUnicode.ApplyDetectedEmojiLevel(elFull);

end.
