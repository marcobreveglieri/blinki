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
{   Unit:        Blinki.Widgets.Sidebar.pas                      }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget container TTuiSidebar: collapsible single-child side panel.
/// </summary>
unit Blinki.Widgets.Sidebar;

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

{ TTuiSidebar }

  /// <summary>
  ///   Single-child container that collapses and expands via Space or Enter.
  ///   When collapsed, shows only the toggle glyph (U+2630, three lines).
  ///   When expanded, draws a Rounded border around the child.
  ///   The LayoutConstraint is updated automatically on state change.
  ///   Accepts at most one child; a second AddChild raises ETuiWidgetError.
  ///   Becomes focusable in DoInit.
  /// </summary>
  TTuiSidebar = class(TTuiWidget)
  strict private
    FCollapsed: Boolean;
    FExpandedWidth: Integer;
    FCollapsedWidth: Integer;
    FOnToggle: TProc<Boolean>;
    FBorderStyle: TTuiStyle;
    FStyleOverride: Boolean;
    procedure SetCollapsed(AValue: Boolean);
    procedure SetExpandedWidth(AValue: Integer);
    procedure SetCollapsedWidth(AValue: Integer);
    procedure SetBorderStyle(const AValue: TTuiStyle);
    procedure UpdateConstraint;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function  DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the sidebar. ExpandedWidth default: 24. CollapsedWidth default: 3.
    ///   Initial state: expanded.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Override: raises ETuiWidgetError if a child is already present.
    /// </summary>
    procedure AddChild(AChild: TTuiWidget); override;
    /// <summary>
    ///   Toggles between collapsed and expanded state.
    /// </summary>
    procedure Toggle;
    /// <summary>
    ///   Current state. True means collapsed. The setter updates the LayoutConstraint.
    /// </summary>
    property Collapsed: Boolean read FCollapsed write SetCollapsed;
    /// <summary>
    ///   Width when expanded, in columns. Default: 24.
    /// </summary>
    property ExpandedWidth: Integer read FExpandedWidth write SetExpandedWidth;
    /// <summary>
    ///   Width when collapsed, in columns. Default: 3.
    /// </summary>
    property CollapsedWidth: Integer read FCollapsedWidth write SetCollapsedWidth;
    /// <summary>
    ///   Invoked on state change; receives the new value of Collapsed.
    /// </summary>
    property OnToggle: TProc<Boolean> read FOnToggle write FOnToggle;
    /// <summary>
    ///   Border style when expanded. Assigning it disables theme-driven updates.
    /// </summary>
    property BorderStyle: TTuiStyle read FBorderStyle write SetBorderStyle;
  end;

implementation

uses
  System.Generics.Collections,
  Blinki.Core.Ansi,
  Blinki.Core.Geometry,
  Blinki.Core.Input;

{ TTuiSidebar }

constructor TTuiSidebar.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FExpandedWidth := 24;
  FCollapsedWidth := 3;
  FBorderStyle := TTuiStyle.Create(Theme.Border, Theme.Surface);
  UpdateConstraint;
end;

procedure TTuiSidebar.UpdateConstraint;
begin
  if FCollapsed then
    LayoutConstraint := TTuiLayoutConstraint.Fixed(FCollapsedWidth)
  else
    LayoutConstraint := TTuiLayoutConstraint.Fixed(FExpandedWidth);
end;

procedure TTuiSidebar.DoInit;
begin
  SetFocusable(True);
end;

procedure TTuiSidebar.DoApplyTheme(const ATheme: TTuiTheme);
begin
  if not FStyleOverride then
    FBorderStyle := TTuiStyle.Create(ATheme.Border, ATheme.Surface);
end;

procedure TTuiSidebar.AddChild(AChild: TTuiWidget);
begin
  if ChildCount >= 1 then
    raise ETuiWidgetError.Create(
      'TTuiSidebar.AddChild: the sidebar accepts a maximum of one child');
  inherited AddChild(AChild);
end;

procedure TTuiSidebar.Toggle;
begin
  SetCollapsed(not FCollapsed);
end;

procedure TTuiSidebar.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  if FCollapsed then
  begin
    // Show only the toggle glyph centred vertically
    var LGlyphStyle := TTuiStyle.Create(Theme.Border, Theme.Surface);
    if Focused then
      LGlyphStyle := TTuiStyle.Create(Theme.Primary, Theme.Surface, [taBold]);
    ACanvas.FillRect(ARect, ' ', LGlyphStyle);
    ACanvas.WriteAt(
      ARect.Left + (ARect.Width - 1) div 2,
      ARect.Top  + ARect.Height div 2,
      #$2261,
      LGlyphStyle);
  end
  else
  begin
    ACanvas.DrawBox(ARect, bsRounded, '', FBorderStyle);
    if ChildCount = 1 then
    begin
      var LInner := ARect;
      LInner.Inflate(-1, -1);
      if not LInner.IsEmpty then
        Children[0].Render(ACanvas, LInner);
    end;
  end;
end;

function TTuiSidebar.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  if (AEvent.Key.Code = kcSpace) or (AEvent.Key.Code = kcEnter) then
  begin
    Toggle;
    Result := True;
  end;
end;

procedure TTuiSidebar.SetCollapsed(AValue: Boolean);
begin
  if FCollapsed = AValue then
    Exit;
  FCollapsed := AValue;
  UpdateConstraint;
  if Assigned(FOnToggle) then
    FOnToggle(FCollapsed);
  Invalidate;
end;

procedure TTuiSidebar.SetExpandedWidth(AValue: Integer);
begin
  if AValue < 1 then
    AValue := 1;
  if FExpandedWidth = AValue then
    Exit;
  FExpandedWidth := AValue;
  if not FCollapsed then
    UpdateConstraint;
end;

procedure TTuiSidebar.SetCollapsedWidth(AValue: Integer);
begin
  if AValue < 1 then
    AValue := 1;
  if FCollapsedWidth = AValue then
    Exit;
  FCollapsedWidth := AValue;
  if FCollapsed then
    UpdateConstraint;
end;

procedure TTuiSidebar.SetBorderStyle(const AValue: TTuiStyle);
begin
  if FBorderStyle = AValue then
    Exit;
  FBorderStyle := AValue;
  FStyleOverride := True;
  Invalidate;
end;

end.
