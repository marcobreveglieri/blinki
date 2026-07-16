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
{   Unit:        Blinki.Widgets.TextArea.pas                     }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiTextArea: multi-line editable text field with vertical and horizontal scrolling.
///   Supports placeholder text, read-only mode, and an OnTextChanged callback.
/// </summary>
unit Blinki.Widgets.TextArea;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget;

type

{ TTuiTextArea }

  /// <summary>
  ///   Multi-line editable text field with automatic scrolling.
  ///   Handles character insertion and deletion, cursor navigation across lines,
  ///   placeholder text with a dimmed style, and an optional read-only mode.
  ///   Becomes focusable in DoInit; the block cursor (inverse video) is shown
  ///   only when focused and not in read-only mode.
  ///   Tab is intentionally not consumed — the application intercepts it for focus cycling.
  /// </summary>
  TTuiTextArea = class(TTuiWidget)
  strict private
    FCursorCol: Integer;
    FCursorRow: Integer;
    FCursorStyle: TTuiStyle;
    FFocusedStyle: TTuiStyle;
    FFocusedStyleOverride: Boolean;
    FLeftCol: Integer;
    FLines: TStringList;
    FNormalStyle: TTuiStyle;
    FNormalStyleOverride: Boolean;
    FOnTextChanged: TProc<string>;
    FPlaceholder: string;
    FPlaceholderStyle: TTuiStyle;
    FReadOnly: Boolean;
    FTopLine: Integer;
    FViewHeight: Integer;
    procedure ClampCursor;
    procedure ClampViewport(AViewWidth, AViewHeight: Integer);
    function  GetText: string;
    procedure InsertText(const AText: string);
    procedure RebuildStyles;
    function  SnapColToBoundary(const ALine: string; ACol: Integer): Integer;
    procedure SetFocusedStyle(const AValue: TTuiStyle);
    procedure SetNormalStyle(const AValue: TTuiStyle);
    procedure SetPlaceholder(const AValue: string);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetText(const AValue: string);
  protected
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    function  DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Creates the widget. Becomes focusable after Init.
    ///   Starts with a single empty line and a default view height of 10 rows.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Frees the internal line list.
    /// </summary>
    destructor Destroy; override;
    /// <summary>
    ///   Current column position of the cursor (0-based within the current row).
    /// </summary>
    property CursorCol: Integer read FCursorCol;
    /// <summary>
    ///   Current row position of the cursor (0-based).
    /// </summary>
    property CursorRow: Integer read FCursorRow;
    /// <summary>
    ///   Style used when focused. Assigning it disables automatic updates from the theme.
    /// </summary>
    property FocusedStyle: TTuiStyle read FFocusedStyle write SetFocusedStyle;
    /// <summary>
    ///   Style used when unfocused. Assigning it disables automatic updates from the theme.
    /// </summary>
    property NormalStyle: TTuiStyle read FNormalStyle write SetNormalStyle;
    /// <summary>
    ///   Fired on every text change; receives the current text as argument.
    /// </summary>
    property OnTextChanged: TProc<string> read FOnTextChanged write FOnTextChanged;
    /// <summary>
    ///   Text displayed with a dimmed style when the content is empty and the widget is unfocused.
    /// </summary>
    property Placeholder: string read FPlaceholder write SetPlaceholder;
    /// <summary>
    ///   When True, navigation is still active but editing input is ignored.
    /// </summary>
    property ReadOnly: Boolean read FReadOnly write SetReadOnly;
    /// <summary>
    ///   Full text content, with lines joined by sLineBreak.
    ///   Assigning replaces all content and resets the cursor to (row 0, col 0).
    /// </summary>
    property Text: string read GetText write SetText;
  end;

implementation

uses
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Unicode;

{ TTuiTextArea }

constructor TTuiTextArea.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FLines := TStringList.Create;
  FLines.Add('');
  FViewHeight := 10;
  RebuildStyles;
end;

destructor TTuiTextArea.Destroy;
begin
  FLines.Free;
  inherited;
end;

procedure TTuiTextArea.RebuildStyles;
begin
  if not FNormalStyleOverride then
    FNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  if not FFocusedStyleOverride then
    FFocusedStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  FPlaceholderStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
  FCursorStyle := TTuiStyle.Create(Theme.Text, Theme.Surface, [taInverse]);
end;

procedure TTuiTextArea.DoInit;
begin
  SetFocusable(True);
end;

procedure TTuiTextArea.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TTuiTextArea.ClampCursor;
begin
  if FCursorRow < 0 then
    FCursorRow := 0;
  if FCursorRow >= FLines.Count then
    FCursorRow := FLines.Count - 1;
  var LLineLen := Length(FLines[FCursorRow]);
  if FCursorCol < 0 then
    FCursorCol := 0;
  if FCursorCol > LLineLen then
    FCursorCol := LLineLen;
  // Moving between rows can land inside a grapheme cluster of the new line
  // (e.g. between the two halves of an emoji): snap back to its start.
  FCursorCol := SnapColToBoundary(FLines[FCursorRow], FCursorCol);
end;

function TTuiTextArea.SnapColToBoundary(const ALine: string; ACol: Integer): Integer;
begin
  if ACol <= 0 then
    Exit(0);
  if ACol >= Length(ALine) then
    Exit(Length(ALine));
  // Find the largest cluster boundary not beyond ACol.
  var LBoundary := 1;
  while LBoundary <= ACol do
  begin
    var LNext := TTuiUnicode.NextGraphemeBoundary(ALine, LBoundary);
    if LNext > ACol + 1 then
      Break;
    LBoundary := LNext;
  end;
  Result := LBoundary - 1;
end;

procedure TTuiTextArea.ClampViewport(AViewWidth, AViewHeight: Integer);
begin
  if AViewHeight > 0 then
  begin
    if FCursorRow < FTopLine then
      FTopLine := FCursorRow;
    if FCursorRow >= FTopLine + AViewHeight then
      FTopLine := FCursorRow - AViewHeight + 1;
    if FTopLine < 0 then
      FTopLine := 0;
  end;
  if AViewWidth > 0 then
  begin
    if FCursorCol < FLeftCol then
      FLeftCol := FCursorCol;
    if FCursorCol >= FLeftCol + AViewWidth then
      FLeftCol := FCursorCol - AViewWidth + 1;
    if FLeftCol < 0 then
      FLeftCol := 0;
  end;
end;

function TTuiTextArea.GetText: string;
begin
  Result := '';
  for var I := 0 to FLines.Count - 1 do
  begin
    if I > 0 then
      Result := Result + sLineBreak;
    Result := Result + FLines[I];
  end;
end;

procedure TTuiTextArea.InsertText(const AText: string);
begin
  var LLine := FLines[FCursorRow];
  Insert(AText, LLine, FCursorCol + 1);
  FLines[FCursorRow] := LLine;
  Inc(FCursorCol, Length(AText));
end;

procedure TTuiTextArea.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  FViewHeight := ARect.Height;

  var LBase := FNormalStyle;
  if Focused then
    LBase := FFocusedStyle;

  ACanvas.FillRect(ARect, ' ', LBase);

  // Show placeholder when content is empty and widget is unfocused
  if (FLines.Count = 1) and (FLines[0] = '') and not Focused then
  begin
    var LPlaceholder := Copy(FPlaceholder, 1, ARect.Width);
    ACanvas.WriteAt(ARect.Left, ARect.Top, LPlaceholder, FPlaceholderStyle);
    Exit;
  end;

  ClampViewport(ARect.Width, ARect.Height);

  ACanvas.PushClip(ARect);
  try
    // Draw visible lines. The horizontal cut starts on a cluster boundary
    // and the right edge is truncated by columns, so emoji never split.
    for var LRow := 0 to ARect.Height - 1 do
    begin
      var LLineIndex := FTopLine + LRow;
      if LLineIndex >= FLines.Count then
        Break;
      var LLineText := FLines[LLineIndex];
      var LStartCol := SnapColToBoundary(LLineText, FLeftCol);
      var LVisible := TTuiAnsi.TruncateToWidth(
        Copy(LLineText, LStartCol + 1, MaxInt), ARect.Width);
      if LVisible <> '' then
        ACanvas.WriteAt(ARect.Left, ARect.Top + LRow, LVisible, LBase);
    end;

    // Draw block cursor when focused and editable
    if Focused and not FReadOnly then
    begin
      var LCursorScreenRow := FCursorRow - FTopLine;
      var LCursorScreenCol := FCursorCol - FLeftCol;
      if (LCursorScreenRow >= 0) and (LCursorScreenRow < ARect.Height) and
         (LCursorScreenCol >= 0) and (LCursorScreenCol < ARect.Width) then
      begin
        var LCursorLine := FLines[FCursorRow];
        // Highlight the whole cluster under the cursor, not just its first
        // code unit, so the inverse-video block covers the entire emoji.
        var LCursorText: string;
        if FCursorCol < Length(LCursorLine) then
          LCursorText := Copy(LCursorLine, FCursorCol + 1,
            TTuiUnicode.GraphemeLengthAt(LCursorLine, FCursorCol + 1))
        else
          LCursorText := ' ';
        ACanvas.WriteAt(
          ARect.Left + LCursorScreenCol,
          ARect.Top + LCursorScreenRow,
          LCursorText,
          FCursorStyle);
      end;
    end;
  finally
    ACanvas.PopClip;
  end;
end;

function TTuiTextArea.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;

  case AEvent.Key.Code of
    kcChar, kcSpace:
      if not FReadOnly then
      begin
        if (AEvent.Key.Code = kcSpace) or AEvent.Key.IsPrintable then
        begin
          // CharText may span two code units (emoji beyond the BMP).
          InsertText(AEvent.Key.CharText);
          if Assigned(FOnTextChanged) then
            FOnTextChanged(GetText);
          Invalidate;
          Result := True;
        end;
      end;

    kcEnter:
      if not FReadOnly then
      begin
        // Split current line at cursor position
        var LCurrentLine := FLines[FCursorRow];
        var LTail := Copy(LCurrentLine, FCursorCol + 1, MaxInt);
        FLines[FCursorRow] := Copy(LCurrentLine, 1, FCursorCol);
        FLines.Insert(FCursorRow + 1, LTail);
        Inc(FCursorRow);
        FCursorCol := 0;
        if Assigned(FOnTextChanged) then
          FOnTextChanged(GetText);
        Invalidate;
        Result := True;
      end;

    kcBackspace:
      if not FReadOnly then
      begin
        if FCursorCol > 0 then
        begin
          // Delete the whole grapheme cluster to the left on the same line
          var LLine := FLines[FCursorRow];
          var LStart := TTuiUnicode.PrevGraphemeBoundary(LLine, FCursorCol + 1);
          Delete(LLine, LStart, FCursorCol + 1 - LStart);
          FLines[FCursorRow] := LLine;
          FCursorCol := LStart - 1;
          if Assigned(FOnTextChanged) then
            FOnTextChanged(GetText);
          Invalidate;
          Result := True;
        end
        else if FCursorRow > 0 then
        begin
          // Merge current line into the previous one
          var LPrevLen := Length(FLines[FCursorRow - 1]);
          FLines[FCursorRow - 1] := FLines[FCursorRow - 1] + FLines[FCursorRow];
          FLines.Delete(FCursorRow);
          Dec(FCursorRow);
          FCursorCol := LPrevLen;
          if Assigned(FOnTextChanged) then
            FOnTextChanged(GetText);
          Invalidate;
          Result := True;
        end;
      end;

    kcDelete:
      if not FReadOnly then
      begin
        var LLine := FLines[FCursorRow];
        if FCursorCol < Length(LLine) then
        begin
          // Delete the whole grapheme cluster to the right on the same line
          Delete(LLine, FCursorCol + 1,
            TTuiUnicode.GraphemeLengthAt(LLine, FCursorCol + 1));
          FLines[FCursorRow] := LLine;
          if Assigned(FOnTextChanged) then
            FOnTextChanged(GetText);
          Invalidate;
          Result := True;
        end
        else if FCursorRow < FLines.Count - 1 then
        begin
          // Merge next line into the current one
          FLines[FCursorRow] := LLine + FLines[FCursorRow + 1];
          FLines.Delete(FCursorRow + 1);
          if Assigned(FOnTextChanged) then
            FOnTextChanged(GetText);
          Invalidate;
          Result := True;
        end;
      end;

    kcLeft:
      begin
        if FCursorCol > 0 then
          FCursorCol :=
            TTuiUnicode.PrevGraphemeBoundary(FLines[FCursorRow], FCursorCol + 1) - 1
        else if FCursorRow > 0 then
        begin
          Dec(FCursorRow);
          FCursorCol := Length(FLines[FCursorRow]);
        end;
        Invalidate;
        Result := True;
      end;

    kcRight:
      begin
        var LLineLen := Length(FLines[FCursorRow]);
        if FCursorCol < LLineLen then
          FCursorCol :=
            TTuiUnicode.NextGraphemeBoundary(FLines[FCursorRow], FCursorCol + 1) - 1
        else if FCursorRow < FLines.Count - 1 then
        begin
          Inc(FCursorRow);
          FCursorCol := 0;
        end;
        Invalidate;
        Result := True;
      end;

    kcUp:
      begin
        if FCursorRow > 0 then
        begin
          Dec(FCursorRow);
          ClampCursor;
        end;
        Invalidate;
        Result := True;
      end;

    kcDown:
      begin
        if FCursorRow < FLines.Count - 1 then
        begin
          Inc(FCursorRow);
          ClampCursor;
        end;
        Invalidate;
        Result := True;
      end;

    kcHome:
      begin
        FCursorCol := 0;
        Invalidate;
        Result := True;
      end;

    kcEnd:
      begin
        FCursorCol := Length(FLines[FCursorRow]);
        Invalidate;
        Result := True;
      end;

    kcPageUp:
      begin
        FCursorRow := Max(0, FCursorRow - FViewHeight);
        ClampCursor;
        Invalidate;
        Result := True;
      end;

    kcPageDown:
      begin
        FCursorRow := Min(FLines.Count - 1, FCursorRow + FViewHeight);
        ClampCursor;
        Invalidate;
        Result := True;
      end;
  end;
end;

procedure TTuiTextArea.SetFocusedStyle(const AValue: TTuiStyle);
begin
  if FFocusedStyle = AValue then
    Exit;
  FFocusedStyle := AValue;
  FFocusedStyleOverride := True;
  Invalidate;
end;

procedure TTuiTextArea.SetNormalStyle(const AValue: TTuiStyle);
begin
  if FNormalStyle = AValue then
    Exit;
  FNormalStyle := AValue;
  FNormalStyleOverride := True;
  Invalidate;
end;

procedure TTuiTextArea.SetPlaceholder(const AValue: string);
begin
  if FPlaceholder = AValue then
    Exit;
  FPlaceholder := AValue;
  Invalidate;
end;

procedure TTuiTextArea.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then
    Exit;
  FReadOnly := AValue;
  Invalidate;
end;

procedure TTuiTextArea.SetText(const AValue: string);
begin
  FLines.Text := AValue;
  if FLines.Count = 0 then
    FLines.Add('');
  FCursorRow := 0;
  FCursorCol := 0;
  FTopLine := 0;
  FLeftCol := 0;
  if Assigned(FOnTextChanged) then
    FOnTextChanged(GetText);
  Invalidate;
end;

end.
