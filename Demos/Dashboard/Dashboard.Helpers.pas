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
{   Unit:        Dashboard.Helpers.pas                           }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Dashboard demo — stateless helper procedures and functions shared by
///   all panel widgets: HeatColor gradient, LevelStyle per severity,
///   DrawHBar for horizontal bars, and text truncation helpers.
/// </summary>
unit Dashboard.Helpers;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  Blinki.Core.Canvas,
  Blinki.Core.Style;

/// <summary>
///   Returns a True Color RGB value for a heat value in [0..1].
///   0 is the coolest colour (blue); 1 is the hottest (red).
///   Interpolates through five stops: blue → cyan → yellow → orange → red.
/// </summary>
function HeatColor(AHeat: Double): TTuiColor;

/// <summary>
///   Returns the foreground TTuiStyle appropriate for the given log level string.
///   The background is always CColorBlack.
/// </summary>
function LevelStyle(const ALevel: string): TTuiStyle;

/// <summary>
///   Returns the TTuiColor constant associated with the given log level string.
/// </summary>
function LevelColor(const ALevel: string): TTuiColor;

/// <summary>
///   Draws a horizontal bar of the form │▓▓▓░░░│ at (AX, AY) on ACanvas.
///   ABarInnerWidth is the number of inner characters (excluding the │ delimiters).
///   AFilledCount is the number of filled (full-block) characters; the rest are shaded.
/// </summary>
procedure DrawHBar(const ACanvas: TTuiCanvas; AX, AY, ABarInnerWidth, AFilledCount: Integer;
  const AFullStyle, AShadeStyle, ABorderStyle: TTuiStyle);

/// <summary>
///   Truncates AText to at most AMaxLen characters, returning a copy.
/// </summary>
function TruncateStr(const AText: string; AMaxLen: Integer): string;

/// <summary>
///   Returns AText right-padded with spaces to exactly AWidth characters.
/// </summary>
function PadRight(const AText: string; AWidth: Integer): string;

implementation

uses
  System.SysUtils,
  Blinki.FX.Gradient,
  Dashboard.Consts;

function HeatColor(AHeat: Double): TTuiColor;
var
  LT: Double;
  LFrom, LTo: TTuiColor;
begin
  // Clamp to [0..1]
  if AHeat < 0.0 then
    AHeat := 0.0;
  if AHeat > 1.0 then
    AHeat := 1.0;

  // Five-stop gradient: blue → cyan → yellow → orange → red
  if AHeat < 0.25 then
  begin
    LT := AHeat / 0.25;
    LFrom := TTuiColor.RGB(60, 90, 200);
    LTo := TTuiColor.RGB(60, 180, 180);
  end
  else if AHeat < 0.5 then
  begin
    LT := (AHeat - 0.25) / 0.25;
    LFrom := TTuiColor.RGB(60, 180, 180);
    LTo := TTuiColor.RGB(230, 200, 60);
  end
  else if AHeat < 0.75 then
  begin
    LT := (AHeat - 0.5) / 0.25;
    LFrom := TTuiColor.RGB(230, 200, 60);
    LTo := TTuiColor.RGB(235, 140, 50);
  end
  else
  begin
    LT := (AHeat - 0.75) / 0.25;
    LFrom := TTuiColor.RGB(235, 140, 50);
    LTo := TTuiColor.RGB(230, 60, 40);
  end;

  Result := LerpColor(LFrom, LTo, LT);
end;

function LevelColor(const ALevel: string): TTuiColor;
begin
  if ALevel = 'ERROR' then
    Result := CColorSevError
  else if ALevel = 'WARN' then
    Result := CColorSevWarn
  else if ALevel = 'FATAL' then
    Result := CColorSevFatal
  else if ALevel = 'DEBUG' then
    Result := CColorSevDebug
  else if ALevel = 'TRACE' then
    Result := CColorSevTrace
  else
    Result := CColorSevInfo;
end;

function LevelStyle(const ALevel: string): TTuiStyle;
begin
  var LAttrs: TTuiTextAttrs := [];
  if (ALevel = 'ERROR') or (ALevel = 'FATAL') then
    LAttrs := [taBold];
  var LFg := LevelColor(ALevel);
  Result := TTuiStyle.Create(LFg, CColorBlack, LAttrs);
end;

procedure DrawHBar(const ACanvas: TTuiCanvas; AX, AY, ABarInnerWidth, AFilledCount: Integer;
  const AFullStyle, AShadeStyle, ABorderStyle: TTuiStyle);
begin
  // Left delimiter
  ACanvas.WriteAt(AX, AY, CGlyphVBar, ABorderStyle);
  // Filled portion
  for var LI := 0 to AFilledCount - 1 do
    ACanvas.WriteAt(AX + 1 + LI, AY, CGlyphBlockFull, AFullStyle);
  // Shaded (empty) portion
  for var LI := AFilledCount to ABarInnerWidth - 1 do
    ACanvas.WriteAt(AX + 1 + LI, AY, CGlyphBlockShade, AShadeStyle);
  // Right delimiter
  ACanvas.WriteAt(AX + 1 + ABarInnerWidth, AY, CGlyphVBar, ABorderStyle);
end;

function TruncateStr(const AText: string; AMaxLen: Integer): string;
begin
  if AMaxLen <= 0 then
    Result := ''
  else if Length(AText) <= AMaxLen then
    Result := AText
  else
    Result := Copy(AText, 1, AMaxLen);
end;

function PadRight(const AText: string; AWidth: Integer): string;
begin
  Result := AText;
  while Length(Result) < AWidth do
    Result := Result + ' ';
end;

end.
