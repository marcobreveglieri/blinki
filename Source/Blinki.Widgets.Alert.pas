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
{   Unit:        Blinki.Widgets.Alert.pas                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TTuiAlert widget: highlighted message with semantic style and dismiss via ESC.
/// </summary>
unit Blinki.Widgets.Alert;

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

{ TTuiAlertLevel }

  /// <summary>
  ///   Semantic severity level of an alert.
  /// </summary>
  TTuiAlertLevel = (
    /// <summary>
    ///   Informational (Primary).
    /// </summary>
    alInfo,
    /// <summary>
    ///   Operation completed successfully (Success).
    /// </summary>
    alSuccess,
    /// <summary>
    ///   Warning condition (Warning).
    /// </summary>
    alWarning,
    /// <summary>
    ///   Error condition (Error).
    /// </summary>
    alError
  );

{ TTuiAlert }

  /// <summary>
  ///   Bordered semantic message widget (bsRounded). The border colour depends on Level
  ///   and is refreshed whenever the theme changes. Press ESC to dismiss (FVisible := False);
  ///   the widget stays in the tree and can be shown again by setting Visible := True.
  ///   Recommended minimum height: 3 rows (top border, text, bottom border).
  /// </summary>
  TTuiAlert = class(TTuiWidget)
  strict private
    FText: string;
    FLevel: TTuiAlertLevel;
    FVisible: Boolean;
    FIcon: string;
    FBorderStyle: TTuiStyle;
    FTextStyle: TTuiStyle;
    procedure SetText(const AValue: string);
    procedure SetLevel(AValue: TTuiAlertLevel);
    procedure SetVisible(AValue: Boolean);
    procedure RebuildStyles;
    function LevelColor: TTuiColor;
    function DefaultIcon: string;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the alert. Initial Level: alInfo; Visible: True.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Text of the alert message.
    /// </summary>
    property Text: string read FText write SetText;
    /// <summary>
    ///   Semantic level. Changing this value automatically updates colours and icon.
    /// </summary>
    property Level: TTuiAlertLevel read FLevel write SetLevel;
    /// <summary>
    ///   When False, the widget occupies no visual space (no-op in DoRender).
    /// </summary>
    property Visible: Boolean read FVisible write SetVisible;
  end;

implementation

uses
  Blinki.Core.Ansi,
  Blinki.Core.Input;

{ TTuiAlert }

constructor TTuiAlert.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FVisible := True;
  FIcon := DefaultIcon;
  RebuildStyles;
end;

function TTuiAlert.LevelColor: TTuiColor;
begin
  case FLevel of
    alInfo:
      Result := Theme.Primary;
    alSuccess:
      Result := Theme.Success;
    alWarning:
      Result := Theme.Warning;
    alError:
      Result := Theme.Error;
  else
    Result := Theme.Primary;
  end;
end;

function TTuiAlert.DefaultIcon: string;
begin
  case FLevel of
    alInfo:
      Result := 'i';
    alSuccess:
      Result := '+';
    alWarning:
      Result := '!';
    alError:
      Result := 'x';
  else
    Result := 'i';
  end;
end;

procedure TTuiAlert.RebuildStyles;
begin
  var LColor := LevelColor;
  FBorderStyle := TTuiStyle.Create(LColor, Theme.Surface);
  FTextStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
end;

procedure TTuiAlert.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TTuiAlert.SetText(const AValue: string);
begin
  if FText = AValue then
    Exit;
  FText := AValue;
  Invalidate;
end;

procedure TTuiAlert.SetLevel(AValue: TTuiAlertLevel);
begin
  if FLevel = AValue then
    Exit;
  FLevel := AValue;
  FIcon := DefaultIcon;
  RebuildStyles;
  Invalidate;
end;

procedure TTuiAlert.SetVisible(AValue: Boolean);
begin
  if FVisible = AValue then
    Exit;
  FVisible := AValue;
  Invalidate;
end;

function TTuiAlert.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if not FVisible then
    Exit;
  if (AEvent.Kind = ekKey) and (AEvent.Key.Code = kcEscape) then
  begin
    FVisible := False;
    Invalidate;
    Result := True;
  end;
end;

procedure TTuiAlert.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  if not FVisible then
  begin
    var LBgStyle := TTuiStyle.Create(Theme.Text, Theme.Background);
    ACanvas.FillRect(ARect, ' ', LBgStyle);
    Exit;
  end;
  ACanvas.DrawBox(ARect, bsRounded, '', FBorderStyle);
  var LInner := ARect;
  LInner.Inflate(-1, -1);
  if LInner.IsEmpty then
    Exit;
  ACanvas.FillRect(LInner, ' ', FTextStyle);
  var LContent := '[' + FIcon + '] ' + FText;
  var LMaxLen := LInner.Width;
  if Length(LContent) > LMaxLen then
    LContent := Copy(LContent, 1, LMaxLen);
  ACanvas.WriteAt(LInner.Left, LInner.Top, LContent, FTextStyle);
end;

end.
