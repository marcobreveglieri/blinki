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
{   Unit:        Blinki.Core.Widget.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   OOP base class for all Blinki widgets. TTuiWidget provides the full
///   lifecycle (Init/Render/HandleEvent/Destroy), automatic child ownership
///   via TObjectList(OwnsObjects=True), a dirty flag with propagation to the
///   parent, and the focus protocol (Focusable, Focused, Focus/Blur).
///   The class procedure BuildFocusRing builds the flat list of focusable
///   widgets in depth-first order; it will be called by the App on the first
///   Run().
/// </summary>
unit Blinki.Core.Widget;

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
  Blinki.Core.Geometry,
  Blinki.Core.Theme;

type

{ Class forward declarations }

  TTuiWidget = class;

{ ETuiWidgetError }

  /// <summary>
  ///   Raised on widget protocol violations (e.g. a widget assigned to two parents).
  /// </summary>
  ETuiWidgetError = class(Exception);

{ TTuiWidgetList }

  /// <summary>
  ///   List of widget pointers used for the focus ring. The caller owns the list.
  /// </summary>
  TTuiWidgetList = TList<TTuiWidget>;

{ TTuiWidget }

  /// <summary>
  ///   Abstract base class for every Blinki widget.
  /// </summary>
  /// <remarks>
  ///   Concrete widgets override DoInit, DoRender, and DoHandleEvent in the
  ///   protected section. The caller invokes Init explicitly after the full
  ///   widget tree has been constructed, Render on every frame,
  ///   and HandleEvent for each input event.
  /// </remarks>
  TTuiWidget = class
  strict private
    FChildren: TObjectList<TTuiWidget>;
    FDirty: Boolean;
    FFocusable: Boolean;
    FFocused: Boolean;
    FInitialized: Boolean;
    FLastRect: TRect;
    FLayoutConstraint: TTuiLayoutConstraint;
    FOnFocusStructureChanged: TProc;
    FParent: TTuiWidget;
    FTheme: TTuiTheme;
    function GetChildCount: Integer; inline;
    function GetChild(AIndex: Integer): TTuiWidget; inline;
    procedure SetLayoutConstraint(const AValue: TTuiLayoutConstraint);
  protected
    /// <summary>
    ///   Initialization hook; called by Init after all children. Override is optional.
    /// </summary>
    procedure DoInit; virtual;
    /// <summary>
    ///   Draws the widget within ARect on ACanvas. Must not mutate widget state.
    /// </summary>
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); virtual; abstract;
    /// <summary>
    ///   Handles AEvent; returns True if the event was consumed.
    /// </summary>
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; virtual;
    /// <summary>
    ///   Returns True if the child at AIndex should be included in the focus ring
    ///   and hit-test traversal. Default implementation always returns True.
    ///   Override in containers with dynamic visibility (e.g. TTuiTabs) to
    ///   exclude children that are not currently displayed.
    /// </summary>
    function IsChildFocusTraversable(AIndex: Integer): Boolean; virtual;
    /// <summary>
    ///   Walks up to the root widget (FParent = nil) and invokes the handler
    ///   registered there via SetFocusStructureChangedHandler, if any.
    ///   Call this from SetActiveIndex-style methods that change which children
    ///   are traversable, so the App can rebuild the focus ring on demand.
    /// </summary>
    procedure NotifyFocusStructureChanged;
    /// <summary>
    ///   Sets the Focusable flag; to be called in DoInit of interactive descendants.
    /// </summary>
    procedure SetFocusable(AValue: Boolean);
    /// <summary>
    ///   Responds to a theme change; receives the new theme already stored in FTheme.
    ///   Override is optional.
    /// </summary>
    procedure DoApplyTheme(const ATheme: TTuiTheme); virtual;
    /// <summary>
    ///   Receives the timer tick (elapsed milliseconds); used by animated widgets.
    ///   Override is optional.
    /// </summary>
    procedure DoTick(AElapsedMs: Integer); virtual;
  public
    /// <summary>
    ///   Creates the widget. If AParent is specified, registers itself automatically
    ///   as a child, transferring ownership to the parent.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Destroys the widget and recursively all owned children.
    /// </summary>
    destructor Destroy; override;
    /// <summary>
    ///   Initializes the widget and all children in post-order (children first,
    ///   then self). Idempotent: subsequent calls are no-ops. Must be called once
    ///   after the entire widget tree has been constructed.
    /// </summary>
    procedure Init;
    /// <summary>
    ///   Delegates to DoRender, then clears the dirty flag.
    /// </summary>
    procedure Render(const ACanvas: TTuiCanvas; const ARect: TRect);
    /// <summary>
    ///   Delegates to DoHandleEvent; returns True if the event was consumed.
    /// </summary>
    function HandleEvent(const AEvent: TTuiEvent): Boolean;
    /// <summary>
    ///   Adds AChild as a child (ownership transferred to self).
    ///   Raises ETuiWidgetError if AChild is nil or already has a parent.
    ///   Override in subclasses to enforce constraints on child cardinality.
    /// </summary>
    procedure AddChild(AChild: TTuiWidget); virtual;
    /// <summary>
    ///   Removes AChild from the child list without freeing it (ownership returned
    ///   to the caller). No action if AChild is not a child of self.
    /// </summary>
    procedure RemoveChild(AChild: TTuiWidget);
    /// <summary>
    ///   Marks the widget dirty and propagates to the parent (short-circuits if
    ///   already dirty).
    /// </summary>
    procedure Invalidate;
    /// <summary>
    ///   Applies ATheme to the widget and all descendants.
    ///   Short-circuits if the theme is identical to the current one.
    ///   Calls DoApplyTheme to allow widgets to recalculate derived styles.
    /// </summary>
    procedure ApplyTheme(const ATheme: TTuiTheme);
    /// <summary>
    ///   Propagates the timer tick to the widget and all descendants.
    ///   Animated widgets (spinner, toast) implement DoTick to advance their state.
    /// </summary>
    procedure Tick(AElapsedMs: Integer);
    /// <summary>
    ///   Sets Focused=True if the widget is Focusable; no-op otherwise.
    /// </summary>
    procedure Focus;
    /// <summary>
    ///   Sets Focused=False; no-op if the widget is not already focused.
    /// </summary>
    procedure Blur;
    /// <summary>
    ///   Builds in ARing the flat list of focusable widgets rooted at ARoot,
    ///   in depth-first pre-order. ARing must be created and owned by the caller.
    /// </summary>
    class procedure BuildFocusRing(ARoot: TTuiWidget; const ARing: TTuiWidgetList); static;
    /// <summary>
    ///   Returns the deepest focusable widget in the subtree rooted at Self
    ///   whose LastRect contains APoint, or nil if none matches.
    ///   Children are visited in reverse paint order (last child = topmost).
    ///   Only traversable children (IsChildFocusTraversable = True) are visited.
    ///   Valid only after the first Render call (LastRect is zero until then).
    /// </summary>
    function HitTestFocusable(const APoint: TPoint): TTuiWidget;
    /// <summary>
    ///   Registers a callback invoked by NotifyFocusStructureChanged when the
    ///   focus structure of any descendant changes. Register this on the root
    ///   widget (and on modal roots) from the App to trigger focus-ring rebuilds.
    /// </summary>
    procedure SetFocusStructureChangedHandler(const AHandler: TProc);
    /// <summary>
    ///   Number of direct child widgets.
    /// </summary>
    property ChildCount: Integer read GetChildCount;
    /// <summary>
    ///   Indexed access to direct child widgets (0-based).
    /// </summary>
    property Children[AIndex: Integer]: TTuiWidget read GetChild;
    /// <summary>
    ///   True if the widget or a descendant requires re-rendering.
    /// </summary>
    property Dirty: Boolean read FDirty;
    /// <summary>
    ///   True if the widget can receive keyboard focus.
    /// </summary>
    property Focusable: Boolean read FFocusable;
    /// <summary>
    ///   True if this widget is currently the focused widget.
    /// </summary>
    property Focused: Boolean read FFocused;
    /// <summary>
    ///   The TRect most recently passed to Render. Updated at the beginning of
    ///   every Render call; zero-value until the first frame has been drawn.
    ///   Used by HitTestFocusable and by widgets that need to map screen
    ///   coordinates (e.g. mouse clicks) back to their own item rows.
    /// </summary>
    property LastRect: TRect read FLastRect;
    /// <summary>
    ///   Layout constraint used by the parent container to size this widget.
    ///   Default: TTuiLayoutConstraint.Fill(1). Assigning it invalidates the parent.
    /// </summary>
    property LayoutConstraint: TTuiLayoutConstraint
      read FLayoutConstraint write SetLayoutConstraint;
    /// <summary>
    ///   Parent widget, or nil if this is the root widget.
    /// </summary>
    property Parent: TTuiWidget read FParent;
    /// <summary>
    ///   Current theme of the widget; propagated from TTuiApp.Theme via ApplyTheme.
    /// </summary>
    property Theme: TTuiTheme read FTheme;
  end;

implementation

{ TTuiWidget }

constructor TTuiWidget.Create(AParent: TTuiWidget = nil);
begin
  inherited Create;
  FChildren := TObjectList<TTuiWidget>.Create(True);
  FDirty := True;
  FLayoutConstraint := TTuiLayoutConstraint.Fill(1);
  FTheme := TTuiTheme.Default;
  if Assigned(AParent) then
    AParent.AddChild(Self);
end;

destructor TTuiWidget.Destroy;
begin
  if Assigned(FParent) then
    FParent.FChildren.Extract(Self);
  if Assigned(FChildren) then
  begin
    // Clear each child's FParent before freeing the list so that children do not
    // call Extract on this same list while it is being destroyed (re-entry into
    // IndexOf on partially-freed memory).
    for var LIdx := 0 to FChildren.Count - 1 do
      FChildren[LIdx].FParent := nil;
    FreeAndNil(FChildren);
  end;
  inherited Destroy;
end;

function TTuiWidget.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TTuiWidget.GetChild(AIndex: Integer): TTuiWidget;
begin
  Result := FChildren[AIndex];
end;

procedure TTuiWidget.DoInit;
begin
end;

function TTuiWidget.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
end;

function TTuiWidget.IsChildFocusTraversable(AIndex: Integer): Boolean;
begin
  Result := True;
end;

procedure TTuiWidget.NotifyFocusStructureChanged;
begin
  // Walk up to the root (first ancestor with no parent) and fire its handler.
  var LNode: TTuiWidget := Self;
  while Assigned(LNode.FParent) do
    LNode := LNode.FParent;
  if Assigned(LNode.FOnFocusStructureChanged) then
    LNode.FOnFocusStructureChanged();
end;

procedure TTuiWidget.SetFocusStructureChangedHandler(const AHandler: TProc);
begin
  FOnFocusStructureChanged := AHandler;
end;

procedure TTuiWidget.DoApplyTheme(const ATheme: TTuiTheme);
begin
  // No action
end;

procedure TTuiWidget.DoTick(AElapsedMs: Integer);
begin
  // No action
end;

procedure TTuiWidget.SetFocusable(AValue: Boolean);
begin
  FFocusable := AValue;
end;

procedure TTuiWidget.SetLayoutConstraint(const AValue: TTuiLayoutConstraint);
begin
  if (FLayoutConstraint.Kind = AValue.Kind) and
     (FLayoutConstraint.Value = AValue.Value) then
    Exit;
  FLayoutConstraint := AValue;
  if Assigned(FParent) then
    FParent.Invalidate;
end;

procedure TTuiWidget.Init;
begin
  if FInitialized then
    Exit;
  for var LIndex := 0 to FChildren.Count - 1 do
    FChildren[LIndex].Init;
  DoApplyTheme(FTheme);
  DoInit;
  FInitialized := True;
end;

procedure TTuiWidget.Render(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  FLastRect := ARect;
  DoRender(ACanvas, ARect);
  FDirty := False;
end;

function TTuiWidget.HandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := DoHandleEvent(AEvent);
end;

procedure TTuiWidget.AddChild(AChild: TTuiWidget);
begin
  if not Assigned(AChild) then
    raise ETuiWidgetError.Create('TTuiWidget.AddChild: AChild cannot be nil');
  if Assigned(AChild.FParent) then
    raise ETuiWidgetError.Create('TTuiWidget.AddChild: widget already has a parent');
  AChild.FParent := Self;
  FChildren.Add(AChild);
  AChild.ApplyTheme(FTheme);
  Invalidate;
end;

procedure TTuiWidget.RemoveChild(AChild: TTuiWidget);
begin
  if Assigned(FChildren.Extract(AChild)) then
  begin
    AChild.FParent := nil;
    Invalidate;
  end;
end;

procedure TTuiWidget.ApplyTheme(const ATheme: TTuiTheme);
begin
  if FTheme = ATheme then
    Exit;
  FTheme := ATheme;
  DoApplyTheme(ATheme);
  for var LIndex := 0 to FChildren.Count - 1 do
    FChildren[LIndex].ApplyTheme(ATheme);
  Invalidate;
end;

procedure TTuiWidget.Tick(AElapsedMs: Integer);
begin
  DoTick(AElapsedMs);
  for var LIndex := 0 to FChildren.Count - 1 do
    FChildren[LIndex].Tick(AElapsedMs);
end;

procedure TTuiWidget.Invalidate;
begin
  if FDirty then
    Exit;
  FDirty := True;
  if Assigned(FParent) then
    FParent.Invalidate;
end;

procedure TTuiWidget.Focus;
begin
  if not FFocusable then
    Exit;
  if FFocused then
    Exit;
  FFocused := True;
  Invalidate;
end;

procedure TTuiWidget.Blur;
begin
  if not FFocused then
    Exit;
  FFocused := False;
  Invalidate;
end;

class procedure TTuiWidget.BuildFocusRing(ARoot: TTuiWidget;
  const ARing: TTuiWidgetList);
begin
  if not Assigned(ARoot) then
    Exit;
  if ARoot.Focusable then
    ARing.Add(ARoot);
  for var LIndex := 0 to ARoot.ChildCount - 1 do
    if ARoot.IsChildFocusTraversable(LIndex) then
      BuildFocusRing(ARoot.Children[LIndex], ARing);
end;

function TTuiWidget.HitTestFocusable(const APoint: TPoint): TTuiWidget;
begin
  Result := nil;
  // Quick reject: the point must lie within our last rendered rect
  if not FLastRect.Contains(APoint) then
    Exit;
  // Visit traversable children in reverse paint order so the topmost widget wins
  for var LIndex := FChildren.Count - 1 downto 0 do
  begin
    if not IsChildFocusTraversable(LIndex) then
      Continue;
    Result := FChildren[LIndex].HitTestFocusable(APoint);
    if Assigned(Result) then
      Exit;
  end;
  // No child matched; if this widget itself is focusable, claim the hit
  if FFocusable then
    Result := Self;
end;

end.
