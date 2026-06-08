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
{   Unit:        Kanban.Model.pas                                }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   KanbanDemo -- Domain types: TKanbanStatus, TKanbanPriority, TKanbanKind,
///   TKanbanTask and TKanbanModel. Zero UI or DB dependencies.
/// </summary>
unit Kanban.Model;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Generics.Collections;

type

  /// <summary>
  ///   Column status of a Kanban task.
  /// </summary>
  TKanbanStatus = (ksBacklog, ksInProgress, ksReview, ksDone);

  /// <summary>
  ///   Priority level of a Kanban task.
  /// </summary>
  TKanbanPriority = (kpLow, kpMedium, kpHigh);

  /// <summary>
  ///   Execution kind: automated pipeline or pair-programmed work.
  /// </summary>
  TKanbanKind = (kkAuto, kkPair);

  /// <summary>
  ///   Immutable value record representing a single Kanban task.
  ///   Use the static factory Make to construct instances.
  /// </summary>
  TKanbanTask = record
    Id: Integer;
    Kind: TKanbanKind;
    Priority: TKanbanPriority;
    SortOrder: Integer;
    Status: TKanbanStatus;
    Title: string;
    /// <summary>
    ///   Creates a fully-initialized TKanbanTask record.
    /// </summary>
    class function Make(AId: Integer; const ATitle: string; AStatus: TKanbanStatus;
      APriority: TKanbanPriority; AKind: TKanbanKind; ASortOrder: Integer): TKanbanTask; static;
  end;

  /// <summary>
  ///   In-memory Kanban task repository.
  ///   Holds the canonical task list and provides CRUD operations.
  ///   Has no UI or database dependencies.
  /// </summary>
  TKanbanModel = class
  strict private
    FTasks: TList<TKanbanTask>;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Appends ATask to the internal list and returns its index.
    ///   The caller must have already assigned a unique Id to the task.
    /// </summary>
    function Add(const ATask: TKanbanTask): Integer;
    /// <summary>
    ///   Returns the number of tasks that have the given status.
    /// </summary>
    function CountByStatus(AStatus: TKanbanStatus): Integer;
    /// <summary>
    ///   Searches for a task by Id. Returns True and sets ATask on success.
    /// </summary>
    function FindById(AId: Integer; out ATask: TKanbanTask): Boolean;
    /// <summary>
    ///   Returns the next sort order value to place a new task at the end of
    ///   the given column. Equal to max(SortOrder) in that column plus one,
    ///   or 1 if the column is empty.
    /// </summary>
    function NextSortOrder(AStatus: TKanbanStatus): Integer;
    /// <summary>
    ///   Removes the task with the given Id. Raises an exception if not found.
    /// </summary>
    procedure Remove(AId: Integer);
    /// <summary>
    ///   Replaces the internal list with ATasks (bulk initial load).
    /// </summary>
    procedure SetTasks(const ATasks: TArray<TKanbanTask>);
    /// <summary>
    ///   Returns all tasks with the given status, ordered ascending by SortOrder.
    /// </summary>
    function TasksByStatus(AStatus: TKanbanStatus): TArray<TKanbanTask>;
    /// <summary>
    ///   Replaces the stored task that has the same Id as ATask. Raises an
    ///   exception if no matching task is found.
    /// </summary>
    procedure Update(const ATask: TKanbanTask);
  end;

implementation

uses
  System.Generics.Defaults,
  System.SysUtils;

{ TKanbanTask }

class function TKanbanTask.Make(AId: Integer; const ATitle: string;
  AStatus: TKanbanStatus; APriority: TKanbanPriority; AKind: TKanbanKind;
  ASortOrder: Integer): TKanbanTask;
begin
  Result.Id := AId;
  Result.Title := ATitle;
  Result.Status := AStatus;
  Result.Priority := APriority;
  Result.Kind := AKind;
  Result.SortOrder := ASortOrder;
end;

{ TKanbanModel }

constructor TKanbanModel.Create;
begin
  inherited Create;
  FTasks := TList<TKanbanTask>.Create;
end;

destructor TKanbanModel.Destroy;
begin
  FTasks.Free;
  inherited Destroy;
end;

function TKanbanModel.Add(const ATask: TKanbanTask): Integer;
begin
  Result := FTasks.Add(ATask);
end;

function TKanbanModel.CountByStatus(AStatus: TKanbanStatus): Integer;
begin
  Result := 0;
  for var LTask in FTasks do
    if LTask.Status = AStatus then
      Inc(Result);
end;

function TKanbanModel.FindById(AId: Integer; out ATask: TKanbanTask): Boolean;
begin
  for var LIdx := 0 to FTasks.Count - 1 do
  begin
    if FTasks[LIdx].Id = AId then
    begin
      ATask := FTasks[LIdx];
      Exit(True);
    end;
  end;
  Result := False;
end;

function TKanbanModel.NextSortOrder(AStatus: TKanbanStatus): Integer;
begin
  Result := 0;
  for var LTask in FTasks do
    if (LTask.Status = AStatus) and (LTask.SortOrder > Result) then
      Result := LTask.SortOrder;
  Inc(Result);
end;

procedure TKanbanModel.Remove(AId: Integer);
begin
  for var LIdx := 0 to FTasks.Count - 1 do
  begin
    if FTasks[LIdx].Id = AId then
    begin
      FTasks.Delete(LIdx);
      Exit;
    end;
  end;
  raise Exception.CreateFmt('TKanbanModel.Remove: task with Id=%d not found.', [AId]);
end;

procedure TKanbanModel.SetTasks(const ATasks: TArray<TKanbanTask>);
begin
  FTasks.Clear;
  for var LTask in ATasks do
    FTasks.Add(LTask);
end;

function TKanbanModel.TasksByStatus(AStatus: TKanbanStatus): TArray<TKanbanTask>;
begin
  var LResult := TList<TKanbanTask>.Create;
  try
    for var LTask in FTasks do
      if LTask.Status = AStatus then
        LResult.Add(LTask);
    // Sort ascending by SortOrder
    LResult.Sort(
      TComparer<TKanbanTask>.Construct(
        function(const A, B: TKanbanTask): Integer
        begin
          Result := A.SortOrder - B.SortOrder;
        end
      )
    );
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

procedure TKanbanModel.Update(const ATask: TKanbanTask);
begin
  for var LIdx := 0 to FTasks.Count - 1 do
  begin
    if FTasks[LIdx].Id = ATask.Id then
    begin
      FTasks[LIdx] := ATask;
      Exit;
    end;
  end;
  raise Exception.CreateFmt('TKanbanModel.Update: task with Id=%d not found.', [ATask.Id]);
end;

end.
