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
{   Unit:        Blinki.Widgets.Tabs.pas                         }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget container TTuiTabs: tab bar with left/right navigation.
/// </summary>
unit Blinki.Widgets.Tabs;

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

{ TTuiTabs }

  /// <summary>
  ///   Container that displays a horizontal tab bar on the first row and renders
  ///   the active tab's widget in the remaining area. Navigates with Left/Right
  ///   when focused. Add tabs with AddTab(ACaption, AChild); the child is owned
  ///   by the container. If AChild is created with Create(ATabs) it is registered
  ///   automatically; call AddTab afterwards to set its caption (the child is
  ///   located by searching the children list). Becomes focusable in DoInit.
  /// </summary>
  TTuiTabs = class(TTuiWidget)
  strict private
    FTabCaptions: TStringList;
    FActiveIndex: Integer;
    FNormalStyle: TTuiStyle;
    FActiveStyle: TTuiStyle;
    FNormalStyleOverride: Boolean;
    FActiveStyleOverride: Boolean;
    FOnChange: TProc<Integer>;
    procedure SetActiveIndex(AValue: Integer);
    procedure SetNormalStyle(const AValue: TTuiStyle);
    procedure SetActiveStyle(const AValue: TTuiStyle);
    procedure RebuildStyles;
    function TabIndexAtPoint(AX, AY: Integer): Integer;
  protected
    /// <summary>
    ///   Only the active tab page (AIndex = FActiveIndex) is traversable for
    ///   focus-ring construction and mouse hit-testing.
    /// </summary>
    function IsChildFocusTraversable(AIndex: Integer): Boolean; override;
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function  DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the tab container. Initial ActiveIndex: 0 (first tab once added).
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <inheritdoc/>
    destructor Destroy; override;
    /// <summary>
    ///   Override: adds an empty caption entry for the newly registered child.
    /// </summary>
    procedure AddChild(AChild: TTuiWidget); override;
    /// <summary>
    ///   Adds a tab with caption ACaption and widget AChild.
    ///   If AChild.Parent = nil, it is added as a child (ownership transferred).
    ///   If AChild is already a child of this Tabs, only the caption is updated.
    /// </summary>
    procedure AddTab(const ACaption: string; AChild: TTuiWidget);
    /// <summary>
    ///   Index of the active tab (0-based). The setter clamps to the valid range.
    /// </summary>
    property ActiveIndex: Integer read FActiveIndex write SetActiveIndex;
    /// <summary>
    ///   Style for inactive tabs. Assigning it disables automatic theme updates.
    /// </summary>
    property NormalStyle: TTuiStyle read FNormalStyle write SetNormalStyle;
    /// <summary>
    ///   Style for the active tab. Assigning it disables automatic theme updates.
    /// </summary>
    property ActiveStyle: TTuiStyle read FActiveStyle write SetActiveStyle;
    /// <summary>
    ///   Invoked when the active tab changes; receives the new index.
    /// </summary>
    property OnChange: TProc<Integer> read FOnChange write FOnChange;
  end;

implementation

uses
  System.Generics.Collections,
  Blinki.Core.Input;

{ TTuiTabs }

constructor TTuiTabs.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FActiveIndex := -1;
  FTabCaptions := TStringList.Create;
  RebuildStyles;
end;

destructor TTuiTabs.Destroy;
begin
  if Assigned(FTabCaptions) then
    FreeAndNil(FTabCaptions);
  inherited Destroy;
end;

procedure TTuiTabs.AddChild(AChild: TTuiWidget);
begin
  inherited AddChild(AChild);
  // Adds an empty caption entry parallel to the new child
  FTabCaptions.Add('');
  if FActiveIndex < 0 then
    FActiveIndex := 0;
end;

procedure TTuiTabs.AddTab(const ACaption: string; AChild: TTuiWidget);
begin
  if not Assigned(AChild.Parent) then
  begin
    AddChild(AChild);
    // AddChild added an empty caption: update the last one
    FTabCaptions[FTabCaptions.Count - 1] := ACaption;
  end
  else
  begin
    // The child is already a child: find its index and update the caption
    var LChildIndex := -1;
    for var LIndex := 0 to ChildCount - 1 do
      if Children[LIndex] = AChild then
      begin
        LChildIndex := LIndex;
        Break;
      end;
    if LChildIndex >= 0 then
    begin
      while FTabCaptions.Count <= LChildIndex do
        FTabCaptions.Add('');
      FTabCaptions[LChildIndex] := ACaption;
    end;
  end;
  Invalidate;
end;

procedure TTuiTabs.RebuildStyles;
begin
  if not FNormalStyleOverride then
    FNormalStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
  if not FActiveStyleOverride then
    FActiveStyle := TTuiStyle.Create(Theme.Background, Theme.Primary, [taBold]);
end;

function TTuiTabs.TabIndexAtPoint(AX, AY: Integer): Integer;
begin
  Result := -1;
  // Only the header row is interactive
  if AY <> LastRect.Top then
    Exit;
  var LX := LastRect.Left;
  for var LIndex := 0 to ChildCount - 1 do
  begin
    if LX >= LastRect.Right then
      Break;
    var LCaption: string;
    if LIndex < FTabCaptions.Count then
      LCaption := FTabCaptions[LIndex]
    else
      LCaption := '';
    var LPadded := ' ' + LCaption + ' ';
    if LX + Length(LPadded) > LastRect.Right then
      LPadded := Copy(LPadded, 1, LastRect.Right - LX);
    if (AX >= LX) and (AX < LX + Length(LPadded)) then
    begin
      Result := LIndex;
      Exit;
    end;
    Inc(LX, Length(LPadded));
    // Account for the separator between tabs
    if (LIndex < ChildCount - 1) and (LX < LastRect.Right) then
      Inc(LX);
  end;
end;

function TTuiTabs.IsChildFocusTraversable(AIndex: Integer): Boolean;
begin
  Result := AIndex = FActiveIndex;
end;

procedure TTuiTabs.DoInit;
begin
  SetFocusable(True);
  if (FActiveIndex = -1) and (ChildCount > 0) then
    FActiveIndex := 0;
end;

procedure TTuiTabs.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TTuiTabs.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  // Header row: ARect.Top
  var LHeaderRect := TRect.Create(ARect.Left, ARect.Top, ARect.Right, ARect.Top + 1);
  ACanvas.FillRect(LHeaderRect, ' ', FNormalStyle);

  var LX := ARect.Left;
  for var LIndex := 0 to ChildCount - 1 do
  begin
    if LX >= ARect.Right then
      Break;

    var LCaption: string;
    if LIndex < FTabCaptions.Count then
      LCaption := FTabCaptions[LIndex]
    else
      LCaption := '';

    var LPadded := ' ' + LCaption + ' ';

    var LStyle: TTuiStyle;
    if LIndex = FActiveIndex then
      LStyle := FActiveStyle
    else
      LStyle := FNormalStyle;

    if LX + Length(LPadded) > ARect.Right then
      LPadded := Copy(LPadded, 1, ARect.Right - LX);

    ACanvas.WriteAt(LX, ARect.Top, LPadded, LStyle);
    Inc(LX, Length(LPadded));

    // Separator between tabs (only if not the last one and space is available)
    if (LIndex < ChildCount - 1) and (LX < ARect.Right) then
    begin
      ACanvas.WriteAt(LX, ARect.Top, #$2502, FNormalStyle);
      Inc(LX);
    end;
  end;

  // Body: header row excluded
  if ARect.Height <= 1 then
    Exit;

  var LBodyRect := TRect.Create(
    ARect.Left,
    ARect.Top + 1,
    ARect.Right,
    ARect.Bottom
  );

  if (FActiveIndex >= 0) and (FActiveIndex < ChildCount) then
    Children[FActiveIndex].Render(ACanvas, LBodyRect);
end;

function TTuiTabs.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if ChildCount = 0 then
    Exit;
  if AEvent.Kind = ekMouse then
  begin
    if (AEvent.Mouse.Kind = mekDown) and (AEvent.Mouse.Button = mbLeft) then
    begin
      var LTabIndex := TabIndexAtPoint(AEvent.Mouse.X, AEvent.Mouse.Y);
      if LTabIndex >= 0 then
      begin
        SetActiveIndex(LTabIndex);
        Result := True;
      end;
    end;
    Exit;
  end;
  if AEvent.Kind <> ekKey then
    Exit;
  case AEvent.Key.Code of
    kcLeft:
      begin
        if FActiveIndex > 0 then
          SetActiveIndex(FActiveIndex - 1)
        else
          SetActiveIndex(ChildCount - 1);
        Result := True;
      end;
    kcRight:
      begin
        if FActiveIndex < ChildCount - 1 then
          SetActiveIndex(FActiveIndex + 1)
        else
          SetActiveIndex(0);
        Result := True;
      end;
  end;
end;

procedure TTuiTabs.SetActiveIndex(AValue: Integer);
begin
  if ChildCount = 0 then
    Exit;
  if AValue < 0 then
    AValue := 0;
  if AValue >= ChildCount then
    AValue := ChildCount - 1;
  if FActiveIndex = AValue then
    Exit;
  FActiveIndex := AValue;
  if Assigned(FOnChange) then
    FOnChange(FActiveIndex);
  // Notify the App to rebuild the focus ring scoped to the new active page.
  NotifyFocusStructureChanged;
  Invalidate;
end;

procedure TTuiTabs.SetNormalStyle(const AValue: TTuiStyle);
begin
  if FNormalStyle = AValue then
    Exit;
  FNormalStyle := AValue;
  FNormalStyleOverride := True;
  Invalidate;
end;

procedure TTuiTabs.SetActiveStyle(const AValue: TTuiStyle);
begin
  if FActiveStyle = AValue then
    Exit;
  FActiveStyle := AValue;
  FActiveStyleOverride := True;
  Invalidate;
end;

end.
