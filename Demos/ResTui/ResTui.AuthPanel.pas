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
{   Unit:        ResTui.AuthPanel.pas                            }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Authentication panel widget for the ResTui demo.
///   Displays and edits the authentication settings of a REST request:
///   a type selector (None / Bearer / Basic / API Key) and contextual
///   input fields for the selected strategy.
/// </summary>
unit ResTui.AuthPanel;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Widget,
  ResTui.Model;

type

{ TResTuiAuthPanel }

  /// <summary>
  ///   Custom widget that renders and edits authentication parameters.
  ///   The auth type is cycled with Left/Right; fields are selected with
  ///   Up/Down; printable characters and Backspace edit the active field.
  /// </summary>
  TResTuiAuthPanel = class(TTuiWidget)
  strict private
    // Auth kind and field values
    FAuthKind: TResTuiAuthKind;
    FFieldIndex: Integer;
    FHeaderName: string;
    FHeaderValue: string;
    FPassword: string;
    FToken: string;
    FUsername: string;
    // Helper: returns the number of editable fields for the current auth kind
    function FieldCount: Integer;
    // Helper: appends a labelled field row to the canvas
    procedure RenderField(const ACanvas: TTuiCanvas; AX, AY, AWidth: Integer;
      const ALabel, AValue: string; AActive: Boolean; AMask: Boolean);
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
  public
    /// <summary>
    ///   Creates the auth panel widget. AParent receives ownership.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Loads auth settings from the given record into the widget state.
    /// </summary>
    procedure LoadAuth(const AAuth: TResTuiAuth);
    /// <summary>
    ///   Builds and returns a TResTuiAuth record from the current widget state.
    /// </summary>
    function CollectAuth: TResTuiAuth;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  Blinki.Core.Ansi,
  Blinki.Core.Geometry,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  ResTui.Consts;

{ Helpers }

const
  // Display names for each auth kind
  CAuthKindNames: array[TResTuiAuthKind] of string = (
    'None', 'Bearer', 'Basic', 'API Key'
  );

{ TResTuiAuthPanel }

constructor TResTuiAuthPanel.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FAuthKind := akNone;
  // FFieldIndex defaults to 0, which is correct
  // All string fields default to ''
end;

procedure TResTuiAuthPanel.DoInit;
begin
  SetFocusable(True);
end;

function TResTuiAuthPanel.FieldCount: Integer;
begin
  case FAuthKind of
    akNone:
      Result := 0;
    akBearer:
      Result := 1; // Token
    akBasic:
      Result := 2; // Username, Password
    akApiKey:
      Result := 2; // HeaderName, HeaderValue
  else
    Result := 0;
  end;
end;

procedure TResTuiAuthPanel.RenderField(const ACanvas: TTuiCanvas;
  AX, AY, AWidth: Integer; const ALabel, AValue: string;
  AActive: Boolean; AMask: Boolean);
begin
  var LLabelStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
  var LNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  var LActiveStyle := TTuiStyle.Create(Theme.Text, Theme.Primary);

  var LLabelText := ALabel + ': ';
  ACanvas.WriteAt(AX, AY, LLabelText, LLabelStyle);

  var LValueX := AX + Length(LLabelText);
  var LMaxValueWidth := AWidth - Length(LLabelText);
  if LMaxValueWidth <= 0 then
    Exit;

  var LDisplayValue: string;
  if AMask then
    LDisplayValue := StringOfChar('*', Length(AValue))
  else
    LDisplayValue := AValue;

  // Truncate if too long (show the end of the string so cursor is visible)
  if Length(LDisplayValue) > LMaxValueWidth - 1 then
    LDisplayValue := Copy(LDisplayValue, Length(LDisplayValue) - LMaxValueWidth + 2, LMaxValueWidth - 1);

  ACanvas.WriteAt(LValueX, AY, LDisplayValue, LNormalStyle);

  // Draw cursor character (inverse) after the value if this field is active
  if AActive and Focused then
  begin
    var LCursorX := LValueX + Length(LDisplayValue);
    if LCursorX < AX + AWidth then
      ACanvas.WriteAt(LCursorX, AY, ' ', LActiveStyle);
  end;
end;

procedure TResTuiAuthPanel.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  var LInner := ARect.Interior;
  if LInner.IsEmpty then
    Exit;

  var LBorderColor := CColorBorderNormal;
  if Focused then
    LBorderColor := CColorBorderFocus;
  var LBorderStyle := TTuiStyle.Create(LBorderColor, Theme.Surface);

  // Draw outer box with title
  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(Theme.Text, Theme.Surface));
  ACanvas.DrawBox(ARect, bsRounded, CPanelAuth, LBorderStyle);

  var LWidth := LInner.Width;
  var LX := LInner.Left;
  var LY := LInner.Top;

  // Row 0: auth type selector
  var LLabelStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
  var LNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  var LSelectedStyle := TTuiStyle.Create(Theme.Surface, Theme.Primary);

  ACanvas.WriteAt(LX, LY, 'Auth type: ', LLabelStyle);
  var LTypeX := LX + 11;

  // Render each auth kind option, highlighting the selected one
  for var LKind := Low(TResTuiAuthKind) to High(TResTuiAuthKind) do
  begin
    var LName := ' ' + CAuthKindNames[LKind] + ' ';
    if LKind = FAuthKind then
      ACanvas.WriteAt(LTypeX, LY, LName, LSelectedStyle)
    else
      ACanvas.WriteAt(LTypeX, LY, LName, LNormalStyle);
    Inc(LTypeX, Length(LName));
    if LKind < High(TResTuiAuthKind) then
    begin
      ACanvas.WriteAt(LTypeX, LY, '|', LLabelStyle);
      Inc(LTypeX);
    end;
  end;

  // Rows 2+: contextual fields
  if LInner.Height < 3 then
    Exit;

  var LFieldY := LY + 2;

  case FAuthKind of
    akNone:
    begin
      var LHintStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
      ACanvas.WriteAt(LX, LFieldY, 'No authentication', LHintStyle);
    end;

    akBearer:
    begin
      RenderField(ACanvas, LX, LFieldY, LWidth, 'Token', FToken,
        (FFieldIndex = 0), False);
    end;

    akBasic:
    begin
      RenderField(ACanvas, LX, LFieldY, LWidth, 'Username', FUsername,
        (FFieldIndex = 0), False);
      if LFieldY + 1 < LInner.Bottom then
        RenderField(ACanvas, LX, LFieldY + 1, LWidth, 'Password', FPassword,
          (FFieldIndex = 1), True);
    end;

    akApiKey:
    begin
      RenderField(ACanvas, LX, LFieldY, LWidth, 'Header name', FHeaderName,
        (FFieldIndex = 0), False);
      if LFieldY + 1 < LInner.Bottom then
        RenderField(ACanvas, LX, LFieldY + 1, LWidth, 'Header value', FHeaderValue,
          (FFieldIndex = 1), False);
    end;
  end;
end;

function TResTuiAuthPanel.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;

  var LKey := AEvent.Key;

  case LKey.Code of
    kcLeft:
    begin
      // Cycle auth kind backward
      if FAuthKind = Low(TResTuiAuthKind) then
        FAuthKind := High(TResTuiAuthKind)
      else
        FAuthKind := Pred(FAuthKind);
      // Clamp field index to valid range
      if FFieldIndex >= FieldCount then
        FFieldIndex := 0;
      Invalidate;
      Result := True;
    end;

    kcRight:
    begin
      // Cycle auth kind forward
      if FAuthKind = High(TResTuiAuthKind) then
        FAuthKind := Low(TResTuiAuthKind)
      else
        FAuthKind := Succ(FAuthKind);
      // Clamp field index to valid range
      if FFieldIndex >= FieldCount then
        FFieldIndex := 0;
      Invalidate;
      Result := True;
    end;

    kcUp:
    begin
      if FieldCount > 0 then
      begin
        if FFieldIndex > 0 then
          Dec(FFieldIndex)
        else
          FFieldIndex := FieldCount - 1;
        Invalidate;
        Result := True;
      end;
    end;

    kcDown:
    begin
      if FieldCount > 0 then
      begin
        if FFieldIndex < FieldCount - 1 then
          Inc(FFieldIndex)
        else
          FFieldIndex := 0;
        Invalidate;
        Result := True;
      end;
    end;

    kcBackspace:
    begin
      if FieldCount > 0 then
      begin
        case FAuthKind of
          akBearer:
            if FFieldIndex = 0 then
            begin
              if Length(FToken) > 0 then
              begin
                Delete(FToken, Length(FToken), 1);
                Invalidate;
              end;
            end;
          akBasic:
            if FFieldIndex = 0 then
            begin
              if Length(FUsername) > 0 then
              begin
                Delete(FUsername, Length(FUsername), 1);
                Invalidate;
              end;
            end
            else
            begin
              if Length(FPassword) > 0 then
              begin
                Delete(FPassword, Length(FPassword), 1);
                Invalidate;
              end;
            end;
          akApiKey:
            if FFieldIndex = 0 then
            begin
              if Length(FHeaderName) > 0 then
              begin
                Delete(FHeaderName, Length(FHeaderName), 1);
                Invalidate;
              end;
            end
            else
            begin
              if Length(FHeaderValue) > 0 then
              begin
                Delete(FHeaderValue, Length(FHeaderValue), 1);
                Invalidate;
              end;
            end;
        end;
        Result := True;
      end;
    end;

    kcChar:
    begin
      if LKey.IsPrintable and (FieldCount > 0) then
      begin
        case FAuthKind of
          akBearer:
            if FFieldIndex = 0 then
            begin
              FToken := FToken + LKey.CharText;
              Invalidate;
            end;
          akBasic:
            if FFieldIndex = 0 then
            begin
              FUsername := FUsername + LKey.CharText;
              Invalidate;
            end
            else
            begin
              FPassword := FPassword + LKey.CharText;
              Invalidate;
            end;
          akApiKey:
            if FFieldIndex = 0 then
            begin
              FHeaderName := FHeaderName + LKey.CharText;
              Invalidate;
            end
            else
            begin
              FHeaderValue := FHeaderValue + LKey.CharText;
              Invalidate;
            end;
        end;
        Result := True;
      end;
    end;
  end;
end;

procedure TResTuiAuthPanel.LoadAuth(const AAuth: TResTuiAuth);
begin
  FAuthKind := AAuth.Kind;
  FToken := AAuth.Token;
  FUsername := AAuth.Username;
  FPassword := AAuth.Password;
  FHeaderName := AAuth.HeaderName;
  FHeaderValue := AAuth.HeaderValue;
  FFieldIndex := 0;
  Invalidate;
end;

function TResTuiAuthPanel.CollectAuth: TResTuiAuth;
begin
  Result.Kind := FAuthKind;
  Result.Token := FToken;
  Result.Username := FUsername;
  Result.Password := FPassword;
  Result.HeaderName := FHeaderName;
  Result.HeaderValue := FHeaderValue;
end;

end.
