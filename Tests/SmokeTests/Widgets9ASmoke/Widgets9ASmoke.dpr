/// <summary>
///   Widgets9ASmoke -- Smoke test Phase 9A: Navigation Widgets.
///
///   Verifies the requirements INPUT-04, INPUT-05, NAV-01, NAV-02:
///   - INPUT-04: TTuiRadioButton (single selection per group)
///   - INPUT-05: TTuiMenu (navigation, shortcuts, separators)
///   - NAV-01: TTuiTabs (header + active child, Left/Right navigation)
///   - NAV-02: TTuiSidebar (collapsible with Space/Enter)
///
///   Global keys:
///     Tab / Shift-Tab  -- cycle through focusable widgets
///     T                -- toggle Dark / Light theme
///     Q                -- quit
///
///   Layout:
///     LRoot (TTuiVStack)
///       LHeader (TTuiLabel)                             Fixed(1)
///       LMain (TTuiHStack)                              Fill(1)
///         LRadioBox (TTuiBox 'Radio Buttons')            Fixed(25)
///           LRadioStack (TTuiVStack)
///             [3 radios group 'color', 1 sep label, 2 radios group 'size']
///         LMenuBox (TTuiBox 'Menu')                      Fixed(24)
///           LMenu (TTuiMenu)
///         LRight (TTuiVStack)                            Fill(1)
///           LTabsBox (TTuiBox 'Tabs')                    Fixed(7)
///             LTabs (TTuiTabs)
///               [3 tabs with TTuiLabel]
///           LNavRow (TTuiHStack)                         Fill(1)
///             LSidebar (TTuiSidebar)                     Fixed auto
///               LNavLabel (TTuiLabel)
///             LContentBox (TTuiBox 'Main Area')           Fill(1)
///               LContent (TTuiLabel)
///       LFooter (TTuiLabel)                             Fixed(1)
/// </summary>
program Widgets9ASmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Input,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Geometry,
  Blinki.Core.Ansi,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Box,
  Blinki.Widgets.RadioButton,
  Blinki.Widgets.Menu,
  Blinki.Widgets.Tabs,
  Blinki.Widgets.Sidebar,
  Blinki.Layout.Stack;

var
  LApp: TTuiApp;
  LRoot: TTuiVStack;

  LHeader: TTuiLabel;
  LMain: TTuiHStack;
  LFooter: TTuiLabel;

  // Radio column
  LRadioBox: TTuiBox;
  LRadioStack: TTuiVStack;
  LRadioA: TTuiRadioButton;
  LRadioB: TTuiRadioButton;
  LRadioC: TTuiRadioButton;
  LRadioSep: TTuiLabel;
  LRadioX: TTuiRadioButton;
  LRadioY: TTuiRadioButton;

  // Menu column
  LMenuBox: TTuiBox;
  LMenu: TTuiMenu;

  // Right column
  LRight: TTuiVStack;

  // Tabs
  LTabsBox: TTuiBox;
  LTabs: TTuiTabs;
  LTab1: TTuiLabel;
  LTab2: TTuiLabel;
  LTab3: TTuiLabel;

  // Sidebar + content
  LNavRow: TTuiHStack;
  LSidebar: TTuiSidebar;
  LNavLabel: TTuiLabel;
  LContentBox: TTuiBox;
  LContent: TTuiLabel;

  LDark: Boolean;
  LStatus: string;

begin
  ReportMemoryLeaksOnShutdown := True;
  LDark   := True;
  LStatus := '...';

  LApp  := TTuiApp.Create;
  LRoot := TTuiVStack.Create;
  try
    // ---- Header ----
    LHeader      := TTuiLabel.Create(LRoot);
    LHeader.Text := ' Blinki Phase 9A -- Navigation Widgets | Tab=focus  T=theme  Q=quit';
    LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- Main row ----
    LMain := TTuiHStack.Create(LRoot);
    LMain.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // --- Radio column ---
    LRadioBox       := TTuiBox.Create(LMain);
    LRadioBox.Title := ' Radio ';
    LRadioBox.BoxStyle := bsRounded;
    LRadioBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(25);

    LRadioStack := TTuiVStack.Create(LRadioBox);

    LRadioA         := TTuiRadioButton.Create(LRadioStack);
    LRadioA.Caption := ' Red';
    LRadioA.Group   := 'color';
    LRadioA.Checked := True;
    LRadioA.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LRadioB         := TTuiRadioButton.Create(LRadioStack);
    LRadioB.Caption := ' Green';
    LRadioB.Group   := 'color';
    LRadioB.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LRadioC         := TTuiRadioButton.Create(LRadioStack);
    LRadioC.Caption := ' Blue';
    LRadioC.Group   := 'color';
    LRadioC.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LRadioSep      := TTuiLabel.Create(LRadioStack);
    LRadioSep.Text := ' ----';
    LRadioSep.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LRadioX         := TTuiRadioButton.Create(LRadioStack);
    LRadioX.Caption := ' Small';
    LRadioX.Group   := 'size';
    LRadioX.Checked := True;
    LRadioX.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LRadioY         := TTuiRadioButton.Create(LRadioStack);
    LRadioY.Caption := ' Large';
    LRadioY.Group   := 'size';
    LRadioY.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LRadioA.OnSelect := procedure begin LStatus := 'color=Red'; end;
    LRadioB.OnSelect := procedure begin LStatus := 'color=Green'; end;
    LRadioC.OnSelect := procedure begin LStatus := 'color=Blue'; end;
    LRadioX.OnSelect := procedure begin LStatus := 'size=Small'; end;
    LRadioY.OnSelect := procedure begin LStatus := 'size=Large'; end;

    // --- Menu column ---
    LMenuBox       := TTuiBox.Create(LMain);
    LMenuBox.Title := ' Menu ';
    LMenuBox.BoxStyle := bsRounded;
    LMenuBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(24);

    LMenu := TTuiMenu.Create(LMenuBox);
    LMenu.AddItem('New File',   'N');
    LMenu.AddItem('Open...',   'O');
    LMenu.AddItem('Save',      'S');
    LMenu.AddSeparator;
    LMenu.AddItem('Cut',       'X');
    LMenu.AddItem('Copy',      'C');
    LMenu.AddItem('Paste',     'V');
    LMenu.AddSeparator;
    LMenu.AddItem('Quit',      'Q');
    LMenu.OnSelect := procedure(AIdx: Integer) begin LStatus := 'menu:' + IntToStr(AIdx); end;

    // --- Right column ---
    LRight := TTuiVStack.Create(LMain);
    LRight.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // Tabs
    LTabsBox       := TTuiBox.Create(LRight);
    LTabsBox.Title := ' Tabs ';
    LTabsBox.BoxStyle := bsRounded;
    LTabsBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(7);

    LTabs := TTuiTabs.Create(LTabsBox);

    LTab1      := TTuiLabel.Create(nil);
    LTab1.Text := '  Content of tab Alpha  ';
    LTabs.AddTab('Alpha', LTab1);

    LTab2      := TTuiLabel.Create(nil);
    LTab2.Text := '  Content of tab Beta  ';
    LTabs.AddTab('Beta', LTab2);

    LTab3      := TTuiLabel.Create(nil);
    LTab3.Text := '  Content of tab Gamma  ';
    LTabs.AddTab('Gamma', LTab3);

    LTabs.OnChange := procedure(AIdx: Integer) begin LStatus := 'tab:' + IntToStr(AIdx); end;

    // Sidebar + content
    LNavRow := TTuiHStack.Create(LRight);
    LNavRow.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    LSidebar := TTuiSidebar.Create(LNavRow);
    LSidebar.ExpandedWidth  := 18;
    LSidebar.CollapsedWidth := 3;
    LSidebar.OnToggle := procedure(ACollapsed: Boolean)
      begin
        if ACollapsed then
          LStatus := 'sidebar: collapsed'
        else
          LStatus := 'sidebar: expanded';
      end;

    LNavLabel      := TTuiLabel.Create(LSidebar);
    LNavLabel.Text := ' Navigation panel ';

    LContentBox       := TTuiBox.Create(LNavRow);
    LContentBox.Title := ' Main Area ';
    LContentBox.BoxStyle := bsRounded;
    LContentBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    LContent      := TTuiLabel.Create(LContentBox);
    LContent.Text := ' Use Tab to cycle focus.  Space/Enter on Sidebar toggles collapse.';

    // ---- Footer ----
    LFooter := TTuiLabel.Create(LRoot);
    LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- App setup ----
    LApp.SetRoot(LRoot);

    LApp.OnTimer := procedure(AElapsed: Integer)
      begin
        LFooter.Text := Format(' Status: %s', [LStatus]);
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
