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
{   Unit:        Blinki.Widgets.Button.pas                       }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiButton: keyboard-activatable button (Enter/Space).
/// </summary>
unit Blinki.Widgets.Button;

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

{ TTuiButton }

  /// <summary>
  ///   Single-line button widget. Renders the caption with one-character lateral padding.
  ///   When focused, inverts the colour scheme (Background on Primary). Pressing Enter or
  ///   Space invokes OnClick. Becomes focusable during DoInit.
  /// </summary>
  TTuiButton = class(TTuiWidget)
  strict private
    FCaption: string;
    FOnClick: TProc;
    FNormalStyle: TTuiStyle;
    FFocusedStyle: TTuiStyle;
    FNormalStyleOverride: Boolean;
    FFocusedStyleOverride: Boolean;
    procedure SetCaption(const AValue: string);
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
    /// Creates the button. Becomes focusable after Init.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    /// Text displayed on the button.
    /// </summary>
    property Caption: string read FCaption write SetCaption;
    /// <summary>
    /// Invoked when the user presses Enter or Space.
    /// </summary>
    property OnClick: TProc read FOnClick write FOnClick;
    /// <summary>
    /// Style used when the button is unfocused. Assigning a value disables automatic
    /// theme-driven updates.
    /// </summary>
    property NormalStyle: TTuiStyle read FNormalStyle write SetNormalStyle;
    /// <summary>
    /// Style used when the button is focused. Assigning a value disables automatic
    /// theme-driven updates.
    /// </summary>
    property FocusedStyle: TTuiStyle read FFocusedStyle write SetFocusedStyle;
  end;

implementation

uses
  Blinki.Core.Input;

{ TTuiButton }

constructor TTuiButton.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  RebuildStyles;
end;

procedure TTuiButton.RebuildStyles;
begin
  if not FNormalStyleOverride then
    FNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  if not FFocusedStyleOverride then
    FFocusedStyle := TTuiStyle.Create(Theme.Background, Theme.Primary);
end;

procedure TTuiButton.DoInit;
begin
  SetFocusable(True);
end;

procedure TTuiButton.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TTuiButton.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  var LStyle: TTuiStyle;
  if Focused then
    LStyle := FFocusedStyle
  else
    LStyle := FNormalStyle;

  ACanvas.FillRect(ARect, ' ', LStyle);

  var LLabel := ' ' + FCaption + ' ';
  if Length(LLabel) > ARect.Width then
    LLabel := Copy(LLabel, 1, ARect.Width);

  // centre horizontally
  var LX := ARect.Left + (ARect.Width - Length(LLabel)) div 2;
  ACanvas.WriteAt(LX, ARect.Top, LLabel, LStyle);
end;

function TTuiButton.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  if (AEvent.Key.Code = kcEnter) or (AEvent.Key.Code = kcSpace) then
  begin
    if Assigned(FOnClick) then
      FOnClick();
    Result := True;
  end;
end;

procedure TTuiButton.SetCaption(const AValue: string);
begin
  if FCaption = AValue then
    Exit;
  FCaption := AValue;
  Invalidate;
end;

procedure TTuiButton.SetNormalStyle(const AValue: TTuiStyle);
begin
  if FNormalStyle = AValue then
    Exit;
  FNormalStyle := AValue;
  FNormalStyleOverride := True;
  Invalidate;
end;

procedure TTuiButton.SetFocusedStyle(const AValue: TTuiStyle);
begin
  if FFocusedStyle = AValue then
    Exit;
  FFocusedStyle := AValue;
  FFocusedStyleOverride := True;
  Invalidate;
end;

end.
