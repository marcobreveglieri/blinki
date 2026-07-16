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
{   Unit:        Blinki.UnitTests.Core.Emoji.pas                 }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   DUnitX test fixture for the emoji shortcode catalog of
///   Blinki.Core.Emoji: lookup, expansion, and the sorted-catalog invariant
///   required by the binary search.
/// </summary>
unit Blinki.UnitTests.Core.Emoji;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  DUnitX.TestFramework;

type

{ TEmojiCatalogTests }

  /// <summary>
  ///   Verifies TTuiEmoji.Find/Expand and the catalog invariants.
  /// </summary>
  [TestFixture]
  TEmojiCatalogTests = class
  public
    /// <summary>
    ///   Find resolves a known shortcode, with or without colons and
    ///   regardless of case.
    /// </summary>
    [Test]
    procedure Find_KnownShortcode;
    /// <summary>
    ///   Find returns '' for unknown names and degenerate input.
    /// </summary>
    [Test]
    procedure Find_Unknown_ReturnsEmpty;
    /// <summary>
    ///   Expand replaces known shortcodes and leaves everything else intact.
    /// </summary>
    [Test]
    procedure Expand_MixedText;
    /// <summary>
    ///   The catalog must be sorted by name: the binary search depends on it.
    /// </summary>
    [Test]
    procedure Catalog_IsSortedByName;
    /// <summary>
    ///   Every catalog glyph must be non-empty and resolvable via Find.
    /// </summary>
    [Test]
    procedure Catalog_EntriesAreConsistent;
  end;

implementation

uses
  System.SysUtils,
  Blinki.Core.Emoji;

const
  // 🚀 rocket (2 units)
  Rocket = #$D83D#$DE80;
  // 🇮🇹 Italy flag (4 units)
  FlagIt = #$D83C#$DDEE#$D83C#$DDF9;

{ TEmojiCatalogTests }

procedure TEmojiCatalogTests.Find_KnownShortcode;
begin
  Assert.AreEqual(Rocket, TTuiEmoji.Find('rocket'));
  Assert.AreEqual(Rocket, TTuiEmoji.Find(':rocket:'));
  Assert.AreEqual(Rocket, TTuiEmoji.Find('ROCKET'));
  Assert.AreEqual(FlagIt, TTuiEmoji.Find('flag_it'));
end;

procedure TEmojiCatalogTests.Find_Unknown_ReturnsEmpty;
begin
  Assert.AreEqual('', TTuiEmoji.Find('no_such_emoji'));
  Assert.AreEqual('', TTuiEmoji.Find(''));
  Assert.AreEqual('', TTuiEmoji.Find('::'));
end;

procedure TEmojiCatalogTests.Expand_MixedText;
begin
  Assert.AreEqual('Go ' + Rocket + '!', TTuiEmoji.Expand('Go :rocket:!'));
  Assert.AreEqual('a :unknown: b', TTuiEmoji.Expand('a :unknown: b'),
    'Unknown shortcodes stay untouched');
  Assert.AreEqual('10:30 ok', TTuiEmoji.Expand('10:30 ok'),
    'Stray colons stay untouched');
  Assert.AreEqual(Rocket + FlagIt, TTuiEmoji.Expand(':rocket::flag_it:'),
    'Adjacent shortcodes both expand');
  Assert.AreEqual('', TTuiEmoji.Expand(''));
end;

procedure TEmojiCatalogTests.Catalog_IsSortedByName;
begin
  for var LIndex := 1 to TTuiEmoji.Count - 1 do
    Assert.IsTrue(
      CompareStr(TTuiEmoji.Entry(LIndex - 1).Name, TTuiEmoji.Entry(LIndex).Name) < 0,
      Format('Catalog must be strictly sorted: "%s" >= "%s"',
        [TTuiEmoji.Entry(LIndex - 1).Name, TTuiEmoji.Entry(LIndex).Name]));
end;

procedure TEmojiCatalogTests.Catalog_EntriesAreConsistent;
begin
  for var LIndex := 0 to TTuiEmoji.Count - 1 do
  begin
    var LEntry := TTuiEmoji.Entry(LIndex);
    Assert.IsTrue(LEntry.Glyph <> '', 'Glyph must not be empty: ' + LEntry.Name);
    Assert.AreEqual(LEntry.Glyph, TTuiEmoji.Find(LEntry.Name),
      'Find must resolve every catalog entry: ' + LEntry.Name);
  end;
end;

end.
