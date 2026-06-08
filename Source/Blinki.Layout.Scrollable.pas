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
{   Unit:        Blinki.Layout.Scrollable.pas                    }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Scrollable container for the Blinki library.
///   TTuiScrollable wraps a single child widget of virtual size ContentSize,
///   showing only the visible portion via PushClip/PopClip on the canvas.
///   Handles vertical and/or horizontal scrolling with arrow keys,
///   PgUp/PgDn, Home and End. Optionally renders a scrollbar.
/// </summary>
unit Blinki.Layout.Scrollable;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Widget;

type

{ TTuiScrollDirection }

  /// <summary>
  ///   Scroll direction(s) enabled in TTuiScrollable.
  /// </summary>
  TTuiScrollDirection = (
    /// <summary>
    ///   No scrolling (static content with clipping).
    /// </summary>
    sdNone,
    /// <summary>
    ///   Vertical scrolling only.
    /// </summary>
    sdVertical,
    /// <summary>
    ///   Horizontal scrolling only.
    /// </summary>
    sdHorizontal,
    /// <summary>
    ///   Both vertical and horizontal scrolling.
    /// </summary>
    sdBoth
  );

{ TTuiScrollable }

  /// <summary>
  ///   Container that shows the visible portion of a child widget larger than
  ///   the available area. The child is rendered into a TRect of size ContentSize
  ///   translated by -Offset; clipping constrains output to the visible area.
  ///   Focusable: handles arrow keys, PgUp/PgDn, Home/End to update Offset.
  /// </summary>
  TTuiScrollable = class(TTuiWidget)
  strict private
    FContent: TTuiWidget;
    FContentSize: TSize;
    FOffsetX: Integer;
    FOffsetY: Integer;
    FDirection: TTuiScrollDirection;
    FShowScrollbar: Boolean;
    FLastViewSize: TSize;  // updated on each DoRender
    procedure ClampOffset(const AViewSize: TSize);
    function  HasVertical: Boolean; inline;
    function  HasHorizontal: Boolean; inline;
    procedure DrawVerticalScrollbar(const ACanvas: TTuiCanvas;
      const ARect: TRect; AViewHeight: Integer);
    procedure DrawHorizontalScrollbar(const ACanvas: TTuiCanvas;
      const ARect: TRect; AViewWidth: Integer);
  protected
    /// <summary>
    ///   Sets Focusable=True when the direction includes at least one scroll axis.
    /// </summary>
    procedure DoInit; override;
    /// <summary>
    ///   Computes the visible area, applies PushClip, renders FContent in translated
    ///   coordinates, calls PopClip, then draws the optional scrollbars.
    /// </summary>
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    /// <summary>
    ///   Handles arrow keys, PgUp, PgDn, Home and End by updating the offset and
    ///   invalidating the widget. Returns True if the event was consumed.
    /// </summary>
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
  public
    /// <summary>
    ///   Creates a TTuiScrollable wrapping AContent.
    ///   AContent is registered as a child widget (ownership is transferred).
    ///   ADirection specifies the scroll axes; default: sdVertical.
    ///   ContentSize is initialized to (0, 0): assign it before calling Run.
    /// </summary>
    constructor Create(AContent: TTuiWidget;
      ADirection: TTuiScrollDirection = sdVertical;
      AParent: TTuiWidget = nil);
    /// <summary>
    ///   Virtual size of the content (Width x Height in cells).
    ///   Set before the first Run; changing this value invalidates the widget.
    /// </summary>
    property ContentSize: TSize read FContentSize write FContentSize;
    /// <summary>
    ///   When True (default), renders the scrollbar on the enabled axis.
    ///   The scrollbar occupies 1 column on the right (vertical) or 1 row at
    ///   the bottom (horizontal).
    /// </summary>
    property ShowScrollbar: Boolean read FShowScrollbar write FShowScrollbar;
    /// <summary>
    ///   Current horizontal scroll offset in columns.
    /// </summary>
    property OffsetX: Integer read FOffsetX;
    /// <summary>
    ///   Current vertical scroll offset in rows.
    /// </summary>
    property OffsetY: Integer read FOffsetY;
    /// <summary>
    ///   Enabled scroll direction(s).
    /// </summary>
    property Direction: TTuiScrollDirection read FDirection;
  end;

implementation

uses
  System.Math,
  Blinki.Core.Geometry,
  Blinki.Core.Input,
  Blinki.Core.Style;

{ TTuiScrollable }

constructor TTuiScrollable.Create(AContent: TTuiWidget;
  ADirection: TTuiScrollDirection; AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FContent := AContent;
  FDirection := ADirection;
  FShowScrollbar := True;
  FContentSize := TSize.Create(0, 0);
  FLastViewSize := TSize.Create(0, 0);
  // Registers the child (ownership transferred)
  if Assigned(AContent) and not Assigned(AContent.Parent) then
    AddChild(AContent);
end;

function TTuiScrollable.HasVertical: Boolean;
begin
  Result := FDirection in [sdVertical, sdBoth];
end;

function TTuiScrollable.HasHorizontal: Boolean;
begin
  Result := FDirection in [sdHorizontal, sdBoth];
end;

procedure TTuiScrollable.DoInit;
begin
  inherited DoInit;
  SetFocusable(FDirection <> sdNone);
end;

procedure TTuiScrollable.ClampOffset(const AViewSize: TSize);
begin
  if HasHorizontal then
  begin
    var LMaxX := Max(0, FContentSize.cx - AViewSize.cx);
    if FOffsetX < 0 then
      FOffsetX := 0;
    if FOffsetX > LMaxX then
      FOffsetX := LMaxX;
  end
  else
    FOffsetX := 0;

  if HasVertical then
  begin
    var LMaxY := Max(0, FContentSize.cy - AViewSize.cy);
    if FOffsetY < 0 then
      FOffsetY := 0;
    if FOffsetY > LMaxY then
      FOffsetY := LMaxY;
  end
  else
    FOffsetY := 0;
end;

procedure TTuiScrollable.DrawVerticalScrollbar(const ACanvas: TTuiCanvas;
  const ARect: TRect; AViewHeight: Integer);
begin
  var LX := ARect.Right - 1;
  if (LX < ARect.Left) or (AViewHeight < 3) then
    Exit;

  var LStyleActive: TTuiStyle;
  if Focused then
    LStyleActive := TTuiStyle.Create(TTuiColors.BrightWhite, TTuiColor.Default, [])
  else
    LStyleActive := TTuiStyle.Create(TTuiColors.BrightBlack, TTuiColor.Default, []);
  var LStyleTrack := TTuiStyle.Create(TTuiColors.BrightBlack, TTuiColor.Default, []);

  // Arrows
  ACanvas.WriteAt(LX, ARect.Top, #$25B2, LStyleActive);  // ▲
  ACanvas.WriteAt(LX, ARect.Top + AViewHeight - 1, #$25BC, LStyleActive);  // ▼

  // Track
  var LTrackTop := ARect.Top + 1;
  var LTrackBot := ARect.Top + AViewHeight - 2;
  var LTrackLen := LTrackBot - LTrackTop + 1;
  if LTrackLen < 1 then
    Exit;

  // Thumb: size and position are proportional
  var LThumbTop: Integer;
  var LThumbBot: Integer;
  var LContentH  := Max(1, FContentSize.cy);
  var LMaxOffset := Max(1, LContentH - AViewHeight);
  if FContentSize.cy <= AViewHeight then
  begin
    // Content smaller than the viewport: thumb fills the entire track
    LThumbTop := LTrackTop;
    LThumbBot := LTrackBot;
  end
  else
  begin
    var LThumbLen := Max(1, Round(LTrackLen * AViewHeight / LContentH));
    var LScrollRatio := FOffsetY / LMaxOffset;
    LThumbTop := LTrackTop + Round((LTrackLen - LThumbLen) * LScrollRatio);
    LThumbBot := LThumbTop + LThumbLen - 1;
    if LThumbBot > LTrackBot then
      LThumbBot := LTrackBot;
  end;

  for var LIndex := LTrackTop to LTrackBot do
    if (LIndex >= LThumbTop) and (LIndex <= LThumbBot) then
      ACanvas.WriteAt(LX, LIndex, #$2588, LStyleActive)  // █ thumb
    else
      ACanvas.WriteAt(LX, LIndex, #$2591, LStyleTrack);  // ░ track
end;

procedure TTuiScrollable.DrawHorizontalScrollbar(const ACanvas: TTuiCanvas;
  const ARect: TRect; AViewWidth: Integer);
begin
  var LY := ARect.Bottom - 1;
  if (LY < ARect.Top) or (AViewWidth < 3) then
    Exit;

  var LStyleActive: TTuiStyle;
  if Focused then
    LStyleActive := TTuiStyle.Create(TTuiColors.BrightWhite, TTuiColor.Default, [])
  else
    LStyleActive := TTuiStyle.Create(TTuiColors.BrightBlack, TTuiColor.Default, []);
  var LStyleTrack := TTuiStyle.Create(TTuiColors.BrightBlack, TTuiColor.Default, []);

  // Arrows
  ACanvas.WriteAt(ARect.Left,                  LY, #$25C4, LStyleActive);  // ◄
  ACanvas.WriteAt(ARect.Left + AViewWidth - 1, LY, #$25BA, LStyleActive);  // ►

  // Track
  var LTrackLeft  := ARect.Left + 1;
  var LTrackRight := ARect.Left + AViewWidth - 2;
  var LTrackLen   := LTrackRight - LTrackLeft + 1;
  if LTrackLen < 1 then
    Exit;

  var LThumbLeft: Integer;
  var LThumbRight: Integer;
  var LContentW := Max(1, FContentSize.cx);
  var LMaxOffset := Max(1, LContentW - AViewWidth);
  if FContentSize.cx <= AViewWidth then
  begin
    LThumbLeft := LTrackLeft;
    LThumbRight := LTrackRight;
  end
  else
  begin
    var LThumbLen := Max(1, Round(LTrackLen * AViewWidth / LContentW));
    var LScrollRatio := FOffsetX / LMaxOffset;
    LThumbLeft := LTrackLeft + Round((LTrackLen - LThumbLen) * LScrollRatio);
    LThumbRight := LThumbLeft + LThumbLen - 1;
    if LThumbRight > LTrackRight then
      LThumbRight := LTrackRight;
  end;

  for var LIndex := LTrackLeft to LTrackRight do
  begin
    if (LIndex >= LThumbLeft) and (LIndex <= LThumbRight) then
      ACanvas.WriteAt(LIndex, LY, #$2588, LStyleActive)  // █ thumb
    else
      ACanvas.WriteAt(LIndex, LY, #$2591, LStyleTrack);  // ░ track
  end;
end;

procedure TTuiScrollable.DoRender(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  if not Assigned(FContent) then
    Exit;

  // Computes the visible area (excludes scrollbars when active)
  var LViewRect := ARect;
  if FShowScrollbar and HasVertical and (ARect.Width >= 2) then
    Dec(LViewRect.Right);
  if FShowScrollbar and HasHorizontal and (ARect.Height >= 2) then
    Dec(LViewRect.Bottom);

  if LViewRect.IsEmpty then
    Exit;

  var LViewSize := TSize.Create(LViewRect.Width, LViewRect.Height);
  FLastViewSize := LViewSize;
  ClampOffset(LViewSize);

  // If ContentSize has not been set, uses the visible area as content
  if FContentSize.cx <= 0 then
    FContentSize.cx := LViewSize.cx;
  if FContentSize.cy <= 0 then
    FContentSize.cy := LViewSize.cy;

  // Clips to the visible area, then renders the translated content
  ACanvas.PushClip(LViewRect);
  try
    var LContentRect := TRect.Create(
      LViewRect.Left - FOffsetX,
      LViewRect.Top  - FOffsetY,
      LViewRect.Left - FOffsetX + FContentSize.cx,
      LViewRect.Top  - FOffsetY + FContentSize.cy);
    FContent.Render(ACanvas, LContentRect);
  finally
    ACanvas.PopClip;
  end;

  // Draws the scrollbars outside the clip region
  if FShowScrollbar then
  begin
    if HasVertical and (ARect.Width >= 2) then
      DrawVerticalScrollbar(ACanvas, ARect, LViewRect.Height);
    if HasHorizontal and (ARect.Height >= 2) then
      DrawHorizontalScrollbar(ACanvas, ARect, LViewRect.Width);
  end;
end;

function TTuiScrollable.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;

  if AEvent.Kind <> ekKey then
    Exit;

  // Uses the viewport height measured during the last DoRender
  var LPageH := Max(1, FLastViewSize.cy);

  case AEvent.Key.Code of
    kcUp:
      if HasVertical then
      begin
        Dec(FOffsetY);
        ClampOffset(FLastViewSize);
        Invalidate;
        Result := True;
      end;
    kcDown:
      if HasVertical then
      begin
        Inc(FOffsetY);
        ClampOffset(FLastViewSize);
        Invalidate;
        Result := True;
      end;
    kcLeft:
      if HasHorizontal then
      begin
        Dec(FOffsetX);
        ClampOffset(FLastViewSize);
        Invalidate;
        Result := True;
      end;
    kcRight:
      if HasHorizontal then
      begin
        Inc(FOffsetX);
        ClampOffset(FLastViewSize);
        Invalidate;
        Result := True;
      end;
    kcPageUp:
      if HasVertical then
      begin
        Dec(FOffsetY, LPageH);
        ClampOffset(FLastViewSize);
        Invalidate;
        Result := True;
      end;
    kcPageDown:
      if HasVertical then
      begin
        Inc(FOffsetY, LPageH);
        ClampOffset(FLastViewSize);
        Invalidate;
        Result := True;
      end;
    kcHome:
      if HasVertical then
      begin
        FOffsetY := 0;
        Invalidate;
        Result := True;
      end;
    kcEnd:
      if HasVertical then
      begin
        FOffsetY := Max(0, FContentSize.cy - LPageH);
        ClampOffset(FLastViewSize);
        Invalidate;
        Result := True;
      end;
  end;
end;

end.
