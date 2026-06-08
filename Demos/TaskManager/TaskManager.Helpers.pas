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
{   Unit:        TaskManager.Helpers.pas                         }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TaskManagerDemo -- Stateless formatting helpers: memory, CPU percentage,
///   uptime, and process status to human-readable strings.
/// </summary>
unit TaskManager.Helpers;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  TaskManager.Model;

/// <summary>
///   Formats a memory size given in megabytes as a compact string.
///   Values below 1024 MB are rendered as "NNN MB"; values above as "N.N GB".
/// </summary>
function FormatMem(AMegabytes: Integer): string;

/// <summary>
///   Formats a CPU usage value (0.0 .. 100.0) as "NN.N%" with one decimal place.
/// </summary>
function FormatCpu(AValue: Double): string;

/// <summary>
///   Formats an elapsed time in milliseconds as "HH:MM:SS".
/// </summary>
function FormatUptime(AMs: Int64): string;

/// <summary>
///   Returns a short English label for the given process status.
/// </summary>
function StatusToText(AStatus: TProcessStatus): string;

implementation

uses
  System.SysUtils;

function FormatMem(AMegabytes: Integer): string;
begin
  if AMegabytes < 1024 then
    Result := IntToStr(AMegabytes) + ' MB'
  else
    Result := FormatFloat('0.0', AMegabytes / 1024.0) + ' GB';
end;

function FormatCpu(AValue: Double): string;
begin
  Result := FormatFloat('0.0', AValue) + '%';
end;

function FormatUptime(AMs: Int64): string;
var
  LTotalSec: Int64;
  LHours: Int64;
  LMins: Int64;
  LSecs: Int64;
begin
  LTotalSec := AMs div 1000;
  LHours := LTotalSec div 3600;
  LMins := (LTotalSec mod 3600) div 60;
  LSecs := LTotalSec mod 60;
  Result := Format('%2.2d:%2.2d:%2.2d', [LHours, LMins, LSecs]);
end;

function StatusToText(AStatus: TProcessStatus): string;
begin
  case AStatus of
    psRunning:   Result := 'Running';
    psSleeping:  Result := 'Sleeping';
    psSuspended: Result := 'Suspended';
  else
    Result := '?';
  end;
end;

end.
