/// <summary>
///   InteractiveSmoke — Interactive smoke test for Blinki Phase 7: Interactive Widgets.
///
///   Verifies the success criteria INTER-01..INTER-04:
///   - INTER-01: TTuiTextInput with Placeholder, PasswordChar, MaxLength, OnSubmit
///   - INTER-02: TTuiButton with OnClick, Normal/Focused style
///   - INTER-03: TTuiCheckbox with Space/Enter toggle and OnToggle callback
///   - INTER-04: TTuiSelect visible list with arrows/Home/End/PgUp/PgDn navigation
///
///   Keys:
///     Tab / Shift-Tab  -- cycle through the focusable widgets
///     T                -- toggle Dark / Light theme
///     Q                -- quit
///     Ctrl-C           -- quit with guaranteed cleanup
///
///   Widget tree:
///     LRoot (TTuiVStack)
///       LTitle (TTuiLabel)                     Fixed(1)
///       LFormBox (TTuiBox "Form")               Fill(1)
///         LFormInner (TTuiVStack)
///           LUserRow (TTuiHStack)               Fixed(1)
///             LUserLabel (TTuiLabel)             Fixed(12)
///             LUserInput (TTuiTextInput)         Fill(1)
///           LPassRow (TTuiHStack)               Fixed(1)
///             LPassLabel (TTuiLabel)             Fixed(12)
///             LPassInput (TTuiTextInput)         Fill(1)  PasswordChar='*' MaxLen=12
///           LCheck (TTuiCheckbox)               Fixed(1)
///           LPlanRow (TTuiHStack)               Fixed(5)
///             LPlanLabel (TTuiLabel)             Fixed(12)
///             LPlanSelect (TTuiSelect)           Fill(1)
///           LBtnRow (TTuiHStack)                Fixed(1)
///             LBtnSubmit (TTuiButton)            Fill(1)
///             LBtnCancel (TTuiButton)            Fill(1)
///       LStateBox (TTuiBox "Live state")        Fixed(3)
///         LStateLabel (TTuiLabel)               Fill(1)
/// </summary>
program InteractiveSmoke;

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
  Blinki.Widgets.Box,
  Blinki.Widgets.TextInput,
  Blinki.Widgets.Button,
  Blinki.Widgets.Checkbox,
  Blinki.Widgets.Select,
  Blinki.Layout.Stack;

var
  LApp: TTuiApp;
  LRoot: TTuiVStack;

  LTitle: TTuiLabel;

  LFormBox: TTuiBox;
  LFormInner: TTuiVStack;

  LUserRow: TTuiHStack;
  LUserLabel: TTuiLabel;
  LUserInput: TTuiTextInput;

  LPassRow: TTuiHStack;
  LPassLabel: TTuiLabel;
  LPassInput: TTuiTextInput;

  LCheck: TTuiCheckbox;

  LPlanRow: TTuiHStack;
  LPlanLabel: TTuiLabel;
  LPlanSelect: TTuiSelect;

  LBtnRow: TTuiHStack;
  LBtnSubmit: TTuiButton;
  LBtnCancel: TTuiButton;

  LStateBox: TTuiBox;
  LStateLabel: TTuiLabel;

  LDark: Boolean;
  LUsername: string;
  LPwdLen: Integer;
  LAccepted: Boolean;
  LPlanText: string;
  LLastAction: string;
  LUpdate: TProc;

begin
  ReportMemoryLeaksOnShutdown := True;

  LDark       := True;
  LUsername   := '';
  LPwdLen     := 0;
  LAccepted   := False;
  LPlanText   := 'Free';
  LLastAction := '(none)';

  LApp  := TTuiApp.Create;
  LRoot := TTuiVStack.Create;
  try
    // ---- Title ----
    LTitle      := TTuiLabel.Create(LRoot);
    LTitle.Text := ' Blinki Phase 7 -- Interactive Widgets | Tab=focus  T=theme  Q=quit';
    LTitle.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- Form box ----
    LFormBox       := TTuiBox.Create(LRoot);
    LFormBox.Title := ' Form ';
    LFormBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    LFormInner := TTuiVStack.Create(LFormBox);

    // Username row
    LUserRow := TTuiHStack.Create(LFormInner);
    LUserRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LUserLabel      := TTuiLabel.Create(LUserRow);
    LUserLabel.Text := ' Username:  ';
    LUserLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(12);

    LUserInput             := TTuiTextInput.Create(LUserRow);
    LUserInput.Placeholder := 'type your name...';
    LUserInput.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // Password row
    LPassRow := TTuiHStack.Create(LFormInner);
    LPassRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LPassLabel      := TTuiLabel.Create(LPassRow);
    LPassLabel.Text := ' Password:  ';
    LPassLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(12);

    LPassInput              := TTuiTextInput.Create(LPassRow);
    LPassInput.PasswordChar := '*';
    LPassInput.MaxLength    := 12;
    LPassInput.Placeholder  := 'max 12 chars';
    LPassInput.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // Checkbox
    LCheck         := TTuiCheckbox.Create(LFormInner);
    LCheck.Caption := ' I accept the terms';
    LCheck.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // Plan select row
    LPlanRow := TTuiHStack.Create(LFormInner);
    LPlanRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(5);

    LPlanLabel      := TTuiLabel.Create(LPlanRow);
    LPlanLabel.Text := ' Plan:      ';
    LPlanLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(12);

    LPlanSelect := TTuiSelect.Create(LPlanRow);
    LPlanSelect.Items.Add('Free');
    LPlanSelect.Items.Add('Pro');
    LPlanSelect.Items.Add('Enterprise');
    LPlanSelect.ItemIndex := 0;
    LPlanSelect.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // Button row
    LBtnRow := TTuiHStack.Create(LFormInner);
    LBtnRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LBtnSubmit         := TTuiButton.Create(LBtnRow);
    LBtnSubmit.Caption := 'Submit';
    LBtnSubmit.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    LBtnCancel         := TTuiButton.Create(LBtnRow);
    LBtnCancel.Caption := 'Cancel';
    LBtnCancel.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // ---- Live state box ----
    LStateBox       := TTuiBox.Create(LRoot);
    LStateBox.Title := ' Live state ';
    LStateBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(3);

    LStateLabel := TTuiLabel.Create(LStateBox);

    // ---- State update closure (captures local variables by reference) ----
    LUpdate := procedure
      begin
        LStateLabel.Text := Format(
          ' User: %s | Pwd: %d chars | Plan: %s | OK: %s | Last: %s',
          [LUsername, LPwdLen, LPlanText, BoolToStr(LAccepted, True), LLastAction]);
      end;

    // assign the callbacks now that LUpdate is ready
    LUserInput.OnTextChanged := procedure(AText: string)
      begin
        LUsername := AText;
        LUpdate;
      end;
    LUserInput.OnSubmit := procedure(AText: string)
      begin
        LLastAction := 'submit username';
        LUpdate;
      end;

    LPassInput.OnTextChanged := procedure(AText: string)
      begin
        LPwdLen := Length(AText);
        LUpdate;
      end;

    LCheck.OnToggle := procedure(AChecked: Boolean)
      begin
        LAccepted   := AChecked;
        LLastAction := 'toggle checkbox';
        LUpdate;
      end;

    LPlanSelect.OnChange := procedure(AIndex: Integer)
      begin
        LPlanText   := LPlanSelect.Items[AIndex];
        LLastAction := 'select plan';
        LUpdate;
      end;

    LBtnSubmit.OnClick := procedure
      begin
        LLastAction := 'click submit';
        LUpdate;
      end;

    LBtnCancel.OnClick := procedure
      begin
        LLastAction := 'click cancel';
        LUpdate;
      end;

    // initial state
    LUpdate;

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
