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
{   Unit:        Blinki.Widgets.MatrixRain.pas                   }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiMatrixRain: "falling characters" animation in Matrix style.
/// </summary>
unit Blinki.Widgets.MatrixRain;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Math,
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget;

type

{ TTuiMatrixRain }

  /// <summary>
  ///   Non-focusable widget that animates columns of characters falling from top to bottom.
  ///   The column head is bright white; the trail fades from green to black.
  ///   Columns are re-initialised when they scroll past the bottom edge.
  ///   The number of columns adapts automatically to the width of the rect in DoRender.
  /// </summary>
  TTuiMatrixRain = class(TTuiWidget)
  strict private
    type
      TMatrixColumn = record
        Y: Single;
        Speed: Single;
        TrailLen: Integer;
        Chars: TArray<Char>;
      end;
    var
      FColumns: TArray<TMatrixColumn>;
      FLastWidth: Integer;
      FLastHeight: Integer;
      FAccumMs: Integer;
    procedure InitColumns(AWidth, AHeight: Integer);
    procedure InitColumn(var ACol: TMatrixColumn; AHeight: Integer; AStartOffscreen: Boolean);
    function  RandomMatrixChar: Char;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    /// <summary>
    /// Creates the widget. Columns are initialised on the first DoRender call.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
  end;

implementation

uses
  Blinki.Core.Event,
  Blinki.FX.Gradient;

const
  CMatrixChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789' +
    '!@#$%^&*()_+-=[]{}|;:,.<>?/~`';

{ TTuiMatrixRain }

constructor TTuiMatrixRain.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
end;

function TTuiMatrixRain.RandomMatrixChar: Char;
begin
  Result := CMatrixChars[1 + Random(Length(CMatrixChars))];
end;

procedure TTuiMatrixRain.InitColumn(var ACol: TMatrixColumn; AHeight: Integer;
  AStartOffscreen: Boolean);
begin
  ACol.Speed := 3.0 + Random(8);
  ACol.TrailLen := 4 + Random(AHeight div 2 + 1);
  if AStartOffscreen then
    ACol.Y := -ACol.TrailLen - Random(AHeight)
  else
    ACol.Y := Random(AHeight);
  SetLength(ACol.Chars, ACol.TrailLen + 1);
  for var LIndex := 0 to Length(ACol.Chars) - 1 do
    ACol.Chars[LIndex] := RandomMatrixChar;
end;

procedure TTuiMatrixRain.InitColumns(AWidth, AHeight: Integer);
begin
  if AWidth <= 0 then
    Exit;
  SetLength(FColumns, AWidth);
  for var LIndex := 0 to AWidth - 1 do
    InitColumn(FColumns[LIndex], AHeight, True);
  FLastWidth := AWidth;
  FLastHeight := AHeight;
end;

procedure TTuiMatrixRain.DoApplyTheme(const ATheme: TTuiTheme);
begin
  // Hardcoded colors for the matrix effect — the theme is not used here
end;

procedure TTuiMatrixRain.DoTick(AElapsedMs: Integer);
begin
  Inc(FAccumMs, AElapsedMs);
  // Updates position every 50 ms (~20 fps), consistent with the base tick
  if FAccumMs < 50 then
    Exit;
  Dec(FAccumMs, 50);

  if FLastHeight <= 0 then
    Exit;

  for var LIndex := 0 to High(FColumns) do
  begin
    FColumns[LIndex].Y := FColumns[LIndex].Y + FColumns[LIndex].Speed * 0.05;
    // Rotates a random character in the trail for the "glyph change" effect
    if Length(FColumns[LIndex].Chars) > 0 then
      FColumns[LIndex].Chars[Random(Length(FColumns[LIndex].Chars))] := RandomMatrixChar;
    // Reinitialises the column when the head scrolls past the bottom edge
    if FColumns[LIndex].Y - FColumns[LIndex].TrailLen > FLastHeight then
      InitColumn(FColumns[LIndex], FLastHeight, True);
  end;

  Invalidate;
end;

procedure TTuiMatrixRain.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  // Reinitialises columns if the dimensions have changed
  if (ARect.Width <> FLastWidth) or (ARect.Height <> FLastHeight) then
    InitColumns(ARect.Width, ARect.Height);

  var LBg := TTuiColor.RGB(0, 0, 0);
  var LGreen := TTuiColor.RGB(0, 220, 0);
  var LDark := TTuiColor.RGB(0, 30, 0);
  var LWhite := TTuiColor.RGB(220, 255, 220);

  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(LBg, LBg));

  for var LCol := 0 to Min(ARect.Width - 1, High(FColumns)) do
  begin
    var LHead := Trunc(FColumns[LCol].Y);

    // Column head
    if (LHead >= 0) and (LHead < ARect.Height) then
    begin
      var LCh: Char;
      if Length(FColumns[LCol].Chars) > 0 then
        LCh := FColumns[LCol].Chars[0]
      else
        LCh := RandomMatrixChar;
      ACanvas.WriteAt(ARect.Left + LCol, ARect.Top + LHead, LCh,
        TTuiStyle.Create(LWhite, LBg, [taBold]));
    end;

    // Trail
    for var LTrailI := 1 to FColumns[LCol].TrailLen do
    begin
      var LRow := LHead - LTrailI;
      if (LRow < 0) or (LRow >= ARect.Height) then
        Continue;

      var LT := 1.0 - LTrailI / Max(1, FColumns[LCol].TrailLen);
      var LFg := LerpColor(LDark, LGreen, LT);

      var LCh: Char;
      if LTrailI < Length(FColumns[LCol].Chars) then
        LCh := FColumns[LCol].Chars[LTrailI]
      else
        LCh := RandomMatrixChar;

      ACanvas.WriteAt(ARect.Left + LCol, ARect.Top + LRow, LCh,
        TTuiStyle.Create(LFg, LBg));
    end;
  end;
end;

end.
