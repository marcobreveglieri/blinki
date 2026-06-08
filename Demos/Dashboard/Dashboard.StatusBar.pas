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
{   Unit:        Dashboard.StatusBar.pas                         }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Dashboard demo — TDashboardStatusBar: single-row status bar at the
///   bottom of the screen. Shows the active section name, keyboard hints,
///   and the update interval (or "PAUSED" when the simulation is paused).
/// </summary>
unit Dashboard.StatusBar;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Geometry,
  Blinki.Core.Widget;

type

{ TDashboardSection }

  /// <summary>
  ///   Associates a display name with a focusable panel widget so the status
  ///   bar can show which section is currently active.
  /// </summary>
  TDashboardSection = record
    Name: string;
    Widget: TTuiWidget;
    class function Make(const AName: string; AWidget: TTuiWidget): TDashboardSection; static;
  end;

{ TDashboardStatusBar }

  /// <summary>
  ///   Non-focusable single-row status bar with navy background.
  ///   Left: [ActiveSectionName] + keyboard hint text.
  ///   Right: "Update: 1s" or "PAUSED".
  ///   Set Paused to toggle the right label; call Invalidate after changing it.
  /// </summary>
  TDashboardStatusBar = class(TTuiWidget)
  strict private
    FSections: TArray<TDashboardSection>;
    FPaused: Boolean;
    procedure SetPaused(AValue: Boolean);
    function ActiveSectionName: string;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Registers the ordered list of focusable sections. Call once after all
    ///   panel widgets have been created.
    /// </summary>
    procedure SetSections(const ASections: TArray<TDashboardSection>);
    /// <summary>
    ///   When True the right label reads "PAUSED"; when False it reads "Update: 1s".
    ///   Assigning triggers an automatic repaint.
    /// </summary>
    property Paused: Boolean read FPaused write SetPaused;
  end;

implementation

uses
  System.SysUtils,
  Blinki.Core.Style,
  Dashboard.Consts;

{ TDashboardSection }

class function TDashboardSection.Make(const AName: string;
  AWidget: TTuiWidget): TDashboardSection;
begin
  Result.Name := AName;
  Result.Widget := AWidget;
end;

{ TDashboardStatusBar }

procedure TDashboardStatusBar.SetPaused(AValue: Boolean);
begin
  if FPaused = AValue then
    Exit;
  FPaused := AValue;
  Invalidate;
end;

function TDashboardStatusBar.ActiveSectionName: string;
begin
  Result := '';
  for var LSection in FSections do
  begin
    if Assigned(LSection.Widget) and LSection.Widget.Focused then
    begin
      Result := LSection.Name;
      Exit;
    end;
  end;
end;

procedure TDashboardStatusBar.SetSections(const ASections: TArray<TDashboardSection>);
begin
  FSections := ASections;
end;

procedure TDashboardStatusBar.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
var
  LBgStyle, LTextStyle, LSecStyle: TTuiStyle;
  LY: Integer;
  LSecLabel, RightLabel: string;
  LRightX: Integer;
begin
  LBgStyle := TTuiStyle.Create(CColorStatusText, CColorStatusBg);
  LTextStyle := TTuiStyle.Create(CColorStatusText, CColorStatusBg);
  LSecStyle := TTuiStyle.Create(CColorTitle, CColorStatusBg, [taBold]);

  LY := ARect.Top;
  ACanvas.FillRect(ARect, ' ', LBgStyle);

  // Left: [ActiveSection] + hints
  LSecLabel := '[' + ActiveSectionName + ']';
  ACanvas.WriteAt(ARect.Left + 1, LY, LSecLabel, LSecStyle);
  var LHintsX := ARect.Left + 1 + Length(LSecLabel) + 1;
  var LHintsMaxW := ARect.Width - Length(LSecLabel) - Length(CUpdateLabel) - 4;
  if (LHintsMaxW > 0) and (LHintsX < ARect.Right) then
    ACanvas.WriteAt(LHintsX, LY,
      Copy(CStatusHints, 1, LHintsMaxW), LTextStyle);

  // Right: update interval or PAUSED label
  if FPaused then
    RightLabel := CPausedLabel
  else
    RightLabel := CUpdateLabel;
  LRightX := ARect.Right - Length(RightLabel) - 1;
  if LRightX > ARect.Left then
    ACanvas.WriteAt(LRightX, LY, RightLabel, LTextStyle);
end;

end.
