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
{   Unit:        Blinki.Widgets.Badge.pas                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TTuiBadge widget: inline coloured label for status indicators, tags, or version strings.
/// </summary>
unit Blinki.Widgets.Badge;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget;

type

{ TTuiBadgeKind }

  /// <summary>
  /// Semantic level of the badge; determines the colours when the Kind property is used.
  /// </summary>
  TTuiBadgeKind = (
    /// <summary>
    /// Informational (theme Primary colour).
    /// </summary>
    bkInfo,
    /// <summary>
    /// Positive status (theme Success colour).
    /// </summary>
    bkSuccess,
    /// <summary>
    /// Warning (theme Warning colour).
    /// </summary>
    bkWarning,
    /// <summary>
    /// Error or critical status (theme Error colour).
    /// </summary>
    bkError,
    /// <summary>
    /// Neutral (theme TextDim on Surface colour).
    /// </summary>
    bkNeutral
  );

{ TTuiBadge }

  /// <summary>
  ///   Coloured label with internal padding (' text ').
  ///   Use Kind to automatically apply colours from the current theme,
  ///   or assign Style manually for full control.
  ///   Truncated when the text exceeds the width of the assigned rectangle.
  /// </summary>
  TTuiBadge = class(TTuiWidget)
  strict private
    FText: string;
    FStyle: TTuiStyle;
    FKind: TTuiBadgeKind;
    FStyleOverride: Boolean;
    procedure SetText(const AValue: string);
    procedure SetStyle(const AValue: TTuiStyle);
    procedure SetKind(AValue: TTuiBadgeKind);
    procedure RebuildStyleFromKind;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    /// Creates the badge. Initial Kind: bkInfo.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    /// Text displayed in the badge (without padding — padding is added by the renderer).
    /// </summary>
    property Text: string read FText write SetText;
    /// <summary>
    ///   ANSI style of the badge. Once assigned explicitly, Kind and the theme no
    ///   longer override it.
    /// </summary>
    property Style: TTuiStyle read FStyle write SetStyle;
    /// <summary>
    ///   Semantic level: assigning it recalculates Style from the current theme colours
    ///   and cancels any manual Style override.
    /// </summary>
    property Kind: TTuiBadgeKind read FKind write SetKind;
  end;

implementation

{ TTuiBadge }

constructor TTuiBadge.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FKind := bkInfo;
  RebuildStyleFromKind;
end;

procedure TTuiBadge.RebuildStyleFromKind;
begin
  var LBg: TTuiColor;
  case FKind of
    bkInfo:
      LBg := Theme.Primary;
    bkSuccess:
      LBg := Theme.Success;
    bkWarning:
      LBg := Theme.Warning;
    bkError:
      LBg := Theme.Error;
    bkNeutral:
      LBg := Theme.Surface;
  else
    LBg := Theme.Primary;
  end;
  FStyle := TTuiStyle.Create(Theme.Text, LBg, [taBold]);
end;

procedure TTuiBadge.DoApplyTheme(const ATheme: TTuiTheme);
begin
  if not FStyleOverride then
    RebuildStyleFromKind;
end;

procedure TTuiBadge.SetText(const AValue: string);
begin
  if FText = AValue then
    Exit;
  FText := AValue;
  Invalidate;
end;

procedure TTuiBadge.SetStyle(const AValue: TTuiStyle);
begin
  if FStyle = AValue then
    Exit;
  FStyle := AValue;
  FStyleOverride := True;
  Invalidate;
end;

procedure TTuiBadge.SetKind(AValue: TTuiBadgeKind);
begin
  if FKind = AValue then
    Exit;
  FKind := AValue;
  FStyleOverride := False;
  RebuildStyleFromKind;
  Invalidate;
end;

procedure TTuiBadge.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  var LPadded := ' ' + FText + ' ';
  var LMaxLen := ARect.Width;
  if Length(LPadded) > LMaxLen then
    LPadded := Copy(LPadded, 1, LMaxLen);
  ACanvas.FillRect(ARect, ' ', FStyle);
  ACanvas.WriteAt(ARect.Left, ARect.Top, LPadded, FStyle);
end;

end.
