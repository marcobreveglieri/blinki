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
{   Unit:        Blinki.Widgets.TextInput.pas                    }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiTextInput: single-line editable text field.
///   Supports placeholder text, password masking, maximum length, and an OnSubmit callback.
/// </summary>
unit Blinki.Widgets.TextInput;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget;

type

{ TTuiTextInput }

  /// <summary>
  ///   Single-line editable text field. Handles character insertion and deletion,
  ///   cursor navigation with automatic horizontal scrolling, placeholder text
  ///   with a dimmed style, password masking, and an OnSubmit callback on Enter.
  ///   Becomes focusable in DoInit; the cursor (inverse video) is shown only when focused.
  /// </summary>
  TTuiTextInput = class(TTuiWidget)
  strict private
    FText: string;
    FCursorPos: Integer;
    FViewOffset: Integer;
    FPlaceholder: string;
    FPasswordChar: Char;
    FMaxLength: Integer;
    FOnTextChanged: TProc<string>;
    FOnSubmit: TProc<string>;
    FNormalStyle: TTuiStyle;
    FFocusedStyle: TTuiStyle;
    FPlaceholderStyle: TTuiStyle;
    FCursorStyle: TTuiStyle;
    FNormalStyleOverride: Boolean;
    FFocusedStyleOverride: Boolean;
    function  DisplayCursorPos: Integer;
    function  SnapCursorToBoundary(AValue: Integer): Integer;
    procedure SetText(const AValue: string);
    procedure SetCursorPos(AValue: Integer);
    procedure SetPlaceholder(const AValue: string);
    procedure SetPasswordChar(AValue: Char);
    procedure SetMaxLength(AValue: Integer);
    procedure SetNormalStyle(const AValue: TTuiStyle);
    procedure SetFocusedStyle(const AValue: TTuiStyle);
    procedure RebuildStyles;
    procedure ClampViewOffset(ACursorCol, AViewWidth: Integer);
    function  BuildDisplay: string;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function  DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the widget. Becomes focusable after Init. Initial PasswordChar: #0 (disabled).
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Current content of the field.
    /// </summary>
    property Text: string read FText write SetText;
    /// <summary>
    ///   Cursor position in UTF-16 code units (0 = before the first character,
    ///   Length(Text) = after the last one). Always kept on a grapheme cluster
    ///   boundary: assigned values that fall inside a cluster (e.g. in the
    ///   middle of an emoji sequence) snap back to the cluster start.
    /// </summary>
    property CursorPos: Integer read FCursorPos write SetCursorPos;
    /// <summary>
    ///   Text displayed with a dimmed style when the field is empty and not focused.
    /// </summary>
    property Placeholder: string read FPlaceholder write SetPlaceholder;
    /// <summary>
    ///   When different from #0, each character is rendered using this glyph (e.g. '*').
    /// </summary>
    property PasswordChar: Char read FPasswordChar write SetPasswordChar;
    /// <summary>
    ///   Maximum text length (0 = unlimited).
    /// </summary>
    property MaxLength: Integer read FMaxLength write SetMaxLength;
    /// <summary>
    ///   Fired on every text change; receives the current text as argument.
    /// </summary>
    property OnTextChanged: TProc<string> read FOnTextChanged write FOnTextChanged;
    /// <summary>
    ///   Fired when the user presses Enter; receives the current text as argument.
    /// </summary>
    property OnSubmit: TProc<string> read FOnSubmit write FOnSubmit;
    /// <summary>
    ///   Style used when unfocused. Assigning it disables automatic updates from the theme.
    /// </summary>
    property NormalStyle: TTuiStyle read FNormalStyle write SetNormalStyle;
    /// <summary>
    ///   Style used when focused. Assigning it disables automatic updates from the theme.
    /// </summary>
    property FocusedStyle: TTuiStyle read FFocusedStyle write SetFocusedStyle;
  end;

implementation

uses
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Unicode;

{ TTuiTextInput }

constructor TTuiTextInput.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  RebuildStyles;
end;

procedure TTuiTextInput.RebuildStyles;
begin
  if not FNormalStyleOverride then
    FNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  if not FFocusedStyleOverride then
    FFocusedStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  FPlaceholderStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
  FCursorStyle := TTuiStyle.Create(Theme.Text, Theme.Surface, [taInverse]);
end;

procedure TTuiTextInput.DoInit;
begin
  SetFocusable(True);
end;

procedure TTuiTextInput.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

function TTuiTextInput.BuildDisplay: string;
begin
  if FPasswordChar <> #0 then
  begin
    // One mask character per grapheme cluster, so an emoji counts as a
    // single masked position, not one per UTF-16 code unit.
    Result := '';
    var LIndex := 1;
    while LIndex <= Length(FText) do
    begin
      Result := Result + FPasswordChar;
      LIndex := TTuiUnicode.NextGraphemeBoundary(FText, LIndex);
    end;
  end
  else
    Result := FText;
end;

function TTuiTextInput.DisplayCursorPos: Integer;
begin
  if FPasswordChar = #0 then
    Exit(FCursorPos);
  // In password mode the display holds one mask char per cluster: the
  // cursor position is the number of clusters before it.
  Result := 0;
  var LIndex := 1;
  while LIndex <= FCursorPos do
  begin
    Inc(Result);
    LIndex := TTuiUnicode.NextGraphemeBoundary(FText, LIndex);
  end;
end;

function TTuiTextInput.SnapCursorToBoundary(AValue: Integer): Integer;
begin
  Result := TTuiUnicode.SnapToClusterStart(FText, AValue + 1) - 1;
end;

procedure TTuiTextInput.ClampViewOffset(ACursorCol, AViewWidth: Integer);
begin
  if AViewWidth <= 0 then
    Exit;

  // cursor is too far left relative to the viewport
  if ACursorCol < FViewOffset then
    FViewOffset := ACursorCol;
  // cursor is too far right relative to the viewport
  if ACursorCol >= FViewOffset + AViewWidth then
    FViewOffset := ACursorCol - AViewWidth + 1;

  if FViewOffset < 0 then
    FViewOffset := 0;
end;

procedure TTuiTextInput.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  var LBase := FNormalStyle;
  if Focused then
    LBase := FFocusedStyle;

  ACanvas.FillRect(ARect, ' ', LBase);

  if (FText = '') and (not Focused) then
  begin
    // show placeholder
    var LPlaceholder := TTuiAnsi.TruncateToWidth(FPlaceholder, ARect.Width);
    ACanvas.WriteAt(ARect.Left, ARect.Top, LPlaceholder, FPlaceholderStyle);
    Exit;
  end;

  var LDisplay := BuildDisplay;
  var LDisplayCursor := DisplayCursorPos;
  // Compute the cursor column once and reuse it for viewport clamping and
  // cursor placement below.
  var LCursorCol := TTuiAnsi.VisibleLength(Copy(LDisplay, 1, LDisplayCursor));
  ClampViewOffset(LCursorCol, ARect.Width);

  // Find which part of LDisplay starts at FViewOffset (in columns), skipping
  // whole grapheme clusters so surrogate pairs and emoji sequences never split.
  var LSkipIndex := 1;
  var LSkipCols := 0;
  while (LSkipIndex <= Length(LDisplay)) and (LSkipCols < FViewOffset) do
  begin
    var LLen := TTuiUnicode.GraphemeLengthAt(LDisplay, LSkipIndex);
    Inc(LSkipCols, TTuiUnicode.ClusterWidthAt(LDisplay, LSkipIndex, LLen));
    Inc(LSkipIndex, LLen);
  end;

  var LVisible := TTuiAnsi.TruncateToWidth(Copy(LDisplay, LSkipIndex), ARect.Width);
  ACanvas.WriteAt(ARect.Left, ARect.Top, LVisible, LBase);

  if Focused then
  begin
    var LCursorX := ARect.Left + (LCursorCol - FViewOffset);
    if (LCursorX >= ARect.Left) and (LCursorX < ARect.Right) then
    begin
      // Highlight the whole cluster under the cursor, not just its first
      // code unit, so the inverse-video block covers the entire emoji.
      var LCursorText: string;
      if LDisplayCursor < Length(LDisplay) then
        LCursorText := Copy(LDisplay, LDisplayCursor + 1,
          TTuiUnicode.GraphemeLengthAt(LDisplay, LDisplayCursor + 1))
      else
        LCursorText := ' ';
      // A 2-column cluster that would overflow the widget's right edge
      // degrades to a plain block cursor: never paint outside the rect.
      if LCursorX + TTuiAnsi.VisibleLength(LCursorText) > ARect.Right then
        LCursorText := ' ';
      ACanvas.WriteAt(LCursorX, ARect.Top, LCursorText, FCursorStyle);
    end;
  end;
end;

function TTuiTextInput.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;

  case AEvent.Key.Code of
    kcChar, kcSpace:
      if (AEvent.Key.Code = kcSpace) or AEvent.Key.IsPrintable then
      begin
        // CharText may span two code units (emoji beyond the BMP): MaxLength
        // stays measured in UTF-16 code units, so check the insertion fits.
        var LInsert := AEvent.Key.CharText;
        if (FMaxLength = 0) or (Length(FText) + Length(LInsert) <= FMaxLength) then
        begin
          Insert(LInsert, FText, FCursorPos + 1);
          Inc(FCursorPos, Length(LInsert));
          if Assigned(FOnTextChanged) then
            FOnTextChanged(FText);
          Invalidate;
          Result := True;
        end;
      end;

    kcBackspace:
      if FCursorPos > 0 then
      begin
        // Delete the whole grapheme cluster before the cursor (an emoji
        // sequence disappears in one keystroke, like in any editor).
        var LStart := TTuiUnicode.PrevGraphemeBoundary(FText, FCursorPos + 1);
        Delete(FText, LStart, FCursorPos + 1 - LStart);
        FCursorPos := LStart - 1;
        if Assigned(FOnTextChanged) then
          FOnTextChanged(FText);
        Invalidate;
        Result := True;
      end;

    kcDelete:
      if FCursorPos < Length(FText) then
      begin
        Delete(FText, FCursorPos + 1,
          TTuiUnicode.GraphemeLengthAt(FText, FCursorPos + 1));
        if Assigned(FOnTextChanged) then
          FOnTextChanged(FText);
        Invalidate;
        Result := True;
      end;

    kcLeft:
      begin
        var LNewPos := FCursorPos;
        if FCursorPos > 0 then
          LNewPos := TTuiUnicode.PrevGraphemeBoundary(FText, FCursorPos + 1) - 1;
        if LNewPos <> FCursorPos then
        begin
          FCursorPos := LNewPos;
          Invalidate;
        end;
        Result := True;
      end;

    kcRight:
      begin
        var LNewPos := FCursorPos;
        if FCursorPos < Length(FText) then
          LNewPos := TTuiUnicode.NextGraphemeBoundary(FText, FCursorPos + 1) - 1;
        if LNewPos <> FCursorPos then
        begin
          FCursorPos := LNewPos;
          Invalidate;
        end;
        Result := True;
      end;

    kcHome:
      begin
        if FCursorPos <> 0 then
        begin
          FCursorPos := 0;
          Invalidate;
        end;
        Result := True;
      end;

    kcEnd:
      begin
        var LNewPos := Length(FText);
        if LNewPos <> FCursorPos then
        begin
          FCursorPos := LNewPos;
          Invalidate;
        end;
        Result := True;
      end;

    kcEnter:
      begin
        if Assigned(FOnSubmit) then
          FOnSubmit(FText);
        Result := True;
      end;
  end;
end;

procedure TTuiTextInput.SetText(const AValue: string);
begin
  if FText = AValue then
    Exit;
  FText := AValue;
  if FCursorPos > Length(FText) then
    FCursorPos := Length(FText);
  FCursorPos := SnapCursorToBoundary(FCursorPos);
  FViewOffset := 0;
  Invalidate;
end;

procedure TTuiTextInput.SetCursorPos(AValue: Integer);
begin
  if AValue < 0 then
    AValue := 0;
  if AValue > Length(FText) then
    AValue := Length(FText);
  AValue := SnapCursorToBoundary(AValue);
  if FCursorPos = AValue then
    Exit;
  FCursorPos := AValue;
  Invalidate;
end;

procedure TTuiTextInput.SetPlaceholder(const AValue: string);
begin
  if FPlaceholder = AValue then
    Exit;
  FPlaceholder := AValue;
  Invalidate;
end;

procedure TTuiTextInput.SetPasswordChar(AValue: Char);
begin
  if FPasswordChar = AValue then
    Exit;
  FPasswordChar := AValue;
  Invalidate;
end;

procedure TTuiTextInput.SetMaxLength(AValue: Integer);
begin
  if FMaxLength = AValue then
    Exit;
  FMaxLength := AValue;
  if (FMaxLength > 0) and (Length(FText) > FMaxLength) then
  begin
    // Cut on a cluster boundary so the truncation never leaves half an emoji.
    var LCut := SnapCursorToBoundary(FMaxLength);
    FText := Copy(FText, 1, LCut);
    if FCursorPos > LCut then
      FCursorPos := LCut;
  end;
  Invalidate;
end;

procedure TTuiTextInput.SetNormalStyle(const AValue: TTuiStyle);
begin
  if FNormalStyle = AValue then
    Exit;
  FNormalStyle := AValue;
  FNormalStyleOverride := True;
  Invalidate;
end;

procedure TTuiTextInput.SetFocusedStyle(const AValue: TTuiStyle);
begin
  if FFocusedStyle = AValue then
    Exit;
  FFocusedStyle := AValue;
  FFocusedStyleOverride := True;
  Invalidate;
end;

end.
