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
{   Unit:        Blinki.Core.Emoji.pas                           }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Emoji shortcode catalog for the Blinki library: maps ':name:' shortcodes
///   (GitHub/Slack style) to emoji grapheme clusters, following the glyph
///   catalog idiom of TTuiBoxCharSet. Rendering, width measurement and input
///   of emoji live in Blinki.Core.Unicode and the canvas; this unit is a pure
///   convenience layer for application code.
/// </summary>
/// <remarks>
///   Usage:
///     LLabel.Caption := TTuiEmoji.Expand('Build passed :check_mark_button:');
///     LGlyph := TTuiEmoji.Find('rocket'); // returns the emoji, or '' if unknown
/// </remarks>
unit Blinki.Core.Emoji;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

type

{ TTuiEmojiEntry }

  /// <summary>
  ///   One catalog entry: a shortcode name (without colons) and the emoji
  ///   grapheme cluster it expands to.
  /// </summary>
  TTuiEmojiEntry = record
    /// <summary>
    ///   Shortcode name, lowercase, without the surrounding colons.
    /// </summary>
    Name: string;
    /// <summary>
    ///   The emoji as a UTF-16 string (may be a multi-code-point sequence).
    /// </summary>
    Glyph: string;
  end;

{ TTuiEmoji }

  /// <summary>
  ///   Static access to the emoji shortcode catalog.
  /// </summary>
  TTuiEmoji = record
  public
    /// <summary>
    ///   Number of entries in the catalog.
    /// </summary>
    class function Count: Integer; static;

    /// <summary>
    ///   Returns the catalog entry at AIndex (0-based). Useful to enumerate
    ///   the catalog, e.g. in pickers or demos.
    /// </summary>
    class function Entry(AIndex: Integer): TTuiEmojiEntry; static;

    /// <summary>
    ///   Replaces every known ':name:' shortcode in AText with its emoji.
    ///   Unknown shortcodes and stray colons are left untouched.
    /// </summary>
    class function Expand(const AText: string): string; static;

    /// <summary>
    ///   Returns the emoji for the given shortcode name (with or without
    ///   the surrounding colons, case-insensitive), or '' when unknown.
    /// </summary>
    class function Find(const AName: string): string; static;
  end;

implementation

uses
  System.SysUtils;

const
  // Curated subset of the GitHub/Slack shortcode set. Kept sorted by Name
  // (binary searched by Find). Sequences (flags, ZWJ, skin tones, VS16) are
  // spelled with explicit code units so the file survives any re-encoding.
  Catalog: array[0..99] of TTuiEmojiEntry = (
    (Name: '100';                 Glyph: #$D83D#$DCAF),                    // 💯
    (Name: 'airplane';            Glyph: #$2708#$FE0F),                    // ✈️
    (Name: 'alarm_clock';         Glyph: #$23F0),                          // ⏰
    (Name: 'ambulance';           Glyph: #$D83D#$DE91),                    // 🚑
    (Name: 'anchor';              Glyph: #$2693),                          // ⚓
    (Name: 'apple';               Glyph: #$D83C#$DF4E),                    // 🍎
    (Name: 'art';                 Glyph: #$D83C#$DFA8),                    // 🎨
    (Name: 'balloon';             Glyph: #$D83C#$DF88),                    // 🎈
    (Name: 'bank';                Glyph: #$D83C#$DFE6),                    // 🏦
    (Name: 'battery';             Glyph: #$D83D#$DD0B),                    // 🔋
    (Name: 'beer';                Glyph: #$D83C#$DF7A),                    // 🍺
    (Name: 'bell';                Glyph: #$D83D#$DD14),                    // 🔔
    (Name: 'birthday';            Glyph: #$D83C#$DF82),                    // 🎂
    (Name: 'books';               Glyph: #$D83D#$DCDA),                    // 📚
    (Name: 'brain';               Glyph: #$D83E#$DDE0),                    // 🧠
    (Name: 'briefcase';           Glyph: #$D83D#$DCBC),                    // 💼
    (Name: 'bug';                 Glyph: #$D83D#$DC1B),                    // 🐛
    (Name: 'bulb';                Glyph: #$D83D#$DCA1),                    // 💡
    (Name: 'calendar';            Glyph: #$D83D#$DCC5),                    // 📅
    (Name: 'camera';              Glyph: #$D83D#$DCF7),                    // 📷
    (Name: 'cat';                 Glyph: #$D83D#$DC31),                    // 🐱
    (Name: 'chart_up';            Glyph: #$D83D#$DCC8),                    // 📈
    (Name: 'check_mark';          Glyph: #$2714#$FE0F),                    // ✔️
    (Name: 'check_mark_button';   Glyph: #$2705),                          // ✅
    (Name: 'clap';                Glyph: #$D83D#$DC4F),                    // 👏
    (Name: 'clipboard';           Glyph: #$D83D#$DCCB),                    // 📋
    (Name: 'cloud';               Glyph: #$2601#$FE0F),                    // ☁️
    (Name: 'coffee';              Glyph: #$2615),                          // ☕
    (Name: 'computer';            Glyph: #$D83D#$DCBB),                    // 💻
    (Name: 'construction';        Glyph: #$D83D#$DEA7),                    // 🚧
    (Name: 'cool';                Glyph: #$D83D#$DE0E),                    // 😎
    (Name: 'cross_mark';          Glyph: #$274C),                          // ❌
    (Name: 'crown';               Glyph: #$D83D#$DC51),                    // 👑
    (Name: 'cry';                 Glyph: #$D83D#$DE22),                    // 😢
    (Name: 'dart';                Glyph: #$D83C#$DFAF),                    // 🎯
    (Name: 'dog';                 Glyph: #$D83D#$DC36),                    // 🐶
    (Name: 'envelope';            Glyph: #$2709#$FE0F),                    // ✉️
    (Name: 'eyes';                Glyph: #$D83D#$DC40),                    // 👀
    (Name: 'family';              Glyph: #$D83D#$DC68#$200D#$D83D#$DC69#$200D#$D83D#$DC67), // 👨‍👩‍👧
    (Name: 'fire';                Glyph: #$D83D#$DD25),                    // 🔥
    (Name: 'flag_de';             Glyph: #$D83C#$DDE9#$D83C#$DDEA),        // 🇩🇪
    (Name: 'flag_es';             Glyph: #$D83C#$DDEA#$D83C#$DDF8),        // 🇪🇸
    (Name: 'flag_fr';             Glyph: #$D83C#$DDEB#$D83C#$DDF7),        // 🇫🇷
    (Name: 'flag_gb';             Glyph: #$D83C#$DDEC#$D83C#$DDE7),        // 🇬🇧
    (Name: 'flag_it';             Glyph: #$D83C#$DDEE#$D83C#$DDF9),        // 🇮🇹
    (Name: 'flag_us';             Glyph: #$D83C#$DDFA#$D83C#$DDF8),        // 🇺🇸
    (Name: 'folder';              Glyph: #$D83D#$DCC1),                    // 📁
    (Name: 'game_die';            Glyph: #$D83C#$DFB2),                    // 🎲
    (Name: 'gear';                Glyph: #$2699#$FE0F),                    // ⚙️
    (Name: 'gem';                 Glyph: #$D83D#$DC8E),                    // 💎
    (Name: 'ghost';               Glyph: #$D83D#$DC7B),                    // 👻
    (Name: 'gift';                Glyph: #$D83C#$DF81),                    // 🎁
    (Name: 'globe';               Glyph: #$D83C#$DF10),                    // 🌐
    (Name: 'grin';                Glyph: #$D83D#$DE01),                    // 😁
    (Name: 'hammer';              Glyph: #$D83D#$DD28),                    // 🔨
    (Name: 'heart';               Glyph: #$2764#$FE0F),                    // ❤️
    (Name: 'hourglass';           Glyph: #$23F3),                          // ⏳
    (Name: 'house';               Glyph: #$D83C#$DFE0),                    // 🏠
    (Name: 'hundred';             Glyph: #$D83D#$DCAF),                    // 💯
    (Name: 'joy';                 Glyph: #$D83D#$DE02),                    // 😂
    (Name: 'key';                 Glyph: #$D83D#$DD11),                    // 🔑
    (Name: 'link';                Glyph: #$D83D#$DD17),                    // 🔗
    (Name: 'lock';                Glyph: #$D83D#$DD12),                    // 🔒
    (Name: 'loudspeaker';         Glyph: #$D83D#$DCE2),                    // 📢
    (Name: 'magnifier';           Glyph: #$D83D#$DD0D),                    // 🔍
    (Name: 'memo';                Glyph: #$D83D#$DCDD),                    // 📝
    (Name: 'moon';                Glyph: #$D83C#$DF19),                    // 🌙
    (Name: 'muscle';              Glyph: #$D83D#$DCAA),                    // 💪
    (Name: 'music';               Glyph: #$D83C#$DFB5),                    // 🎵
    (Name: 'ok_hand';             Glyph: #$D83D#$DC4C),                    // 👌
    (Name: 'package';             Glyph: #$D83D#$DCE6),                    // 📦
    (Name: 'palette';             Glyph: #$D83C#$DFA8),                    // 🎨
    (Name: 'party';               Glyph: #$D83E#$DD73),                    // 🥳
    (Name: 'pencil';              Glyph: #$270F#$FE0F),                    // ✏️
    (Name: 'phone';               Glyph: #$D83D#$DCF1),                    // 📱
    (Name: 'pin';                 Glyph: #$D83D#$DCCC),                    // 📌
    (Name: 'pizza';               Glyph: #$D83C#$DF55),                    // 🍕
    (Name: 'pray';                Glyph: #$D83D#$DE4F),                    // 🙏
    (Name: 'question';            Glyph: #$2753),                          // ❓
    (Name: 'rainbow';             Glyph: #$D83C#$DF08),                    // 🌈
    (Name: 'robot';               Glyph: #$D83E#$DD16),                    // 🤖
    (Name: 'rocket';              Glyph: #$D83D#$DE80),                    // 🚀
    (Name: 'rotating_light';      Glyph: #$D83D#$DEA8),                    // 🚨
    (Name: 'smile';               Glyph: #$D83D#$DE04),                    // 😄
    (Name: 'snowflake';           Glyph: #$2744#$FE0F),                    // ❄️
    (Name: 'sparkles';            Glyph: #$2728),                          // ✨
    (Name: 'star';                Glyph: #$2B50),                          // ⭐
    (Name: 'stopwatch';           Glyph: #$23F1#$FE0F),                    // ⏱️
    (Name: 'sun';                 Glyph: #$2600#$FE0F),                    // ☀️
    (Name: 'tada';                Glyph: #$D83C#$DF89),                    // 🎉
    (Name: 'thinking';            Glyph: #$D83E#$DD14),                    // 🤔
    (Name: 'thumbs_down';         Glyph: #$D83D#$DC4E),                    // 👎
    (Name: 'thumbs_up';           Glyph: #$D83D#$DC4D),                    // 👍
    (Name: 'trash';               Glyph: #$D83D#$DDD1#$FE0F),              // 🗑️
    (Name: 'trophy';              Glyph: #$D83C#$DFC6),                    // 🏆
    (Name: 'unicorn';             Glyph: #$D83E#$DD84),                    // 🦄
    (Name: 'unlock';              Glyph: #$D83D#$DD13),                    // 🔓
    (Name: 'warning';             Glyph: #$26A0#$FE0F),                    // ⚠️
    (Name: 'wave';                Glyph: #$D83D#$DC4B),                    // 👋
    (Name: 'wrench';              Glyph: #$D83D#$DD27)                     // 🔧
  );

{ TTuiEmoji }

class function TTuiEmoji.Count: Integer;
begin
  Result := Length(Catalog);
end;

class function TTuiEmoji.Entry(AIndex: Integer): TTuiEmojiEntry;
begin
  Result := Catalog[AIndex];
end;

class function TTuiEmoji.Find(const AName: string): string;
begin
  Result := '';
  var LName := LowerCase(AName);
  if (Length(LName) >= 2) and (LName[1] = ':') and (LName[Length(LName)] = ':') then
    LName := Copy(LName, 2, Length(LName) - 2);
  if LName = '' then
    Exit;

  // Binary search: the catalog is kept sorted by Name (ordinal order).
  var LLow := 0;
  var LHigh := High(Catalog);
  while LLow <= LHigh do
  begin
    var LMid := (LLow + LHigh) div 2;
    var LCompare := CompareStr(Catalog[LMid].Name, LName);
    if LCompare < 0 then
      LLow := LMid + 1
    else if LCompare > 0 then
      LHigh := LMid - 1
    else
      Exit(Catalog[LMid].Glyph);
  end;
end;

class function TTuiEmoji.Expand(const AText: string): string;
begin
  Result := '';
  var LIndex := 1;
  while LIndex <= Length(AText) do
  begin
    var LChar := AText[LIndex];
    if LChar = ':' then
    begin
      // Candidate shortcode: look for the closing colon.
      var LClose := LIndex + 1;
      while (LClose <= Length(AText)) and (AText[LClose] <> ':') and
            (AText[LClose] > ' ') do
        Inc(LClose);
      if (LClose <= Length(AText)) and (AText[LClose] = ':') and
         (LClose > LIndex + 1) then
      begin
        var LGlyph := Find(Copy(AText, LIndex + 1, LClose - LIndex - 1));
        if LGlyph <> '' then
        begin
          Result := Result + LGlyph;
          LIndex := LClose + 1;
          Continue;
        end;
      end;
    end;
    Result := Result + LChar;
    Inc(LIndex);
  end;
end;

end.
