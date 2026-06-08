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
{   Unit:        FileManager.dpr                                 }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

{ FileManagerDemo: bipane file manager demo for the Blinki TUI framework.
  VStack layout: header / HStack(left panel, right panel) / footer.
  F2=Rename F5=Copy F6=Move F7=NewFolder F8=Delete F10/Q=Quit Esc=Quit. }
program FileManager;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.App,
  Blinki.Core.Geometry,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Layout.Stack,
  Blinki.Widgets.Dialog,
  Blinki.Widgets.Labels,
  FileManager.Consts in 'FileManager.Consts.pas',
  FileManager.Dialogs in 'FileManager.Dialogs.pas',
  FileManager.Helpers in 'FileManager.Helpers.pas',
  FileManager.Model in 'FileManager.Model.pas',
  FileManager.View in 'FileManager.View.pas';

// ============================================================================
// Main body
// ============================================================================

begin
  ReportMemoryLeaksOnShutdown := True;
  Randomize;

  var LVFS := TVirtualFileSystem.Create;
  try
    BuildSampleTree(LVFS);

    var LApp := TTuiApp.Create;
    var LRoot := TTuiVStack.Create;
    try
      // ---- Header ----
      var LHeader := TFileManagerHeader.Create(LRoot);
      LHeader.Title := CTitleName;
      LHeader.Commands := CTitleCommands;
      LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      // ---- Panel area ----
      var LPanels := TTuiHStack.Create(LRoot);
      LPanels.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      var LLeft := TFilePanelView.Create(LPanels);
      LLeft.SetCurrentFolder(LVFS.Root);

      var LRight := TFilePanelView.Create(LPanels);
      LRight.SetCurrentFolder(LVFS.Root);

      // ---- Footer ----
      var LFooter := TTuiLabel.Create(LRoot);
      LFooter.Style := TTuiStyle.Create(LApp.Theme.TextDim, TTuiColor.Default);
      LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      LApp.SetRoot(LRoot);

      // ---- Dialog button localisation ----------------------------------------
      // Button captions default to English and are fully localizable. To switch
      // the whole application to another language, build a record once at startup:
      //   var LCaps := TTuiDialogCaptions.Default;
      //   LCaps.Cancel := 'Annulla';
      //   LCaps.Yes    := 'Sì';
      //   TTuiDialog.DefaultCaptions := LCaps;
      // A single dialog can also override its own captions, e.g.:
      //   LDlg.Captions.Cancel := 'Annulla';
      // This demo keeps English intentionally; the default is set explicitly here
      // to document the mechanism.
      TTuiDialog.DefaultCaptions := TTuiDialogCaptions.Default;

      // Refresh proc: clamp both panels' selection after VFS modifications.
      var LRefresh: TProc;
      LRefresh :=
        procedure
        begin
          LLeft.Refresh;
          LRight.Refresh;
        end;

      // Status proc: writes the result of the last operation to the footer.
      var LSetStatus: TProc<string>;
      LSetStatus :=
        procedure(AMsg: string)
        begin
          LFooter.Text := '  ' + AMsg;
        end;

      // ---- OnResize: enforce minimum terminal size ----
      LApp.OnResize :=
        procedure(const ASize: TSize)
        begin
          if (ASize.cx < CMinTerminalWidth) or (ASize.cy < CMinTerminalHeight) then
            LHeader.OverrideText := CSmallTerminalMsg
          else
            LHeader.OverrideText := '';
        end;

      // ---- OnKeyPress: global function-key shortcuts ----
      LApp.OnKeyPress :=
        procedure(const AKey: TTuiKeyEvent)
        begin
          // Determine active and opposite panel
          var LActive: TFilePanelView;
          if LLeft.Focused then
            LActive := LLeft
          else
            LActive := LRight;
          var LOther: TFilePanelView;
          if LActive = LLeft then
            LOther := LRight
          else
            LOther := LLeft;

          case AKey.Code of
            kcEscape:
              LApp.Quit;

            kcF10:
              LApp.Quit;

            kcF2:
            begin
              var LNode := LActive.SelectedNode;
              if Assigned(LNode) then
                ShowRename(LApp, LVFS, LNode, LActive, LRefresh, LSetStatus);
            end;

            kcF5:
            begin
              var LNode := LActive.SelectedNode;
              if Assigned(LNode) then
                ShowConfirmCopy(LApp, LVFS, LNode, LOther, LRefresh, LSetStatus);
            end;

            kcF6:
            begin
              var LNode := LActive.SelectedNode;
              if Assigned(LNode) then
                ShowConfirmMove(LApp, LVFS, LNode, LActive, LOther, LRefresh, LSetStatus);
            end;

            kcF7:
              ShowNewFolder(LApp, LVFS, LActive, LRefresh, LSetStatus);

            kcF8:
            begin
              var LNode := LActive.SelectedNode;
              if Assigned(LNode) then
                ShowConfirmDelete(LApp, LVFS, LNode, LActive, LRefresh, LSetStatus);
            end;

            kcChar:
              case UpCase(AKey.Character) of
                'Q': LApp.Quit;
              end;
          end;
        end;

      LApp.Run;
    finally
      LApp.Free;
    end;

  finally
    LVFS.Free;
  end;
end.
