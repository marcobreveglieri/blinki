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
{   Unit:        Blinki.Core.Ansi.pas                            }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Builder of ANSI/VT100 escape sequences for the Blinki library.
///   All methods are pure functions returning strings: no state, no direct
///   terminal writes. The caller concatenates and passes to the backend.
/// </summary>
/// <remarks>
///   Usage pattern:
///   LBackend.Write(TTuiAnsi.CursorTo(5, 10) + TTuiAnsi.ApplyStyle(LStyle) +
///     'Ciao' + TTuiAnsi.Reset);
/// </remarks>
unit Blinki.Core.Ansi;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Blinki.Core.Style;

type

{ TTuiBoxStyle }

  /// <summary>
  ///   Box drawing style: single, double, rounded or thick.
  /// </summary>
  TTuiBoxStyle = (
    /// <summary>
    ///   Single line border (U+2500).
    /// </summary>
    bsSingle,
    /// <summary>
    ///   Double line border (U+2550).
    /// </summary>
    bsDouble,
    /// <summary>
    ///   Edge with rounded corners (U+256D).
    /// </summary>
    bsRounded,
    /// <summary>
    ///   Border with thick lines (U+2501).
    /// </summary>
    bsHeavy
  );

{ TTuiBoxCharSet }

  /// <summary>
  ///   Set of Unicode characters for drawing a rectangular border.
  /// </summary>
  TTuiBoxCharSet = record
    /// <summary>
    ///   Top-left corner character.
    /// </summary>
    TopLeft: Char;
    /// <summary>
    ///   Top-right corner character.
    /// </summary>
    TopRight: Char;
    /// <summary>
    ///   Bottom-left corner character.
    /// </summary>
    BottomLeft: Char;
    /// <summary>
    ///   Bottom-right corner character.
    /// </summary>
    BottomRight: Char;
    /// <summary>
    ///   Horizontal line character.
    /// </summary>
    Horizontal: Char;
    /// <summary>
    ///   Vertical line character.
    /// </summary>
    Vertical: Char;
  end;

{ TTuiAnsi }

  /// <summary>
  /// Builder of ANSI/VT100 escape sequences and box drawing primitives.
  /// </summary>
  /// <remarks>
  /// All methods are static class functions returning Unicode strings.
  /// Coordinates are 1-based as required by the ANSI protocol.
  /// </remarks>
  TTuiAnsi = record
  public
    {$REGION 'SGR sequences: colors and styles'}
    /// <summary>
    ///   Resets all SGR attributes to the terminal default state.
    /// </summary>
    class function Reset: string; static;

    /// <summary>
    ///   Sets the text (foreground) color based on the TTuiColor kind.
    /// </summary>
    class function SetForeground(const AColor: TTuiColor): string; static;

    /// <summary>
    ///   Sets the background color based on the TTuiColor kind.
    /// </summary>
    class function SetBackground(const AColor: TTuiColor): string; static;

    /// <summary>
    ///   Returns the SGR sequence for all specified style attributes.
    ///   If AAttrs is empty, returns an empty string.
    /// </summary>
    class function SetAttributes(AAttrs: TTuiTextAttrs): string; static;

    /// <summary>
    ///   Applies a full style (foreground + background + attributes) by emitting
    ///   a reset followed by the appropriate SGR sequences.
    /// </summary>
    class function ApplyStyle(const AStyle: TTuiStyle): string; static;

    /// <summary>
    ///   Emits only the SGR sequences needed to transition from style APrev to ANext.
    ///   More efficient than ApplyStyle for the diff renderer: avoids Reset when
    ///   no attribute is being turned off. Returns '' if the styles are identical.
    /// </summary>
    /// <remarks>
    ///   Falls back to Reset + full ApplyStyle in two cases: an attribute is turned off
    ///   (no stable individual SGR "off" codes in v1), or a color returns to ckDefault
    ///   (SetForeground/SetBackground emit '' for ckDefault, so without a reset the
    ///   terminal would retain the previous color).
    /// </remarks>
    class function ApplyStyleDelta(const APrev, ANext: TTuiStyle): string; static;
    {$ENDREGION}
    {$REGION 'Cursor control'}
    /// <summary>
    ///   Moves the cursor to position (ARow, ACol).
    /// </summary>
    /// <remarks>
    ///   Coordinates are 1-based.
    /// </remarks>
    class function CursorTo(ARow, ACol: Integer): string; static;

    /// <summary>
    ///   Moves the cursor up by N rows.
    /// </summary>
    class function CursorUp(N: Integer = 1): string; static;

    /// <summary>
    ///   Moves the cursor down by N rows.
    /// </summary>
    class function CursorDown(N: Integer = 1): string; static;

    /// <summary>
    ///   Moves the cursor right by N columns.
    /// </summary>
    class function CursorRight(N: Integer = 1): string; static;

    /// <summary>
    ///   Moves the cursor left by N columns.
    /// </summary>
    class function CursorLeft(N: Integer = 1): string; static;

    /// <summary>
    ///   Hides the cursor (not displayed, but the position is preserved).
    /// </summary>
    class function CursorHide: string; static;

    /// <summary>
    ///   Shows the cursor.
    /// </summary>
    class function CursorShow: string; static;

    /// <summary>
    ///   Saves the current cursor position.
    /// </summary>
    class function CursorSavePosition: string; static;

    /// <summary>
    ///   Restores the previously saved cursor position.
    /// </summary>
    class function CursorRestorePosition: string; static;
    {$ENDREGION}
    {$REGION 'Screen control'}
    /// <summary>
    ///   Clears the entire screen and positions the cursor at (1, 1).
    /// </summary>
    class function ClearScreen: string; static;

    /// <summary>
    ///   Clears the screen from the current cursor position to the end.
    /// </summary>
    class function ClearScreenAfterCursor: string; static;

    /// <summary>
    ///   Clears the entire current line.
    /// </summary>
    class function ClearLine: string; static;

    /// <summary>
    ///   Clears from the current cursor position to the end of the line.
    /// </summary>
    class function ClearLineToEnd: string; static;
    {$ENDREGION}
    {$REGION 'Alternate buffer'}
    /// <summary>
    ///   Enters the alternate buffer: saves the current screen content
    ///   and displays an empty buffer. Use together with AlternateBufferOff in try/finally.
    /// </summary>
    class function AlternateBufferOn: string; static;

    /// <summary>
    ///   Exits the alternate buffer and restores the previous screen content.
    /// </summary>
    class function AlternateBufferOff: string; static;
    {$ENDREGION}
    {$REGION 'Window title'}
    /// <summary>
    ///   Sets the terminal window title.
    /// </summary>
    class function SetTitle(const ATitle: string): string; static;
    {$ENDREGION}
    {$REGION 'Utilities'}
    /// <summary>
    ///   True for EAW = W/F characters (CJK, Hangul, Fullwidth): occupy 2 terminal columns.
    /// </summary>
    class function IsWideChar(ACh: Char): Boolean; static;

    /// <summary>
    ///   Computes the visible length of a string, excluding ANSI escape sequences
    ///   (CSI ... [A-Za-z] and OSC ... BEL/ST). Correctly accounts for WideChar
    ///   characters (CJK) that occupy 2 columns.
    /// </summary>
    class function VisibleLength(const AText: string): Integer; static;

    /// <summary>
    ///   Returns a substring of AText that fits within AMaxWidth columns.
    ///   Correctly handles WideChar characters.
    /// </summary>
    class function TruncateToWidth(const AText: string; AMaxWidth: Integer): string; static;

    /// <summary>
    ///   Splits AText into word-wrapped lines that fit within AWidth columns
    ///   using greedy wrapping. Returns at least one element even for empty input.
    ///   Words longer than AWidth are placed on their own line without hard-breaking.
    /// </summary>
    class function WrapText(const AText: string; AWidth: Integer): TArray<string>; static;
    {$ENDREGION}
    {$REGION 'Box drawing'}
    /// <summary>
    ///   Returns the Unicode character set for the specified border style.
    /// </summary>
    class function BoxCharset(AStyle: TTuiBoxStyle): TTuiBoxCharSet; static;
    {$ENDREGION}
  end;

{ TTuiBoxes }

  /// <summary>
  ///   Exposes the predefined box drawing character sets for the four supported styles.
  /// </summary>
  TTuiBoxes = record
  public
    /// <summary>
    ///   Character set for the single-line border style.
    /// </summary>
    class function Single: TTuiBoxCharSet; static; inline;
    /// <summary>
    ///   Character set for the double-line border style.
    /// </summary>
    class function Double: TTuiBoxCharSet; static; inline;
    /// <summary>
    ///   Character set for the rounded-corner border style.
    /// </summary>
    class function Rounded: TTuiBoxCharSet; static; inline;
    /// <summary>
    ///   Character set for the heavy-line border style.
    /// </summary>
    class function Heavy: TTuiBoxCharSet; static; inline;
  end;

implementation

uses
  System.Classes,
  System.SysUtils;

const
  CSI   = #27'[';
  ESC   = #27;
  OSC   = #27']';
  BEL   = #7;
  CRESET = #27'[0m';

{ TTuiAnsi }

class function TTuiAnsi.Reset: string;
begin
  Result := CRESET;
end;

class function TTuiAnsi.SetForeground(const AColor: TTuiColor): string;
begin
  case AColor.Kind of
    ckDefault:
      Result := '';
    ck16:
      if AColor.R < 8 then
        Result := CSI + IntToStr(30 + AColor.R) + 'm'
      else
        Result := CSI + IntToStr(90 + (AColor.R - 8)) + 'm';
    ck256:
      Result := CSI + '38;5;' + IntToStr(AColor.R) + 'm';
    ckRGB:
      Result := CSI + '38;2;' + IntToStr(AColor.R) + ';' +
        IntToStr(AColor.G) + ';' + IntToStr(AColor.B) + 'm';
  else
    Result := '';
  end;
end;

class function TTuiAnsi.SetBackground(const AColor: TTuiColor): string;
begin
  case AColor.Kind of
    ckDefault:
      Result := '';
    ck16:
      if AColor.R < 8 then
        Result := CSI + IntToStr(40 + AColor.R) + 'm'
      else
        Result := CSI + IntToStr(100 + (AColor.R - 8)) + 'm';
    ck256:
      Result := CSI + '48;5;' + IntToStr(AColor.R) + 'm';
    ckRGB:
      Result := CSI + '48;2;' + IntToStr(AColor.R) + ';' +
        IntToStr(AColor.G) + ';' + IntToStr(AColor.B) + 'm';
  else
    Result := '';
  end;
end;

class function TTuiAnsi.SetAttributes(AAttrs: TTuiTextAttrs): string;
const
  AttrCodes: array[TTuiTextAttr] of string = ('1', '2', '3', '4', '5', '7', '9');
begin
  if AAttrs = [] then
    Exit('');
  var LParams := '';
  for var LAttr := Low(TTuiTextAttr) to High(TTuiTextAttr) do
    if LAttr in AAttrs then
    begin
      if LParams <> '' then
        LParams := LParams + ';';
      LParams := LParams + AttrCodes[LAttr];
    end;
  Result := CSI + LParams + 'm';
end;

class function TTuiAnsi.ApplyStyle(const AStyle: TTuiStyle): string;
begin
  Result := CRESET
    + SetForeground(AStyle.Foreground)
    + SetBackground(AStyle.Background)
    + SetAttributes(AStyle.Attributes);
end;

class function TTuiAnsi.ApplyStyleDelta(const APrev, ANext: TTuiStyle): string;
begin
  if APrev = ANext then
    Exit('');
  if ((APrev.Attributes - ANext.Attributes) <> []) or
     ((APrev.Foreground.Kind <> ckDefault) and (ANext.Foreground.Kind = ckDefault)) or
     ((APrev.Background.Kind <> ckDefault) and (ANext.Background.Kind = ckDefault)) then
    Exit(ApplyStyle(ANext));
  Result := '';
  if APrev.Foreground <> ANext.Foreground then
    Result := Result + SetForeground(ANext.Foreground);
  if APrev.Background <> ANext.Background then
    Result := Result + SetBackground(ANext.Background);
  if (ANext.Attributes - APrev.Attributes) <> [] then
    Result := Result + SetAttributes(ANext.Attributes - APrev.Attributes);
end;

class function TTuiAnsi.CursorTo(ARow, ACol: Integer): string;
begin
  Result := CSI + IntToStr(ARow) + ';' + IntToStr(ACol) + 'H';
end;

class function TTuiAnsi.CursorUp(N: Integer): string;
begin
  Result := CSI + IntToStr(N) + 'A';
end;

class function TTuiAnsi.CursorDown(N: Integer): string;
begin
  Result := CSI + IntToStr(N) + 'B';
end;

class function TTuiAnsi.CursorRight(N: Integer): string;
begin
  Result := CSI + IntToStr(N) + 'C';
end;

class function TTuiAnsi.CursorLeft(N: Integer): string;
begin
  Result := CSI + IntToStr(N) + 'D';
end;

class function TTuiAnsi.CursorHide: string;
begin
  Result := CSI + '?25l';
end;

class function TTuiAnsi.CursorShow: string;
begin
  Result := CSI + '?25h';
end;

class function TTuiAnsi.CursorSavePosition: string;
begin
  // ANSI Save Cursor (SCO/ANSI): CSI s
  Result := CSI + 's';
end;

class function TTuiAnsi.CursorRestorePosition: string;
begin
  // ANSI Restore Cursor (SCO/ANSI): CSI u
  Result := CSI + 'u';
end;

class function TTuiAnsi.ClearScreen: string;
begin
  Result := CSI + '2J' + CSI + '1;1H';
end;

class function TTuiAnsi.ClearScreenAfterCursor: string;
begin
  Result := CSI + '0J';
end;

class function TTuiAnsi.ClearLine: string;
begin
  Result := CSI + '2K';
end;

class function TTuiAnsi.ClearLineToEnd: string;
begin
  Result := CSI + '0K';
end;

class function TTuiAnsi.AlternateBufferOn: string;
begin
  Result := CSI + '?1049h';
end;

class function TTuiAnsi.AlternateBufferOff: string;
begin
  Result := CSI + '?1049l';
end;

class function TTuiAnsi.SetTitle(const ATitle: string): string;
begin
  Result := OSC + '0;' + ATitle + BEL;
end;

class function TTuiAnsi.IsWideChar(ACh: Char): Boolean;
begin
  var CP: Cardinal := Ord(ACh);
  Result :=
    ((CP >= $1100) and (CP <= $115F)) or  // Hangul Jamo
    ((CP >= $2E80) and (CP <= $303F)) or  // CJK Radicals, Kangxi, CJK Symbols
    ((CP >= $3040) and (CP <= $33FF)) or  // Hiragana, Katakana, Bopomofo, Hangul Compat.
    ((CP >= $3400) and (CP <= $4DBF)) or  // CJK Ext-A
    ((CP >= $4E00) and (CP <= $9FFF)) or  // CJK Unified Ideographs
    ((CP >= $A000) and (CP <= $A4CF)) or  // Yi
    ((CP >= $A960) and (CP <= $A97F)) or  // Hangul Jamo Extended-A
    ((CP >= $AC00) and (CP <= $D7FF)) or  // Hangul Syllables + Jamo Ext-B
    ((CP >= $F900) and (CP <= $FAFF)) or  // CJK Compatibility Ideographs
    ((CP >= $FE10) and (CP <= $FE1F)) or  // Vertical Forms
    ((CP >= $FE30) and (CP <= $FE6F)) or  // CJK Compat. Forms + Small Form Variants
    ((CP >= $FF01) and (CP <= $FF60)) or  // Fullwidth Forms (EAW = F)
    ((CP >= $FFE0) and (CP <= $FFE6));    // Fullwidth Signs (EAW = F)
end;

class function TTuiAnsi.VisibleLength(const AText: string): Integer;
begin
  Result := 0;
  var LIndex := 1;
  while LIndex <= Length(AText) do
  begin
    var LChar := AText[LIndex];
    if LChar = ESC then
    begin
      Inc(LIndex);
      // Handle CSI: ESC '[' ... final letter
      if (LIndex <= Length(AText)) and (AText[LIndex] = '[') then
      begin
        Inc(LIndex);
        // Skip parameters and intermediates up to the final letter (A-Za-z)
        while (LIndex <= Length(AText)) and
              not CharInSet(AText[LIndex], ['A'..'Z', 'a'..'z']) do
          Inc(LIndex);
        // Skip the final letter
        if LIndex <= Length(AText) then
          Inc(LIndex);
      end
      // Handle OSC: ESC ']' ... BEL
      else if (LIndex <= Length(AText)) and (AText[LIndex] = ']') then
      begin
        Inc(LIndex);
        while (LIndex <= Length(AText)) and (AText[LIndex] <> BEL) do
          Inc(LIndex);
        // Skip BEL
        if LIndex <= Length(AText) then
          Inc(LIndex);
      end
      else
      begin
        // Other two-character ESC sequence (e.g. ESC s, ESC u): skip the next character
        if LIndex <= Length(AText) then
          Inc(LIndex);
      end;
    end
    else begin
      if IsWideChar(LChar) then
        Inc(Result, 2)
      else
        Inc(Result);
      Inc(LIndex);
    end;
  end;
end;

class function TTuiAnsi.TruncateToWidth(const AText: string; AMaxWidth: Integer): string;
begin
  if AMaxWidth <= 0 then
    Exit('');
  var LCurrentWidth := 0;
  var LIndex := 1;
  while LIndex <= Length(AText) do
  begin
    var LChar := AText[LIndex];
    var LCharWidth := 1;
    if IsWideChar(LChar) then
      LCharWidth := 2;

    if LCurrentWidth + LCharWidth > AMaxWidth then
      Break;

    Inc(LCurrentWidth, LCharWidth);
    Inc(LIndex);
  end;
  Result := Copy(AText, 1, LIndex - 1);
end;

class function TTuiAnsi.WrapText(const AText: string; AWidth: Integer): TArray<string>;
begin
  if AWidth < 1 then
  begin
    SetLength(Result, 1);
    Result[0] := AText;
    Exit;
  end;
  var LWords := AText.Split([' ']);
  var LResult := TStringList.Create;
  try
    var LLine := '';
    for var LWord in LWords do
    begin
      if LWord = '' then
        Continue;
      if LLine = '' then
        LLine := LWord
      else if Length(LLine) + 1 + Length(LWord) <= AWidth then
        LLine := LLine + ' ' + LWord
      else
      begin
        LResult.Add(LLine);
        LLine := LWord;
      end;
    end;
    if LLine <> '' then
      LResult.Add(LLine);
    if LResult.Count = 0 then
      LResult.Add('');
    Result := LResult.ToStringArray;
  finally
    LResult.Free;
  end;
end;

class function TTuiAnsi.BoxCharset(AStyle: TTuiBoxStyle): TTuiBoxCharSet;
begin
  case AStyle of
    bsSingle:
      begin
        Result.TopLeft := #$250C;  // ┌
        Result.TopRight := #$2510;  // ┐
        Result.BottomLeft := #$2514;  // └
        Result.BottomRight := #$2518;  // ┘
        Result.Horizontal := #$2500;  // ─
        Result.Vertical := #$2502;  // │
      end;
    bsDouble:
      begin
        Result.TopLeft := #$2554;  // ╔
        Result.TopRight := #$2557;  // ╗
        Result.BottomLeft := #$255A;  // ╚
        Result.BottomRight := #$255D;  // ╝
        Result.Horizontal := #$2550;  // ═
        Result.Vertical := #$2551;  // ║
      end;
    bsRounded:
      begin
        Result.TopLeft := #$256D;  // ╭
        Result.TopRight := #$256E;  // ╮
        Result.BottomLeft := #$2570;  // ╰
        Result.BottomRight := #$256F;  // ╯
        Result.Horizontal := #$2500;  // ─
        Result.Vertical := #$2502;  // │
      end;
    bsHeavy:
      begin
        Result.TopLeft := #$250F;  // ┏
        Result.TopRight := #$2513;  // ┓
        Result.BottomLeft := #$2517;  // ┗
        Result.BottomRight := #$251B;  // ┛
        Result.Horizontal := #$2501;  // ━
        Result.Vertical := #$2503;  // ┃
      end;
  end;
end;

{ TTuiBoxes }

class function TTuiBoxes.Single: TTuiBoxCharSet;
begin
  Result := TTuiAnsi.BoxCharset(bsSingle);
end;

class function TTuiBoxes.Double: TTuiBoxCharSet;
begin
  Result := TTuiAnsi.BoxCharset(bsDouble);
end;

class function TTuiBoxes.Rounded: TTuiBoxCharSet;
begin
  Result := TTuiAnsi.BoxCharset(bsRounded);
end;

class function TTuiBoxes.Heavy: TTuiBoxCharSet;
begin
  Result := TTuiAnsi.BoxCharset(bsHeavy);
end;

end.
