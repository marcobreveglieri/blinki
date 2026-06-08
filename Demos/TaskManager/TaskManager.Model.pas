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
{   Unit:        TaskManager.Model.pas                           }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TaskManagerDemo -- Domain layer: process record, status enum,
///   and the owning model that simulates live system data.
///   No UI dependencies; pure data and update logic.
/// </summary>
unit TaskManager.Model;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections;

type

  /// <summary>
  ///   Simulated process status.
  /// </summary>
  TProcessStatus = (psRunning, psSleeping, psSuspended);

  /// <summary>
  ///   Snapshot of a single simulated process.
  /// </summary>
  TProcessInfo = record
    Pid: Integer;
    Name: string;
    Cpu: Double;      // 0.0 .. 100.0
    MemMB: Integer;
    Threads: Integer;
    Status: TProcessStatus;
    /// <summary>
    ///   Factory: creates a TProcessInfo with the supplied field values.
    /// </summary>
    class function Make(APid: Integer; const AName: string; ACpu: Double;
      AMemMB, AThreads: Integer;
      AStatus: TProcessStatus): TProcessInfo; static;
  end;

  /// <summary>
  ///   Owning model that holds the full list of simulated processes
  ///   and the aggregate performance metrics (CPU, RAM, per-core loads,
  ///   thread/handle counts, uptime). Call Update on every timer tick
  ///   to advance the simulation.
  /// </summary>
  TTaskManagerModel = class
  strict private
    FProcesses: TList<TProcessInfo>;
    FCpuTotal: Double;      // 0.0 .. 1.0
    FMemUsedFrac: Double;   // 0.0 .. 1.0
    FCoreLoads: TArray<Double>;
    FTotalThreads: Integer;
    FHandleCount: Integer;
    FUptimeMs: Int64;
    function RandomWalk(ACurrent, AStep, AMin, AMax: Double): Double;
    procedure UpdateAggregates;
  public
    /// <summary>
    ///   Creates and seeds the model with an initial population of
    ///   simulated processes.
    /// </summary>
    constructor Create;
    /// <summary>
    ///   Frees owned resources.
    /// </summary>
    destructor Destroy; override;
    /// <summary>
    ///   Advances the simulation by AElapsedMs milliseconds: random-walks
    ///   all per-process and aggregate metrics, and accumulates uptime.
    /// </summary>
    procedure Update(AElapsedMs: Integer);
    /// <summary>
    ///   Read-only access to the current process list snapshot.
    /// </summary>
    property Processes: TList<TProcessInfo> read FProcesses;
    /// <summary>
    ///   Total CPU utilisation (0.0 .. 1.0).
    /// </summary>
    property CpuTotal: Double read FCpuTotal;
    /// <summary>
    ///   Fraction of memory in use (0.0 .. 1.0).
    /// </summary>
    property MemUsedFrac: Double read FMemUsedFrac;
    /// <summary>
    ///   Per-core load array (CCoreCount elements, each 0.0 .. 1.0).
    /// </summary>
    property CoreLoads: TArray<Double> read FCoreLoads;
    /// <summary>
    ///   Sum of thread counts across all simulated processes.
    /// </summary>
    property TotalThreads: Integer read FTotalThreads;
    /// <summary>
    ///   Simulated total handle count.
    /// </summary>
    property HandleCount: Integer read FHandleCount;
    /// <summary>
    ///   Elapsed simulation time in milliseconds (accumulated from Update calls).
    /// </summary>
    property UptimeMs: Int64 read FUptimeMs;
  end;

implementation

uses
  System.SysUtils,
  TaskManager.Consts;

{ TProcessInfo }

class function TProcessInfo.Make(APid: Integer; const AName: string;
  ACpu: Double; AMemMB, AThreads: Integer;
  AStatus: TProcessStatus): TProcessInfo;
begin
  Result.Pid := APid;
  Result.Name := AName;
  Result.Cpu := ACpu;
  Result.MemMB := AMemMB;
  Result.Threads := AThreads;
  Result.Status := AStatus;
end;

{ TTaskManagerModel }

constructor TTaskManagerModel.Create;
begin
  inherited Create;
  FProcesses := TList<TProcessInfo>.Create;
  SetLength(FCoreLoads, CCoreCount);

  // Seed initial aggregate values
  FCpuTotal := 0.25 + Random(40) / 100.0;
  FMemUsedFrac := 0.40 + Random(30) / 100.0;
  FHandleCount := 15000 + Random(10000);

  for var LCore := 0 to CCoreCount - 1 do
    FCoreLoads[LCore] := Random(80) / 100.0;

  // Seed initial process list
  var LPid := 500;
  for var LI := 0 to 39 do
  begin
    Inc(LPid, 4 + Random(200));
    var LCpu := Random(600) / 10.0;      // 0.0 .. 60.0
    var LMem := 10 + Random(1500);
    var LThreads := 1 + Random(40);
    var LStatusIdx := Random(10);
    var LStatus: TProcessStatus;
    if LStatusIdx < 5 then
      LStatus := psRunning
    else if LStatusIdx < 9 then
      LStatus := psSleeping
    else
      LStatus := psSuspended;
    FProcesses.Add(TProcessInfo.Make(
      LPid,
      CProcessNames[LI mod Length(CProcessNames)],
      LCpu,
      LMem,
      LThreads,
      LStatus));
  end;

  UpdateAggregates;
end;

destructor TTaskManagerModel.Destroy;
begin
  if Assigned(FProcesses) then
    FreeAndNil(FProcesses);
  inherited Destroy;
end;

function TTaskManagerModel.RandomWalk(ACurrent, AStep, AMin, AMax: Double): Double;
begin
  Result := ACurrent + (Random(201) - 100) / 100.0 * AStep;
  if Result < AMin then
    Result := AMin;
  if Result > AMax then
    Result := AMax;
end;

procedure TTaskManagerModel.UpdateAggregates;
begin
  FTotalThreads := 0;
  for var LI := 0 to FProcesses.Count - 1 do
    Inc(FTotalThreads, FProcesses[LI].Threads);
end;

procedure TTaskManagerModel.Update(AElapsedMs: Integer);
begin
  Inc(FUptimeMs, AElapsedMs);

  // Walk aggregate metrics
  FCpuTotal := RandomWalk(FCpuTotal, 0.06, 0.0, 1.0);
  FMemUsedFrac := RandomWalk(FMemUsedFrac, 0.02, 0.0, 1.0);
  FHandleCount := FHandleCount + (Random(201) - 100);
  if FHandleCount < 5000 then
    FHandleCount := 5000;

  // Walk per-core loads
  for var LCore := 0 to CCoreCount - 1 do
    FCoreLoads[LCore] := RandomWalk(FCoreLoads[LCore], 0.10, 0.0, 1.0);

  // Walk per-process metrics
  for var LI := 0 to FProcesses.Count - 1 do
  begin
    var LP := FProcesses[LI];
    LP.Cpu := RandomWalk(LP.Cpu / 100.0, 0.05, 0.0, 1.0) * 100.0;
    LP.MemMB := LP.MemMB + (Random(21) - 10);
    if LP.MemMB < 1 then
      LP.MemMB := 1;
    // Occasionally flip status
    if Random(50) = 0 then
    begin
      var LStatusIdx := Random(10);
      if LStatusIdx < 5 then
        LP.Status := psRunning
      else if LStatusIdx < 9 then
        LP.Status := psSleeping
      else
        LP.Status := psSuspended;
    end;
    FProcesses[LI] := LP;
  end;

  UpdateAggregates;
end;

end.
