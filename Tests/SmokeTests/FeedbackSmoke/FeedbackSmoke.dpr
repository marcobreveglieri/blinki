/// <summary>
///   FeedbackSmoke — Interactive smoke test for Blinki Phase 6: Theme System and Feedback Widgets.
///
///   Verifies the success criteria THEME-01, THEME-02, CANVAS-04, FEED-01..FEED-05:
///   - THEME-01/02: runtime Dark/Light theme switch with the T key (without recreating widgets)
///   - CANVAS-04: TTuiBox decorator with Rounded border and title
///   - FEED-01: TTuiSpinner animated (Dots style) via Tick
///   - FEED-02: TTuiProgressBar that advances over 5s and restarts
///   - FEED-03: TTuiBadge inline colored (Info/Success/Warning)
///   - FEED-04: TTuiAlert with dismiss via ESC
///   - FEED-05: TTuiToast with auto-dismiss after 3s, triggered by N
///
///   Keys:
///     T     — toggle Dark / Light theme
///     N     — show a success TTuiToast
///     ESC   — closes the Info alert (if visible and focused)
///     Q     — quit
///     Ctrl-C — quit with guaranteed cleanup
///
///   Widget tree:
///     LRoot (TTuiVStack)
///       LOuterBox (TTuiBox bsRounded) Fill(1)
///         LInner (TTuiVStack)
///           LStatusLabel (TTuiLabel)         Fixed(1)
///           LSpinner (TTuiSpinner)            Fixed(1)
///           LProgress (TTuiProgressBar)       Fixed(1)
///           LBadgeRow (TTuiHStack)            Fixed(1)
///             LBadgeInfo, LBadgeOk, LBadgeWarn (TTuiBadge)
///           LAlertInfo (TTuiAlert alInfo)     Fixed(3)
///           LAlertOk   (TTuiAlert alSuccess)  Fixed(3)
///       LToast (TTuiToast)                    Fixed(3)
/// </summary>
program FeedbackSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Ansi,
  Blinki.Core.Style,
  Blinki.Core.Input,
  Blinki.Core.Canvas,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Geometry,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Box,
  Blinki.Widgets.Spinner,
  Blinki.Widgets.ProgressBar,
  Blinki.Widgets.Badge,
  Blinki.Widgets.Alert,
  Blinki.Widgets.Toast,
  Blinki.Layout.Stack;

var
  LApp: TTuiApp;
  LRoot: TTuiVStack;

  LOuterBox: TTuiBox;
  LInner: TTuiVStack;

  LStatusLabel: TTuiLabel;
  LSpinner: TTuiSpinner;
  LProgress: TTuiProgressBar;
  LBadgeRow: TTuiHStack;
  LBadgeInfo: TTuiBadge;
  LBadgeOk: TTuiBadge;
  LBadgeWarn: TTuiBadge;
  LAlertInfo: TTuiAlert;
  LAlertOk: TTuiAlert;

  LToast: TTuiToast;

  LDark: Boolean;
  LProgressMs: Int64;

begin
  ReportMemoryLeaksOnShutdown := True;
  LDark       := True;
  LProgressMs := 0;

  LApp  := TTuiApp.Create;
  LRoot := TTuiVStack.Create;
  try
    // ---- Outer box (occupies everything except the last toast row) ----
    LOuterBox           := TTuiBox.Create(LRoot);
    LOuterBox.Title     := ' Blinki Phase 6 — Feedback & Theme ';
    LOuterBox.BoxStyle  := bsRounded;
    LOuterBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // Inner VStack
    LInner := TTuiVStack.Create(LOuterBox);

    // Status line
    LStatusLabel       := TTuiLabel.Create(LInner);
    LStatusLabel.Text  := ' Theme: Dark  |  T=switch theme  N=toast  ESC=dismiss alert  Q=quit';
    LStatusLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // Spinner
    LSpinner              := TTuiSpinner.Create(LInner);
    LSpinner.SpinnerLabel := 'Loading...';
    LSpinner.Style        := ssDots;
    LSpinner.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ProgressBar
    LProgress             := TTuiProgressBar.Create(LInner);
    LProgress.Value       := 0.0;
    LProgress.ShowPercentage := True;
    LProgress.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // Badge row
    LBadgeRow := TTuiHStack.Create(LInner);
    LBadgeRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LBadgeInfo       := TTuiBadge.Create(LBadgeRow);
    LBadgeInfo.Text  := 'v1.0.0';
    LBadgeInfo.Kind  := bkInfo;
    LBadgeInfo.LayoutConstraint := TTuiLayoutConstraint.Fixed(8);

    LBadgeOk       := TTuiBadge.Create(LBadgeRow);
    LBadgeOk.Text  := 'stable';
    LBadgeOk.Kind  := bkSuccess;
    LBadgeOk.LayoutConstraint := TTuiLayoutConstraint.Fixed(9);

    LBadgeWarn       := TTuiBadge.Create(LBadgeRow);
    LBadgeWarn.Text  := 'prod';
    LBadgeWarn.Kind  := bkWarning;
    LBadgeWarn.LayoutConstraint := TTuiLayoutConstraint.Fixed(7);

    // Alert Info
    LAlertInfo       := TTuiAlert.Create(LInner);
    LAlertInfo.Level := alInfo;
    LAlertInfo.Text  := 'Press T to switch theme between Dark and Light.';
    LAlertInfo.LayoutConstraint := TTuiLayoutConstraint.Fixed(3);

    // Alert Success
    LAlertOk       := TTuiAlert.Create(LInner);
    LAlertOk.Level := alSuccess;
    LAlertOk.Text  := 'Operation completed successfully.';
    LAlertOk.LayoutConstraint := TTuiLayoutConstraint.Fixed(3);

    // Toast (in fondo al root, fuori dal box)
    LToast             := TTuiToast.Create(LRoot);
    LToast.DurationMs  := 3000;
    LToast.LayoutConstraint := TTuiLayoutConstraint.Fixed(3);

    // ---- App setup ----
    LApp.SetRoot(LRoot);

    LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'Q') then
          LApp.Quit
        else if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'T') then
        begin
          LDark := not LDark;
          if LDark then
          begin
            LApp.Theme := TTuiTheme.Dark;
            LStatusLabel.Text := ' Theme: Dark  |  T=switch theme  N=toast  ESC=dismiss alert  Q=quit';
          end
          else
          begin
            LApp.Theme := TTuiTheme.Light;
            LStatusLabel.Text := ' Theme: Light  |  T=switch theme  N=toast  ESC=dismiss alert  Q=quit';
          end;
        end
        else if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'N') then
          LToast.Show('Notification sent successfully!', alSuccess)
        else if AKey.Code = kcEscape then
        begin
          if LAlertInfo.Visible then
            LAlertInfo.Visible := False;
        end;
      end;

    LApp.OnTimer := procedure(AElapsedMs: Integer)
      begin
        Inc(LProgressMs, AElapsedMs);
        // Cycle from 0 to 1 in 5 seconds, then restart
        LProgress.Value := (LProgressMs mod 5000) / 5000.0;
      end;

    LApp.Run;

  finally
    LApp.Free;
  end;
end.
