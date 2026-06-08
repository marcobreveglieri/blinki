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
    procedure SetText(const AValue: string);
    procedure SetCursorPos(AValue: Integer);
    procedure SetPlaceholder(const AValue: string);
    procedure SetPasswordChar(AValue: Char);
    procedure SetMaxLength(AValue: Integer);
    procedure SetNormalStyle(const AValue: TTuiStyle);
    procedure SetFocusedStyle(const AValue: TTuiStyle);
    procedure RebuildStyles;
    procedure ClampViewOffset(AViewWidth: Integer);
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
    ///   Cursor position (0 = before the first character, Length(Text) = after the last one).
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
  Blinki.Core.Input;

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
    Result := '';
    for var LIndex := 1 to Length(FText) do
      Result := Result + FPasswordChar;
  end
  else
    Result := FText;
end;

procedure TTuiTextInput.ClampViewOffset(AViewWidth: Integer);
begin
  if AViewWidth <= 0 then
    Exit;
  // cursor is too far left relative to the viewport
  if FCursorPos < FViewOffset then
    FViewOffset := FCursorPos;
  // cursor is too far right relative to the viewport
  if FCursorPos >= FViewOffset + AViewWidth then
    FViewOffset := FCursorPos - AViewWidth + 1;
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

  if (FText = '') and not Focused then
  begin
    // show placeholder
    var LPlaceholder := Copy(FPlaceholder, 1, ARect.Width);
    ACanvas.WriteAt(ARect.Left, ARect.Top, LPlaceholder, FPlaceholderStyle);
    Exit;
  end;

  var LDisplay := BuildDisplay;
  ClampViewOffset(ARect.Width);
  var LVisible := Copy(LDisplay, FViewOffset + 1, ARect.Width);
  ACanvas.WriteAt(ARect.Left, ARect.Top, LVisible, LBase);

  if Focused then
  begin
    var LCursorX := ARect.Left + (FCursorPos - FViewOffset);
    if (LCursorX >= ARect.Left) and (LCursorX < ARect.Right) then
    begin
      var LCursorCh: Char;
      if FCursorPos < Length(LDisplay) then
        LCursorCh := LDisplay[FCursorPos + 1]
      else
        LCursorCh := ' ';
      ACanvas.WriteAt(LCursorX, ARect.Top, LCursorCh, FCursorStyle);
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
      if ((AEvent.Key.Code = kcSpace) or AEvent.Key.IsPrintable) and
         ((FMaxLength = 0) or (Length(FText) < FMaxLength)) then
      begin
        if AEvent.Key.Code = kcSpace then
          Insert(' ', FText, FCursorPos + 1)
        else
          Insert(AEvent.Key.Character, FText, FCursorPos + 1);
        Inc(FCursorPos);
        if Assigned(FOnTextChanged) then
          FOnTextChanged(FText);
        Invalidate;
        Result := True;
      end;

    kcBackspace:
      if FCursorPos > 0 then
      begin
        Delete(FText, FCursorPos, 1);
        Dec(FCursorPos);
        if Assigned(FOnTextChanged) then
          FOnTextChanged(FText);
        Invalidate;
        Result := True;
      end;

    kcDelete:
      if FCursorPos < Length(FText) then
      begin
        Delete(FText, FCursorPos + 1, 1);
        if Assigned(FOnTextChanged) then
          FOnTextChanged(FText);
        Invalidate;
        Result := True;
      end;

    kcLeft:
      begin
        var LNewPos := FCursorPos - 1;
        if LNewPos < 0 then
          LNewPos := 0;
        if LNewPos <> FCursorPos then
        begin
          FCursorPos := LNewPos;
          Invalidate;
        end;
        Result := True;
      end;

    kcRight:
      begin
        var LNewPos := FCursorPos + 1;
        if LNewPos > Length(FText) then
          LNewPos := Length(FText);
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
  FViewOffset := 0;
  Invalidate;
end;

procedure TTuiTextInput.SetCursorPos(AValue: Integer);
begin
  if AValue < 0 then
    AValue := 0;
  if AValue > Length(FText) then
    AValue := Length(FText);
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
    FText := Copy(FText, 1, FMaxLength);
    if FCursorPos > FMaxLength then
      FCursorPos := FMaxLength;
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
