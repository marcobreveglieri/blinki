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
{   Unit:        Dashboard.TopList.pas                           }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Dashboard demo — TDashboardTopList: reusable panel widget for the
///   "Top Words" and "Top Attributes" sections.
///   Renders a ranked list with right-aligned counts and proportional
///   horizontal bars (│████░░│ style) using the gonzo colour palette.
/// </summary>
unit Dashboard.TopList;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  System.Generics.Collections,
  Blinki.Core.Canvas,
  Blinki.Core.Geometry,
  Blinki.Core.Widget,
  Dashboard.Model;

type

{ TDashboardTopList }

  /// <summary>
  ///   Focusable panel that displays a ranked list of TTopItem entries with
  ///   proportional horizontal bar charts.
  ///   The same class is instantiated twice: once for Top Words and once for
  ///   Top Attributes. Pass the appropriate TList reference and a title string.
  /// </summary>
  TDashboardTopList = class(TTuiWidget)
  strict private
    FItems: TList<TTopItem>;
    FSectionName: string;
    FTitle: string;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Creates a TopList widget.
    ///   AItems is a reference to the model list (not owned).
    ///   ATitle is the panel title drawn in the border (e.g. ' Top Words ').
    ///   ASectionName is the short name shown in the status bar (e.g. 'Words').
    /// </summary>
    constructor Create(AParent: TTuiWidget; AItems: TList<TTopItem>;
      const ATitle, ASectionName: string);
    /// <summary>
    ///   Short name of this section, used by the status bar.
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

{ TDashboardTopList }

constructor TDashboardTopList.Create(AParent: TTuiWidget; AItems: TList<TTopItem>;
  const ATitle, ASectionName: string);
begin
  inherited Create(AParent);
  FItems := AItems;
  FTitle := ATitle;
  FSectionName := ASectionName;
end;

procedure TDashboardTopList.DoInit;
begin
  SetFocusable(True);
end;

procedure TDashboardTopList.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
const
  // Total width of the bar area including │ delimiters
  LBarTotalWidth = CBarInnerWidth + 2;
  // Width of count + trailing space before bar
  LCountFieldWidth = 6;
var
  LBorderStyle, LBgStyle, LTextStyle, LBarFullStyle, LBarShadeStyle, LBarBorderStyle: TTuiStyle;
  LInner: TRect;
  LMaxCount: Integer;
  LBarX, LCountX: Integer;
begin
  // Select border colour based on focus state
  if Focused then
    LBorderStyle := TTuiStyle.Create(CColorBorderFocus, CColorBlack)
  else
    LBorderStyle := TTuiStyle.Create(CColorBorderNormal, CColorBlack);

  LBgStyle := TTuiStyle.Create(CColorText, CColorBlack);
  LTextStyle := TTuiStyle.Create(CColorText, CColorBlack);
  LBarFullStyle := TTuiStyle.Create(CColorBarFull,  CColorBlack);
  LBarShadeStyle:= TTuiStyle.Create(CColorBarShade, CColorBlack);
  LBarBorderStyle:= TTuiStyle.Create(CColorBarFull, CColorBlack);

  ACanvas.DrawBox(ARect, bsRounded, FTitle, LBorderStyle);
  LInner := ARect.Interior;
  if LInner.IsEmpty then
    Exit;

  ACanvas.FillRect(LInner, ' ', LBgStyle);

  ACanvas.PushClip(LInner);
  try
    // Compute max count for bar scaling
    LMaxCount := 0;
    for var LItem in FItems do
      if LItem.Count > LMaxCount then
        LMaxCount := LItem.Count;

    LBarX := LInner.Right - LBarTotalWidth;
    LCountX := LBarX - LCountFieldWidth;

    for var LI := 0 to FItems.Count - 1 do
    begin
      var LY := LInner.Top + LI;
      if LY >= LInner.Bottom then
        Break;

      var LItem := FItems[LI];

      // Rank prefix: " 1. " or "10. " (4 chars)
      var LPrefix := Format('%2d. ', [LI + 1]);

      // Caption truncated to the space between rank and count
      var LCaptionMaxW := LCountX - LInner.Left - Length(LPrefix);
      if LCaptionMaxW < 0 then
        LCaptionMaxW := 0;
      var LCaption := TruncateStr(LItem.Caption, LCaptionMaxW);
      var LCaptionPadded := PadRight(LCaption, LCaptionMaxW);

      // Write rank + caption
      ACanvas.WriteAt(LInner.Left, LY, LPrefix + LCaptionPadded, LTextStyle);

      // Write count (5 chars) + space
      var LCountStr := Format('%5d ', [LItem.Count]);
      if LCountX >= LInner.Left then
        ACanvas.WriteAt(LCountX, LY, LCountStr, LTextStyle);

      // Draw horizontal bar
      if LBarX >= LInner.Left then
      begin
        var LFilled := 0;
        if LMaxCount > 0 then
          LFilled := Round(LItem.Count / LMaxCount * CBarInnerWidth);
        LFilled := Min(LFilled, CBarInnerWidth);
        DrawHBar(ACanvas, LBarX, LY, CBarInnerWidth, LFilled,
          LBarFullStyle, LBarShadeStyle, LBarBorderStyle);
      end;
    end;
  finally
    ACanvas.PopClip;
  end;
end;

end.
