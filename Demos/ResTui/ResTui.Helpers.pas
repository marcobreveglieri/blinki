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
{   Unit:        ResTui.Helpers.pas                              }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Stateless helper functions shared across the ResTui demo widgets:
///   method and status colour resolution, JSON pretty-printing,
///   duration formatting, and text truncation.
/// </summary>
unit ResTui.Helpers;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Blinki.Core.Style;

/// <summary>
///   Returns the badge colour for a given HTTP method name.
/// </summary>
function MethodColor(const AMethod: string): TTuiColor;

/// <summary>
///   Returns a colour suitable for displaying an HTTP status code.
///   2xx → green, 3xx → cyan, 4xx → orange, 5xx/error → red.
/// </summary>
function StatusColor(ACode: Integer): TTuiColor;

/// <summary>
///   Attempts to pretty-print a JSON string. Falls back to the original
///   text if parsing fails (e.g. the body is plain text or HTML).
/// </summary>
function PrettyJson(const AText: string): string;

/// <summary>
///   Formats a duration in milliseconds as a short human-readable string
///   (e.g. "42ms" or "1.23s").
/// </summary>
function FormatDuration(AMs: Int64): string;

/// <summary>
///   Truncates AText to at most AMaxLen characters, appending '…' when cut.
/// </summary>
function Truncate(const AText: string; AMaxLen: Integer): string;

implementation

uses
  System.JSON,
  System.SysUtils,
  ResTui.Consts;

function MethodColor(const AMethod: string): TTuiColor;
begin
  var LUpper := UpperCase(AMethod);
  if LUpper = 'GET' then
    Result := CColorMethodGet
  else if LUpper = 'POST' then
    Result := CColorMethodPost
  else if LUpper = 'PUT' then
    Result := CColorMethodPut
  else if LUpper = 'PATCH' then
    Result := CColorMethodPatch
  else if LUpper = 'DELETE' then
    Result := CColorMethodDelete
  else if LUpper = 'HEAD' then
    Result := CColorMethodHead
  else
    Result := CColorMethodOther;
end;

function StatusColor(ACode: Integer): TTuiColor;
begin
  if (ACode >= 200) and (ACode < 300) then
    Result := CColorStatus2xx
  else if (ACode >= 300) and (ACode < 400) then
    Result := CColorStatus3xx
  else if (ACode >= 400) and (ACode < 500) then
    Result := CColorStatus4xx
  else if ACode >= 500 then
    Result := CColorStatus5xx
  else
    Result := CColorStatusErr;
end;

function PrettyJson(const AText: string): string;
begin
  Result := AText;
  var LParsed := TJSONObject.ParseJSONValue(AText);
  if not Assigned(LParsed) then
    Exit;
  try
    Result := LParsed.Format(2);
  finally
    LParsed.Free;
  end;
end;

function FormatDuration(AMs: Int64): string;
begin
  if AMs < 1000 then
    Result := Format('%dms', [AMs])
  else
    Result := Format('%.2fs', [AMs / 1000.0]);
end;

function Truncate(const AText: string; AMaxLen: Integer): string;
begin
  if Length(AText) <= AMaxLen then
    Result := AText
  else
    Result := Copy(AText, 1, AMaxLen - 1) + #$2026;  // U+2026 HORIZONTAL ELLIPSIS
end;

end.
