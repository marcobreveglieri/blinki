/// <summary>
///   DashboardSmoke — Dashboard smoke test for Blinki Phase 8: Advanced Display Widgets.
///
///   Verifies the success criteria DISP-02, DISP-03, DISP-04:
///   - DISP-02: TTuiBarChart with 5 bars and distinct colors, Y axis, labels
///   - DISP-03: TTuiSparkline for CPU/MEM/NET updated live from OnTimer
///   - DISP-04: TTuiGauge with dynamic color Success/Warning/Error and animation
///
///   Keys:
///     T     -- toggle Dark / Light theme
///     Q     -- quit
///     Ctrl-C -- quit with guaranteed cleanup
///
///   Widget tree:
///     LRoot (TTuiVStack)
///       LHeader (TTuiLabel)                        Fixed(1)
///       LBodyBox (TTuiBox "Dashboard demo")         Fill(1)
///         LBody (TTuiHStack)
///           LLeftCol (TTuiVStack) Fill(1) -- sparkline
///             LCpuLabel (TTuiLabel)                Fixed(1)
///             LCpuSpark (TTuiSparkline)             Fixed(1)
///             LMemLabel (TTuiLabel)                Fixed(1)
///             LMemSpark (TTuiSparkline)             Fixed(1)
///             LNetLabel (TTuiLabel)                Fixed(1)
///             LNetSpark (TTuiSparkline)             Fixed(1)
///           LMidCol (TTuiVStack) Fill(2) -- bar chart
///             LChart (TTuiBarChart)                Fill(1)
///           LRightCol (TTuiVStack) Fill(1) -- gauge
///             LCpuPctLabel (TTuiLabel)             Fixed(1)
///             LCpuGauge (TTuiGauge)                Fixed(1)
///             LMemPctLabel (TTuiLabel)             Fixed(1)
///             LMemGauge (TTuiGauge)                Fixed(1)
///             LDskPctLabel (TTuiLabel)             Fixed(1)
///             LDskGauge (TTuiGauge)                Fixed(1)
///       LFooter (TTuiLabel)                        Fixed(1)
/// </summary>
program DashboardSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Input,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Geometry,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Box,
  Blinki.Widgets.Sparkline,
  Blinki.Widgets.BarChart,
  Blinki.Widgets.Gauge,
  Blinki.Layout.Stack;

var
  LApp: TTuiApp;
  LRoot: TTuiVStack;

  LHeader: TTuiLabel;
  LBodyBox: TTuiBox;
  LBody: TTuiHStack;

  LLeftCol: TTuiVStack;
  LCpuLabel: TTuiLabel;
  LCpuSpark: TTuiSparkline;
  LMemLabel: TTuiLabel;
  LMemSpark: TTuiSparkline;
  LNetLabel: TTuiLabel;
  LNetSpark: TTuiSparkline;

  LMidCol: TTuiVStack;
  LChart: TTuiBarChart;

  LRightCol: TTuiVStack;
  LCpuPctLabel: TTuiLabel;
  LCpuGauge: TTuiGauge;
  LMemPctLabel: TTuiLabel;
  LMemGauge: TTuiGauge;
  LDskPctLabel: TTuiLabel;
  LDskGauge: TTuiGauge;

  LFooter: TTuiLabel;

  LDark: Boolean;
  LTickAcc: Integer;
  LCpuVal: Double;
  LMemVal: Double;
  LNetVal: Double;
  LDskVal: Double;
  LTick: Int64;

function RandomWalk(ACurrent: Double; AStep: Double): Double;
begin
  Result := ACurrent + (Random(201) - 100) / 100.0 * AStep;
  if Result < 0 then Result := 0;
  if Result > 1 then Result := 1;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  Randomize;

  LDark     := True;
  LTickAcc  := 0;
  LTick     := 0;
  LCpuVal   := 0.3;
  LMemVal   := 0.5;
  LNetVal   := 0.1;
  LDskVal   := 0.65;

  LApp  := TTuiApp.Create;
  LRoot := TTuiVStack.Create;
  try
    // Header
    LHeader      := TTuiLabel.Create(LRoot);
    LHeader.Text := ' Blinki Phase 8 -- Dashboard | T=theme  Q=quit';
    LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // Body box
    LBodyBox       := TTuiBox.Create(LRoot);
    LBodyBox.Title := ' Dashboard demo ';
    LBodyBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    LBody := TTuiHStack.Create(LBodyBox);

    // Left column: sparkline
    LLeftCol := TTuiVStack.Create(LBody);
    LLeftCol.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    LCpuLabel      := TTuiLabel.Create(LLeftCol);
    LCpuLabel.Text := ' CPU';
    LCpuLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LCpuSpark := TTuiSparkline.Create(LLeftCol);
    LCpuSpark.MaxPoints := 60;
    LCpuSpark.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LMemLabel      := TTuiLabel.Create(LLeftCol);
    LMemLabel.Text := ' MEM';
    LMemLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LMemSpark := TTuiSparkline.Create(LLeftCol);
    LMemSpark.MaxPoints := 60;
    LMemSpark.Color     := TTuiColor.Standard(2);  // ANSI green
    LMemSpark.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LNetLabel      := TTuiLabel.Create(LLeftCol);
    LNetLabel.Text := ' NET';
    LNetLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LNetSpark := TTuiSparkline.Create(LLeftCol);
    LNetSpark.MaxPoints := 60;
    LNetSpark.Color     := TTuiColor.Standard(3);  // ANSI yellow
    LNetSpark.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // Center column: bar chart
    LMidCol := TTuiVStack.Create(LBody);
    LMidCol.LayoutConstraint := TTuiLayoutConstraint.Fill(2);

    LChart       := TTuiBarChart.Create(LMidCol);
    LChart.Title := 'Quarterly';
    LChart.LayoutConstraint := TTuiLayoutConstraint.Fill(1);
    LChart.AddBar('Q1', 0.42 + Random(30) / 100.0, TTuiColor.RGB(70, 130, 180));
    LChart.AddBar('Q2', 0.60 + Random(25) / 100.0, TTuiColor.RGB(60, 179, 113));
    LChart.AddBar('Q3', 0.35 + Random(40) / 100.0, TTuiColor.RGB(255, 165, 0));
    LChart.AddBar('Q4', 0.75 + Random(20) / 100.0, TTuiColor.RGB(220, 20, 60));
    LChart.AddBar('FY', 0.55 + Random(30) / 100.0, TTuiColor.RGB(148, 0, 211));

    // Right column: gauge
    LRightCol := TTuiVStack.Create(LBody);
    LRightCol.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    LCpuPctLabel      := TTuiLabel.Create(LRightCol);
    LCpuPctLabel.Text := ' CPU%';
    LCpuPctLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LCpuGauge := TTuiGauge.Create(LRightCol);
    LCpuGauge.ThresholdWarn  := 0.6;
    LCpuGauge.ThresholdError := 0.85;
    LCpuGauge.Value          := LCpuVal;
    LCpuGauge.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LMemPctLabel      := TTuiLabel.Create(LRightCol);
    LMemPctLabel.Text := ' MEM%';
    LMemPctLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LMemGauge := TTuiGauge.Create(LRightCol);
    LMemGauge.ThresholdWarn  := 0.5;
    LMemGauge.ThresholdError := 0.8;
    LMemGauge.Value          := LMemVal;
    LMemGauge.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LDskPctLabel      := TTuiLabel.Create(LRightCol);
    LDskPctLabel.Text := ' DSK%';
    LDskPctLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LDskGauge := TTuiGauge.Create(LRightCol);
    LDskGauge.ThresholdWarn  := 0.7;
    LDskGauge.ThresholdError := 0.9;
    LDskGauge.Value          := LDskVal;
    LDskGauge.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // Footer
    LFooter := TTuiLabel.Create(LRoot);
    LFooter.Text := ' Tick: 0';
    LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // App setup
    LApp.SetRoot(LRoot);

    LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'Q') then
          LApp.Quit
        else if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'T') then
        begin
          LDark := not LDark;
          if LDark then LApp.Theme := TTuiTheme.Dark
          else           LApp.Theme := TTuiTheme.Light;
        end;
      end;

    LApp.OnTimer := procedure(AElapsedMs: Integer)
      begin
        Inc(LTick);
        Inc(LTickAcc, AElapsedMs);
        // Update every ~200ms (about 4 ticks at 50ms)
        if LTickAcc >= 200 then
        begin
          LTickAcc := LTickAcc - 200;

          LCpuVal := RandomWalk(LCpuVal, 0.08);
          LMemVal := RandomWalk(LMemVal, 0.04);
          LNetVal := RandomWalk(LNetVal, 0.12);
          LDskVal := RandomWalk(LDskVal, 0.02);

          LCpuSpark.AddPoint(LCpuVal);
          LMemSpark.AddPoint(LMemVal);
          LNetSpark.AddPoint(LNetVal);

          LCpuGauge.Value := LCpuVal;
          LMemGauge.Value := LMemVal;
          LDskGauge.Value := LDskVal;

          LFooter.Text := Format(' Tick: %d', [LTick]);
        end;
      end;

    LApp.Run;

  finally
    LApp.Free;
  end;
end.
