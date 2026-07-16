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
{   Unit:        Blinki.Widgets.Menu.pas                         }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TTuiMenu widget: navigable menu with items, shortcuts and separators.
/// </summary>
unit Blinki.Widgets.Menu;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget;

type

{ TTuiMenuItem }

  /// <summary>
  ///   A menu item: caption text, optional shortcut character, separator flag.
  /// </summary>
  TTuiMenuItem = record
    Caption: string;
    Shortcut: Char;
    Separator: Boolean;
  end;

{ TTuiMenu }

  /// <summary>
  ///   Single-column always-visible navigable menu. Items may have optional
  ///   shortcuts and horizontal separators. Navigate with Up/Down arrows,
  ///   Home/End, PgUp/PgDn. Pressing Enter on the highlighted item or typing
  ///   a shortcut key invokes OnSelect. OnChange signals the highlighted item
  ///   change during navigation. Becomes focusable in DoInit.
  /// </summary>
  TTuiMenu = class(TTuiWidget)
  strict private
    FItems: TList<TTuiMenuItem>;
    FItemIndex: Integer;
    FViewOffset: Integer;
    FLastViewHeight: Integer;
    FOnSelect: TProc<Integer>;
    FOnChange: TProc<Integer>;
    FNormalStyle: TTuiStyle;
    FSelectedStyle: TTuiStyle;
    FSelectedFocusedStyle: TTuiStyle;
    FSeparatorStyle: TTuiStyle;
    FNormalStyleOverride: Boolean;
    FSelectedStyleOverride: Boolean;
    FSelectedFocusedStyleOverride: Boolean;
    FSeparatorStyleOverride: Boolean;
    procedure SetItemIndex(AValue: Integer);
    procedure SetNormalStyle(const AValue: TTuiStyle);
    procedure SetSelectedStyle(const AValue: TTuiStyle);
    procedure SetSelectedFocusedStyle(const AValue: TTuiStyle);
    procedure SetSeparatorStyle(const AValue: TTuiStyle);
    procedure RebuildStyles;
    procedure AdjustViewOffset;
    function  NextSelectableIndex(AFrom: Integer; ADir: Integer): Integer;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function  DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the menu. Initial ItemIndex: first selectable item.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <inheritdoc/>
    destructor Destroy; override;
    /// <summary>
    ///   Adds an item. AShortcut=#0 means no shortcut.
    /// </summary>
    procedure AddItem(const ACaption: string; AShortcut: Char = #0);
    /// <summary>
    ///   Adds a horizontal separator (not selectable).
    /// </summary>
    procedure AddSeparator;
    /// <summary>
    ///   Removes all items.
    /// </summary>
    procedure Clear;
    /// <summary>
    ///   Number of items (including separators).
    /// </summary>
    function ItemCount: Integer;
    /// <summary>
    ///   Index of the highlighted item (-1 if none). The setter skips separators.
    /// </summary>
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
    /// <summary>
    ///   Invoked when Enter is pressed or a shortcut key is typed; receives the item index.
    /// </summary>
    property OnSelect: TProc<Integer> read FOnSelect write FOnSelect;
    /// <summary>
    ///   Invoked when the highlighted item changes during navigation.
    /// </summary>
    property OnChange: TProc<Integer> read FOnChange write FOnChange;
    /// <summary>
    ///   Style for non-highlighted items. Assigning it disables theme-driven updates.
    /// </summary>
    property NormalStyle: TTuiStyle read FNormalStyle write SetNormalStyle;
    /// <summary>
    ///   Style for the highlighted item when unfocused.
    /// </summary>
    property SelectedStyle: TTuiStyle read FSelectedStyle write SetSelectedStyle;
    /// <summary>
    ///   Style for the highlighted item when focused.
    /// </summary>
    property SelectedFocusedStyle: TTuiStyle
      read FSelectedFocusedStyle write SetSelectedFocusedStyle;
    /// <summary>
    ///   Style for separators.
    /// </summary>
    property SeparatorStyle: TTuiStyle read FSeparatorStyle write SetSeparatorStyle;
  end;

implementation

uses
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Unicode;

{ TTuiMenu }

constructor TTuiMenu.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FItems := TList<TTuiMenuItem>.Create;
  FItemIndex := -1;
  RebuildStyles;
end;

destructor TTuiMenu.Destroy;
begin
  if Assigned(FItems) then
    FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TTuiMenu.RebuildStyles;
begin
  if not FNormalStyleOverride then
    FNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  if not FSelectedStyleOverride then
    FSelectedStyle := TTuiStyle.Create(Theme.Text, Theme.Border);
  if not FSelectedFocusedStyleOverride then
    FSelectedFocusedStyle := TTuiStyle.Create(Theme.Background, Theme.Primary);
  if not FSeparatorStyleOverride then
    FSeparatorStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
end;

procedure TTuiMenu.DoInit;
begin
  SetFocusable(True);
  if (FItemIndex = -1) and (FItems.Count > 0) then
    FItemIndex := NextSelectableIndex(0, 1);
end;

procedure TTuiMenu.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

function TTuiMenu.NextSelectableIndex(AFrom: Integer; ADir: Integer): Integer;
begin
  Result := -1;
  if FItems.Count = 0 then
    Exit;
  var LIndex := AFrom;
  while (LIndex >= 0) and (LIndex < FItems.Count) do
  begin
    if not FItems[LIndex].Separator then
    begin
      Result := LIndex;
      Exit;
    end;
    Inc(LIndex, ADir);
  end;
end;

procedure TTuiMenu.AdjustViewOffset;
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

procedure TTuiMenu.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
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
    var LItem := FItems[LIndex];

    if LItem.Separator then
    begin
      var LSepText := StringOfChar('-', ARect.Width);
      ACanvas.FillRect(LRowRect, ' ', FSeparatorStyle);
      ACanvas.WriteAt(ARect.Left, LRow, LSepText, FSeparatorStyle);
      Continue;
    end;

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

    // Truncate by columns so a wide glyph (CJK, emoji) is never cut in half.
    var LText := TTuiAnsi.TruncateToWidth(LItem.Caption, ARect.Width);

    if LItem.Shortcut = #0 then
    begin
      ACanvas.WriteAt(ARect.Left, LRow, LText, LStyle);
    end
    else
    begin
      // Render text + underlined shortcut
      var LShortIdx := Pos(UpCase(LItem.Shortcut), UpperCase(LText));
      if LShortIdx = 0 then
        LShortIdx := Pos(LowerCase(LItem.Shortcut), LText);
      if LShortIdx > 0 then
      begin
        ACanvas.WriteAt(ARect.Left, LRow, LText, LStyle);
        // Overwrite the shortcut character with the underline attribute.
        // Pos returns a UTF-16 index: convert it to a terminal column so the
        // underline lands on the right cell after wide glyphs (emoji, CJK).
        var LShortCol := TTuiAnsi.VisibleLength(Copy(LText, 1, LShortIdx - 1));
        if LShortCol < ARect.Width then
          ACanvas.WriteAt(ARect.Left + LShortCol, LRow,
            Copy(LText, LShortIdx, TTuiUnicode.GraphemeLengthAt(LText, LShortIdx)),
            TTuiStyle.Create(LStyle.Foreground, LStyle.Background, [taUnderline]));
      end
      else
        ACanvas.WriteAt(ARect.Left, LRow, LText, LStyle);
    end;
  end;
end;

function TTuiMenu.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  if FItems.Count = 0 then
    Exit;

  var LPageStep := Max(1, FLastViewHeight);

  case AEvent.Key.Code of
    kcUp:
      begin
        var LIndex := FItemIndex - 1;
        while (LIndex >= 0) and FItems[LIndex].Separator do
          Dec(LIndex);
        if LIndex >= 0 then
          SetItemIndex(LIndex);
        Result := True;
      end;
    kcDown:
      begin
        var LIndex := FItemIndex + 1;
        while (LIndex < FItems.Count) and FItems[LIndex].Separator do
          Inc(LIndex);
        if LIndex < FItems.Count then
          SetItemIndex(LIndex);
        Result := True;
      end;
    kcHome:
      begin
        var LIndex := NextSelectableIndex(0, 1);
        if LIndex >= 0 then
          SetItemIndex(LIndex);
        Result := True;
      end;
    kcEnd:
      begin
        var LIndex := FItems.Count - 1;
        while (LIndex >= 0) and FItems[LIndex].Separator do
          Dec(LIndex);
        if LIndex >= 0 then
          SetItemIndex(LIndex);
        Result := True;
      end;
    kcPageUp:
      begin
        var LIndex := Max(0, FItemIndex - LPageStep);
        while (LIndex < FItems.Count) and FItems[LIndex].Separator do
          Inc(LIndex);
        if LIndex < FItems.Count then
          SetItemIndex(LIndex);
        Result := True;
      end;
    kcPageDown:
      begin
        var LIndex := Min(FItems.Count - 1, FItemIndex + LPageStep);
        while (LIndex >= 0) and FItems[LIndex].Separator do
          Dec(LIndex);
        if LIndex >= 0 then
          SetItemIndex(LIndex);
        Result := True;
      end;
    kcEnter:
      begin
        if (FItemIndex >= 0) and not FItems[FItemIndex].Separator then
        begin
          if Assigned(FOnSelect) then
            FOnSelect(FItemIndex);
          Result := True;
        end;
      end;
  else
    // Shortcut key: search for the matching item
    if AEvent.Key.Code = kcChar then
    begin
      var LUp := UpCase(AEvent.Key.Character);
      for var LIndex := 0 to FItems.Count - 1 do
      begin
        if (not FItems[LIndex].Separator) and (FItems[LIndex].Shortcut <> #0) and
           (UpCase(FItems[LIndex].Shortcut) = LUp) then
        begin
          SetItemIndex(LIndex);
          if Assigned(FOnSelect) then
            FOnSelect(FItemIndex);
          Result := True;
          Exit;
        end;
      end;
    end;
  end;
end;

procedure TTuiMenu.SetItemIndex(AValue: Integer);
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

procedure TTuiMenu.AddItem(const ACaption: string; AShortcut: Char);
begin
  var LItem: TTuiMenuItem;
  LItem.Caption := ACaption;
  LItem.Shortcut := AShortcut;
  LItem.Separator := False;
  FItems.Add(LItem);
  if FItemIndex = -1 then
    FItemIndex := FItems.Count - 1;
  Invalidate;
end;

procedure TTuiMenu.AddSeparator;
begin
  var LItem: TTuiMenuItem;
  LItem.Caption := '';
  LItem.Shortcut := #0;
  LItem.Separator := True;
  FItems.Add(LItem);
  Invalidate;
end;

procedure TTuiMenu.Clear;
begin
  FItems.Clear;
  FItemIndex := -1;
  FViewOffset := 0;
  Invalidate;
end;

function TTuiMenu.ItemCount: Integer;
begin
  Result := FItems.Count;
end;

procedure TTuiMenu.SetNormalStyle(const AValue: TTuiStyle);
begin
  if FNormalStyle = AValue then
    Exit;
  FNormalStyle := AValue;
  FNormalStyleOverride := True;
  Invalidate;
end;

procedure TTuiMenu.SetSelectedStyle(const AValue: TTuiStyle);
begin
  if FSelectedStyle = AValue then
    Exit;
  FSelectedStyle := AValue;
  FSelectedStyleOverride := True;
  Invalidate;
end;

procedure TTuiMenu.SetSelectedFocusedStyle(const AValue: TTuiStyle);
begin
  if FSelectedFocusedStyle = AValue then
    Exit;
  FSelectedFocusedStyle := AValue;
  FSelectedFocusedStyleOverride := True;
  Invalidate;
end;

procedure TTuiMenu.SetSeparatorStyle(const AValue: TTuiStyle);
begin
  if FSeparatorStyle = AValue then
    Exit;
  FSeparatorStyle := AValue;
  FSeparatorStyleOverride := True;
  Invalidate;
end;

end.
