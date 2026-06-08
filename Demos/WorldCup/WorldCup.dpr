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
{   Unit:        WorldCup.dpr                                    }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   WorldCupDemo -- Entry point.
///   Builds the widget tree, wires live-simulation via OnTimer,
///   and handles global keyboard shortcuts.
///
///   Widget tree:
///     TTuiVStack (root)
///       TWorldCupDashboard  Fill(1)   -- main multi-panel view / bracket
///       TTuiLabel           Fixed(1)  -- keyboard hints footer
///
///   Keys:
///     Left / Right   -- navigate group in standings panel
///     B              -- toggle bracket view
///     T              -- toggle Dark / Light theme
///     Esc / Q        -- quit
/// </summary>
program WorldCup;

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
  Blinki.Widgets.Labels,
  WorldCup.Consts in 'WorldCup.Consts.pas',
  WorldCup.Dashboard in 'WorldCup.Dashboard.pas',
  WorldCup.Helpers in 'WorldCup.Helpers.pas',
  WorldCup.Model in 'WorldCup.Model.pas';

begin
  ReportMemoryLeaksOnShutdown := True;

  var LModel := TWorldCupModel.Create;
  var LApp := TTuiApp.Create;
  try
    LApp.Theme := TTuiTheme.Dark;
    LModel.Seed;

    // ---- Widget tree ----
    var LRoot := TTuiVStack.Create;

    var LDashboard := TWorldCupDashboard.Create(LModel, LRoot);
    LDashboard.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    var LFooter := TTuiLabel.Create(LRoot);
    LFooter.Text := CFooterHint;
    LFooter.Style := TTuiStyle.Create(
      TTuiTheme.Dark.TextDim, TTuiTheme.Dark.Background);
    LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- Tick accumulator ----
    var LTickAcc := 0;

    // ---- Timer: advance live matches every CTickIntervalMs ----
    LApp.OnTimer :=
      procedure(AElapsedMs: Integer)
      begin
        LTickAcc := LTickAcc + AElapsedMs;
        if LTickAcc < CTickIntervalMs then
          Exit;
        LTickAcc := 0;
        LModel.Tick;
        LDashboard.Invalidate;
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
  end;
end.
