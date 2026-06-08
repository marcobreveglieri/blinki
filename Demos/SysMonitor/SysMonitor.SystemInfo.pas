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
{   Unit:        SysMonitor.SystemInfo.pas                       }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Windows-only module for retrieving real-time system information.
///   Used by the SysMonitor sample. Not part of the core library.
/// </summary>
unit SysMonitor.SystemInfo;

{$APPTYPE CONSOLE}

interface

type
  /// <summary>
  ///   System memory usage snapshot.
  /// </summary>
  TMemorySnapshot = record
    /// <summary>
    ///   Physical memory in use (bytes).
    /// </summary>
    Used: UInt64;
    /// <summary>
    ///   Total physical memory (bytes).
    /// </summary>
    Total: UInt64;
    /// <summary>
    ///   Usage percentage [0..100].
    /// </summary>
    function UsedPercent: Double;
  end;

  /// <summary>
  ///   Information about a system process.
  /// </summary>
  TProcessInfo = record
    PID: Cardinal;
    Name: string;
    WorkingSet: UInt64;
  end;

/// <summary>
///   Returns the CPU usage percentage since the last call.
///   The first call always returns 0 (no delta available).
/// </summary>
function GetCpuPercent: Double;

/// <summary>
///   Returns the current system memory usage snapshot.
/// </summary>
function GetMemoryUsage: TMemorySnapshot;

/// <summary>
///   Returns the list of active processes ordered by descending WorkingSet.
///   AMaxCount: maximum number of processes to return (default 30).
/// </summary>
function GetProcessList(AMaxCount: Integer = 30): TArray<TProcessInfo>;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  Winapi.Windows,
  Winapi.PsAPI,
  Winapi.TlHelp32;

{$IF NOT DECLARED(PROCESS_QUERY_LIMITED_INFORMATION)}
const
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
{$IFEND}

// State for CPU delta calculation
var
  GLastIdle: TFileTime;
  GLastKernel: TFileTime;
  GLastUser: TFileTime;
  GCpuInit: Boolean = False;

function FileTimeToUInt64(const AFT: TFileTime): UInt64; inline;
begin
  Result := (UInt64(AFT.dwHighDateTime) shl 32) or AFT.dwLowDateTime;
end;

function TMemorySnapshot.UsedPercent: Double;
begin
  if Total = 0 then
    Result := 0
  else
    Result := Used / Total * 100.0;
end;

function GetCpuPercent: Double;
begin
  Result := 0.0;
  var LIdle: TFileTime;
  var LKernel: TFileTime;
  var LUser: TFileTime;
  if not GetSystemTimes(LIdle, LKernel, LUser) then
    Exit;

  if not GCpuInit then
  begin
    GLastIdle := LIdle;
    GLastKernel := LKernel;
    GLastUser := LUser;
    GCpuInit := True;
    Exit;
  end;

  var DIdle := FileTimeToUInt64(LIdle) - FileTimeToUInt64(GLastIdle);
  var DKernel := FileTimeToUInt64(LKernel) - FileTimeToUInt64(GLastKernel);
  var DUser := FileTimeToUInt64(LUser) - FileTimeToUInt64(GLastUser);

  GLastIdle := LIdle;
  GLastKernel := LKernel;
  GLastUser := LUser;

  var LTotal := DKernel + DUser;
  if LTotal = 0 then
    Exit;

  Result := (1.0 - DIdle / LTotal) * 100.0;
  if Result < 0 then
    Result := 0;
  if Result > 100 then
    Result := 100;
end;

function GetMemoryUsage: TMemorySnapshot;
begin
  Result.Used := 0;
  Result.Total := 0;
  var LStatus: TMemoryStatusEx;
  LStatus.dwLength := SizeOf(LStatus);
  if GlobalMemoryStatusEx(LStatus) then
  begin
    Result.Total := LStatus.ullTotalPhys;
    Result.Used := LStatus.ullTotalPhys - LStatus.ullAvailPhys;
  end;
end;

function GetProcessList(AMaxCount: Integer): TArray<TProcessInfo>;
begin
  var LList := TList<TProcessInfo>.Create;
  try
    var LSnap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if LSnap = INVALID_HANDLE_VALUE then
      Exit(nil);
    try
      var LEntry: TProcessEntry32W;
      LEntry.dwSize := SizeOf(LEntry);
      if Process32FirstW(LSnap, LEntry) then
      repeat
        var LProc: TProcessInfo;
        LProc.PID := LEntry.th32ProcessID;
        LProc.Name := LEntry.szExeFile;
        LProc.WorkingSet := 0;

        var LHandle := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, LProc.PID);
        if LHandle <> 0 then
        try
          var LCounters: TProcessMemoryCounters;
          LCounters.cb := SizeOf(LCounters);
          if GetProcessMemoryInfo(LHandle, @LCounters, SizeOf(LCounters)) then
            LProc.WorkingSet := LCounters.WorkingSetSize;
        finally
          CloseHandle(LHandle);
        end;

        LList.Add(LProc);
      until not Process32NextW(LSnap, LEntry);
    finally
      CloseHandle(LSnap);
    end;

    LList.Sort(TComparer<TProcessInfo>.Construct(
      function(const A, B: TProcessInfo): Integer
      begin
        if A.WorkingSet > B.WorkingSet then
          Result := -1
        else if A.WorkingSet < B.WorkingSet then
          Result := 1
        else
          Result := 0;
      end));

    if LList.Count > AMaxCount then
      LList.Count := AMaxCount;

    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

end.
