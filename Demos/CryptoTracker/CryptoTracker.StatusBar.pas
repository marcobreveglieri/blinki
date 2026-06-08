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
{   Unit:        CryptoTracker.StatusBar.pas                    }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   CryptoTrackerDemo -- TCryptoStatusBar: single-row status bar widget with
///   three sections: source attribution (left), timeframe selector (centre),
///   and keyboard hints (right). The active timeframe is rendered in violet.
/// </summary>
unit CryptoTracker.StatusBar;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Geometry,
  Blinki.Core.Widget,
  CryptoTracker.Model;

type

{ TCryptoStatusBar }

  /// <summary>
  ///   Non-focusable single-row status bar.
  ///   Set ActiveTimeframe to update the highlighted timeframe tab;
  ///   the widget invalidates itself automatically.
  /// </summary>
  TCryptoStatusBar = class(TTuiWidget)
  strict private
    FActiveTimeframe: TTimeframe;
    procedure SetActiveTimeframe(AValue: TTimeframe);
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Currently highlighted timeframe in the centre selector.
    ///   Assigning a new value triggers an automatic repaint.
    /// </summary>
    property ActiveTimeframe: TTimeframe
      read FActiveTimeframe write SetActiveTimeframe;
  end;

implementation

uses
  System.SysUtils,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  CryptoTracker.Consts;

{ TCryptoStatusBar }

procedure TCryptoStatusBar.SetActiveTimeframe(AValue: TTimeframe);
begin
  if FActiveTimeframe = AValue then
    Exit;
  FActiveTimeframe := AValue;
  Invalidate;
end;

procedure TCryptoStatusBar.DoRender(const ACanvas: TTuiCanvas;
  const ARect: TRect);
var
  LNormalStyle, LActiveStyle, LDimStyle: TTuiStyle;
  LY, LTfX, LTfWidth: Integer;
  LTfStr: string;
begin
  LY := ARect.Top;
  LNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  LActiveStyle := TTuiStyle.Create(Theme.Secondary, Theme.Surface, [taBold]);
  LDimStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);

  // Fill the full row with Surface background
  ACanvas.FillRect(ARect, ' ', LNormalStyle);

  // Left: data-source attribution
  ACanvas.WriteAt(ARect.Left + 1, LY, CStatusSource, LDimStyle);

  // Centre: timeframe selector — measure total width first for centering
  LTfStr := '';
  for var LI := 0 to 3 do
  begin
    if LI > 0 then
      LTfStr := LTfStr + ' ';
    if LI = Ord(FActiveTimeframe) then
      LTfStr := LTfStr + '[' + CTimeframeLabels[LI] + ']'
    else
      LTfStr := LTfStr + CTimeframeLabels[LI];
  end;
  LTfWidth := Length(LTfStr);
  LTfX := ARect.Left + (ARect.Width - LTfWidth) div 2;

  // Render each token with its own style
  for var LI := 0 to 3 do
  begin
    if LI > 0 then
    begin
      ACanvas.WriteAt(LTfX, LY, ' ', LNormalStyle);
      Inc(LTfX);
    end;
    var LLabel: string;
    var LStyle: TTuiStyle;
    if LI = Ord(FActiveTimeframe) then
    begin
      LLabel := '[' + CTimeframeLabels[LI] + ']';
      LStyle := LActiveStyle;
    end
    else
    begin
      LLabel := CTimeframeLabels[LI];
      LStyle := LNormalStyle;
    end;
    ACanvas.WriteAt(LTfX, LY, LLabel, LStyle);
    Inc(LTfX, Length(LLabel));
  end;

  // Right: keyboard hints
  var LHintsLen := Length(CStatusHints);
  if LHintsLen < ARect.Width - 2 then
    ACanvas.WriteAt(ARect.Right - LHintsLen - 1, LY, CStatusHints, LDimStyle);
end;

end.
