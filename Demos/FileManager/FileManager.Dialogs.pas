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
{   Unit:        FileManager.Dialogs.pas                         }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   FileManagerDemo -- dialog factory procedures.
///   Each procedure creates a dialog, pushes it via TTuiApp.PushModal, and
///   performs the requested VFS operation (or shows an error) on confirmation.
/// </summary>
unit FileManager.Dialogs;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  Blinki.Core.App,
  FileManager.Model,
  FileManager.View;

/// <summary>
///   Shows a simple error dialog (OK only).
/// </summary>
procedure ShowError(AApp: TTuiApp; const ATitle, AMessage: string);

/// <summary>
///   Shows a properties info dialog for ANode.
/// </summary>
procedure ShowProperties(AApp: TTuiApp; ANode: TVfsNode);

/// <summary>
///   Asks for confirmation and deletes ANode from the VFS.
///   If APanel is currently showing ANode or one of its descendants, it is
///   navigated to the VFS root after deletion.
///   AStatusProc, when assigned, is called with a result message.
/// </summary>
procedure ShowConfirmDelete(AApp: TTuiApp; AVFS: TVirtualFileSystem;
  ANode: TVfsNode; APanel: TFilePanelView; const ARefreshProc: TProc;
  const AStatusProc: TProc<string> = nil);

/// <summary>
///   Asks for confirmation and copies ANode into ADestPanel.CurrentFolder.
///   AStatusProc, when assigned, is called with a result message.
/// </summary>
procedure ShowConfirmCopy(AApp: TTuiApp; AVFS: TVirtualFileSystem;
  ANode: TVfsNode; ADestPanel: TFilePanelView; const ARefreshProc: TProc;
  const AStatusProc: TProc<string> = nil);

/// <summary>
///   Asks for confirmation and moves ANode into ADestPanel.CurrentFolder.
///   If ASrcPanel is showing ANode it is navigated back to ANode's parent
///   (saved before the move).
///   AStatusProc, when assigned, is called with a result message.
/// </summary>
procedure ShowConfirmMove(AApp: TTuiApp; AVFS: TVirtualFileSystem;
  ANode: TVfsNode; ASrcPanel, ADestPanel: TFilePanelView;
  const ARefreshProc: TProc; const AStatusProc: TProc<string> = nil);

/// <summary>
///   Prompts for a name and creates a new folder inside APanel.CurrentFolder.
///   AStatusProc, when assigned, is called with a result message.
/// </summary>
procedure ShowNewFolder(AApp: TTuiApp; AVFS: TVirtualFileSystem;
  APanel: TFilePanelView; const ARefreshProc: TProc;
  const AStatusProc: TProc<string> = nil);

/// <summary>
///   Prompts for a new name and renames ANode.
///   AStatusProc, when assigned, is called with a result message.
/// </summary>
procedure ShowRename(AApp: TTuiApp; AVFS: TVirtualFileSystem;
  ANode: TVfsNode; APanel: TFilePanelView; const ARefreshProc: TProc;
  const AStatusProc: TProc<string> = nil);

implementation

uses
  Blinki.Widgets.Dialog,
  FileManager.Helpers;

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

// Returns True if AFolder is ANode or one of ANode's descendants.
function IsUnderNode(AFolder, ANode: TVfsNode): Boolean;
begin
  var LCurrent := AFolder;
  while Assigned(LCurrent) do
  begin
    if LCurrent = ANode then
      Exit(True);
    LCurrent := LCurrent.Parent;
  end;
  Result := False;
end;

// ---------------------------------------------------------------------------
// Public procedures
// ---------------------------------------------------------------------------

procedure ShowError(AApp: TTuiApp; const ATitle, AMessage: string);
begin
  var LDlg := TTuiDialogs.Error(ATitle, AMessage);
  LDlg.OnClose :=
    procedure(ASender: TObject; AResult: TTuiDialogResult)
    begin
      AApp.PopModal;
    end;
  AApp.PushModal(LDlg);
end;

procedure ShowProperties(AApp: TTuiApp; ANode: TVfsNode);
begin
  var LKind: string;
  var LExtra: string;
  if ANode.Kind = vkFolder then
  begin
    LKind := 'Folder';
    LExtra := IntToStr(ANode.ChildCount) + ' item(s)';
  end
  else
  begin
    LKind := 'File';
    LExtra := FormatSize(ANode.Size);
  end;
  var LMsg := LKind + '  |  ' + LExtra + '  |  ' + FormatDate(ANode.Modified);
  var LTitle := ' ' + ANode.Name + ' ';

  var LDlg := TTuiDialogs.Info(LTitle, LMsg);
  LDlg.OnClose :=
    procedure(ASender: TObject; AResult: TTuiDialogResult)
    begin
      AApp.PopModal;
    end;
  AApp.PushModal(LDlg);
end;

procedure ShowConfirmDelete(AApp: TTuiApp; AVFS: TVirtualFileSystem;
  ANode: TVfsNode; APanel: TFilePanelView; const ARefreshProc: TProc;
  const AStatusProc: TProc<string> = nil);
begin
  var LMsg := 'Delete "' + ANode.Name + '"?';
  if ANode.Kind = vkFolder then
    LMsg := LMsg + ' (folder and all contents)';

  // Determine if the panel will need to navigate after deletion
  var LNeedsNav := IsUnderNode(APanel.CurrentFolder, ANode);

  // Save the name now: Delete frees ANode, making ANode.Name inaccessible afterwards.
  var LNodeName := ANode.Name;

  var LDlg := TTuiDialogs.Confirm(' Delete ', LMsg);
  LDlg.OnClose :=
    procedure(ASender: TObject; AResult: TTuiDialogResult)
    begin
      AApp.PopModal;
      if AResult <> drOK then
      begin
        if Assigned(AStatusProc) then
          AStatusProc('Delete cancelled.');
        Exit;
      end;
      var LError: string;
      if not AVFS.Delete(ANode, LError) then
        ShowError(AApp, ' Error ', LError)
      else
      begin
        if LNeedsNav then
          APanel.SetCurrentFolder(AVFS.Root);
        if Assigned(AStatusProc) then
          AStatusProc('"' + LNodeName + '" deleted.');
        if Assigned(ARefreshProc) then
          ARefreshProc;
      end;
    end;
  AApp.PushModal(LDlg);
end;

procedure ShowConfirmCopy(AApp: TTuiApp; AVFS: TVirtualFileSystem;
  ANode: TVfsNode; ADestPanel: TFilePanelView; const ARefreshProc: TProc;
  const AStatusProc: TProc<string> = nil);
begin
  var LDest := ADestPanel.CurrentFolder;
  if not Assigned(LDest) then
    LDest := AVFS.Root;

  var LMsg := 'Copy "' + ANode.Name + '" to "' + LDest.Name + '"?';

  var LDlg := TTuiDialogs.Confirm(' Copy ', LMsg);
  LDlg.OnClose :=
    procedure(ASender: TObject; AResult: TTuiDialogResult)
    begin
      AApp.PopModal;
      if AResult <> drOK then
      begin
        if Assigned(AStatusProc) then
          AStatusProc('Copy cancelled.');
        Exit;
      end;
      var LError: string;
      if AVFS.Copy(ANode, LDest, LError) = nil then
        ShowError(AApp, ' Error ', LError)
      else
      begin
        if Assigned(AStatusProc) then
          AStatusProc('"' + ANode.Name + '" copied to "' + LDest.Name + '".');
        if Assigned(ARefreshProc) then
          ARefreshProc;
      end;
    end;
  AApp.PushModal(LDlg);
end;

procedure ShowConfirmMove(AApp: TTuiApp; AVFS: TVirtualFileSystem;
  ANode: TVfsNode; ASrcPanel, ADestPanel: TFilePanelView;
  const ARefreshProc: TProc; const AStatusProc: TProc<string> = nil);
begin
  var LDest := ADestPanel.CurrentFolder;
  if not Assigned(LDest) then
    LDest := AVFS.Root;

  var LMsg := 'Move "' + ANode.Name + '" to "' + LDest.Name + '"?';

  // Save the parent before the move (the node will be freed inside Move)
  var LSrcFolder := ANode.Parent;
  var LNeedsNav := IsUnderNode(ASrcPanel.CurrentFolder, ANode);

  // Save names now: Move frees ANode, making ANode.Name inaccessible afterwards.
  var LMovedName := ANode.Name;
  var LDestName := LDest.Name;

  var LDlg := TTuiDialogs.Confirm(' Move ', LMsg);
  LDlg.OnClose :=
    procedure(ASender: TObject; AResult: TTuiDialogResult)
    begin
      AApp.PopModal;
      if AResult <> drOK then
      begin
        if Assigned(AStatusProc) then
          AStatusProc('Move cancelled.');
        Exit;
      end;
      var LError: string;
      if not AVFS.Move(ANode, LDest, LError) then
        ShowError(AApp, ' Error ', LError)
      else
      begin
        if LNeedsNav then
        begin
          var LNavTarget: TVfsNode;
          if Assigned(LSrcFolder) then
            LNavTarget := LSrcFolder
          else
            LNavTarget := AVFS.Root;
          ASrcPanel.SetCurrentFolder(LNavTarget);
        end;
        if Assigned(AStatusProc) then
          AStatusProc('"' + LMovedName + '" moved to "' + LDestName + '".');
        if Assigned(ARefreshProc) then
          ARefreshProc;
      end;
    end;
  AApp.PushModal(LDlg);
end;

procedure ShowNewFolder(AApp: TTuiApp; AVFS: TVirtualFileSystem;
  APanel: TFilePanelView; const ARefreshProc: TProc;
  const AStatusProc: TProc<string> = nil);
begin
  var LParent := APanel.CurrentFolder;
  if not Assigned(LParent) then
    LParent := AVFS.Root;

  var LDlg := TTuiDialogs.Input(' New Folder ', 'Folder name:', '');
  LDlg.OnClose :=
    procedure(ASender: TObject; AResult: TTuiDialogResult)
    begin
      // Read the value before PopModal: with AOwnsModal=True the dialog is
      // freed inside PopModal, making ASender a dangling pointer afterwards.
      var LName := (ASender as TTuiInputDialog).Value.Trim;
      AApp.PopModal;
      if AResult <> drOK then
      begin
        if Assigned(AStatusProc) then
          AStatusProc('New folder cancelled.');
        Exit;
      end;
      if LName = '' then
        Exit;
      var LError: string;
      if AVFS.CreateFolder(LParent, LName, LError) = nil then
        ShowError(AApp, ' Error ', LError)
      else
      begin
        if Assigned(AStatusProc) then
          AStatusProc('Folder "' + LName + '" created.');
        if Assigned(ARefreshProc) then
          ARefreshProc;
      end;
    end;
  AApp.PushModal(LDlg);
end;

procedure ShowRename(AApp: TTuiApp; AVFS: TVirtualFileSystem;
  ANode: TVfsNode; APanel: TFilePanelView; const ARefreshProc: TProc;
  const AStatusProc: TProc<string> = nil);
begin
  var LOldName := ANode.Name;

  var LDlg := TTuiDialogs.Input(' Rename ', 'New name:', ANode.Name);
  LDlg.OnClose :=
    procedure(ASender: TObject; AResult: TTuiDialogResult)
    begin
      // Read the value before PopModal: with AOwnsModal=True the dialog is
      // freed inside PopModal, making ASender a dangling pointer afterwards.
      var LName := (ASender as TTuiInputDialog).Value.Trim;
      AApp.PopModal;
      if AResult <> drOK then
      begin
        if Assigned(AStatusProc) then
          AStatusProc('Rename cancelled.');
        Exit;
      end;
      if LName = '' then
        Exit;
      var LError: string;
      if not AVFS.Rename(ANode, LName, LError) then
        ShowError(AApp, ' Error ', LError)
      else
      begin
        if Assigned(AStatusProc) then
          AStatusProc('"' + LOldName + '" renamed to "' + LName + '".');
        if Assigned(ARefreshProc) then
          ARefreshProc;
      end;
    end;
  AApp.PushModal(LDlg);
end;

end.
