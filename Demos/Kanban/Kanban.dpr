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
{   Unit:        Kanban.dpr                                      }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   KanbanDemo -- Blinki demo: 4-column Kanban board with SQLite persistence,
///   card rendering, keyboard navigation, and dialog-based CRUD operations.
/// </summary>
program Kanban;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Blinki.Core.App,
  Blinki.Core.Event,
  Blinki.Core.Geometry,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  Blinki.Layout.Stack,
  Blinki.Widgets.Dialog,
  Blinki.Widgets.Labels,
  Kanban.Consts in 'Kanban.Consts.pas',
  Kanban.Data in 'Kanban.Data.pas',
  Kanban.Helpers in 'Kanban.Helpers.pas',
  Kanban.Model in 'Kanban.Model.pas',
  Kanban.View in 'Kanban.View.pas';

begin
  ReportMemoryLeaksOnShutdown := True;

  var LDbPath := ExtractFilePath(ParamStr(0)) + 'kanban.db';
  var LRepo := TKanbanRepository.Create(LDbPath);
  var LModel := TKanbanModel.Create;
  var LApp := TTuiApp.Create;
  try
    LApp.Theme := TTuiTheme.Dark;
    LRepo.EnsureDatabase;
    LModel.SetTasks(LRepo.LoadAll);

    // ---- widget tree ----
    var LRoot := TTuiVStack.Create;

    var LHeader := TTuiLabel.Create(LRoot);
    LHeader.Text := CAppTitle;
    LHeader.Style := TTuiStyle.Create(
      TTuiTheme.Dark.Primary, TTuiTheme.Dark.Background, [taBold]);
    LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    var LBoard := TKanbanView.Create(LRoot);
    LBoard.LayoutConstraint := TTuiLayoutConstraint.Fill(1);
    LBoard.SetModel(LModel);

    var LFooter := TTuiLabel.Create(LRoot);
    LFooter.Text := CFooterHint;
    LFooter.Style := TTuiStyle.Create(
      TTuiTheme.Dark.TextDim, TTuiTheme.Dark.Background);
    LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- Callback: new task ----
    LBoard.OnRequestNew := procedure(AStatus: TKanbanStatus)
    begin
      var LDlg := TTuiDialogs.Input('New Task', 'Title:', '');
      LDlg.OnClose :=
        procedure(ASender: TObject; AResult: TTuiDialogResult)
        begin
          if AResult = drOK then
          begin
            var LTitle := Trim((ASender as TTuiInputDialog).Value);
            if LTitle <> '' then
            begin
              var LNewTask := TKanbanTask.Make(0, LTitle, AStatus, kpMedium, kkAuto,
                LModel.NextSortOrder(AStatus));
              var LNewId := LRepo.Insert(LNewTask);
              LNewTask.Id := LNewId;
              LModel.Add(LNewTask);
              LBoard.RefreshFromModel;
            end;
          end;
          LApp.PopModal;
        end;
      LApp.PushModal(LDlg);
    end;

    // ---- Callback: edit task ----
    LBoard.OnRequestEdit := procedure(ATask: TKanbanTask)
    begin
      var LDlg := TTuiDialogs.Input('Edit Task', 'Title:', ATask.Title);
      LDlg.OnClose :=
        procedure(ASender: TObject; AResult: TTuiDialogResult)
        begin
          if AResult = drOK then
          begin
            var LTitle := Trim((ASender as TTuiInputDialog).Value);
            if LTitle <> '' then
            begin
              ATask.Title := LTitle;
              LRepo.UpdateTask(ATask);
              LModel.Update(ATask);
              LBoard.RefreshFromModel;
            end;
          end;
          LApp.PopModal;
        end;
      LApp.PushModal(LDlg);
    end;

    // ---- Callback: delete task ----
    LBoard.OnRequestDelete := procedure(ATask: TKanbanTask)
    begin
      var LDlg := TTuiDialogs.Confirm(
        'Delete Task',
        'Delete "' + ATask.Title + '"?',
        dbYesNo);
      LDlg.OnClose :=
        procedure(ASender: TObject; AResult: TTuiDialogResult)
        begin
          if AResult = drYes then
          begin
            LRepo.Delete(ATask.Id);
            LModel.Remove(ATask.Id);
            LBoard.RefreshFromModel;
          end;
          LApp.PopModal;
        end;
      LApp.PushModal(LDlg);
    end;

    // ---- Callback: change priority ----
    LBoard.OnChangePriority := procedure(ATask: TKanbanTask; ANewPriority: TKanbanPriority)
    begin
      ATask.Priority := ANewPriority;
      LRepo.UpdateTask(ATask);
      LModel.Update(ATask);
      LBoard.RefreshFromModel;
    end;

    // ---- Callback: change kind ----
    LBoard.OnChangeKind := procedure(ATask: TKanbanTask; ANewKind: TKanbanKind)
    begin
      ATask.Kind := ANewKind;
      LRepo.UpdateTask(ATask);
      LModel.Update(ATask);
      LBoard.RefreshFromModel;
    end;

    // ---- Callback: move task ----
    LBoard.OnMoveTask := procedure(ATask: TKanbanTask; ANewStatus: TKanbanStatus)
    begin
      ATask.Status := ANewStatus;
      ATask.SortOrder := LModel.NextSortOrder(ANewStatus);
      LRepo.UpdateTask(ATask);
      LModel.Update(ATask);
      LBoard.RefreshFromModel;
      LBoard.SelectColumn(ANewStatus, True);
    end;

    // ---- Global key handling ----
    LApp.OnKeyPress :=
      procedure(const AKey: TTuiKeyEvent)
      begin
        case AKey.Code of
          kcEscape:
            LApp.Quit;
          kcChar:
            case UpCase(AKey.Character) of
              'Q': LApp.Quit;
              'T':
              begin
                if LApp.Theme.Background.R < 128 then
                  LApp.Theme := TTuiTheme.Light
                else
                  LApp.Theme := TTuiTheme.Dark;
              end;
            end;
        end;
      end;

    LApp.SetRoot(LRoot);
    LApp.Run;
  finally
    LApp.Free;
    LModel.Free;
    LRepo.Free;
  end;
end.
