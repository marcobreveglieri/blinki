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
{   Unit:        ResTui.Overlays.pas                             }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Modal overlay base class and concrete help overlay for the ResTui demo.
///   TResTuiOverlay dims the background, draws a centred panel, and closes
///   on Esc or Enter. TResTuiHelpView lists the keyboard shortcuts.
/// </summary>
unit ResTui.Overlays;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Widget;

type

{ TResTuiOverlay }

  /// <summary>
  ///   Base class for semi-modal overlays. Dims the background, draws a centred
  ///   rounded panel, and closes on Esc or Enter via the OnClose callback.
  /// </summary>
  TResTuiOverlay = class(TTuiWidget)
  strict private
    FOnClose: TProc;
  protected
    procedure DoInit; override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    /// <summary>
    ///   Draws a centred rounded panel inside ARect and returns the inner rect in AInner.
    ///   Subclasses call this first, then draw their content inside AInner.
    /// </summary>
    procedure DrawPanel(const ACanvas: TTuiCanvas; const ARect: TRect;
      const ATitle: string; out AInner: TRect); virtual;
  public
    /// <summary>
    ///   Creates the overlay. Pass AParent to register it in the widget tree.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Invoked when the user presses Esc or Enter to close the overlay.
    /// </summary>
    property OnClose: TProc read FOnClose write FOnClose;
  end;

{ TResTuiHelpView }

  /// <summary>
  ///   Help overlay listing the main keyboard shortcuts for the ResTui demo.
  /// </summary>
  TResTuiHelpView = class(TResTuiOverlay)
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Creates the help overlay.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
  end;

implementation

uses
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  ResTui.Consts;

{ TResTuiOverlay }

constructor TResTuiOverlay.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
end;

procedure TResTuiOverlay.DoInit;
begin
  inherited DoInit;
  SetFocusable(True);
end;

function TResTuiOverlay.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  if (AEvent.Key.Code = kcEscape) or (AEvent.Key.Code = kcEnter) then
  begin
    if Assigned(FOnClose) then
      FOnClose();
    Result := True;
  end;
end;

procedure TResTuiOverlay.DrawPanel(const ACanvas: TTuiCanvas;
  const ARect: TRect; const ATitle: string; out AInner: TRect);
begin
  // Panel size: 60% width, 70% height of the available area (minimum 30x10)
  var LPanelW := Max(30, ARect.Width * 60 div 100);
  var LPanelH := Max(10, ARect.Height * 70 div 100);

  // Centre horizontally and vertically
  var LPanelLeft := ARect.Left + (ARect.Width - LPanelW) div 2;
  var LPanelTop := ARect.Top + (ARect.Height - LPanelH) div 2;

  var LPanelRect := TRect.Create(LPanelLeft, LPanelTop,
    LPanelLeft + LPanelW, LPanelTop + LPanelH);

  var LBorderStyle := TTuiStyle.Create(CColorBorderFocus, TTuiColor.Default, [taBold]);

  // Fill the panel background with the surface colour
  ACanvas.FillRect(LPanelRect, ' ', TTuiStyle.Create(Theme.Text, Theme.Surface));

  // Draw the rounded box
  ACanvas.DrawBox(LPanelRect, bsRounded, ATitle, LBorderStyle);

  // Inner rect (inside the border)
  AInner := TRect.Create(
    LPanelRect.Left + 1,
    LPanelRect.Top + 1,
    LPanelRect.Right - 1,
    LPanelRect.Bottom - 1
  );
end;

procedure TResTuiOverlay.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
var
  LInner: TRect;
begin
  // Dim everything behind the overlay
  ACanvas.DimRect(ARect);

  // Draw the panel
  DrawPanel(ACanvas, ARect, '', LInner);

  if LInner.IsEmpty then
    Exit;

  // Hint at the bottom of the panel interior
  var LHint := 'Press Esc or Enter to close';
  var LHintStyle := TTuiStyle.Create(Theme.TextDim, TTuiColor.Default);
  var LHintX := LInner.Left + (LInner.Width - Length(LHint)) div 2;
  if LHintX < LInner.Left then
    LHintX := LInner.Left;
  ACanvas.WriteAt(LHintX, LInner.Bottom - 1, LHint, LHintStyle);
end;

{ TResTuiHelpView }

constructor TResTuiHelpView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
end;

procedure TResTuiHelpView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
const
  CKeys: array[0..10] of string = (
    'F5 / Ctrl+Enter',
    'F2',
    'F7',
    'F8',
    'F1',
    'F10 / Ctrl+Q',
    'Tab / Shift+Tab',
    'Up / Down',
    'Enter',
    'Left / Right',
    'Space / T'
  );
  CDescs: array[0..10] of string = (
    'Send request',
    'Save collection',
    'New request',
    'Delete request',
    'This help',
    'Quit',
    'Cycle focus',
    'Navigate list',
    'Select / Edit',
    'Change type / Tab',
    'Toggle enabled'
  );
var
  LInner: TRect;
begin
  // Dim the background
  ACanvas.DimRect(ARect);

  // Draw the panel
  DrawPanel(ACanvas, ARect, ' Keyboard Shortcuts ', LInner);

  if LInner.IsEmpty then
    Exit;

  // Styles
  var LTitleStyle := TTuiStyle.Create(Theme.Primary, TTuiColor.Default, [taBold]);
  var LKeyStyle := TTuiStyle.Create(Theme.Secondary, TTuiColor.Default, [taBold]);
  var LDescStyle := TTuiStyle.Create(Theme.Text, TTuiColor.Default);
  var LSepStyle := TTuiStyle.Create(Theme.Border, TTuiColor.Default);

  // Column positions
  var LKeyCol := LInner.Left + 2;
  var LDescCol := LKeyCol + 20;  // key column is 18 chars wide + 2 spacing

  // Header row
  ACanvas.WriteAt(LKeyCol, LInner.Top + 1, 'Key', LTitleStyle);
  ACanvas.WriteAt(LDescCol, LInner.Top + 1, 'Action', LTitleStyle);

  // Separator
  var LSep := StringOfChar('-', LInner.Width - 4);
  ACanvas.WriteAt(LKeyCol, LInner.Top + 2, LSep, LSepStyle);

  // Key rows
  for var I := 0 to High(CKeys) do
  begin
    var LRow := LInner.Top + 3 + I;
    if LRow >= LInner.Bottom - 1 then
      Break;
    ACanvas.WriteAt(LKeyCol, LRow, CKeys[I], LKeyStyle);
    if LDescCol < LInner.Right then
      ACanvas.WriteAt(LDescCol, LRow, CDescs[I], LDescStyle);
  end;

  // Close hint at the bottom
  var LHint := 'Press Esc or Enter to close';
  var LHintStyle := TTuiStyle.Create(Theme.TextDim, TTuiColor.Default);
  var LHintX := LInner.Left + (LInner.Width - Length(LHint)) div 2;
  if LHintX < LInner.Left then
    LHintX := LInner.Left;
  ACanvas.WriteAt(LHintX, LInner.Bottom - 1, LHint, LHintStyle);
end;

end.
