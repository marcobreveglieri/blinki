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
{   Unit:        CryptoTracker.Helpers.pas                      }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   CryptoTrackerDemo -- Pure formatting and colour-mapping helpers.
///   No class wrappers; all functions are free-standing.
///   Depends only on CryptoTracker.Model and Blinki.Core.Style/Theme.
/// </summary>
unit CryptoTracker.Helpers;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  Blinki.Core.Style,
  Blinki.Core.Theme;

/// <summary>
///   Formats a price value for display in the watchlist or chart axis.
///   Values >= 1000 are shown without decimal places; smaller values use
///   two decimal places. Invariant decimal separator ('.') is always used.
/// </summary>
function FormatPrice(AValue: Double): string;

/// <summary>
///   Formats a percentage change with an explicit sign and two decimal places,
///   e.g. '+2.89%' or '-6.88%'. Uses the invariant decimal separator.
/// </summary>
function FormatPercent(AValue: Double): string;

/// <summary>
///   Formats a price for the chart Y-axis label, adapting precision to the
///   magnitude so the string fits comfortably in a narrow column.
/// </summary>
function FormatChartPrice(AValue: Double): string;

/// <summary>
///   Returns the theme colour that represents a price change direction:
///   Theme.Success for gains (AValue >= 0), Theme.Error for losses.
/// </summary>
function ChangeColor(const ATheme: TTuiTheme; AValue: Double): TTuiColor;

implementation

uses
  System.SysUtils;

var
  GFmt: TFormatSettings;

function FormatPrice(AValue: Double): string;
begin
  if AValue >= 1000 then
    Result := Format('%.0f', [AValue], GFmt)
  else
    Result := Format('%.2f', [AValue], GFmt);
end;

function FormatPercent(AValue: Double): string;
begin
  if AValue >= 0 then
    Result := Format('+%.2f%%', [AValue], GFmt)
  else
    Result := Format('%.2f%%', [AValue], GFmt);
end;

function FormatChartPrice(AValue: Double): string;
begin
  if AValue >= 10000 then
    Result := Format('%.0f', [AValue], GFmt)
  else if AValue >= 100 then
    Result := Format('%.1f', [AValue], GFmt)
  else
    Result := Format('%.2f', [AValue], GFmt);
end;

function ChangeColor(const ATheme: TTuiTheme; AValue: Double): TTuiColor;
begin
  if AValue >= 0 then
    Result := ATheme.Success
  else
    Result := ATheme.Error;
end;

initialization
  GFmt := TFormatSettings.Invariant;

end.
