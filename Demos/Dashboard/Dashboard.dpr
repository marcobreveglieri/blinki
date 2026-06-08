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
{   Unit:        Dashboard.dpr                                   }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Dashboard demo — entry point.
///   Builds the widget tree (two rows of panels + log table + status bar),
///   wires live log simulation via OnTimer, and handles global shortcuts.
///
///   Widget tree:
///     TTuiVStack (root)
///       TTuiHStack    Fixed(12) — top row
///         TDashboardTopList  Fill(1) — Top Words
///         TDashboardTopList  Fill(1) — Top Attributes
///       TTuiHStack    Fixed(12) — middle row
///         TDashboardPatterns Fill(1) — Log Patterns
///         TDashboardCounts   Fill(1) — Log Counts
///       TDashboardLogTable   Fill(1) — scrollable log viewer
///       TDashboardStatusBar  Fixed(1) — status bar
///
///   Keys:
///     Tab / Shift+Tab            — cycle focus between the five panels
///     Up/Down/PgUp/PgDn/Home/End — move row cursor in the log table
///     Enter                      — open detail view of selected log entry
///     Scroll wheel               — scroll log table viewport
///     Click                      — focus a panel
///     Space                      — pause / resume the simulation
///     i                          — show statistics overlay
///     ? / h                      — show keyboard help overlay
///     T                          — toggle Dark / Light theme
///     Esc / Q                    — quit
/// </summary>
program Dashboard;

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
  Dashboard.Consts   in 'Dashboard.Consts.pas',
  Dashboard.Counts   in 'Dashboard.Counts.pas',
  Dashboard.Helpers  in 'Dashboard.Helpers.pas',
  Dashboard.LogTable in 'Dashboard.LogTable.pas',
  Dashboard.Model    in 'Dashboard.Model.pas',
  Dashboard.Overlays in 'Dashboard.Overlays.pas',
  Dashboard.Patterns in 'Dashboard.Patterns.pas',
  Dashboard.StatusBar in 'Dashboard.StatusBar.pas',
  Dashboard.TopList  in 'Dashboard.TopList.pas';

begin
  ReportMemoryLeaksOnShutdown := True;

  var LModel := TDashboardModel.Create;
  var LApp   := TTuiApp.Create;
  try
    // Custom dark theme with pure-black background (gonzo aesthetic)
    var LCustomDark := TTuiTheme.Dark;
    LCustomDark.Background := TTuiColor.RGB(0, 0, 0);
    LCustomDark.Surface    := TTuiColor.RGB(0, 0, 0);
    LApp.Theme := LCustomDark;

    LModel.Seed;

    // ---- Widget tree ----
    var LRoot := TTuiVStack.Create;

    // Top row: Top Words | Top Attributes
    var LTopRow := TTuiHStack.Create(LRoot);
    LTopRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(12);

    var LTopWords := TDashboardTopList.Create(LTopRow, LModel.TopWords,
      CPanelTopWords, 'Words');
    // LTopWords.LayoutConstraint defaults to Fill(1)

    var LTopAttrs := TDashboardTopList.Create(LTopRow, LModel.TopAttributes,
      CPanelTopAttributes, 'Attributes');
    // LTopAttrs.LayoutConstraint defaults to Fill(1)

    // Middle row: Log Patterns | Log Counts
    var LMidRow := TTuiHStack.Create(LRoot);
    LMidRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(12);

    var LPatterns := TDashboardPatterns.Create(LMidRow, LModel);
    // LPatterns.LayoutConstraint defaults to Fill(1)

    var LCounts := TDashboardCounts.Create(LMidRow, LModel);
    // LCounts.LayoutConstraint defaults to Fill(1)

    // Log table — takes all remaining vertical space
    var LLogTable := TDashboardLogTable.Create(LRoot, LModel.LogEntries);
    // LLogTable.LayoutConstraint defaults to Fill(1)

    // Status bar — always 1 row tall
    var LStatusBar := TDashboardStatusBar.Create(LRoot);
    LStatusBar.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);
    LStatusBar.SetSections(
      TArray<TDashboardSection>.Create(
        TDashboardSection.Make('Words',      LTopWords),
        TDashboardSection.Make('Attributes', LTopAttrs),
        TDashboardSection.Make('Patterns',   LPatterns),
        TDashboardSection.Make('Counts',     LCounts),
        TDashboardSection.Make('Logs',       LLogTable)
      )
    );

    // ---- Shared state captured by closures ----
    var LTickAcc := 0;
    var LPaused  := False;

    // ---- Timer: advance simulation every CTickIntervalMs ----
    LApp.OnTimer :=
      procedure(AElapsedMs: Integer)
      begin
        if LPaused then
          Exit;
        LTickAcc := LTickAcc + AElapsedMs;
        if LTickAcc < CTickIntervalMs then
          Exit;
        LTickAcc := 0;
        LModel.Tick;
        if LLogTable.AutoFollow then
          LLogTable.ScrollToBottom;
        LTopWords.Invalidate;
        LTopAttrs.Invalidate;
        LPatterns.Invalidate;
        LCounts.Invalidate;
        LLogTable.Invalidate;
      end;

    // ---- Global key handling ----
    LApp.OnKeyPress :=
      procedure(const AKey: TTuiKeyEvent)
      begin
        case AKey.Code of
          kcEscape:
            LApp.Quit;
          kcSpace:
          begin
            // Toggle simulation pause
            LPaused := not LPaused;
            LStatusBar.Paused := LPaused;
          end;
          kcChar:
            case UpCase(AKey.Character) of
              'Q': LApp.Quit;
              'T':
              begin
                if LApp.Theme.Background.R < 128 then
                  LApp.Theme := TTuiTheme.Light
                else
                  LApp.Theme := LCustomDark;
              end;
              'I':
              begin
                // Statistics overlay
                var LStats := TDashboardStatsView.Create(nil, LModel);
                LStats.OnClose := procedure
                  begin
                    LApp.PopModal;
                  end;
                LApp.PushModal(LStats);
              end;
              'H', '?':
              begin
                // Help overlay
                var LHelp := TDashboardHelpView.Create(nil);
                LHelp.OnClose := procedure
                  begin
                    LApp.PopModal;
                  end;
                LApp.PushModal(LHelp);
              end;
            end;
        end;
      end;

    // ---- Log entry detail on Enter ----
    LLogTable.OnActivate :=
      procedure(const AEntry: TLogEntry)
      begin
        var LDetail := TDashboardDetailView.Create(nil, AEntry);
        LDetail.OnClose := procedure
          begin
            LApp.PopModal;
          end;
        LApp.PushModal(LDetail);
      end;

    // ---- Initial scroll position ----
    LLogTable.ScrollToBottom;

    LApp.SetRoot(LRoot);
    LApp.Run;
  finally
    LApp.Free;
    LModel.Free;
  end;
end.
