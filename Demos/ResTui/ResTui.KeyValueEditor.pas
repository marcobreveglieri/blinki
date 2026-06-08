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
{   Unit:        ResTui.KeyValueEditor.pas                       }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Reusable widget for editing a list of TResTuiKeyValue items (query params
///   or HTTP headers). Displays each item with an enabled/disabled indicator,
///   supports keyboard navigation, and fires callback delegates for add, delete,
///   toggle, and edit operations without opening dialogs directly.
/// </summary>
unit ResTui.KeyValueEditor;

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
  Blinki.Core.Widget,
  ResTui.Model;

type

  /// <summary>
  ///   Widget for viewing and navigating a list of key-value pairs.
  ///   Keyboard shortcuts delegate add/delete/toggle/edit actions to the caller
  ///   via callback properties; no dialog is opened internally.
  /// </summary>
  TResTuiKeyValueEditor = class(TTuiWidget)
  strict private
    FActiveIndex: Integer;
    FItems: TList<TResTuiKeyValue>;
    FOnAddRequest: TProc;
    FOnDeleteRequest: TProc<Integer>;
    FOnEditRequest: TProc<Integer>;
    FOnToggleRequest: TProc<Integer>;
    FTitle: string;
    FTopLine: Integer;
    procedure SetActiveIndex(AValue: Integer);
    procedure EnsureVisible(const ARect: TRect);
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
  public
    /// <summary>
    ///   Creates the widget. AItems is a reference — not owned by this widget.
    ///   ATitle is shown in the box border (e.g. CPanelParams or CPanelHeaders).
    /// </summary>
    constructor Create(AParent: TTuiWidget; AItems: TList<TResTuiKeyValue>;
      const ATitle: string);
    /// <summary>
    ///   Call after externally modifying Items to clamp the active index and
    ///   trigger a repaint.
    /// </summary>
    procedure Refresh;
    /// <summary>
    ///   Index of the currently active item, or -1 when the list is empty.
    /// </summary>
    property ActiveIndex: Integer read FActiveIndex write SetActiveIndex;
    /// <summary>
    ///   Fired when the user requests adding a new item (N or Insert key).
    /// </summary>
    property OnAddRequest: TProc read FOnAddRequest write FOnAddRequest;
    /// <summary>
    ///   Fired when the user requests deleting the active item (D or Delete key).
    ///   The argument is the index of the item to delete.
    /// </summary>
    property OnDeleteRequest: TProc<Integer> read FOnDeleteRequest write FOnDeleteRequest;
    /// <summary>
    ///   Fired when the user requests editing the active item (Enter key).
    ///   The argument is the index of the item to edit.
    /// </summary>
    property OnEditRequest: TProc<Integer> read FOnEditRequest write FOnEditRequest;
    /// <summary>
    ///   Fired when the user requests toggling the enabled flag of the active
    ///   item (Space key). The argument is the index of the item to toggle.
    /// </summary>
    property OnToggleRequest: TProc<Integer> read FOnToggleRequest write FOnToggleRequest;
  end;

implementation

uses
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  ResTui.Consts,
  ResTui.Helpers;

const
  // Keyboard hint shown at the bottom of the box.
  CHint = 'N:Add  D:Del  Space:Toggle  Enter:Edit';
  // Unicode check and cross marks for the enabled indicator.
  CMarkEnabled  = #$2713;  // ✓
  CMarkDisabled = #$2717;  // ✗
  // Placeholder shown when the list is empty.
  CEmptyMsg = '(empty — press N to add)';

{ TResTuiKeyValueEditor }

constructor TResTuiKeyValueEditor.Create(AParent: TTuiWidget;
  AItems: TList<TResTuiKeyValue>; const ATitle: string);
begin
  inherited Create(AParent);
  FItems := AItems;
  FTitle := ATitle;
  FActiveIndex := -1;
end;

procedure TResTuiKeyValueEditor.DoInit;
begin
  SetFocusable(True);
end;

procedure TResTuiKeyValueEditor.SetActiveIndex(AValue: Integer);
begin
  // Clamp to valid range; use -1 when the list is empty.
  var LCount := FItems.Count;
  if LCount = 0 then
    AValue := -1
  else
    AValue := Max(0, Min(AValue, LCount - 1));
  if FActiveIndex = AValue then
    Exit;
  FActiveIndex := AValue;
  Invalidate;
end;

procedure TResTuiKeyValueEditor.EnsureVisible(const ARect: TRect);
// Adjusts FTopLine so that FActiveIndex is visible inside the content area.
// The content rows available = box height - 2 borders - 1 hint row.
var
  LVisibleRows: Integer;
begin
  if FActiveIndex < 0 then
    Exit;
  LVisibleRows := ARect.Height - 3;  // top border + bottom border + hint row
  if LVisibleRows <= 0 then
    Exit;
  if FActiveIndex < FTopLine then
    FTopLine := FActiveIndex
  else if FActiveIndex >= FTopLine + LVisibleRows then
    FTopLine := FActiveIndex - LVisibleRows + 1;
  FTopLine := Max(0, FTopLine);
end;

procedure TResTuiKeyValueEditor.DoRender(const ACanvas: TTuiCanvas;
  const ARect: TRect);
var
  LBorderColor: TTuiColor;
  LBorderStyle: TTuiStyle;
  LNormalStyle: TTuiStyle;
  LInnerLeft: Integer;
  LInnerTop: Integer;
  LInnerWidth: Integer;
  LContentRows: Integer;
begin
  // Choose border colour based on focus state.
  if Focused then
    LBorderColor := CColorBorderFocus
  else
    LBorderColor := CColorBorderNormal;
  LBorderStyle := TTuiStyle.Create(LBorderColor, Theme.Background);
  LNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Background);

  // Fill background and draw surrounding box.
  ACanvas.FillRect(ARect, ' ', LNormalStyle);
  ACanvas.DrawBox(ARect, bsRounded, FTitle, LBorderStyle);

  LInnerLeft := ARect.Left + 1;
  LInnerTop := ARect.Top + 1;
  LInnerWidth := ARect.Width - 2;
  // Content rows: total inner rows minus the bottom hint row.
  LContentRows := ARect.Height - 3;  // top border + bottom border + hint

  if (LInnerWidth <= 0) or (LContentRows <= 0) then
    Exit;

  EnsureVisible(ARect);

  // --- Content rows ---
  ACanvas.PushClip(TRect.Create(LInnerLeft, LInnerTop,
    LInnerLeft + LInnerWidth, LInnerTop + LContentRows));
  try
    if FItems.Count = 0 then
    begin
      // Show a centred placeholder message.
      var LMsg := CEmptyMsg;
      var LMsgX := LInnerLeft + Max(0, (LInnerWidth - Length(LMsg)) div 2);
      ACanvas.WriteAt(LMsgX, LInnerTop,
        Truncate(LMsg, LInnerWidth),
        TTuiStyle.Create(Theme.TextDim, Theme.Background));
    end
    else
    begin
      for var I := 0 to LContentRows - 1 do
      begin
        var LItemIndex := FTopLine + I;
        if LItemIndex >= FItems.Count then
          Break;
        var LItem := FItems[LItemIndex];
        var LRowY := LInnerTop + I;

        // Row background: highlighted for active row.
        var LRowStyle: TTuiStyle;
        if LItemIndex = FActiveIndex then
          LRowStyle := TTuiStyle.Create(Theme.Text, Theme.Primary)
        else
          LRowStyle := LNormalStyle;

        // Clear the row with the row background.
        ACanvas.FillRect(
          TRect.Create(LInnerLeft, LRowY, LInnerLeft + LInnerWidth, LRowY + 1),
          ' ', LRowStyle);

        // Enabled/disabled indicator.
        var LIndicatorStyle: TTuiStyle;
        if LItem.Enabled then
          LIndicatorStyle := TTuiStyle.Create(Theme.Success, LRowStyle.Background)
        else
          LIndicatorStyle := TTuiStyle.Create(Theme.Error, LRowStyle.Background);
        var LMark: string;
        if LItem.Enabled then
          LMark := CMarkEnabled
        else
          LMark := CMarkDisabled;
        // Format: [✓] or [✗]
        ACanvas.WriteAt(LInnerLeft, LRowY, '[', LRowStyle);
        ACanvas.WriteAt(LInnerLeft + 1, LRowY, LMark, LIndicatorStyle);
        ACanvas.WriteAt(LInnerLeft + 2, LRowY, '] ', LRowStyle);

        // Key = Value text, truncated to the remaining width.
        // 4 chars used: '[', mark, ']', ' '
        var LTextWidth := LInnerWidth - 4;
        if LTextWidth > 0 then
        begin
          var LText := LItem.Key + ' = ' + LItem.Value;
          ACanvas.WriteAt(LInnerLeft + 4, LRowY,
            Truncate(LText, LTextWidth), LRowStyle);
        end;
      end;
    end;
  finally
    ACanvas.PopClip;
  end;

  // --- Hint row (last inner row, just above the bottom border) ---
  var LHintY := ARect.Bottom - 2;
  if LHintY > ARect.Top then
  begin
    var LHintStyle := TTuiStyle.Create(Theme.TextDim, Theme.Background);
    // Clear the hint row first.
    ACanvas.FillRect(
      TRect.Create(LInnerLeft, LHintY, LInnerLeft + LInnerWidth, LHintY + 1),
      ' ', LHintStyle);
    ACanvas.WriteAt(LInnerLeft, LHintY,
      Truncate(CHint, LInnerWidth), LHintStyle);
  end;
end;

function TResTuiKeyValueEditor.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  var LCount := FItems.Count;
  case AEvent.Key.Code of
    kcUp:
      begin
        if FActiveIndex > 0 then
        begin
          Dec(FActiveIndex);
          Invalidate;
        end;
        Result := True;
      end;
    kcDown:
      begin
        if FActiveIndex < LCount - 1 then
        begin
          Inc(FActiveIndex);
          Invalidate;
        end;
        Result := True;
      end;
    kcEnter:
      begin
        if (FActiveIndex >= 0) and Assigned(FOnEditRequest) then
          FOnEditRequest(FActiveIndex);
        Result := True;
      end;
    kcSpace:
      begin
        if (FActiveIndex >= 0) and Assigned(FOnToggleRequest) then
          FOnToggleRequest(FActiveIndex);
        Result := True;
      end;
    kcInsert:
      begin
        if Assigned(FOnAddRequest) then
          FOnAddRequest();
        Result := True;
      end;
    kcDelete:
      begin
        if Assigned(FOnDeleteRequest) then
          FOnDeleteRequest(FActiveIndex);
        Result := True;
      end;
    kcChar:
      begin
        case AEvent.Key.Character of
          'N', 'n':
            begin
              if Assigned(FOnAddRequest) then
                FOnAddRequest();
              Result := True;
            end;
          'D', 'd':
            begin
              if Assigned(FOnDeleteRequest) then
                FOnDeleteRequest(FActiveIndex);
              Result := True;
            end;
        end;
      end;
  end;
end;

procedure TResTuiKeyValueEditor.Refresh;
begin
  // Clamp the active index after an external change and repaint.
  var LCount := FItems.Count;
  if LCount = 0 then
    FActiveIndex := -1
  else if FActiveIndex >= LCount then
    FActiveIndex := LCount - 1;
  FTopLine := Max(0, Min(FTopLine, Max(0, LCount - 1)));
  Invalidate;
end;

end.
