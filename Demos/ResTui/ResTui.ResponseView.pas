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
{   Unit:        ResTui.ResponseView.pas                         }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget that renders the result of an HTTP request in three states:
///   idle (blank), loading (spinner), and done (status line + Body/Headers tabs).
/// </summary>
unit ResTui.ResponseView;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  Blinki.Layout.Scrollable,
  Blinki.Widgets.Spinner,
  Blinki.Widgets.Table,
  Blinki.Widgets.Tabs,
  Blinki.Widgets.TextArea,
  ResTui.Model;

type

{ TResTuiResponseView }

  /// <summary>
  ///   Panel widget showing the result of an HTTP request.
  ///   Call ShowIdle, ShowLoading, or ShowResponse to switch state.
  /// </summary>
  TResTuiResponseView = class(TTuiWidget)
  strict private
    // State flags
    FShowSpinner: Boolean;
    FHasResponse: Boolean;
    // Status line data
    FStatusLabel: string;
    FStatusColor: TTuiColor;
    // Child widgets
    FSpinner: TTuiSpinner;
    FTabs: TTuiTabs;
    FBodyArea: TTuiTextArea;
    FBodyScrollable: TTuiScrollable;
    FHeadersTable: TTuiTable;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the response view and builds child widgets (spinner, tabs, body, headers).
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Frees the spinner (not parented to the widget tree) and inherited children.
    /// </summary>
    destructor Destroy; override;
    /// <summary>
    ///   Resets the panel to idle state: no status, no spinner, no content.
    /// </summary>
    procedure ShowIdle;
    /// <summary>
    ///   Shows the loading spinner while the request is in flight.
    /// </summary>
    procedure ShowLoading;
    /// <summary>
    ///   Populates the panel with the HTTP response: status line, body and headers.
    /// </summary>
    procedure ShowResponse(const AResponse: TResTuiResponse);
  end;

implementation

uses
  System.SysUtils,
  Blinki.Core.Ansi,
  Blinki.Core.Event,
  Blinki.Core.Geometry,
  ResTui.Consts,
  ResTui.Helpers;

{ TResTuiResponseView }

constructor TResTuiResponseView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);

  // Spinner — shown only in loading state; not added as a child here because
  // we render it manually in DoRender with a custom rect.
  FSpinner := TTuiSpinner.Create;
  FSpinner.Style := ssDots;
  FSpinner.SpinnerLabel := ' Executing request...';

  // Body area (read-only text area wrapped in a vertical scrollable)
  FBodyArea := TTuiTextArea.Create;
  FBodyArea.ReadOnly := True;
  FBodyArea.Placeholder := '(no body)';

  FBodyScrollable := TTuiScrollable.Create(FBodyArea, sdVertical);

  // Headers table (two columns)
  FHeadersTable := TTuiTable.Create;
  FHeadersTable.ShowBorder := False;
  FHeadersTable.AddColumn('Header', 30);
  FHeadersTable.AddColumn('Value', 0);

  // Tabs container — owns both pages
  FTabs := TTuiTabs.Create(Self);
  FTabs.AddTab('Body', FBodyScrollable);
  FTabs.AddTab('Headers', FHeadersTable);

  FStatusColor := TTuiColor.Default;
end;

destructor TResTuiResponseView.Destroy;
begin
  FreeAndNil(FSpinner);
  inherited Destroy;
end;

procedure TResTuiResponseView.DoInit;
begin
  inherited DoInit;
  // Propagate Init to manually-owned widgets that are not in our child list
  FSpinner.Init;
end;

procedure TResTuiResponseView.DoApplyTheme(const ATheme: TTuiTheme);
begin
  FSpinner.ApplyTheme(ATheme);
end;

procedure TResTuiResponseView.DoRender(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  // Choose border color based on focus
  var LBorderStyle: TTuiStyle;
  if Focused then
    LBorderStyle := TTuiStyle.Create(CColorBorderFocus, TTuiColor.Default)
  else
    LBorderStyle := TTuiStyle.Create(CColorBorderNormal, TTuiColor.Default);

  // Draw the outer box
  ACanvas.DrawBox(ARect, bsRounded, CPanelResponse, LBorderStyle);

  // Compute inner rect (inside the border)
  var LInner := TRect.Create(
    ARect.Left + 1,
    ARect.Top + 1,
    ARect.Right - 1,
    ARect.Bottom - 1
  );

  if LInner.IsEmpty or (LInner.Height < 2) then
    Exit;

  // Row 0 of inner: status line
  var LStatusStyle := TTuiStyle.Create(FStatusColor, TTuiColor.Default, [taBold]);
  var LStatusText: string;
  if FStatusLabel <> '' then
    LStatusText := ' ' + FStatusLabel
  else if FShowSpinner then
    LStatusText := ''
  else
    LStatusText := ' Ready.';

  ACanvas.FillRect(
    TRect.Create(LInner.Left, LInner.Top, LInner.Right, LInner.Top + 1),
    ' ',
    TTuiStyle.Default
  );
  if LStatusText <> '' then
    ACanvas.WriteAt(LInner.Left, LInner.Top, LStatusText, LStatusStyle);

  // Remaining rows: spinner or tabs
  var LContentRect := TRect.Create(
    LInner.Left,
    LInner.Top + 1,
    LInner.Right,
    LInner.Bottom
  );

  if LContentRect.IsEmpty then
    Exit;

  if FShowSpinner then
  begin
    // Render spinner centered vertically in the content area
    var LCenterY := LContentRect.Top + (LContentRect.Height div 2);
    var LSpinnerRect := TRect.Create(
      LContentRect.Left,
      LCenterY,
      LContentRect.Right,
      LCenterY + 1
    );
    FSpinner.Render(ACanvas, LSpinnerRect);
  end
  else if FHasResponse then
    FTabs.Render(ACanvas, LContentRect)
  else
  begin
    // Idle state: show a dim hint
    var LHintStyle := TTuiStyle.Create(Theme.TextDim, TTuiColor.Default);
    ACanvas.WriteAt(
      LContentRect.Left + 1,
      LContentRect.Top + (LContentRect.Height div 2),
      'Send a request to see the response here.',
      LHintStyle
    );
  end;
end;

procedure TResTuiResponseView.ShowIdle;
begin
  FShowSpinner := False;
  FHasResponse := False;
  FStatusLabel := '';
  FStatusColor := TTuiColor.Default;
  FBodyArea.Text := '';
  FHeadersTable.ClearRows;
  Invalidate;
end;

procedure TResTuiResponseView.ShowLoading;
begin
  FShowSpinner := True;
  FHasResponse := False;
  FStatusLabel := '';
  FStatusColor := TTuiColor.Default;
  Invalidate;
end;

procedure TResTuiResponseView.ShowResponse(const AResponse: TResTuiResponse);
begin
  FShowSpinner := False;
  FHasResponse := True;

  if AResponse.HasError then
  begin
    FStatusLabel := 'Error: ' + AResponse.ErrorMessage;
    FStatusColor := CColorStatusErr;
    FBodyArea.Text := '';
  end
  else
  begin
    FStatusLabel := Format('%d %s  %s',
      [AResponse.StatusCode, AResponse.StatusText,
       FormatDuration(AResponse.DurationMs)]);
    FStatusColor := StatusColor(AResponse.StatusCode);
    FBodyArea.Text := PrettyJson(AResponse.Body);
  end;

  // Populate headers table
  FHeadersTable.ClearRows;
  for var LKV in AResponse.Headers do
    FHeadersTable.AddRow([LKV.Key, LKV.Value]);

  // Switch to Body tab by default
  FTabs.ActiveIndex := 0;

  Invalidate;
end;

end.
