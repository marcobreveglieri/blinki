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
{   Unit:        Blinki.Core.App.pas                             }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Event loop and main application class of the Blinki library.
///   TTuiApp manages the complete lifecycle: terminal setup, canvas,
///   focus ring, 20fps tick, resize detection, and guaranteed teardown.
///   Handlers for keyboard, timer and resize are registered as anonymous methods.
///   A modal overlay stack (PushModal/PopModal) allows dialog widgets to
///   render above the root tree and trap keyboard and mouse input while open.
/// </summary>
/// <remarks>
///   Minimal usage (three lines):
///     App := TTuiApp.Create;
///     App.SetRoot(LMyWidget);
///     App.Run;
///   The terminal is always restored on exit, even if an exception is raised.
/// </remarks>
unit Blinki.Core.App;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Console,
  Blinki.Core.Input,
  Blinki.Core.Theme,
  Blinki.Core.Widget;

type

{ ETuiAppError }

  /// <summary>
  ///   Protocol error raised by TTuiApp (e.g. Run without root, duplicate SetRoot).
  /// </summary>
  ETuiAppError = class(Exception);

{ TTuiKeyHandler }

  /// <summary>
  ///   Handler for keyboard events, invoked before dispatch to the focused widget.
  /// </summary>
  TTuiKeyHandler = reference to procedure(const AKey: TTuiKeyEvent);

{ TTuiMouseHandler }

  /// <summary>
  ///   Handler for mouse events not consumed by the hit widget.
  ///   Invoked after the event has been forwarded to the target widget.
  /// </summary>
  TTuiMouseHandler = reference to procedure(const AMouse: TTuiMouseEvent);

{ TTuiTimerHandler }

  /// <summary>
  ///   Handler for the timer tick; receives the milliseconds elapsed since the previous iteration.
  /// </summary>
  TTuiTimerHandler = reference to procedure(AElapsedMs: Integer);

{ TTuiResizeHandler }

  /// <summary>
  ///   Handler for terminal resize; receives the new terminal dimensions.
  /// </summary>
  TTuiResizeHandler = reference to procedure(const ASize: TSize);

{ TTuiApp }

  /// <summary>
  ///   Blinki application class. Encapsulates the entire event loop: terminal setup
  ///   and teardown, double-buffered canvas, root widget initialization, depth-first
  ///   focus ring management, and resize detection via polling.
  ///   The loop runs at TickMs (default 50ms = 20fps). Teardown is guaranteed via
  ///   try/finally even if an exception is raised in the loop or in anonymous handlers.
  ///   A modal overlay stack (PushModal/PopModal) allows dialog widgets to render
  ///   above the root tree and trap keyboard and mouse input while open. When the
  ///   stack is empty the behaviour is identical to the original single-root design.
  /// </summary>
  TTuiApp = class
  strict private
    type
      /// <summary>
      ///   Entry in the modal overlay stack: the widget and its ownership flag.
      /// </summary>
      TTuiModalEntry = record
        Widget: TTuiWidget;
        Owned: Boolean;
      end;
  strict private
    FBackend: ITuiConsoleBackend;
    FCanvas: TTuiCanvas;
    FRoot: TTuiWidget;
    FOwnsRoot: Boolean;
    FFocusRing: TTuiWidgetList;
    FFocusIndex: Integer;
    FFocused: TTuiWidget;
    FModalDim: Boolean;
    FModalStack: TList<TTuiModalEntry>;
    FModalTrapsGlobalKeys: Boolean;
    FTickMs: Integer;
    FQuitRequested: Boolean;
    FRunning: Boolean;
    FLastSize: TSize;
    FOnKeyPress: TTuiKeyHandler;
    FOnMouse: TTuiMouseHandler;
    FOnTimer: TTuiTimerHandler;
    FOnResize: TTuiResizeHandler;
    FTheme: TTuiTheme;
    procedure SetTheme(const AValue: TTuiTheme);
    procedure SetupTerminal;
    procedure TeardownTerminal;
    procedure InitializeRunState;
    procedure SelectFirstFocusable;
    procedure CycleFocus(AForward: Boolean);
    // Rebuilds the focus ring from ARoot and selects the first focusable widget.
    // Used both at startup and after every PushModal/PopModal.
    procedure RebuildFocusRing(ARoot: TTuiWidget);
    // Returns the top modal widget when the stack is non-empty, FRoot otherwise.
    function ActiveFocusRoot: TTuiWidget;
    procedure DispatchKey(const AKey: TTuiKeyEvent);
    procedure DispatchMouse(const AMouse: TTuiMouseEvent);
    // Fills the entire canvas with a light-shade character to dim the content below.
    procedure ApplyDimOverlay;
    function GetModalActive: Boolean;
    function GetModalCount: Integer;
    procedure PollResize;
    procedure RenderFrame;
  public
    /// <summary>
    ///   Creates the application. The backend is instantiated but not opened;
    ///   the console remains unchanged until Run is called.
    /// </summary>
    constructor Create;

    /// <summary>
    ///   Destroys the application. Frees the canvas, focus ring, and — if FOwnsRoot is
    ///   True — the root widget. Any owned modals remaining on the stack are also freed.
    ///   Safe to call after Run (the canvas is already freed by Run).
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    ///   Sets the root widget. AOwnsRoot = True (default) transfers ownership:
    ///   Destroy will automatically free AWidget together with the application.
    ///   Raises ETuiAppError if AWidget is nil, if Run is active, or if a root is
    ///   already set.
    /// </summary>
    procedure SetRoot(AWidget: TTuiWidget; AOwnsRoot: Boolean = True);

    /// <summary>
    ///   Starts the event loop. Initializes the terminal, canvas and focus ring, then
    ///   runs the loop until Quit is called. The terminal is always restored on exit
    ///   (try/finally), even if an exception is raised.
    /// </summary>
    /// <remarks>
    ///   Raises ETuiAppError if SetRoot has not been called or if Run is already active.
    /// </remarks>
    procedure Run;

    /// <summary>
    ///   Signals the event loop to terminate.
    /// </summary>
    /// <remarks>
    ///   Safe to call from OnKeyPress, OnTimer, or OnResize.
    /// </remarks>
    procedure Quit;

    /// <summary>
    ///   Propagates Invalidate to the root widget. No-op if no root is set.
    /// </summary>
    procedure Invalidate;

    /// <summary>
    ///   Pushes AModal onto the overlay stack. AModal is rendered above the root
    ///   widget tree each frame and traps all keyboard and mouse input: Tab cycles
    ///   only within AModal's focus ring, and mouse hits outside AModal are absorbed.
    ///   The global OnKeyPress handler is suppressed while any modal is active.
    ///   AOwnsModal = True (default) transfers ownership: PopModal or Destroy will
    ///   free AModal automatically.
    /// </summary>
    procedure PushModal(AModal: TTuiWidget; AOwnsModal: Boolean = True);

    /// <summary>
    ///   Removes the topmost modal from the overlay stack and restores the focus ring
    ///   to the modal beneath it, or to the root when the stack becomes empty.
    ///   If the popped entry was owned, the widget is freed. No-op when the stack is empty.
    /// </summary>
    procedure PopModal;

    /// <summary>
    ///   Duration of each tick in milliseconds. Default: 50 (= 20fps).
    /// </summary>
    property TickMs: Integer read FTickMs write FTickMs;

    /// <summary>
    ///   Invoked for key presses not consumed by the focused widget.
    ///   Suppressed while any modal is on the stack when ModalTrapsGlobalKeys is True
    ///   (the default). Set ModalTrapsGlobalKeys to False to receive the global handler
    ///   even while a modal is open (e.g. to wire a quit key that always works).
    /// </summary>
    property OnKeyPress: TTuiKeyHandler read FOnKeyPress write FOnKeyPress;

    /// <summary>
    ///   Invoked for mouse events not consumed by the hit widget.
    ///   The hit widget (identified by HitTestFocusable on the active focus root)
    ///   receives the event first; only if it returns False does the event bubble here.
    ///   Focus transfer on left-button-down always happens before this handler.
    /// </summary>
    property OnMouse: TTuiMouseHandler read FOnMouse write FOnMouse;

    /// <summary>
    ///   Invoked on every tick with the milliseconds elapsed since the previous iteration.
    /// </summary>
    property OnTimer: TTuiTimerHandler read FOnTimer write FOnTimer;

    /// <summary>
    ///   Invoked when the terminal is resized, providing the new dimensions.
    /// </summary>
    property OnResize: TTuiResizeHandler read FOnResize write FOnResize;

    /// <summary>
    ///   Application theme. The setter propagates the theme to all widgets
    ///   via Root.ApplyTheme and invalidates the root for re-rendering.
    ///   Default: TTuiTheme.Dark.
    /// </summary>
    property Theme: TTuiTheme read FTheme write SetTheme;

    /// <summary>
    ///   True when at least one modal overlay is on the stack.
    /// </summary>
    property ModalActive: Boolean read GetModalActive;

    /// <summary>
    ///   Number of modal overlays currently on the stack.
    /// </summary>
    property ModalCount: Integer read GetModalCount;

    /// <summary>
    ///   When True, the canvas area below the topmost modal is covered with a
    ///   light-shade overlay before the modal is rendered, creating a dim effect.
    ///   Set to False to show only the modal border/shadow without dimming.
    ///   Default: True.
    /// </summary>
    property ModalDim: Boolean read FModalDim write FModalDim;

    /// <summary>
    ///   When True (default), the global OnKeyPress handler is suppressed while
    ///   any modal is on the stack, so all key input is trapped by the modal.
    ///   Set to False to let the global handler receive keys even while a modal is
    ///   open — useful when a quit shortcut must always be reachable.
    /// </summary>
    property ModalTrapsGlobalKeys: Boolean
      read FModalTrapsGlobalKeys write FModalTrapsGlobalKeys;
  end;

implementation

uses
  System.Diagnostics,
  Blinki.Core.Ansi,
  Blinki.Core.Event,
  Blinki.Core.Render;

{ TTuiApp }

constructor TTuiApp.Create;
begin
  inherited Create;
  FBackend := TTuiConsoleBackendFactory.CreateBackend;
  FFocusRing := TTuiWidgetList.Create;
  FModalStack := TList<TTuiModalEntry>.Create;
  FModalDim := True;
  FModalTrapsGlobalKeys := True;
  FTickMs := 50;
  FTheme := TTuiTheme.Default;
end;

destructor TTuiApp.Destroy;
begin
  // Free owned modals before canvas and root to avoid dangling references.
  if Assigned(FModalStack) then
  begin
    for var LIdx := 0 to FModalStack.Count - 1 do
    begin
      if FModalStack[LIdx].Owned then
        FModalStack[LIdx].Widget.Free;
    end;
    FreeAndNil(FModalStack);
  end;
  if Assigned(FCanvas) then
    FreeAndNil(FCanvas);
  if Assigned(FFocusRing) then
    FreeAndNil(FFocusRing);
  if FOwnsRoot and Assigned(FRoot) then
    FreeAndNil(FRoot);
  inherited Destroy;
end;

procedure TTuiApp.SetTheme(const AValue: TTuiTheme);
begin
  if FTheme = AValue then
    Exit;
  FTheme := AValue;
  if Assigned(FRoot) then
    FRoot.ApplyTheme(FTheme);
end;

procedure TTuiApp.SetRoot(AWidget: TTuiWidget; AOwnsRoot: Boolean);
begin
  if FRunning then
    raise ETuiAppError.Create('TTuiApp.SetRoot: cannot set the root while Run is active');
  if not Assigned(AWidget) then
    raise ETuiAppError.Create('TTuiApp.SetRoot: AWidget cannot be nil');
  if Assigned(FRoot) then
    raise ETuiAppError.Create('TTuiApp.SetRoot: the root is already set');
  FRoot := AWidget;
  FOwnsRoot := AOwnsRoot;
  FRoot.ApplyTheme(FTheme);
  // Register the focus-structure notification so widgets like TTuiTabs can
  // trigger a focus-ring rebuild when their active page changes at runtime.
  FRoot.SetFocusStructureChangedHandler(
    procedure
    begin
      RebuildFocusRing(ActiveFocusRoot);
    end);
end;

procedure TTuiApp.SetupTerminal;
begin
  FBackend.Open;
  FBackend.Write(TTuiAnsi.AlternateBufferOn);
  FBackend.Write(TTuiAnsi.CursorHide);
  FBackend.Write(TTuiAnsi.ClearScreen);
end;

procedure TTuiApp.TeardownTerminal;
begin
  FBackend.Write(TTuiAnsi.CursorShow);
  FBackend.Write(TTuiAnsi.AlternateBufferOff);
  FBackend.Write(TTuiAnsi.Reset);
  FBackend.Close;
end;

procedure TTuiApp.RebuildFocusRing(ARoot: TTuiWidget);
begin
  // Blur the currently focused widget before clearing the ring.
  if Assigned(FFocused) then
    FFocused.Blur;
  FFocused := nil;
  FFocusRing.Clear;
  if Assigned(ARoot) then
    TTuiWidget.BuildFocusRing(ARoot, FFocusRing);
  FFocusIndex := 0;
  SelectFirstFocusable;
end;

function TTuiApp.ActiveFocusRoot: TTuiWidget;
begin
  if FModalStack.Count > 0 then
    Result := FModalStack[FModalStack.Count - 1].Widget
  else
    Result := FRoot;
end;

procedure TTuiApp.InitializeRunState;
begin
  FRoot.Init;
  // Init any modals that were pushed before Run was called.
  for var LIdx := 0 to FModalStack.Count - 1 do
    FModalStack[LIdx].Widget.Init;
  RebuildFocusRing(ActiveFocusRoot);
  FLastSize := FBackend.GetSize;
  FQuitRequested := False;
end;

procedure TTuiApp.SelectFirstFocusable;
begin
  FFocused := nil;
  if FFocusRing.Count > 0 then
  begin
    FFocused := FFocusRing[0];
    FFocused.Focus;
  end;
end;

procedure TTuiApp.CycleFocus(AForward: Boolean);
begin
  if FFocusRing.Count = 0 then
    Exit;
  if Assigned(FFocused) then
    FFocused.Blur;
  var LNewIndex: Integer;
  if AForward then
    LNewIndex := (FFocusIndex + 1) mod FFocusRing.Count
  else
    LNewIndex := (FFocusIndex - 1 + FFocusRing.Count) mod FFocusRing.Count;
  FFocusIndex := LNewIndex;
  FFocused := FFocusRing[LNewIndex];
  FFocused.Focus;
end;

procedure TTuiApp.DispatchKey(const AKey: TTuiKeyEvent);
begin
  // Tab/Shift-Tab are always intercepted by the App to cycle the focus ring.
  // The ring is already scoped to the active modal when one is open.
  if AKey.Code = kcTab then
  begin
    CycleFocus(not (kmShift in AKey.Modifiers));
    Exit;
  end;
  // The focused widget takes first priority.
  var LHandled := False;
  if Assigned(FFocused) then
    LHandled := FFocused.HandleEvent(TTuiEvent.MakeKey(AKey));
  // When a modal is active and the focused widget did not consume the key, bubble
  // the event up toward the top modal so dialog-level ESC/Enter always fire even
  // when the focus is on an inner child (e.g. a text input inside a dialog).
  if (not LHandled) and (FModalStack.Count > 0) then
  begin
    var LTop := FModalStack[FModalStack.Count - 1].Widget;
    if Assigned(FFocused) then
    begin
      // Walk from FFocused.Parent up to LTop inclusive, stopping on first consumer.
      var LNode := FFocused.Parent;
      while (not LHandled) and Assigned(LNode) do
      begin
        LHandled := LNode.HandleEvent(TTuiEvent.MakeKey(AKey));
        if LNode = LTop then
          Break;
        LNode := LNode.Parent;
      end;
    end
    else
    begin
      // No focusable child in the modal: try the modal itself directly.
      LHandled := LTop.HandleEvent(TTuiEvent.MakeKey(AKey));
    end;
  end;
  // The global key handler is suppressed while any modal is on the stack when
  // FModalTrapsGlobalKeys is True (the default).  Set it to False to let the
  // global handler receive unconsumed keys even while a modal is open.
  if (not LHandled) and Assigned(FOnKeyPress) and
     ((FModalStack.Count = 0) or not FModalTrapsGlobalKeys) then
    FOnKeyPress(AKey);
end;

procedure TTuiApp.DispatchMouse(const AMouse: TTuiMouseEvent);
begin
  // Identify the deepest focusable widget under the cursor within the active root.
  // When a modal is open this scopes the hit-test to the modal, absorbing clicks outside.
  var LTarget := ActiveFocusRoot.HitTestFocusable(TPoint.Create(AMouse.X, AMouse.Y));

  // On left button press, move focus to the hit widget (if different from current).
  if (AMouse.Kind = mekDown) and (AMouse.Button = mbLeft)
    and Assigned(LTarget) and (LTarget <> FFocused) then
  begin
    if Assigned(FFocused) then
      FFocused.Blur;
    FFocused := LTarget;
    FFocused.Focus;
    FFocusIndex := FFocusRing.IndexOf(LTarget);
  end;

  // Forward the event to the hit widget; if not consumed, bubble to OnMouse.
  var LHandled := False;
  if Assigned(LTarget) then
    LHandled := LTarget.HandleEvent(TTuiEvent.MakeMouse(AMouse));
  if not LHandled and Assigned(FOnMouse) then
    FOnMouse(AMouse);
end;

procedure TTuiApp.ApplyDimOverlay;
begin
  // Add taDim to every cell already drawn by the root tree, without altering
  // characters or colours.  The canvas diff only touches cells whose attributes
  // changed, so the ANSI flush is smaller than a full FillRect repaint.
  var LRect := TRect.Create(0, 0, FCanvas.Width, FCanvas.Height);
  FCanvas.DimRect(LRect);
end;

function TTuiApp.GetModalActive: Boolean;
begin
  Result := FModalStack.Count > 0;
end;

function TTuiApp.GetModalCount: Integer;
begin
  Result := FModalStack.Count;
end;

procedure TTuiApp.PollResize;
begin
  var LSize := FBackend.GetSize;
  if (LSize.cx = FLastSize.cx) and (LSize.cy = FLastSize.cy) then
    Exit;
  FLastSize := LSize;
  FCanvas.UpdateSize(LSize);
  FRoot.Invalidate;
  // Propagate invalidate to all modal overlays so they recentre on the next frame.
  for var LIdx := 0 to FModalStack.Count - 1 do
    FModalStack[LIdx].Widget.Invalidate;
  if Assigned(FOnResize) then
    FOnResize(LSize);
end;

procedure TTuiApp.RenderFrame;
begin
  FCanvas.Clear;
  var LFullRect := TRect.Create(0, 0, FCanvas.Width, FCanvas.Height);
  FRoot.Render(FCanvas, LFullRect);
  // Render modal overlays on top of the root in stack order (bottom to top).
  if FModalStack.Count > 0 then
  begin
    if FModalDim then
      ApplyDimOverlay;
    for var LIdx := 0 to FModalStack.Count - 1 do
      FModalStack[LIdx].Widget.Render(FCanvas, LFullRect);
  end;
  FCanvas.Flush;
end;

procedure TTuiApp.Run;
begin
  if not Assigned(FRoot) then
    raise ETuiAppError.Create('TTuiApp.Run: SetRoot has not been called');
  if FRunning then
    raise ETuiAppError.Create('TTuiApp.Run: already running');
  FRunning := True;
  try
    SetupTerminal;
    FCanvas := TTuiCanvas.Create(FBackend);
    InitializeRunState;
    var LWatch := TStopwatch.StartNew;
    var LLastTick := 0;
    var LEvent: TTuiEvent;
    while not FQuitRequested do
    begin
      if FBackend.TryReadEvent(FTickMs, LEvent) then
        case LEvent.Kind of
          ekKey:   DispatchKey(LEvent.Key);
          ekMouse: DispatchMouse(LEvent.Mouse);
        end;
      if FQuitRequested then
        Break;
      var LNow := LWatch.ElapsedMilliseconds;
      if Assigned(FOnTimer) then
        FOnTimer(LNow - LLastTick);
      FRoot.Tick(LNow - LLastTick);
      // Propagate tick to all modal overlays (e.g. for animated progress bars).
      for var LIdx := 0 to FModalStack.Count - 1 do
        FModalStack[LIdx].Widget.Tick(LNow - LLastTick);
      LLastTick := LNow;
      PollResize;
      RenderFrame;
    end;
  finally
    FreeAndNil(FCanvas);
    TeardownTerminal;
    FRunning := False;
  end;
end;

procedure TTuiApp.Quit;
begin
  FQuitRequested := True;
end;

procedure TTuiApp.Invalidate;
begin
  if Assigned(FRoot) then
    FRoot.Invalidate;
end;

procedure TTuiApp.PushModal(AModal: TTuiWidget; AOwnsModal: Boolean);
begin
  if not Assigned(AModal) then
    raise ETuiAppError.Create('TTuiApp.PushModal: AModal cannot be nil');
  AModal.ApplyTheme(FTheme);
  // Init immediately if the event loop is already running; otherwise InitializeRunState
  // will call Init for modals pushed before Run.
  if FRunning then
    AModal.Init;
  var LEntry: TTuiModalEntry;
  LEntry.Widget := AModal;
  LEntry.Owned := AOwnsModal;
  FModalStack.Add(LEntry);
  // Register the notification handler on the modal so its contained TTuiTabs
  // (if any) can trigger a focus-ring rebuild when their active page changes.
  AModal.SetFocusStructureChangedHandler(
    procedure
    begin
      RebuildFocusRing(ActiveFocusRoot);
    end);
  // Rebuild the focus ring scoped to the new top modal.
  RebuildFocusRing(AModal);
  if Assigned(FRoot) then
    FRoot.Invalidate;
end;

procedure TTuiApp.PopModal;
begin
  if FModalStack.Count = 0 then
    Exit;
  var LIdx := FModalStack.Count - 1;
  var LEntry := FModalStack[LIdx];
  FModalStack.Delete(LIdx);
  // Restore the focus ring to the new top modal, or to the root if the stack is empty.
  RebuildFocusRing(ActiveFocusRoot);
  if Assigned(FRoot) then
    FRoot.Invalidate;
  // Free the widget last, after the ring has been rebuilt from the remaining stack.
  if LEntry.Owned then
    LEntry.Widget.Free;
end;

end.
