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
{   Unit:        Form.dpr                                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Form -- Sample app SAMPLE-02: Form completa.
///
///   Account registration form with validation and visual feedback.
///   Verifies: TTuiTextInput, TTuiButton, TTuiCheckbox, TTuiRadioButton,
///             TTuiSelect, TTuiToast.
///
///   Keys:
///     Tab / Shift-Tab  -- cycle through the focusable widgets
///     Enter / Space    -- activate/select the current widget
///     Ctrl+T           -- toggle Dark / Light theme
///     Ctrl+Q           -- quit
///
///   Layout:
///     LRoot (TTuiVStack)
///       LHeader (TTuiLabel)                          Fixed(1)
///       LToast (TTuiToast)                           Fixed(3)
///       LFormBox (TTuiBox 'Account Registration')    Fill(1)
///         LFormStack (TTuiVStack)
///           LUserLabel (TTuiLabel)                   Fixed(1)
///           LUserInput (TTuiTextInput)               Fixed(1)
///           LPassLabel (TTuiLabel)                   Fixed(1)
///           LPassInput (TTuiTextInput, password)     Fixed(1)
///           LEmailLabel (TTuiLabel)                  Fixed(1)
///           LEmailInput (TTuiTextInput)              Fixed(1)
///           LCountryLabel (TTuiLabel)                Fixed(1)
///           LCountrySelect (TTuiSelect)              Fixed(3)
///           LPlanLabel (TTuiLabel)                   Fixed(1)
///           LPlanFree (TTuiRadioButton, group Plan)  Fixed(1)
///           LPlanPro (TTuiRadioButton, group Plan)   Fixed(1)
///           LPlanEnt (TTuiRadioButton, group Plan)   Fixed(1)
///           LNewsCheck (TTuiCheckbox)                Fixed(1)
///           LTermsCheck (TTuiCheckbox)               Fixed(1)
///           LBtnRow (TTuiHStack)                     Fixed(1)
///             LBtnSubmit (TTuiButton)                Fill(1)
///             LBtnCancel (TTuiButton)                Fill(1)
///       LFooter (TTuiLabel)                          Fixed(1)
/// </summary>
program Form;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Input,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Geometry,
  Blinki.Core.Ansi,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Box,
  Blinki.Widgets.TextInput,
  Blinki.Widgets.Button,
  Blinki.Widgets.Checkbox,
  Blinki.Widgets.RadioButton,
  Blinki.Widgets.Select,
  Blinki.Widgets.Alert,
  Blinki.Widgets.Toast,
  Blinki.Layout.Stack;

var
  LApp: TTuiApp;
  LRoot: TTuiVStack;
  LHeader: TTuiLabel;
  LFooter: TTuiLabel;
  LToast: TTuiToast;

  LFormBox: TTuiBox;
  LFormStack: TTuiVStack;

  LUserLabel: TTuiLabel;
  LUserInput: TTuiTextInput;
  LPassLabel: TTuiLabel;
  LPassInput: TTuiTextInput;
  LEmailLabel: TTuiLabel;
  LEmailInput: TTuiTextInput;

  LCountryLabel: TTuiLabel;
  LCountrySelect: TTuiSelect;

  LPlanLabel: TTuiLabel;
  LPlanFree: TTuiRadioButton;
  LPlanPro: TTuiRadioButton;
  LPlanEnt: TTuiRadioButton;

  LNewsCheck: TTuiCheckbox;
  LTermsCheck: TTuiCheckbox;

  LBtnRow: TTuiHStack;
  LBtnSubmit: TTuiButton;
  LBtnCancel: TTuiButton;

  LDark: Boolean;

begin
  ReportMemoryLeaksOnShutdown := True;
  LDark := True;

  LApp := TTuiApp.Create;
  LRoot := TTuiVStack.Create;
  try
    LHeader := TTuiLabel.Create(LRoot);
    LHeader.Text := ' Blinki Form -- Account Registration | Tab=focus  Ctrl+T=theme  Ctrl+Q=quit';
    LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LToast := TTuiToast.Create(LRoot);
    LToast.DurationMs := 3000;
    LToast.LayoutConstraint := TTuiLayoutConstraint.Fixed(3);

    LFormBox := TTuiBox.Create(LRoot);
    LFormBox.Title := ' Account Registration ';
    LFormBox.BoxStyle := bsRounded;
    LFormBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    LFormStack := TTuiVStack.Create(LFormBox);

    LUserLabel := TTuiLabel.Create(LFormStack);
    LUserLabel.Text := ' Username';
    LUserLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LUserInput := TTuiTextInput.Create(LFormStack);
    LUserInput.Placeholder := 'Enter username...';
    LUserInput.MaxLength := 32;
    LUserInput.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LPassLabel := TTuiLabel.Create(LFormStack);
    LPassLabel.Text := ' Password';
    LPassLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LPassInput := TTuiTextInput.Create(LFormStack);
    LPassInput.Placeholder := 'Enter password...';
    LPassInput.PasswordChar := '*';
    LPassInput.MaxLength := 64;
    LPassInput.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LEmailLabel := TTuiLabel.Create(LFormStack);
    LEmailLabel.Text := ' Email';
    LEmailLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LEmailInput := TTuiTextInput.Create(LFormStack);
    LEmailInput.Placeholder := 'user@example.com';
    LEmailInput.MaxLength := 64;
    LEmailInput.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LCountryLabel := TTuiLabel.Create(LFormStack);
    LCountryLabel.Text := ' Country';
    LCountryLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LCountrySelect := TTuiSelect.Create(LFormStack);
    LCountrySelect.Items.Add('Italy');
    LCountrySelect.Items.Add('Germany');
    LCountrySelect.Items.Add('France');
    LCountrySelect.Items.Add('Spain');
    LCountrySelect.Items.Add('United States');
    LCountrySelect.ItemIndex := 0;
    LCountrySelect.LayoutConstraint := TTuiLayoutConstraint.Fixed(3);

    LPlanLabel := TTuiLabel.Create(LFormStack);
    LPlanLabel.Text := ' Subscription Plan';
    LPlanLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LPlanFree := TTuiRadioButton.Create(LFormStack);
    LPlanFree.Caption := 'Free';
    LPlanFree.Group := 'Plan';
    LPlanFree.Checked := True;
    LPlanFree.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LPlanPro := TTuiRadioButton.Create(LFormStack);
    LPlanPro.Caption := 'Pro';
    LPlanPro.Group := 'Plan';
    LPlanPro.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LPlanEnt := TTuiRadioButton.Create(LFormStack);
    LPlanEnt.Caption := 'Enterprise';
    LPlanEnt.Group := 'Plan';
    LPlanEnt.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LNewsCheck := TTuiCheckbox.Create(LFormStack);
    LNewsCheck.Caption := 'Subscribe to newsletter';
    LNewsCheck.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LTermsCheck := TTuiCheckbox.Create(LFormStack);
    LTermsCheck.Caption := 'I accept the terms and conditions';
    LTermsCheck.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LBtnRow := TTuiHStack.Create(LFormStack);
    LBtnRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LBtnSubmit := TTuiButton.Create(LBtnRow);
    LBtnSubmit.Caption := ' Submit ';
    LBtnSubmit.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    LBtnCancel := TTuiButton.Create(LBtnRow);
    LBtnCancel.Caption := ' Cancel ';
    LBtnCancel.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    LFooter := TTuiLabel.Create(LRoot);
    LFooter.Text := ' Tab=next field  Enter=select  Ctrl+T=theme  Ctrl+Q=quit';
    LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- Submit logic ----
    LBtnSubmit.OnClick := procedure
      begin
        var LUser := Trim(LUserInput.Text);
        var LPass := Trim(LPassInput.Text);
        var LEmail := Trim(LEmailInput.Text);
        if (LUser = '') or (LPass = '') or (LEmail = '') then
          LToast.Show(' Please fill all required fields (username, password, email).', alError)
        else if not LTermsCheck.Checked then
          LToast.Show(' You must accept the terms and conditions.', alWarning)
        else
          LToast.Show(Format(' Account created for %s!', [LUser]), alSuccess);
      end;

    LBtnCancel.OnClick := procedure
      begin
        LUserInput.Text := '';
        LPassInput.Text := '';
        LEmailInput.Text := '';
        LCountrySelect.ItemIndex := 0;
        LPlanFree.Checked := True;
        LNewsCheck.Checked := False;
        LTermsCheck.Checked := False;
        LToast.Show(' Form cleared.', alInfo);
      end;

    // ---- App setup ----
    LApp.SetRoot(LRoot);

    LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        if (AKey.Code = kcChar) and (kmCtrl in AKey.Modifiers) and (AKey.Character = #17) then
          LApp.Quit  // Ctrl+Q
        else if (AKey.Code = kcChar) and (kmCtrl in AKey.Modifiers) and (AKey.Character = #20) then
        begin
          LDark := not LDark;  // Ctrl+T
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
