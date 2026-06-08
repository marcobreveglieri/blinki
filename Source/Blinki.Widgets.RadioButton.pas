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
{   Unit:        Blinki.Widgets.RadioButton.pas                  }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiRadioButton: single-selection radio button for a group.
/// </summary>
unit Blinki.Widgets.RadioButton;

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

{ TTuiRadioButton }

  /// <summary>
  ///   Single-line radio button: Unicode glyph + space + caption.
  ///   Belongs to a group (Group: string); when the state changes to Checked=True,
  ///   all other TTuiRadioButton instances sharing the same Group under the common
  ///   parent are automatically unchecked.
  ///   Pressing Space or Enter selects the radio button (if not already selected).
  ///   OnSelect is invoked when this widget becomes selected.
  ///   Becomes focusable in DoInit.
  /// </summary>
  TTuiRadioButton = class(TTuiWidget)
  strict private
    FCaption: string;
    FChecked: Boolean;
    FGroup: string;
    FOnSelect: TProc;
    FNormalStyle: TTuiStyle;
    FFocusedStyle: TTuiStyle;
    FNormalStyleOverride: Boolean;
    FFocusedStyleOverride: Boolean;
    procedure SetCaption(const AValue: string);
    procedure SetChecked(AValue: Boolean);
    procedure SetGroup(const AValue: string);
    procedure SetNormalStyle(const AValue: TTuiStyle);
    procedure SetFocusedStyle(const AValue: TTuiStyle);
    procedure RebuildStyles;
    /// <summary>
    /// Unchecks the radio button without invoking OnSelect (used by group logic).
    /// </summary>
    procedure UncheckSilent;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function  DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    /// Creates the radio button. Initial Checked state: False. Becomes focusable after Init.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    /// Label text displayed next to the glyph.
    /// </summary>
    property Caption: string read FCaption write SetCaption;
    /// <summary>
    /// Current selection state.
    /// </summary>
    property Checked: Boolean read FChecked write SetChecked;
    /// <summary>
    ///   Name of the belonging group. Radio buttons sharing the same Group and the same
    ///   parent are mutually exclusive. Empty string means anonymous group.
    /// </summary>
    property Group: string read FGroup write SetGroup;
    /// <summary>
    /// Invoked when this radio button becomes selected (Checked transitions from False to True).
    /// </summary>
    property OnSelect: TProc read FOnSelect write FOnSelect;
    /// <summary>
    /// Style applied when the widget is unfocused. Assigning it disables automatic theme updates.
    /// </summary>
    property NormalStyle: TTuiStyle read FNormalStyle write SetNormalStyle;
    /// <summary>
    /// Style applied when the widget is focused. Assigning it disables automatic theme updates.
    /// </summary>
    property FocusedStyle: TTuiStyle read FFocusedStyle write SetFocusedStyle;
  end;

implementation

uses
  System.Generics.Collections,
  Blinki.Core.Input;

const

  /// <summary>
  /// Unicode glyph for a checked radio button (U+25C9).
  /// </summary>
  CRadioChecked   = #$25C9;

  /// <summary>
  /// Unicode glyph for an unchecked radio button (U+25CB).
  /// </summary>
  CRadioUnchecked = #$25CB;

{ TTuiRadioButton }

constructor TTuiRadioButton.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  RebuildStyles;
end;

procedure TTuiRadioButton.RebuildStyles;
begin
  if not FNormalStyleOverride then
    FNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  if not FFocusedStyleOverride then
    FFocusedStyle := TTuiStyle.Create(Theme.Primary, Theme.Surface);
end;

procedure TTuiRadioButton.DoInit;
begin
  SetFocusable(True);
end;

procedure TTuiRadioButton.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TTuiRadioButton.UncheckSilent;
begin
  if not FChecked then
    Exit;
  FChecked := False;
  Invalidate;
end;

procedure TTuiRadioButton.SetChecked(AValue: Boolean);
begin
  if FChecked = AValue then
    Exit;
  FChecked := AValue;
  if FChecked and Assigned(Parent) then
  begin
    for var LIndex := 0 to Parent.ChildCount - 1 do
    begin
      var LSib := Parent.Children[LIndex];
      if (LSib <> Self) and (LSib is TTuiRadioButton) then
      begin
        var LRadio := TTuiRadioButton(LSib);
        if LRadio.FGroup = FGroup then
          LRadio.UncheckSilent;
      end;
    end;
    if Assigned(FOnSelect) then
      FOnSelect;
  end;
  Invalidate;
end;

procedure TTuiRadioButton.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
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
    LLine := CRadioChecked + ' ' + FCaption
  else
    LLine := CRadioUnchecked + ' ' + FCaption;

  if Length(LLine) > ARect.Width then
    LLine := Copy(LLine, 1, ARect.Width);

  ACanvas.WriteAt(ARect.Left, ARect.Top, LLine, LStyle);
end;

function TTuiRadioButton.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  if (AEvent.Key.Code = kcSpace) or (AEvent.Key.Code = kcEnter) then
  begin
    if not FChecked then
      SetChecked(True);
    Result := True;
  end;
end;

procedure TTuiRadioButton.SetCaption(const AValue: string);
begin
  if FCaption = AValue then
    Exit;
  FCaption := AValue;
  Invalidate;
end;

procedure TTuiRadioButton.SetGroup(const AValue: string);
begin
  if FGroup = AValue then
    Exit;
  FGroup := AValue;
end;

procedure TTuiRadioButton.SetNormalStyle(const AValue: TTuiStyle);
begin
  if FNormalStyle = AValue then
    Exit;
  FNormalStyle := AValue;
  FNormalStyleOverride := True;
  Invalidate;
end;

procedure TTuiRadioButton.SetFocusedStyle(const AValue: TTuiStyle);
begin
  if FFocusedStyle = AValue then
    Exit;
  FFocusedStyle := AValue;
  FFocusedStyleOverride := True;
  Invalidate;
end;

end.
