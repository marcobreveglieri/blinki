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
{   Unit:        TaskManager.dpr                                 }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TaskManagerDemo -- Showcase demo for Blinki: Windows-style Task Manager.
///
///   Demonstrates:
///   - TTuiTabs for multi-view layout (Processes / Performance)
///   - TTuiTable with live refresh, real-time text filter, and interactive sort
///   - TTuiTextInput as a live filter field (OnTextChanged)
///   - TTuiGauge (CPU, RAM) with dynamic colour thresholds and smooth animation
///   - TTuiSparkline for scrolling CPU/RAM trend history
///   - TTuiBarChart for per-core CPU load
///   - Summary labels with aggregate metrics (process count, threads, handles, uptime)
///   - Pause/resume of live updates (P key)
///   - Hot dark / light theme toggle
///
///   Keys (when filter field does NOT have focus):
///     Tab / Shift-Tab  -- cycle focus: filter → table → tabs → ...
///     ↑↓ PgUp PgDn     -- navigate table rows (Processes tab)
///     ←→ + S           -- change sort column / cycle direction (Processes tab)
///     P                -- pause / resume live updates
///     T                -- toggle Dark / Light theme
///     Q / Esc          -- quit
///
///   Note: when the filter field has focus, printable keys (including Q, P, T)
///   are consumed by the field. Press Tab to move focus before using shortcuts.
///
///   Widget tree:
///     LRoot (TTuiVStack)
///       LHeader (TTuiLabel)                            Fixed(1)
///       LTabs (TTuiTabs)                               Fill(1)
///         [0] Processes  LProcPage (TTuiVStack)
///               LFilterBox (TTuiBox " Filter ")        Fixed(3)  bsRounded
///                 LFilter (TTuiTextInput)
///               LTable (TTuiTable)                     Fill(1)
///                 columns: PID | Name | CPU% | Memory | Threads | Status
///         [1] Performance  LPerfPage (TTuiVStack)
///               LTopRow (TTuiHStack)                   Fill(2)
///                 LCpuBox (TTuiBox " CPU ")            Fill(1)
///                   LCpuCol (TTuiVStack)
///                     LCpuGauge (TTuiGauge)            Fixed(1)
///                     LCpuSpark (TTuiSparkline)        Fill(1)
///                     LLabelProcs, LLabelThreads,
///                     LLabelUptime (TTuiLabel x3)      Fixed(1) each
///                 LMemBox (TTuiBox " Memory ")         Fill(1)
///                   LMemCol (TTuiVStack)
///                     LMemGauge (TTuiGauge)            Fixed(1)
///                     LMemSpark (TTuiSparkline)        Fill(1)
///                     LLabelMemUsed, LLabelHandles
///                     (TTuiLabel x2)                   Fixed(1) each
///               LCoreBox (TTuiBox " CPU per core ")   Fill(1)
///                 LCoreChart (TTuiBarChart)
///       LFooter (TTuiLabel)                            Fixed(1)
/// </summary>
program TaskManager;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Geometry,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Box,
  Blinki.Widgets.Table,
  Blinki.Widgets.TextInput,
  Blinki.Widgets.Tabs,
  Blinki.Widgets.Gauge,
  Blinki.Widgets.Sparkline,
  Blinki.Widgets.BarChart,
  Blinki.Layout.Stack,
  TaskManager.Model in 'TaskManager.Model.pas',
  TaskManager.Helpers in 'TaskManager.Helpers.pas',
  TaskManager.Consts in 'TaskManager.Consts.pas';

// ============================================================================
// Main body
// ============================================================================

begin
  ReportMemoryLeaksOnShutdown := True;
  Randomize;

  var LDark := True;
  var LPaused := False;
  var LTickAcc := 0;

  var LModel := TTaskManagerModel.Create;
  try

    var LApp := TTuiApp.Create;
    var LRoot := TTuiVStack.Create;
    try

      // ---- header ----
      var LHeader := TTuiLabel.Create(LRoot);
      LHeader.Text := ' Blinki Task Manager';
      LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      // ---- tabs ----
      var LTabs := TTuiTabs.Create(LRoot);
      LTabs.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      // ================================================================
      // Tab 0: Processes
      // ================================================================
      var LProcPage := TTuiVStack.Create(LTabs);

      var LFilterBox := TTuiBox.Create(LProcPage);
      LFilterBox.Title := ' Filter ';
      LFilterBox.BoxStyle := bsRounded;
      LFilterBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(3);

      var LFilter := TTuiTextInput.Create(LFilterBox);
      LFilter.Placeholder := 'Filter by name...';
      LFilter.MaxLength := 80;

      var LTable := TTuiTable.Create(LProcPage);
      LTable.AddColumn('PID',     6,  taRight);
      LTable.AddColumn('Name',    0,  taLeft);
      LTable.AddColumn('CPU%',    7,  taRight);
      LTable.AddColumn('Memory', 10,  taRight);
      LTable.AddColumn('Threads', 7,  taRight);
      LTable.AddColumn('Status', 10,  taLeft);
      LTable.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      LTabs.AddTab(' Processes ', LProcPage);

      // ================================================================
      // Tab 1: Performance
      // ================================================================
      var LPerfPage := TTuiVStack.Create(LTabs);

      // Top row: CPU gauge+spark and RAM gauge+spark side by side
      var LTopRow := TTuiHStack.Create(LPerfPage);
      LTopRow.LayoutConstraint := TTuiLayoutConstraint.Fill(2);

      var LCpuBox := TTuiBox.Create(LTopRow);
      LCpuBox.Title := ' CPU ';
      LCpuBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      var LCpuCol := TTuiVStack.Create(LCpuBox);

      var LCpuGauge := TTuiGauge.Create(LCpuCol);
      LCpuGauge.ThresholdWarn := 0.6;
      LCpuGauge.ThresholdError := 0.85;
      LCpuGauge.Value := LModel.CpuTotal;
      LCpuGauge.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      var LCpuSpark := TTuiSparkline.Create(LCpuCol);
      LCpuSpark.MaxPoints := 60;
      LCpuSpark.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      var LLabelProcs := TTuiLabel.Create(LCpuCol);
      LLabelProcs.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      var LLabelThreads := TTuiLabel.Create(LCpuCol);
      LLabelThreads.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      var LLabelUptime := TTuiLabel.Create(LCpuCol);
      LLabelUptime.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      var LMemBox := TTuiBox.Create(LTopRow);
      LMemBox.Title := ' Memory ';
      LMemBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      var LMemCol := TTuiVStack.Create(LMemBox);

      var LMemGauge := TTuiGauge.Create(LMemCol);
      LMemGauge.ThresholdWarn := 0.5;
      LMemGauge.ThresholdError := 0.8;
      LMemGauge.Value := LModel.MemUsedFrac;
      LMemGauge.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      var LMemSpark := TTuiSparkline.Create(LMemCol);
      LMemSpark.MaxPoints := 60;
      LMemSpark.Color := TTuiColor.Standard(2);  // ANSI green
      LMemSpark.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      var LLabelMemUsed := TTuiLabel.Create(LMemCol);
      LLabelMemUsed.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      var LLabelHandles := TTuiLabel.Create(LMemCol);
      LLabelHandles.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      // Per-core bar chart
      var LCoreBox := TTuiBox.Create(LPerfPage);
      LCoreBox.Title := ' CPU per core ';
      LCoreBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      var LCoreChart := TTuiBarChart.Create(LCoreBox);
      LCoreChart.LayoutConstraint := TTuiLayoutConstraint.Fill(1);
      for var LCore := 0 to CCoreCount - 1 do
        LCoreChart.AddBar('C' + IntToStr(LCore), LModel.CoreLoads[LCore],
          TTuiColor.RGB(86, 156, 214));

      LTabs.AddTab(' Performance ', LPerfPage);

      // ---- footer ----
      var LFooter := TTuiLabel.Create(LRoot);
      LFooter.Text := CHintProcesses;
      LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      // ================================================================
      // Helper: refresh the summary labels from the current model state
      // ================================================================
      var LRefreshSummary: TProc := procedure
      begin
        LLabelProcs.Text   := Format(' Processes : %d', [LModel.Processes.Count]);
        LLabelThreads.Text := Format(' Threads   : %d', [LModel.TotalThreads]);
        LLabelUptime.Text  := ' Uptime    : ' + FormatUptime(LModel.UptimeMs);
        LLabelMemUsed.Text := Format(' Memory    : %.0f%%', [LModel.MemUsedFrac * 100.0]);
        LLabelHandles.Text := Format(' Handles   : %d', [LModel.HandleCount]);
      end;

      // ================================================================
      // Helper: refresh the process table from the model, honouring
      // the current filter text and re-applying sort/selection.
      // ================================================================
      var LRefreshTable: TProc := procedure
      begin
        var LSavedIndex := LTable.ItemIndex;
        var LSavedSortCol := LTable.SortColumn;
        var LSavedSortDir := LTable.SortDir;

        LTable.ClearRows;

        var LFilterText := LFilter.Text;
        for var LI := 0 to LModel.Processes.Count - 1 do
        begin
          var LP := LModel.Processes[LI];
          if (LFilterText <> '') and
             (Pos(LowerCase(LFilterText), LowerCase(LP.Name)) = 0) then
            Continue;
          LTable.AddRow([
            IntToStr(LP.Pid),
            LP.Name,
            FormatCpu(LP.Cpu),
            FormatMem(LP.MemMB),
            IntToStr(LP.Threads),
            StatusToText(LP.Status)
          ]);
        end;

        // Re-apply sort if one was active
        if (LSavedSortCol >= 0) and (LSavedSortDir <> sdNone) then
          LTable.Sort(LSavedSortCol, LSavedSortDir);

        // Restore selection; the ItemIndex setter clamps automatically
        LTable.ItemIndex := LSavedIndex;
      end;

      // ================================================================
      // Helper: rebuild the per-core bar chart from current model data
      // ================================================================
      var LRefreshCoreChart: TProc := procedure
      begin
        LCoreChart.Clear;
        for var LCore := 0 to CCoreCount - 1 do
          LCoreChart.AddBar('C' + IntToStr(LCore),
            LModel.CoreLoads[LCore],
            TTuiColor.RGB(86, 156, 214));
      end;

      // ---- initial population ----
      LRefreshTable();
      LRefreshSummary();

      // ================================================================
      // Event: filter text changes → refresh table immediately
      // ================================================================
      LFilter.OnTextChanged := procedure(AText: string)
      begin
        LRefreshTable();
      end;

      // ================================================================
      // Event: tab change → update footer hint
      // ================================================================
      LTabs.OnChange := procedure(AIdx: Integer)
      begin
        if AIdx = 0 then
          LFooter.Text := CHintProcesses
        else
          LFooter.Text := CHintPerf;
      end;

      // ================================================================
      // Timer: advance simulation and refresh all live widgets
      // ================================================================
      LApp.OnTimer := procedure(AElapsedMs: Integer)
      begin
        Inc(LTickAcc, AElapsedMs);
        if LTickAcc < 500 then
          Exit;
        LTickAcc := LTickAcc - 500;

        if not LPaused then
        begin
          LModel.Update(500);

          // Performance tab widgets
          LCpuGauge.Value := LModel.CpuTotal;
          LMemGauge.Value := LModel.MemUsedFrac;
          LCpuSpark.AddPoint(LModel.CpuTotal);
          LMemSpark.AddPoint(LModel.MemUsedFrac);
          LRefreshCoreChart();
          LRefreshSummary();

          // Process table
          LRefreshTable();
        end
        else
        begin
          // Simulation is paused: only refresh the summary display
          LRefreshSummary();
        end;
      end;

      // ================================================================
      // Global key handler
      // ================================================================
      LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        if AKey.Code = kcEscape then
        begin
          LApp.Quit;
          Exit;
        end;
        if AKey.Code <> kcChar then
          Exit;
        case UpCase(AKey.Character) of
          'Q':
            LApp.Quit;
          'T':
          begin
            LDark := not LDark;
            if LDark then
              LApp.Theme := TTuiTheme.Dark
            else
              LApp.Theme := TTuiTheme.Light;
          end;
          'P':
          begin
            LPaused := not LPaused;
            if LPaused then
              LHeader.Text := ' Blinki Task Manager' + CHintPaused
            else
              LHeader.Text := ' Blinki Task Manager';
          end;
        end;
      end;

      // ---- launch ----
      LApp.SetRoot(LRoot);
      LApp.Run;

    finally
      LApp.Free;
    end;

  finally
    LModel.Free;
  end;
end.
