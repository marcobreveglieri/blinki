/// <summary>
///   TableSmoke -- Smoke test standalone per Blinki Phase 8: TTuiTable.
///
///   Verifica il success criterion DISP-01:
///   - TTuiTable con 4 colonne ("PID" Right, "Name" Left, "CPU%" Right, "Mem MB" Right)
///   - 50 rows of synthetic data (simulated processes)
///   - Arrow / Home / End / PgUp / PgDn navigation
///   - Interactive sort: Left/Right selects column, S cycles sort (none->asc->desc->none)
///   - OnSelectionChanged updates the footer; OnRowActivated signals Enter
///
///   Keys:
///     Up/Down/Home/End/PgUp/PgDn -- navigate rows
///     Left/Right                 -- change sort column (header cursor)
///     S                          -- cycle sort on the selected column
///     T                          -- toggle Dark / Light theme
///     Q                          -- quit
///     Ctrl-C                     -- quit with guaranteed cleanup
///
///   Widget tree:
///     LRoot (TTuiVStack)
///       LHeader (TTuiLabel)     Fixed(1)
///       LTable (TTuiTable)      Fill(1)
///       LFooter (TTuiLabel)     Fixed(1)
/// </summary>
program TableSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Input,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Geometry,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Table,
  Blinki.Layout.Stack;

const
  CProcessNames: array[0..19] of string = (
    'svchost.exe', 'chrome.exe', 'delphi32.exe', 'explorer.exe', 'notepad.exe',
    'code.exe', 'slack.exe', 'teams.exe', 'outlook.exe', 'firefox.exe',
    'conhost.exe', 'csrss.exe', 'lsass.exe', 'winlogon.exe', 'dwm.exe',
    'taskmgr.exe', 'msedge.exe', 'wsl.exe', 'git.exe', 'nvcontainer.exe'
  );

var
  LApp: TTuiApp;
  LRoot: TTuiVStack;
  LHeader: TTuiLabel;
  LTable: TTuiTable;
  LFooter: TTuiLabel;

  LDark: Boolean;
  LI: Integer;
  LPID: Integer;
  LCpu: Double;
  LMem: Integer;

begin
  ReportMemoryLeaksOnShutdown := True;
  Randomize;

  LDark := True;

  LApp  := TTuiApp.Create;
  LRoot := TTuiVStack.Create;
  try
    LHeader      := TTuiLabel.Create(LRoot);
    LHeader.Text := ' Blinki Phase 8 -- Table | Up/Dn=navigate  Lt/Rt=col  S=sort  T=theme  Q=quit';
    LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LTable := TTuiTable.Create(LRoot);
    LTable.AddColumn('PID',    5,  taRight);
    LTable.AddColumn('Name',   0,  taLeft);
    LTable.AddColumn('CPU%',   6,  taRight);
    LTable.AddColumn('Mem MB', 8,  taRight);
    LTable.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // 50 synthetic rows
    LPID := 1000;
    for LI := 0 to 49 do
    begin
      Inc(LPID, 4 + Random(200));
      LCpu := Random(1000) / 10.0;
      LMem := 10 + Random(2000);
      LTable.AddRow([
        IntToStr(LPID),
        CProcessNames[LI mod Length(CProcessNames)],
        FormatFloat('0.0', LCpu) + '%',
        IntToStr(LMem)
      ]);
    end;

    LFooter      := TTuiLabel.Create(LRoot);
    LFooter.Text := ' Select a row...';
    LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LTable.OnSelectionChanged := procedure(AIndex: Integer)
      begin
        LFooter.Text := Format(' Row %d | Sort: col=%d dir=%d',
          [AIndex, LTable.SortColumn, Ord(LTable.SortDir)]);
      end;

    LTable.OnRowActivated := procedure(AIndex: Integer)
      begin
        LFooter.Text := Format(' *** Activated row %d ***', [AIndex]);
      end;

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

    LApp.Run;

  finally
    LApp.Free;
  end;
end.
