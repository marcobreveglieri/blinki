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
{   Unit:        DialogSmoke.dpr                                  }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   DialogSmoke — Interactive smoke test for the Blinki modal dialog
///   infrastructure (TTuiDialog, TTuiInputDialog, TTuiProgressDialog,
///   TTuiDialogs factory, TTuiApp.PushModal / PopModal).
///
///   Keys: 1=Confirm  2=Input  3=Progress (auto-closes in 3 s)
///         4=Error    5=Info   Q/Esc=Quit
///
///   Verifies:
///   - Dialogs centre correctly and redraw on resize.
///   - Tab is trapped within the modal (only modal widgets in focus ring).
///   - ESC and Enter dismiss the dialog; result is displayed in the status row.
///   - Progress dialog auto-advances from OnTimer and auto-closes at 100%.
///   - OnKeyPress is suppressed while any modal is active.
///   - No memory leaks (ReportMemoryLeaksOnShutdown = True).
/// </summary>
program DialogSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.App,
  Blinki.Core.Canvas,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  Blinki.Widgets.Dialog,
  Blinki.Widgets.Labels;

type

  TSmokeRoot = class(TTuiWidget)
  strict private
    FLabelHint: TTuiLabel;
    FLabelStatus: TTuiLabel;
    FLabelInfo: TTuiLabel;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create; reintroduce;
    procedure SetStatus(const AText: string);
  end;

{ TSmokeRoot }

constructor TSmokeRoot.Create;
begin
  inherited Create(nil);
  FLabelHint := TTuiLabel.Create(Self);
  FLabelStatus := TTuiLabel.Create(Self);
  FLabelInfo := TTuiLabel.Create(Self);
end;

procedure TSmokeRoot.DoInit;
begin
  FLabelHint.Style := TTuiStyle.Create(TTuiColors.BrightYellow, TTuiColor.Default, [taBold]);
  FLabelHint.Text :=
    'DialogSmoke | [1] Confirm  [2] Input  [3] Progress  [4] Error  [5] Info  [Q] Quit';
  FLabelStatus.Style := TTuiStyle.Create(TTuiColors.BrightCyan, TTuiColor.Default);
  FLabelStatus.Text := 'Status: (nessun dialogo aperto)';
  FLabelInfo.Style := TTuiStyle.Create(Theme.TextDim, TTuiColor.Default);
  FLabelInfo.Text :=
    'Tab resta nel modale. ESC/Enter chiudono il dialogo. Il modale assorbe i tasti globali.';
end;

procedure TSmokeRoot.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(Theme.Text, Theme.Background));
  if ARect.Height >= 1 then
    FLabelHint.Render(ACanvas,
      TRect.Create(ARect.Left, ARect.Top, ARect.Right, ARect.Top + 1));
  if ARect.Height >= 3 then
    FLabelStatus.Render(ACanvas,
      TRect.Create(ARect.Left, ARect.Top + 2, ARect.Right, ARect.Top + 3));
  if ARect.Height >= 5 then
    FLabelInfo.Render(ACanvas,
      TRect.Create(ARect.Left, ARect.Top + 4, ARect.Right, ARect.Top + 5));
end;

procedure TSmokeRoot.SetStatus(const AText: string);
begin
  FLabelStatus.Text := 'Status: ' + AText;
end;

// ---------------------------------------------------------------------------

var
  LApp: TTuiApp;
  LRoot: TSmokeRoot;

begin
  ReportMemoryLeaksOnShutdown := True;

  LApp := TTuiApp.Create;
  LRoot := TSmokeRoot.Create;
  try
    LApp.SetRoot(LRoot);

    // Progress dialog reference shared between the key handler and OnTimer.
    var LProgressDlg: TTuiProgressDialog := nil;
    var LProgressMs: Integer := 0;

    LApp.OnKeyPress :=
      procedure(const AKey: TTuiKeyEvent)
      begin
        case AKey.Code of
          kcEscape:
            LApp.Quit;

          kcChar:
            case UpCase(AKey.Character) of
              'Q': LApp.Quit;

              '1':
              begin
                var LDlg := TTuiDialogs.Confirm(
                  ' Conferma ', 'Vuoi davvero eseguire questa operazione?');
                LDlg.OnClose :=
                  procedure(ASender: TObject; AResult: TTuiDialogResult)
                  begin
                    case AResult of
                      drOK:     LRoot.SetStatus('Confirm → OK');
                      drCancel: LRoot.SetStatus('Confirm → Annulla');
                    else
                      LRoot.SetStatus('Confirm → ' + IntToStr(Ord(AResult)));
                    end;
                    LApp.PopModal;
                  end;
                LApp.PushModal(LDlg);
              end;

              '2':
              begin
                var LInputDlg := TTuiDialogs.Input(
                  ' Input ', 'Inserisci testo...', '');
                LInputDlg.OnClose :=
                  procedure(ASender: TObject; AResult: TTuiDialogResult)
                  begin
                    if AResult = drOK then
                      LRoot.SetStatus(
                        'Input → "' + (ASender as TTuiInputDialog).Value + '"')
                    else
                      LRoot.SetStatus('Input → annullato');
                    LApp.PopModal;
                  end;
                LApp.PushModal(LInputDlg);
              end;

              '3':
              begin
                if Assigned(LProgressDlg) then
                  Exit; // already open
                var LProgDlg := TTuiDialogs.Progress(' Avanzamento (3 s) ');
                LProgressDlg := LProgDlg;
                LProgressMs := 0;
                LProgDlg.OnCancel :=
                  procedure
                  begin
                    LProgressDlg := nil;
                    LRoot.SetStatus('Progress → annullato');
                  end;
                LProgDlg.OnClose :=
                  procedure(ASender: TObject; AResult: TTuiDialogResult)
                  begin
                    if AResult = drOK then
                      LRoot.SetStatus('Progress → completato');
                    LApp.PopModal;
                  end;
                LApp.PushModal(LProgDlg);
              end;

              '4':
              begin
                var LDlg := TTuiDialogs.Error(
                  ' Errore ', 'Operazione non valida: permesso negato.');
                LDlg.OnClose :=
                  procedure(ASender: TObject; AResult: TTuiDialogResult)
                  begin
                    LRoot.SetStatus('Error → OK');
                    LApp.PopModal;
                  end;
                LApp.PushModal(LDlg);
              end;

              '5':
              begin
                var LDlg := TTuiDialogs.Info(
                  ' Info ', 'Blinki TUI Framework v0.1.0 — dialogo informativo.');
                LDlg.OnClose :=
                  procedure(ASender: TObject; AResult: TTuiDialogResult)
                  begin
                    LRoot.SetStatus('Info → OK');
                    LApp.PopModal;
                  end;
                LApp.PushModal(LDlg);
              end;
            end;
        end;
      end;

    LApp.OnTimer :=
      procedure(AElapsedMs: Integer)
      begin
        if not Assigned(LProgressDlg) then
          Exit;
        Inc(LProgressMs, AElapsedMs);
        var LProgress := LProgressMs / 3000.0;
        if LProgress >= 1.0 then
        begin
          LProgressDlg.Progress := 1.0;
          var LDlg := LProgressDlg;
          LProgressDlg := nil;
          LDlg.Complete;
        end
        else
          LProgressDlg.Progress := LProgress;
      end;

    LApp.Run;
  finally
    LApp.Free;
  end;
end.
