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
{   Unit:        Blinki.Widgets.ProgressBar.pas                  }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiProgressBar: horizontal progress bar with Unicode partial-block characters.
/// </summary>
unit Blinki.Widgets.ProgressBar;

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

{ TTuiProgressBar }

  /// <summary>
  ///   Horizontal progress bar. Value ranges from 0.0 to 1.0 (out-of-range values are
  ///   clamped). Uses Unicode partial-block characters (#$258F..#$2588) for sub-character
  ///   rendering. When ShowPercentage is True, the percentage is right-aligned in 4+1
  ///   characters. Colors are updated automatically on theme changes.
  /// </summary>
  TTuiProgressBar = class(TTuiWidget)
  strict private
    FValue: Single;
    FShowPercentage: Boolean;
    FFillColor: TTuiColor;
    FEmptyColor: TTuiColor;
    FColorOverride: Boolean;
    procedure SetValue(AValue: Single);
    procedure SetShowPercentage(AValue: Boolean);
    procedure SetFillColor(const AValue: TTuiColor);
    procedure SetEmptyColor(const AValue: TTuiColor);
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    /// Creates the progress bar. Initial Value: 0.0; ShowPercentage: True.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    /// Current progress, from 0.0 to 1.0. Out-of-range values are clamped.
    /// </summary>
    property Value: Single read FValue write SetValue;
    /// <summary>
    /// When True, displays the percentage right-aligned (5 chars). Default: True.
    /// </summary>
    property ShowPercentage: Boolean read FShowPercentage write SetShowPercentage;
    /// <summary>
    ///   Color of the filled blocks. Once set explicitly, theme changes no longer override it.
    /// </summary>
    property FillColor: TTuiColor read FFillColor write SetFillColor;
    /// <summary>
    ///   Color of the empty blocks. Once set explicitly, theme changes no longer override it.
    /// </summary>
    property EmptyColor: TTuiColor read FEmptyColor write SetEmptyColor;
  end;

implementation

const

  // Sub-character blocks U+258F (1/8)..U+2588 (8/8) — using #$XXXX notation
  CBlocks: array[0..7] of string = (
    #$258F, #$258E, #$258D, #$258C,
    #$258B, #$258A, #$2589, #$2588);

{ TTuiProgressBar }

constructor TTuiProgressBar.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FShowPercentage := True;
  FFillColor := Theme.Primary;
  FEmptyColor := Theme.Surface;
end;

procedure TTuiProgressBar.DoApplyTheme(const ATheme: TTuiTheme);
begin
  if not FColorOverride then
  begin
    FFillColor := ATheme.Primary;
    FEmptyColor := ATheme.Surface;
  end;
end;

procedure TTuiProgressBar.SetValue(AValue: Single);
begin
  if AValue < 0.0 then
    AValue := 0.0;
  if AValue > 1.0 then
    AValue := 1.0;
  if FValue = AValue then
    Exit;
  FValue := AValue;
  Invalidate;
end;

procedure TTuiProgressBar.SetShowPercentage(AValue: Boolean);
begin
  if FShowPercentage = AValue then
    Exit;
  FShowPercentage := AValue;
  Invalidate;
end;

procedure TTuiProgressBar.SetFillColor(const AValue: TTuiColor);
begin
  if FFillColor = AValue then
    Exit;
  FFillColor := AValue;
  FColorOverride := True;
  Invalidate;
end;

procedure TTuiProgressBar.SetEmptyColor(const AValue: TTuiColor);
begin
  if FEmptyColor = AValue then
    Exit;
  FEmptyColor := AValue;
  FColorOverride := True;
  Invalidate;
end;

procedure TTuiProgressBar.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  var LFillStyle := TTuiStyle.Create(FFillColor, TTuiColor.Default);
  var LEmptyStyle := TTuiStyle.Create(FEmptyColor, TTuiColor.Default);
  var LTextStyle := TTuiStyle.Create(Theme.Text, TTuiColor.Default);

  var LPctStr: string;
  var LPctWidth: Integer;
  if FShowPercentage then
  begin
    LPctStr := Format('%3d%%', [Round(FValue * 100)]);
    LPctWidth := Length(LPctStr) + 1;  // separator space
  end
  else
  begin
    LPctStr := '';
    LPctWidth := 0;
  end;

  var LBarWidth := ARect.Width - LPctWidth;
  if LBarWidth < 1 then
    LBarWidth := 1;

  // Compute full blocks and sub-character remainder
  var LFilledEighths := Round(FValue * LBarWidth * 8);
  var LFullBlocks := LFilledEighths div 8;
  var LRemEighths := LFilledEighths mod 8;

  // Full blocks
  var LX := ARect.Left;
  while (LX < ARect.Left + LFullBlocks) and (LX < ARect.Left + LBarWidth) do
  begin
    ACanvas.WriteAt(LX, ARect.Top, CBlocks[7], LFillStyle);
    Inc(LX);
  end;

  // Partial block
  if (LRemEighths > 0) and (LX < ARect.Left + LBarWidth) then
  begin
    ACanvas.WriteAt(LX, ARect.Top, CBlocks[LRemEighths - 1], LFillStyle);
    Inc(LX);
  end;

  // Remaining empty space
  while LX < ARect.Left + LBarWidth do
  begin
    ACanvas.WriteAt(LX, ARect.Top, ' ', LEmptyStyle);
    Inc(LX);
  end;

  // Percentage
  if FShowPercentage then
    ACanvas.WriteAt(ARect.Left + LBarWidth, ARect.Top, ' ' + LPctStr, LTextStyle);
end;

end.
