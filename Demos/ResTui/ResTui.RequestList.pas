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
{   Unit:        ResTui.RequestList.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Sidebar widget that lists the HTTP requests in a collection.
///   Each row shows a coloured method badge and the truncated request name.
///   Supports keyboard navigation (Up/Down/Home/End/Enter) and fires
///   an OnSelect callback when the user confirms a selection.
/// </summary>
unit ResTui.RequestList;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Widget,
  ResTui.Model;

type

  /// <summary>
  ///   Sidebar widget that displays the request list for the active collection.
  ///   The active row is highlighted and navigable with arrow keys.
  /// </summary>
  TResTuiRequestList = class(TTuiWidget)
  strict private
    FActiveIndex: Integer;
    FCollection: TResTuiCollection;
    FOnSelect: TProc<Integer>;
    FTopLine: Integer;
    procedure SetActiveIndex(AValue: Integer);
    procedure EnsureVisible(const ARect: TRect);
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
  public
    /// <summary>
    ///   Creates the widget. ACollection is a reference — not owned by this widget.
    /// </summary>
    constructor Create(AParent: TTuiWidget; ACollection: TResTuiCollection);
    /// <summary>
    ///   Index of the currently active (highlighted) request, or -1 when none.
    /// </summary>
    property ActiveIndex: Integer read FActiveIndex write SetActiveIndex;
    /// <summary>
    ///   Fired when the user presses Enter to confirm the current selection.
    ///   The argument is the confirmed ActiveIndex.
    /// </summary>
    property OnSelect: TProc<Integer> read FOnSelect write FOnSelect;
  end;

implementation

uses
  System.Generics.Collections,
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  ResTui.Consts,
  ResTui.Helpers;

{ TResTuiRequestList }

constructor TResTuiRequestList.Create(AParent: TTuiWidget;
  ACollection: TResTuiCollection);
begin
  inherited Create(AParent);
  FCollection := ACollection;
  FActiveIndex := -1;
end;

procedure TResTuiRequestList.DoInit;
begin
  SetFocusable(True);
end;

procedure TResTuiRequestList.SetActiveIndex(AValue: Integer);
begin
  // Clamp to valid range; use -1 when the list is empty.
  var LCount := FCollection.Requests.Count;
  if LCount = 0 then
    AValue := -1
  else
    AValue := Max(0, Min(AValue, LCount - 1));
  if FActiveIndex = AValue then
    Exit;
  FActiveIndex := AValue;
  Invalidate;
end;

procedure TResTuiRequestList.EnsureVisible(const ARect: TRect);
// Adjusts FTopLine so that FActiveIndex is visible inside the box.
var
  LInnerHeight: Integer;
begin
  if FActiveIndex < 0 then
    Exit;
  // The box has 1 row for top border and 1 for bottom border.
  LInnerHeight := ARect.Height - 2;
  if LInnerHeight <= 0 then
    Exit;
  if FActiveIndex < FTopLine then
    FTopLine := FActiveIndex
  else if FActiveIndex >= FTopLine + LInnerHeight then
    FTopLine := FActiveIndex - LInnerHeight + 1;
  FTopLine := Max(0, FTopLine);
end;

procedure TResTuiRequestList.DoRender(const ACanvas: TTuiCanvas;
  const ARect: TRect);
var
  LBorderColor: TTuiColor;
  LBorderStyle: TTuiStyle;
  LInnerHeight: Integer;
  LInnerWidth: Integer;
  LInnerLeft: Integer;
  LInnerTop: Integer;
begin
  // Choose border colour based on focus state.
  if Focused then
    LBorderColor := CColorBorderFocus
  else
    LBorderColor := CColorBorderNormal;
  LBorderStyle := TTuiStyle.Create(LBorderColor, Theme.Background);

  // Fill background, then draw the surrounding box.
  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(Theme.Text, Theme.Background));
  ACanvas.DrawBox(ARect, bsRounded, CPanelRequests, LBorderStyle);

  // Inner content area (inside the box borders).
  LInnerLeft := ARect.Left + 1;
  LInnerTop := ARect.Top + 1;
  LInnerHeight := ARect.Height - 2;
  LInnerWidth := ARect.Width - 2;

  if (LInnerHeight <= 0) or (LInnerWidth <= 0) then
    Exit;

  EnsureVisible(ARect);

  ACanvas.PushClip(TRect.Create(LInnerLeft, LInnerTop,
    LInnerLeft + LInnerWidth, LInnerTop + LInnerHeight));
  try
    for var I := 0 to LInnerHeight - 1 do
    begin
      var LReqIndex := FTopLine + I;
      if LReqIndex >= FCollection.Requests.Count then
        Break;
      var LReq := FCollection.Requests[LReqIndex];
      var LRowY := LInnerTop + I;

      // Background style: highlighted for active row, normal otherwise.
      var LRowStyle: TTuiStyle;
      if LReqIndex = FActiveIndex then
        LRowStyle := TTuiStyle.Create(Theme.Text, Theme.Primary)
      else
        LRowStyle := TTuiStyle.Create(Theme.Text, Theme.Background);

      // Clear the full row with the row background.
      ACanvas.FillRect(
        TRect.Create(LInnerLeft, LRowY, LInnerLeft + LInnerWidth, LRowY + 1),
        ' ', LRowStyle);

      // Badge: full method name, padded to 7 chars for alignment ("OPTIONS" is longest).
      const CBadgeW = 7;
      var LMethod := UpperCase(LReq.Method);
      var LBadge := LMethod + StringOfChar(' ', Max(0, CBadgeW - Length(LMethod)));
      var LBadgeStyle := TTuiStyle.Create(MethodColor(LReq.Method),
        LRowStyle.Background, [taBold]);
      ACanvas.WriteAt(LInnerLeft, LRowY, LBadge, LBadgeStyle);

      // Separator space.
      ACanvas.WriteAt(LInnerLeft + CBadgeW, LRowY, ' ', LRowStyle);

      // Request name, truncated to the remaining width.
      var LNameWidth := LInnerWidth - CBadgeW - 1;  // badge + space
      if LNameWidth > 0 then
      begin
        var LName := Truncate(LReq.Name, LNameWidth);
        ACanvas.WriteAt(LInnerLeft + CBadgeW + 1, LRowY, LName, LRowStyle);
      end;
    end;
  finally
    ACanvas.PopClip;
  end;
end;

function TResTuiRequestList.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  var LCount := FCollection.Requests.Count;
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
    kcHome:
      begin
        FActiveIndex := 0;
        Invalidate;
        Result := True;
      end;
    kcEnd:
      begin
        FActiveIndex := Max(0, LCount - 1);
        Invalidate;
        Result := True;
      end;
    kcEnter:
      begin
        if (FActiveIndex >= 0) and Assigned(FOnSelect) then
          FOnSelect(FActiveIndex);
        Result := True;
      end;
  end;
end;

end.
