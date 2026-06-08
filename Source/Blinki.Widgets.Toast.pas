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
{   Unit:        Blinki.Widgets.Toast.pas                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiToast: temporary notification with auto-dismiss via Tick.
/// </summary>
unit Blinki.Widgets.Toast;

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
  Blinki.Core.Widget,
  Blinki.Widgets.Alert;

type

{ TTuiToast }

  /// <summary>
  ///   Temporary notification: appears after Show() and disappears automatically after
  ///   DurationMs milliseconds via DoTick. When inactive, DoRender is a no-op.
  ///   Full overlay positioning (absolute) is out of scope for Phase 6; the toast is
  ///   placed by the parent through normal layout (e.g. Fixed(3) inside a VStack).
  /// </summary>
  TTuiToast = class(TTuiWidget)
  strict private
    FText: string;
    FLevel: TTuiAlertLevel;
    FDurationMs: Integer;
    FActive: Boolean;
    FAccumMs: Integer;
    FBorderStyle: TTuiStyle;
    FTextStyle: TTuiStyle;
    procedure RebuildStyles;
    function LevelColor: TTuiColor;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoTick(AElapsedMs: Integer); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the toast. Initial DurationMs: 3000; inactive by default.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Activates the toast with the given text and level, resetting the timer.
    ///   The toast will disappear automatically after DurationMs milliseconds.
    /// </summary>
    procedure Show(const AText: string; ALevel: TTuiAlertLevel = alInfo);
    /// <summary>
    ///   Display duration in milliseconds. Default: 3000.
    /// </summary>
    property DurationMs: Integer read FDurationMs write FDurationMs;
    /// <summary>
    ///   True if the toast is currently visible.
    /// </summary>
    property Active: Boolean read FActive;
  end;

implementation

uses
  Blinki.Core.Ansi;

{ TTuiToast }

constructor TTuiToast.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FDurationMs := 3000;
  FLevel := alInfo;
  RebuildStyles;
end;

function TTuiToast.LevelColor: TTuiColor;
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

procedure TTuiToast.RebuildStyles;
begin
  FBorderStyle := TTuiStyle.Create(LevelColor, Theme.Surface);
  FTextStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
end;

procedure TTuiToast.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TTuiToast.Show(const AText: string; ALevel: TTuiAlertLevel);
begin
  FText := AText;
  FLevel := ALevel;
  FAccumMs := 0;
  FActive := True;
  RebuildStyles;
  Invalidate;
end;

procedure TTuiToast.DoTick(AElapsedMs: Integer);
begin
  if not FActive then
    Exit;
  Inc(FAccumMs, AElapsedMs);
  if FAccumMs >= FDurationMs then
  begin
    FActive := False;
    FAccumMs := 0;
    Invalidate;
  end;
end;

procedure TTuiToast.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  if not FActive then
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
  var LContent := FText;
  var LMaxLen := LInner.Width;
  if Length(LContent) > LMaxLen then
    LContent := Copy(LContent, 1, LMaxLen);
  ACanvas.WriteAt(LInner.Left, LInner.Top, LContent, FTextStyle);
end;

end.
