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
{   Unit:        Dashboard.Patterns.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Dashboard demo — TDashboardPatterns: the "Log Patterns" panel widget.
///   Renders each pattern with a proportional heat-coloured block strip on
///   the left, followed by the frequency percentage and the pattern text.
/// </summary>
unit Dashboard.Patterns;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Geometry,
  Blinki.Core.Widget,
  Dashboard.Model;

type

{ TDashboardPatterns }

  /// <summary>
  ///   Focusable panel that shows the log pattern frequency list.
  ///   The panel title is dynamic and includes the pattern count and total logs.
  ///   Each row shows: a heat-coloured strip (width proportional to frequency),
  ///   then the percentage, then the pattern template text.
  /// </summary>
  TDashboardPatterns = class(TTuiWidget)
  strict private
    FModel: TDashboardModel;
    FSectionName: string;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Creates the Patterns panel. AModel is a reference (not owned).
    /// </summary>
    constructor Create(AParent: TTuiWidget; AModel: TDashboardModel);
    /// <summary>
    ///   Short name used by the status bar.
    /// </summary>
    property SectionName: string read FSectionName;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Style,
  Dashboard.Consts,
  Dashboard.Helpers;

{ TDashboardPatterns }

constructor TDashboardPatterns.Create(AParent: TTuiWidget; AModel: TDashboardModel);
begin
  inherited Create(AParent);
  FModel := AModel;
  FSectionName := 'Patterns';
end;

procedure TDashboardPatterns.DoInit;
begin
  SetFocusable(True);
end;

procedure TDashboardPatterns.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
var
  LBorderStyle, LBgStyle, LTextStyle: TTuiStyle;
  LInner: TRect;
  LMaxPercent: Double;
  LTitle: string;
begin
  if Focused then
    LBorderStyle := TTuiStyle.Create(CColorBorderFocus, CColorBlack)
  else
    LBorderStyle := TTuiStyle.Create(CColorBorderNormal, CColorBlack);

  LBgStyle := TTuiStyle.Create(CColorText, CColorBlack);
  LTextStyle := TTuiStyle.Create(CColorText, CColorBlack);

  LTitle := Format(' Log Patterns (%d patterns from %d logs) ',
    [FModel.PatternCount, FModel.TotalLogs]);
  ACanvas.DrawBox(ARect, bsRounded, LTitle, LBorderStyle);

  LInner := ARect.Interior;
  if LInner.IsEmpty then
    Exit;

  ACanvas.FillRect(LInner, ' ', LBgStyle);

  ACanvas.PushClip(LInner);
  try
    // Find the maximum percentage for normalising heat values
    LMaxPercent := 0.0;
    for var LItem in FModel.Patterns do
      if LItem.Percent > LMaxPercent then
        LMaxPercent := LItem.Percent;

    for var LI := 0 to FModel.Patterns.Count - 1 do
    begin
      var LY := LInner.Top + LI;
      if LY >= LInner.Bottom then
        Break;

      var LItem := FModel.Patterns[LI];

      // Normalised heat: 0 (coolest) .. 1 (hottest)
      var LHeat := 0.0;
      if LMaxPercent > 0.0 then
        LHeat := LItem.Percent / LMaxPercent;

      // Strip width proportional to frequency, max CMaxHeatStripWidth chars
      var LStripWidth := Round(LHeat * CMaxHeatStripWidth);
      if LStripWidth < 1 then
        LStripWidth := 1;

      var LHeatColor := HeatColor(LHeat);
      var LHeatStyle := TTuiStyle.Create(LHeatColor, CColorBlack);

      // Draw heat strip
      for var LJ := 0 to LStripWidth - 1 do
        ACanvas.WriteAt(LInner.Left + LJ, LY, CGlyphBlockFull, LHeatStyle);

      // Pad remainder of strip area with spaces so the percentage column aligns
      for var LJ := LStripWidth to CMaxHeatStripWidth - 1 do
        ACanvas.WriteAt(LInner.Left + LJ, LY, ' ', LBgStyle);

      // Percentage: " 22.6%  " — 8 chars (5.1f, then "%" and 2 spaces)
      var LPctX := LInner.Left + CMaxHeatStripWidth;
      var LPctStr := Format('%5.1f%%  ', [LItem.Percent]);
      ACanvas.WriteAt(LPctX, LY, LPctStr, LTextStyle);

      // Pattern text (truncated to remaining width)
      var LTextX := LPctX + Length(LPctStr);
      var LTextMaxW := LInner.Right - LTextX;
      if LTextMaxW > 0 then
        ACanvas.WriteAt(LTextX, LY, TruncateStr(LItem.Text, LTextMaxW), LTextStyle);
    end;
  finally
    ACanvas.PopClip;
  end;
end;

end.
