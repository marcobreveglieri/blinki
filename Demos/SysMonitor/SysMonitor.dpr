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
{   Unit:        SysMonitor.dpr                                  }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   SysMonitor -- Sample app SAMPLE-01: Dashboard htop-style.
///
///   Shows CPU%, memory, and process list updated in real-time every 500ms.
///   Verifies: layout engine + widget display (Gauge, Sparkline, BarChart, Table).
///
///   Keys:
///     Tab / Shift-Tab  -- cycle through focusable widgets (process table)
///     T                -- toggle Dark / Light theme
///     Q                -- quit
///
///   Layout:
///     LRoot (TTuiVStack)
///       LHeader (TTuiLabel)                                     Fixed(1)
///       LBody (TTuiHStack)                                       Fill(1)
///         LSystemBox (TTuiBox 'System')                          Fixed(28)
///           LSystemStack (TTuiVStack)
///             LCpuGauge (TTuiGauge)                              Fill(1)
///             LMemGauge (TTuiGauge)                              Fill(1)
///             LCpuSparkline (TTuiSparkline)                      Fixed(4)
///             LMemSparkline (TTuiSparkline)                      Fixed(4)
///         LProcessBox (TTuiBox 'Processes')                      Fill(2)
///           LProcessTable (TTuiTable)
///         LTopBox (TTuiBox 'Top by Memory')                      Fixed(30)
///           LTopChart (TTuiBarChart)
///       LFooter (TTuiLabel)                                     Fixed(1)
/// </summary>
program SysMonitor;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  System.Math,
  Blinki.Core.Input,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Geometry,
  Blinki.Core.Ansi,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Box,
  Blinki.Widgets.Gauge,
  Blinki.Widgets.Sparkline,
  Blinki.Widgets.BarChart,
  Blinki.Widgets.Table,
  Blinki.Layout.Stack,
  SysMonitor.SystemInfo;

var
  LApp: TTuiApp;
  LRoot: TTuiVStack;
  LHeader: TTuiLabel;
  LFooter: TTuiLabel;
  LBody: TTuiHStack;

  LSystemBox: TTuiBox;
  LSystemStack: TTuiVStack;
  LCpuLabel: TTuiLabel;
  LCpuGauge: TTuiGauge;
  LMemLabel: TTuiLabel;
  LMemGauge: TTuiGauge;
  LSparkLabel: TTuiLabel;
  LCpuSpark: TTuiSparkline;
  LMemSpark: TTuiSparkline;

  LProcBox: TTuiBox;
  LProcTable: TTuiTable;

  LTopBox: TTuiBox;
  LTopChart: TTuiBarChart;

  LDark: Boolean;
  LAccumMs: Integer;
  LCpuPct: Double;
  LMemInfo: TMemorySnapshot;
  LProcs: TArray<TProcessInfo>;
  LRow: TArray<string>;

begin
  ReportMemoryLeaksOnShutdown := True;
  Randomize;
  LDark := True;
  LAccumMs := 0;

  LApp := TTuiApp.Create;
  LRoot := TTuiVStack.Create;
  try
    LHeader := TTuiLabel.Create(LRoot);
    LHeader.Text := ' Blinki Dashboard -- htop-style | Tab=focus  T=theme  Q=quit';
    LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LBody := TTuiHStack.Create(LRoot);
    LBody.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // ---- System column ----
    LSystemBox := TTuiBox.Create(LBody);
    LSystemBox.Title := ' System ';
    LSystemBox.BoxStyle := bsRounded;
    LSystemBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(28);

    LSystemStack := TTuiVStack.Create(LSystemBox);

    LCpuLabel := TTuiLabel.Create(LSystemStack);
    LCpuLabel.Text := ' CPU';
    LCpuLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LCpuGauge := TTuiGauge.Create(LSystemStack);
    LCpuGauge.Animated := True;
    LCpuGauge.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LMemLabel := TTuiLabel.Create(LSystemStack);
    LMemLabel.Text := ' Memory';
    LMemLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LMemGauge := TTuiGauge.Create(LSystemStack);
    LMemGauge.Animated := True;
    LMemGauge.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LSparkLabel := TTuiLabel.Create(LSystemStack);
    LSparkLabel.Text := ' CPU history';
    LSparkLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LCpuSpark := TTuiSparkline.Create(LSystemStack);
    LCpuSpark.MaxPoints := 60;
    LCpuSpark.LayoutConstraint := TTuiLayoutConstraint.Fixed(2);

    LMemSpark := TTuiSparkline.Create(LSystemStack);
    LMemSpark.MaxPoints := 60;
    LMemSpark.LayoutConstraint := TTuiLayoutConstraint.Fixed(2);

    // ---- Processes column ----
    LProcBox := TTuiBox.Create(LBody);
    LProcBox.Title := ' Processes ';
    LProcBox.BoxStyle := bsRounded;
    LProcBox.LayoutConstraint := TTuiLayoutConstraint.Fill(2);

    LProcTable := TTuiTable.Create(LProcBox);
    LProcTable.ShowHeader := True;
    LProcTable.ShowBorder := False;
    LProcTable.AddColumn('PID', 6, taRight);
    LProcTable.AddColumn('Name', 20, taLeft);
    LProcTable.AddColumn('Mem (MB)', 10, taRight);

    // ---- Top memory chart column ----
    LTopBox := TTuiBox.Create(LBody);
    LTopBox.Title := ' Top by Memory ';
    LTopBox.BoxStyle := bsRounded;
    LTopBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(30);

    LTopChart := TTuiBarChart.Create(LTopBox);
    LTopChart.Title := '';
    LTopChart.ShowYAxis := True;
    LTopChart.ShowLabels := True;

    // Footer
    LFooter := TTuiLabel.Create(LRoot);
    LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- App setup ----
    LApp.SetRoot(LRoot);

    LApp.OnTimer := procedure(AElapsedMs: Integer)
      begin
        Inc(LAccumMs, AElapsedMs);
        if LAccumMs < 500 then
          Exit;
        LAccumMs := LAccumMs mod 500;

        // CPU
        LCpuPct := GetCpuPercent;
        var LNorm := LCpuPct / 100.0;
        LCpuGauge.Value := LNorm;
        LCpuSpark.AddPoint(LNorm);

        // Memory
        LMemInfo := GetMemoryUsage;
        LNorm := LMemInfo.UsedPercent / 100.0;
        LMemGauge.Value := LNorm;
        LMemSpark.AddPoint(LNorm);

        LFooter.Text := Format(' CPU: %.1f%%  Mem: %d/%d MB  Processes: %d',
          [LCpuPct,
           LMemInfo.Used div (1024*1024),
           LMemInfo.Total div (1024*1024),
           Length(LProcs)]);

        // Processes
        LProcs := GetProcessList(30);
        LProcTable.ClearRows;
        for var LI: Integer := 0 to High(LProcs) do
        begin
          var LMB := LProcs[LI].WorkingSet / (1024*1024);
          LRow := TArray<string>.Create(
            IntToStr(LProcs[LI].PID),
            LProcs[LI].Name,
            Format('%.1f', [LMB]));
          LProcTable.AddRow(LRow);
        end;

        // BarChart top 8
        LTopChart.Clear;
        for var LI: Integer := 0 to Min(8, Length(LProcs)) - 1 do
        begin
          var LMbBar := LProcs[LI].WorkingSet / (1024*1024);
          // Green < 200MB, yellow < 500MB, red >= 500MB
          var LColor: TTuiColor;
          if LMbBar < 200 then
            LColor := TTuiColor.RGB(64, 200, 64)
          else if LMbBar < 500 then
            LColor := TTuiColor.RGB(200, 200, 64)
          else
            LColor := TTuiColor.RGB(200, 64, 64);
          LTopChart.AddBar(Copy(ChangeFileExt(LProcs[LI].Name, ''), 1, 6), LMbBar, LColor);
        end;
      end;

    LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'Q') then
          LApp.Quit
        else if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'T') then
        begin
          LDark := not LDark;
          if LDark then
            LApp.Theme := TTuiTheme.Dark
          else
            LApp.Theme := TTuiTheme.Light;
        end;
      end;

    LApp.Run;

  finally
    LApp.Free;
  end;
end.
