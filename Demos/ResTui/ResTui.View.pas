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
{   Unit:        ResTui.View.pas                                 }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Main view for the ResTui demo.
///   Assembles the full widget tree (header, sidebar, URL row, params tabs,
///   response panel, footer) and exposes references so the program entry
///   point can wire up callbacks and business logic.
/// </summary>
unit ResTui.View;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Widget,
  Blinki.Layout.Stack,
  Blinki.Widgets.Tabs,
  Blinki.Widgets.TextInput,
  ResTui.AuthPanel,
  ResTui.BodyPanel,
  ResTui.KeyValueEditor,
  ResTui.Model,
  ResTui.RequestList,
  ResTui.ResponseView;

type

{ TResTuiMethodWidget }

  /// <summary>
  ///   Compact method selector widget: shows the current HTTP method in a
  ///   rounded box and cycles through CHttpMethods with Left/Right arrow keys.
  /// </summary>
  TResTuiMethodWidget = class(TTuiWidget)
  strict private
    FMethodIndex: Integer;
    function GetMethod: string;
    procedure SetMethod(const AValue: string);
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
  public
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Currently selected HTTP method name (e.g. 'GET', 'POST').
    /// </summary>
    property Method: string read GetMethod write SetMethod;
  end;

{ TResTuiFooterWidget }

  /// <summary>
  ///   Single-row footer that renders a dim hint text on the full width.
  /// </summary>
  TResTuiFooterWidget = class(TTuiWidget)
  strict private
    FText: string;
    procedure SetText(const AValue: string);
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create(AParent: TTuiWidget = nil);
    property Text: string read FText write SetText;
  end;

{ TResTuiView }

  /// <summary>
  ///   Root widget that assembles the complete ResTui interface tree.
  ///   The program entry point (ResTui.dpr) owns the collection and wires
  ///   all callbacks on the exposed widget references.
  /// </summary>
  TResTuiView = class(TTuiVStack)
  strict private
    FAuthPanel: TResTuiAuthPanel;
    FBodyPanel: TResTuiBodyPanel;
    FCurrentRequest: TResTuiRequest;
    FDummyHeaders: TList<TResTuiKeyValue>;
    FDummyParams: TList<TResTuiKeyValue>;
    FFooter: TResTuiFooterWidget;
    FHeadersEditor: TResTuiKeyValueEditor;
    FMethodWidget: TResTuiMethodWidget;
    FParamsEditor: TResTuiKeyValueEditor;
    FParamsTabs: TTuiTabs;
    FRequestList: TResTuiRequestList;
    FResponseView: TResTuiResponseView;
    FUrlInput: TTuiTextInput;
  public
    constructor Create(ACollection: TResTuiCollection);
    destructor Destroy; override;
    /// <summary>
    ///   Populates all editor widgets from the given request.
    ///   Stores a reference to ARequest so CollectIntoCurrentRequest knows where to write back.
    /// </summary>
    procedure LoadRequest(ARequest: TResTuiRequest);
    /// <summary>
    ///   Reads back the editor state into the current request.
    ///   No-op if no request is loaded.
    /// </summary>
    procedure CollectIntoCurrentRequest;
    /// <summary>
    ///   Displays the HTTP response in the response panel.
    /// </summary>
    procedure ShowResponse(const AResponse: TResTuiResponse);
    /// <summary>
    ///   Switches the response panel between loading (spinner) and result states.
    /// </summary>
    procedure SetLoading(ABusy: Boolean);
    property AuthPanel: TResTuiAuthPanel read FAuthPanel;
    property BodyPanel: TResTuiBodyPanel read FBodyPanel;
    property CurrentRequest: TResTuiRequest read FCurrentRequest;
    property DummyHeaders: TList<TResTuiKeyValue> read FDummyHeaders;
    property DummyParams: TList<TResTuiKeyValue> read FDummyParams;
    property Footer: TResTuiFooterWidget read FFooter;
    property HeadersEditor: TResTuiKeyValueEditor read FHeadersEditor;
    property MethodWidget: TResTuiMethodWidget read FMethodWidget;
    property ParamsEditor: TResTuiKeyValueEditor read FParamsEditor;
    property ParamsTabs: TTuiTabs read FParamsTabs;
    property RequestList: TResTuiRequestList read FRequestList;
    property ResponseView: TResTuiResponseView read FResponseView;
    property UrlInput: TTuiTextInput read FUrlInput;
  end;

implementation

uses
  System.SysUtils,
  Blinki.Core.Ansi,
  Blinki.Core.Geometry,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  ResTui.Consts,
  ResTui.Helpers;

{ TResTuiMethodWidget }

constructor TResTuiMethodWidget.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  // FMethodIndex := 0 is the default (GET) — already zero-initialized
end;

function TResTuiMethodWidget.GetMethod: string;
begin
  Result := CHttpMethods[FMethodIndex];
end;

procedure TResTuiMethodWidget.SetMethod(const AValue: string);
begin
  var LUpper := UpperCase(AValue);
  for var I := 0 to High(CHttpMethods) do
  begin
    if CHttpMethods[I] = LUpper then
    begin
      if FMethodIndex = I then
        Exit;
      FMethodIndex := I;
      Invalidate;
      Exit;
    end;
  end;
end;

procedure TResTuiMethodWidget.DoInit;
begin
  SetFocusable(True);
end;

procedure TResTuiMethodWidget.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  var LBorderColor := CColorBorderNormal;
  if Focused then
    LBorderColor := CColorBorderFocus;
  var LBorderStyle := TTuiStyle.Create(LBorderColor, Theme.Background);
  ACanvas.DrawBox(ARect, bsRounded, '', LBorderStyle);
  var LInner := TRect.Create(ARect.Left + 1, ARect.Top + 1, ARect.Right - 1, ARect.Bottom - 1);
  if LInner.IsEmpty then
    Exit;
  ACanvas.FillRect(LInner, ' ', TTuiStyle.Create(Theme.Text, Theme.Background));
  // Centre the method name inside the box
  var LMethod := GetMethod;
  var LX := LInner.Left + (LInner.Width - Length(LMethod)) div 2;
  if LX < LInner.Left then
    LX := LInner.Left;
  var LY := LInner.Top + (LInner.Height - 1) div 2;
  // Coloured method text with bold
  var LMethodStyle := TTuiStyle.Create(ResTui.Helpers.MethodColor(LMethod), Theme.Background, [taBold]);
  ACanvas.WriteAt(LX, LY, LMethod, LMethodStyle);
end;

function TResTuiMethodWidget.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  case AEvent.Key.Code of
    kcLeft:
      begin
        FMethodIndex := (FMethodIndex - 1 + Length(CHttpMethods)) mod Length(CHttpMethods);
        Invalidate;
        Result := True;
      end;
    kcRight:
      begin
        FMethodIndex := (FMethodIndex + 1) mod Length(CHttpMethods);
        Invalidate;
        Result := True;
      end;
    kcUp:
      begin
        FMethodIndex := (FMethodIndex - 1 + Length(CHttpMethods)) mod Length(CHttpMethods);
        Invalidate;
        Result := True;
      end;
    kcDown:
      begin
        FMethodIndex := (FMethodIndex + 1) mod Length(CHttpMethods);
        Invalidate;
        Result := True;
      end;
  end;
end;

{ TResTuiFooterWidget }

constructor TResTuiFooterWidget.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FText := CFooterMain;
end;

procedure TResTuiFooterWidget.SetText(const AValue: string);
begin
  if FText = AValue then
    Exit;
  FText := AValue;
  Invalidate;
end;

procedure TResTuiFooterWidget.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  var LStyle := TTuiStyle.Create(Theme.TextDim, Theme.Background);
  ACanvas.FillRect(ARect, ' ', LStyle);
  ACanvas.WriteAt(ARect.Left + 1, ARect.Top, FText, LStyle);
end;

{ TResTuiView }

constructor TResTuiView.Create(ACollection: TResTuiCollection);
begin
  inherited Create(nil);

  // Shared dummy lists for the key-value editors
  FDummyParams := TList<TResTuiKeyValue>.Create;
  FDummyHeaders := TList<TResTuiKeyValue>.Create;

  // ---- Header row (Fixed 1) ----
  var LHeaderRow := TTuiHStack.Create(Self);
  LHeaderRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);
  var LTitleLabel := TTuiLabel.Create(LHeaderRow);
  LTitleLabel.Text := CAppTitle;

  // ---- Body row (Fill) ----
  var LBodyRow := TTuiHStack.Create(Self);

  // Left column: request list sidebar
  var LLeftCol := TTuiVStack.Create(LBodyRow);
  LLeftCol.LayoutConstraint := TTuiLayoutConstraint.Fixed(CRequestListWidth);
  FRequestList := TResTuiRequestList.Create(LLeftCol, ACollection);

  // Right column: URL row + edit+response area
  var LRightCol := TTuiVStack.Create(LBodyRow);

  // URL row (Fixed 3): method box + URL text input
  var LUrlRow := TTuiHStack.Create(LRightCol);
  LUrlRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(3);
  FMethodWidget := TResTuiMethodWidget.Create(LUrlRow);
  FMethodWidget.LayoutConstraint := TTuiLayoutConstraint.Fixed(CMethodBoxWidth);
  FUrlInput := TTuiTextInput.Create(LUrlRow);
  FUrlInput.Placeholder := 'https://example.com/api/endpoint';

  // Mid area (Fill): params tabs | response view
  var LMidRow := TTuiHStack.Create(LRightCol);

  // Params/Headers/Body/Auth tabs
  FParamsTabs := TTuiTabs.Create(LMidRow);
  FParamsEditor := TResTuiKeyValueEditor.Create(nil, FDummyParams, CPanelParams);
  FParamsTabs.AddTab('Params', FParamsEditor);
  FHeadersEditor := TResTuiKeyValueEditor.Create(nil, FDummyHeaders, CPanelHeaders);
  FParamsTabs.AddTab('Headers', FHeadersEditor);
  FBodyPanel := TResTuiBodyPanel.Create(nil);
  FParamsTabs.AddTab('Body', FBodyPanel);
  FAuthPanel := TResTuiAuthPanel.Create(nil);
  FParamsTabs.AddTab('Auth', FAuthPanel);

  // Response view
  FResponseView := TResTuiResponseView.Create(LMidRow);
  FResponseView.ShowIdle;

  // ---- Footer row (Fixed 1) ----
  FFooter := TResTuiFooterWidget.Create(Self);
  FFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);
end;

destructor TResTuiView.Destroy;
begin
  FDummyParams.Free;
  FDummyHeaders.Free;
  inherited;
end;

procedure TResTuiView.LoadRequest(ARequest: TResTuiRequest);
begin
  FCurrentRequest := ARequest;

  // Populate dummy param/header lists (the editors hold a reference to these)
  FDummyParams.Clear;
  for var I := 0 to ARequest.Params.Count - 1 do
    FDummyParams.Add(ARequest.Params[I]);
  FParamsEditor.Refresh;

  FDummyHeaders.Clear;
  for var I := 0 to ARequest.Headers.Count - 1 do
    FDummyHeaders.Add(ARequest.Headers[I]);
  FHeadersEditor.Refresh;

  FMethodWidget.Method := ARequest.Method;
  FUrlInput.Text := ARequest.Url;
  FBodyPanel.LoadBody(ARequest.BodyKind, ARequest.Body);
  FAuthPanel.LoadAuth(ARequest.Auth);
  FResponseView.ShowIdle;
  Invalidate;
end;

procedure TResTuiView.CollectIntoCurrentRequest;
begin
  if not Assigned(FCurrentRequest) then
    Exit;
  FCurrentRequest.Method := FMethodWidget.Method;
  FCurrentRequest.Url := FUrlInput.Text;

  FCurrentRequest.Params.Clear;
  for var I := 0 to FDummyParams.Count - 1 do
    FCurrentRequest.Params.Add(FDummyParams[I]);

  FCurrentRequest.Headers.Clear;
  for var I := 0 to FDummyHeaders.Count - 1 do
    FCurrentRequest.Headers.Add(FDummyHeaders[I]);

  FCurrentRequest.BodyKind := FBodyPanel.GetBodyKind;
  FCurrentRequest.Body := FBodyPanel.GetBodyContent;
  FCurrentRequest.Auth := FAuthPanel.CollectAuth;
end;

procedure TResTuiView.ShowResponse(const AResponse: TResTuiResponse);
begin
  FResponseView.ShowResponse(AResponse);
end;

procedure TResTuiView.SetLoading(ABusy: Boolean);
begin
  if ABusy then
    FResponseView.ShowLoading
  else
    FResponseView.ShowIdle;
end;

end.
