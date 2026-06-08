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
{   Unit:        Scaffold.dpr                                    }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Entry point for the ScaffoldDemo project.
///   Runs a single-phase inline wizard that collects the project name,
///   template, and optional features via sequential CLI prompts
///   (text input, arrow-key select, arrow-key multi-select).
///   Each prompt collapses to a one-line summary on confirmation.
///   If all prompts are confirmed a simulated install log is shown:
///   animated Braille spinners, an error/retry sequence, and a
///   next-steps box. The app always ends by waiting for a key press.
/// </summary>
program Scaffold;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Blinki.Core.Console,
  Scaffold.Consts in 'Scaffold.Consts.pas',
  Scaffold.Helpers in 'Scaffold.Helpers.pas',
  Scaffold.Model in 'Scaffold.Model.pas';

begin
  ReportMemoryLeaksOnShutdown := True;

  var LConfig := TScaffoldConfig.Create;
  try
    var LBackend := TTuiConsoleBackendFactory.CreateBackend;
    LBackend.Open;
    try
      var LCli := TCliConsole.Create(LBackend);
      try

        LCli.Banner;

        // ------------------------------------------------------------------
        // Prompt 1: project name
        // ------------------------------------------------------------------
        LConfig.ProjectName := LCli.PromptText(
          CPromptName, CDefaultName, CNamePlaceholder
        );

        // ------------------------------------------------------------------
        // Prompt 2: template (single-select)
        // ------------------------------------------------------------------
        if not LCli.Aborted then
        begin
          var LTemplateIdx := LCli.PromptSelect(
            CPromptTemplate,
            [CTemplateDashboard, CTemplateForm, CTemplateEmpty],
            0
          );
          if not LCli.Aborted then
          begin
            case LTemplateIdx of
              0: LConfig.Template := stDashboard;
              1: LConfig.Template := stForm;
              2: LConfig.Template := stEmpty;
            end;

            // --------------------------------------------------------------
            // Prompt 3: features (multi-select)
            // --------------------------------------------------------------
            var LFeaturesSel := LCli.PromptMultiSelect(
              CPromptFeatures,
              [CFeatureDark, CFeatureExamples, CFeatureGit],
              [True, True, True]
            );
            if not LCli.Aborted then
            begin
              var LFeatures: TScaffoldFeatures := [];
              if LFeaturesSel[0] then
                Include(LFeatures, sfDarkTheme);
              if LFeaturesSel[1] then
                Include(LFeatures, sfExamples);
              if LFeaturesSel[2] then
                Include(LFeatures, sfGit);
              LConfig.Features := LFeatures;
              LConfig.Confirmed := True;
            end;
          end;
        end;

        // ------------------------------------------------------------------
        // Install log (only when all prompts were confirmed)
        // ------------------------------------------------------------------
        if LConfig.Confirmed then
        begin
          LCli.Blank;
          LCli.RunTask(CTaskFolders, 800);
          LCli.RunTask(
            CTaskTemplate + ' ' + LConfig.DescribeTemplate, 1200
          );
          LCli.Info(CMsgThemeApplied);
          LCli.RunTaskWithRecovery(
            CTaskDownload,
            CMsgNetworkError,
            CMsgRetryDownload,
            1500, 800, 1200
          );
          LCli.Warn(CMsgDelphiWarn);
          if sfGit in LConfig.Features then
            LCli.RunTask(CTaskGit, 600);
          LCli.RunTask(CTaskCompile, 2000);
          LCli.Blank;
          LCli.Ok(CMsgSuccess);
          LCli.NextSteps(LConfig);
        end
        else
        begin
          LCli.Blank;
          LCli.Note(CMsgCancelled);
        end;

        // ------------------------------------------------------------------
        // Always wait for a key before closing
        // ------------------------------------------------------------------
        LCli.WaitForKey(CMsgPressAnyKey);

      finally
        LCli.Free;
      end;
    finally
      LBackend.Close;
    end;
  finally
    LConfig.Free;
  end;
end.
