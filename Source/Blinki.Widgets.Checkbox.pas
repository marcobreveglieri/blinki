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
{   Unit:        Blinki.Widgets.Checkbox.pas                     }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiCheckbox: single-line check box with label text.
/// </summary>
unit Blinki.Widgets.Checkbox;

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

{ TTuiCheckbox }

  /// <summary>
  ///   Single-line check box: renders a Unicode glyph + space + caption.
  ///   Pressing Space or Enter toggles the state and fires OnToggle.
  ///   When focused, the text is drawn with the theme Primary colour.
  ///   Becomes focusable in DoInit.
  /// </summary>
  TTuiCheckbox = class(TTuiWidget)
  strict private
    FCaption: string;
    FChecked: Boolean;
    FOnToggle: TProc<Boolean>;
    FNormalStyle: TTuiStyle;
    FFocusedStyle: TTuiStyle;
    FNormalStyleOverride: Boolean;
    FFocusedStyleOverride: Boolean;
    procedure SetCaption(const AValue: string);
    procedure SetChecked(AValue: Boolean);
    procedure SetNormalStyle(const AValue: TTuiStyle);
    procedure SetFocusedStyle(const AValue: TTuiStyle);
    procedure RebuildStyles;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function  DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    /// Creates the check box. Initial Checked value: False. Becomes focusable after Init.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    /// Label text displayed next to the glyph.
    /// </summary>
    property Caption: string read FCaption write SetCaption;
    /// <summary>
    /// Current checked state of the check box.
    /// </summary>
    property Checked: Boolean read FChecked write SetChecked;
    /// <summary>
    /// Fired when the state changes; receives the new Checked value.
    /// </summary>
    property OnToggle: TProc<Boolean> read FOnToggle write FOnToggle;
    /// <summary>
    /// Style used when the widget is unfocused. Assigning it disables automatic theme updates.
    /// </summary>
    property NormalStyle: TTuiStyle read FNormalStyle write SetNormalStyle;
    /// <summary>
    /// Style used when the widget is focused. Assigning it disables automatic theme updates.
    /// </summary>
    property FocusedStyle: TTuiStyle read FFocusedStyle write SetFocusedStyle;
  end;

implementation

uses
  Blinki.Core.Input;

const

  /// <summary>
  /// Unicode ballot box checked glyph (U+2611).
  /// </summary>
  CCheckboxChecked = #$2611;

  /// <summary>
  /// Unicode ballot box unchecked glyph (U+2610).
  /// </summary>
  CCheckboxUnchecked = #$2610;

{ TTuiCheckbox }

constructor TTuiCheckbox.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  RebuildStyles;
end;

procedure TTuiCheckbox.RebuildStyles;
begin
  if not FNormalStyleOverride then
    FNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  if not FFocusedStyleOverride then
    FFocusedStyle := TTuiStyle.Create(Theme.Primary, Theme.Surface);
end;

procedure TTuiCheckbox.DoInit;
begin
  SetFocusable(True);
end;

procedure TTuiCheckbox.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TTuiCheckbox.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  var LStyle: TTuiStyle;
  if Focused then
    LStyle := FFocusedStyle
  else
    LStyle := FNormalStyle;

  ACanvas.FillRect(ARect, ' ', LStyle);

  var LLine: string;
  if FChecked then
    LLine := CCheckboxChecked + ' ' + FCaption
  else
    LLine := CCheckboxUnchecked + ' ' + FCaption;

  if Length(LLine) > ARect.Width then
    LLine := Copy(LLine, 1, ARect.Width);

  ACanvas.WriteAt(ARect.Left, ARect.Top, LLine, LStyle);
end;

function TTuiCheckbox.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  if (AEvent.Key.Code = kcSpace) or (AEvent.Key.Code = kcEnter) then
  begin
    SetChecked(not FChecked);
    Result := True;
  end;
end;

procedure TTuiCheckbox.SetChecked(AValue: Boolean);
begin
  if FChecked = AValue then
    Exit;
  FChecked := AValue;
  if Assigned(FOnToggle) then
    FOnToggle(FChecked);
  Invalidate;
end;

procedure TTuiCheckbox.SetCaption(const AValue: string);
begin
  if FCaption = AValue then
    Exit;
  FCaption := AValue;
  Invalidate;
end;

procedure TTuiCheckbox.SetNormalStyle(const AValue: TTuiStyle);
begin
  if FNormalStyle = AValue then
    Exit;
  FNormalStyle := AValue;
  FNormalStyleOverride := True;
  Invalidate;
end;

procedure TTuiCheckbox.SetFocusedStyle(const AValue: TTuiStyle);
begin
  if FFocusedStyle = AValue then
    Exit;
  FFocusedStyle := AValue;
  FFocusedStyleOverride := True;
  Invalidate;
end;

end.
