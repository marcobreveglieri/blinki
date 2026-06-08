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
{   Unit:        Blinki.Widgets.Select.pas                       }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
/// TTuiSelect widget: always-visible selection list with keyboard navigation.
/// </summary>
unit Blinki.Widgets.Select;

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

{ TTuiSelect }

  /// <summary>
  /// Single-choice, always-visible selection list. Navigates with Up/Down arrows,
  /// Home/End, PgUp/PgDn. The selected item is highlighted with a distinct style
  /// (SelectedStyle when unfocused, SelectedFocusedStyle when focused).
  /// Height is dictated by the parent container's layout constraint.
  /// OnChange is invoked when ItemIndex changes. Becomes focusable in DoInit.
  /// </summary>
  TTuiSelect = class(TTuiWidget)
  strict private
    FItems: TStringList;
    FItemIndex: Integer;
    FViewOffset: Integer;
    FLastViewHeight: Integer;
    FOnChange: TProc<Integer>;
    FNormalStyle: TTuiStyle;
    FSelectedStyle: TTuiStyle;
    FSelectedFocusedStyle: TTuiStyle;
    FNormalStyleOverride: Boolean;
    FSelectedStyleOverride: Boolean;
    FSelectedFocusedStyleOverride: Boolean;
    procedure SetItemIndex(AValue: Integer);
    procedure SetNormalStyle(const AValue: TTuiStyle);
    procedure SetSelectedStyle(const AValue: TTuiStyle);
    procedure SetSelectedFocusedStyle(const AValue: TTuiStyle);
    procedure RebuildStyles;
    procedure AdjustViewOffset;
    function  GetItems: TStrings;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function  DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    /// Creates the widget. Initial ItemIndex: -1 (no selection if empty,
    /// 0 otherwise after Populate).
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <inheritdoc/>
    destructor Destroy; override;
    /// <summary>
    /// List of available items. Add or remove items, then assign ItemIndex accordingly.
    /// </summary>
    property Items: TStrings read GetItems;
    /// <summary>
    /// Index of the selected item (-1 if none). The setter clamps the value to the valid
    /// range and updates the viewport accordingly.
    /// </summary>
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
    /// <summary>
    /// Invoked when the selection changes; receives the new index.
    /// </summary>
    property OnChange: TProc<Integer> read FOnChange write FOnChange;
    /// <summary>
    /// Style for unselected rows. Assigning this property disables theme-driven updates.
    /// </summary>
    property NormalStyle: TTuiStyle read FNormalStyle write SetNormalStyle;
    /// <summary>
    /// Style for the selected row when unfocused. Assigning this property disables
    /// theme-driven updates.
    /// </summary>
    property SelectedStyle: TTuiStyle read FSelectedStyle write SetSelectedStyle;
    /// <summary>
    /// Style for the selected row when focused. Assigning this property disables
    /// theme-driven updates.
    /// </summary>
    property SelectedFocusedStyle: TTuiStyle
      read FSelectedFocusedStyle write SetSelectedFocusedStyle;
  end;

implementation

uses
  System.Math,
  Blinki.Core.Input;

{ TTuiSelect }

constructor TTuiSelect.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FItems := TStringList.Create;
  FItemIndex := -1;
  RebuildStyles;
end;

destructor TTuiSelect.Destroy;
begin
  if Assigned(FItems) then
    FreeAndNil(FItems);
  inherited Destroy;
end;

function TTuiSelect.GetItems: TStrings;
begin
  Result := FItems;
end;

procedure TTuiSelect.RebuildStyles;
begin
  if not FNormalStyleOverride then
    FNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  if not FSelectedStyleOverride then
    FSelectedStyle := TTuiStyle.Create(Theme.Text, Theme.Border);
  if not FSelectedFocusedStyleOverride then
    FSelectedFocusedStyle := TTuiStyle.Create(Theme.Background, Theme.Primary);
end;

procedure TTuiSelect.DoInit;
begin
  SetFocusable(True);
  if (FItemIndex = -1) and (FItems.Count > 0) then
    FItemIndex := 0;
end;

procedure TTuiSelect.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TTuiSelect.AdjustViewOffset;
begin
  if FLastViewHeight <= 0 then
    Exit;
  if FItemIndex < FViewOffset then
    FViewOffset := FItemIndex;
  if FItemIndex >= FViewOffset + FLastViewHeight then
    FViewOffset := FItemIndex - FLastViewHeight + 1;
  if FViewOffset < 0 then
    FViewOffset := 0;
end;

procedure TTuiSelect.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  FLastViewHeight := ARect.Height;
  AdjustViewOffset;

  ACanvas.FillRect(ARect, ' ', FNormalStyle);

  for var LIndex := FViewOffset to FViewOffset + ARect.Height - 1 do
  begin
    if LIndex >= FItems.Count then
      Break;

    var LRow := ARect.Top + (LIndex - FViewOffset);
    var LRowRect := TRect.Create(ARect.Left, LRow, ARect.Right, LRow + 1);

    var LStyle: TTuiStyle;
    if LIndex = FItemIndex then
    begin
      if Focused then
        LStyle := FSelectedFocusedStyle
      else
        LStyle := FSelectedStyle;
    end
    else
      LStyle := FNormalStyle;

    ACanvas.FillRect(LRowRect, ' ', LStyle);

    var LText := FItems[LIndex];
    if Length(LText) > ARect.Width then
      LText := Copy(LText, 1, ARect.Width);
    ACanvas.WriteAt(ARect.Left, LRow, LText, LStyle);
  end;
end;

function TTuiSelect.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;

  // Mouse click: map the clicked row back to an item index and select it.
  // Row layout (from DoRender): row Y = ARect.Top + (LIndex - FViewOffset),
  // so the inverse is: LIndex = FViewOffset + (Y - LastRect.Top).
  if AEvent.Kind = ekMouse then
  begin
    if (AEvent.Mouse.Kind = mekDown) and (FItems.Count > 0) then
    begin
      var LItemIndex := FViewOffset + (AEvent.Mouse.Y - LastRect.Top);
      if (LItemIndex >= 0) and (LItemIndex < FItems.Count) then
        SetItemIndex(LItemIndex);  // SetItemIndex already fires OnChange
      Result := True;
    end;
    Exit;
  end;

  if AEvent.Kind <> ekKey then
    Exit;
  if FItems.Count = 0 then
    Exit;

  var LPageStep := Max(1, FLastViewHeight);

  case AEvent.Key.Code of
    kcUp:
      begin
        SetItemIndex(Max(0, FItemIndex - 1));
        Result := True;
      end;
    kcDown:
      begin
        SetItemIndex(Min(FItems.Count - 1, FItemIndex + 1));
        Result := True;
      end;
    kcHome:
      begin
        SetItemIndex(0);
        Result := True;
      end;
    kcEnd:
      begin
        SetItemIndex(FItems.Count - 1);
        Result := True;
      end;
    kcPageUp:
      begin
        SetItemIndex(Max(0, FItemIndex - LPageStep));
        Result := True;
      end;
    kcPageDown:
      begin
        SetItemIndex(Min(FItems.Count - 1, FItemIndex + LPageStep));
        Result := True;
      end;
  end;
end;

procedure TTuiSelect.SetItemIndex(AValue: Integer);
begin
  if FItems.Count = 0 then
  begin
    if FItemIndex <> -1 then
    begin
      FItemIndex := -1;
      Invalidate;
    end;
    Exit;
  end;

  if AValue < 0 then
    AValue := 0;
  if AValue >= FItems.Count then
    AValue := FItems.Count - 1;

  if FItemIndex = AValue then
    Exit;
  FItemIndex := AValue;
  AdjustViewOffset;
  if Assigned(FOnChange) then
    FOnChange(FItemIndex);
  Invalidate;
end;

procedure TTuiSelect.SetNormalStyle(const AValue: TTuiStyle);
begin
  if FNormalStyle = AValue then
    Exit;
  FNormalStyle := AValue;
  FNormalStyleOverride := True;
  Invalidate;
end;

procedure TTuiSelect.SetSelectedStyle(const AValue: TTuiStyle);
begin
  if FSelectedStyle = AValue then
    Exit;
  FSelectedStyle := AValue;
  FSelectedStyleOverride := True;
  Invalidate;
end;

procedure TTuiSelect.SetSelectedFocusedStyle(const AValue: TTuiStyle);
begin
  if FSelectedFocusedStyle = AValue then
    Exit;
  FSelectedFocusedStyle := AValue;
  FSelectedFocusedStyleOverride := True;
  Invalidate;
end;

end.
