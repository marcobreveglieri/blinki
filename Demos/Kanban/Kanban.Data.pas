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
{   Unit:        Kanban.Data.pas                                 }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Data access layer for the Kanban demo. SQLite persistence via FireDAC static driver.
/// </summary>
unit Kanban.Data;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  FireDAC.Comp.Client,
  Kanban.Model;

type
  /// <summary>
  ///   SQLite repository via FireDAC. Static driver (FireDAC.Phys.SQLiteWrapper.Stat).
  ///   The DB path is passed to the constructor.
  /// </summary>
  TKanbanRepository = class
  strict private
    FConnection: TFDConnection;
    procedure CreateSchema;
    procedure InsertSeed;
  public
    constructor Create(const ADatabasePath: string);
    destructor Destroy; override;
    /// <summary>
    ///   Creates schema and inserts seed data only if the tasks table does not exist yet.
    /// </summary>
    procedure EnsureDatabase;
    /// <summary>
    ///   Drops the tasks table, recreates schema and reinserts seed data.
    /// </summary>
    procedure ResetToSeed;
    /// <summary>
    ///   Loads all tasks ordered by (status, sort_order).
    /// </summary>
    function LoadAll: TArray<TKanbanTask>;
    /// <summary>
    ///   Inserts a task and returns the new Id (last_insert_rowid).
    /// </summary>
    function Insert(const ATask: TKanbanTask): Integer;
    /// <summary>
    ///   Updates title, status, priority, kind, sort_order for the given Id.
    /// </summary>
    procedure UpdateTask(const ATask: TKanbanTask);
    /// <summary>
    ///   Deletes the task with the given Id.
    /// </summary>
    procedure Delete(AId: Integer);
  end;

implementation

uses
  System.Generics.Collections,
  Data.DB,
  FireDAC.DApt,
  FireDAC.DApt.Intf,
  FireDAC.DatS,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.Stan.Async,
  FireDAC.Stan.Def,
  FireDAC.Stan.Error,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Pool,
  FireDAC.Comp.UI,
  FireDAC.Phys.Intf,
  FireDAC.UI.Intf;

const
  CSQLCreateTable =
    'CREATE TABLE IF NOT EXISTS tasks (' +
    '  id         INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  title      TEXT    NOT NULL,' +
    '  status     INTEGER NOT NULL,' +
    '  priority   INTEGER NOT NULL,' +
    '  kind       INTEGER NOT NULL,' +
    '  sort_order INTEGER NOT NULL DEFAULT 0' +
    ')';

  CSQLDropTable =
    'DROP TABLE IF EXISTS tasks';

  CSQLCheckTable =
    'SELECT name FROM sqlite_master WHERE type=''table'' AND name=''tasks''';

  CSQLSelectAll =
    'SELECT id, title, status, priority, kind, sort_order ' +
    'FROM tasks ORDER BY status, sort_order';

  CSQLInsert =
    'INSERT INTO tasks (title, status, priority, kind, sort_order) ' +
    'VALUES (:title, :status, :priority, :kind, :sort_order)';

  CSQLLastId =
    'SELECT last_insert_rowid() AS new_id';

  CSQLUpdate =
    'UPDATE tasks SET title = :title, status = :status, priority = :priority, ' +
    'kind = :kind, sort_order = :sort_order WHERE id = :id';

  CSQLDelete =
    'DELETE FROM tasks WHERE id = :id';

{ TKanbanRepository }

constructor TKanbanRepository.Create(const ADatabasePath: string);
begin
  inherited Create;
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Values['Database'] := ADatabasePath;
  FConnection.Params.Values['LockingMode'] := 'Normal';
  FConnection.Params.Values['Synchronous'] := 'Normal';
  FConnection.LoginPrompt := False;
  FConnection.Open;
end;

destructor TKanbanRepository.Destroy;
begin
  FConnection.Free;
  inherited Destroy;
end;

procedure TKanbanRepository.CreateSchema;
begin
  var LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := CSQLCreateTable;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TKanbanRepository.InsertSeed;

  procedure DoInsert(const ATitle: string; AStatus: TKanbanStatus;
    APriority: TKanbanPriority; AKind: TKanbanKind; ASortOrder: Integer);
  begin
    var LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := CSQLInsert;
      LQuery.ParamByName('title').AsString := ATitle;
      LQuery.ParamByName('status').AsInteger := Ord(AStatus);
      LQuery.ParamByName('priority').AsInteger := Ord(APriority);
      LQuery.ParamByName('kind').AsInteger := Ord(AKind);
      LQuery.ParamByName('sort_order').AsInteger := ASortOrder;
      LQuery.ExecSQL;
    finally
      LQuery.Free;
    end;
  end;

begin
  DoInsert('Implement user auth', ksBacklog, kpHigh, kkAuto, 1);
  DoInsert('Add rate limiting', ksBacklog, kpMedium, kkAuto, 2);
  DoInsert('Write API docs', ksBacklog, kpLow, kkPair, 3);
  DoInsert('Fix #342 timeout', ksInProgress, kpHigh, kkAuto, 1);
  DoInsert('Update error handling', ksInProgress, kpMedium, kkAuto, 2);
  DoInsert('Refactor DB queries', ksReview, kpMedium, kkAuto, 1);
  DoInsert('Deploy to staging', ksDone, kpLow, kkAuto, 1);
  DoInsert('Setup CI pipeline', ksDone, kpLow, kkPair, 2);
end;

procedure TKanbanRepository.EnsureDatabase;
begin
  var LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := CSQLCheckTable;
    LQuery.Open;
    if LQuery.Eof then
    begin
      LQuery.Close;
      CreateSchema;
      InsertSeed;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TKanbanRepository.ResetToSeed;
begin
  var LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := CSQLDropTable;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
  CreateSchema;
  InsertSeed;
end;

function TKanbanRepository.LoadAll: TArray<TKanbanTask>;
begin
  var LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := CSQLSelectAll;
    LQuery.Open;
    var LList := TList<TKanbanTask>.Create;
    try
      while not LQuery.Eof do
      begin
        LList.Add(TKanbanTask.Make(
          LQuery.FieldByName('id').AsInteger,
          LQuery.FieldByName('title').AsString,
          TKanbanStatus(LQuery.FieldByName('status').AsInteger),
          TKanbanPriority(LQuery.FieldByName('priority').AsInteger),
          TKanbanKind(LQuery.FieldByName('kind').AsInteger),
          LQuery.FieldByName('sort_order').AsInteger
        ));
        LQuery.Next;
      end;
      Result := LList.ToArray;
    finally
      LList.Free;
    end;
  finally
    LQuery.Free;
  end;
end;

function TKanbanRepository.Insert(const ATask: TKanbanTask): Integer;
begin
  var LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := CSQLInsert;
    LQuery.ParamByName('title').AsString := ATask.Title;
    LQuery.ParamByName('status').AsInteger := Ord(ATask.Status);
    LQuery.ParamByName('priority').AsInteger := Ord(ATask.Priority);
    LQuery.ParamByName('kind').AsInteger := Ord(ATask.Kind);
    LQuery.ParamByName('sort_order').AsInteger := ATask.SortOrder;
    LQuery.ExecSQL;
    LQuery.SQL.Text := CSQLLastId;
    LQuery.Open;
    Result := LQuery.FieldByName('new_id').AsInteger;
  finally
    LQuery.Free;
  end;
end;

procedure TKanbanRepository.UpdateTask(const ATask: TKanbanTask);
begin
  var LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := CSQLUpdate;
    LQuery.ParamByName('title').AsString := ATask.Title;
    LQuery.ParamByName('status').AsInteger := Ord(ATask.Status);
    LQuery.ParamByName('priority').AsInteger := Ord(ATask.Priority);
    LQuery.ParamByName('kind').AsInteger := Ord(ATask.Kind);
    LQuery.ParamByName('sort_order').AsInteger := ATask.SortOrder;
    LQuery.ParamByName('id').AsInteger := ATask.Id;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TKanbanRepository.Delete(AId: Integer);
begin
  var LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := CSQLDelete;
    LQuery.ParamByName('id').AsInteger := AId;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

end.
