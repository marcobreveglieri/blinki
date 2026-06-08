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
{   Unit:        FileManager.Helpers.pas                     }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   FileManagerDemo — formatting helpers and sample tree builder.
/// </summary>
unit FileManager.Helpers;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  FileManager.Model;

/// <summary>
///   Formats a byte count as a human-readable string (e.g. "1.2 MB").
/// </summary>
function FormatSize(ASize: Int64): string;

/// <summary>
///   Formats a TDateTime as "YYYY-MM-DD HH:MM".
/// </summary>
function FormatDate(ADate: TDateTime): string;

/// <summary>
///   Populates AVFS with a plausible 2-3 level tree of folders and files.
/// </summary>
procedure BuildSampleTree(AVFS: TVirtualFileSystem);

implementation

uses
  System.SysUtils;

function FormatSize(ASize: Int64): string;
begin
  if ASize >= 1073741824 then
    Result := Format('%.1f GB', [ASize / 1073741824.0])
  else if ASize >= 1048576 then
    Result := Format('%.1f MB', [ASize / 1048576.0])
  else if ASize >= 1024 then
    Result := Format('%.1f KB', [ASize / 1024.0])
  else
    Result := Format('%d B', [ASize]);
end;

function FormatDate(ADate: TDateTime): string;
begin
  if ADate = 0 then
    Exit('');
  Result := FormatDateTime('yyyy-mm-dd hh:nn', ADate);
end;

procedure BuildSampleTree(AVFS: TVirtualFileSystem);
var
  LRoot: TVfsNode;

  function MkDir(AParent: TVfsNode; const AName: string): TVfsNode;
  begin
    Result := TVfsNode.Create(AName, vkFolder, 0, Now - Random(365), AParent);
  end;

  procedure MkFile(AParent: TVfsNode; const AName: string; ASize: Int64);
  begin
    TVfsNode.Create(AName, vkFile, ASize, Now - Random(365), AParent);
  end;

begin
  LRoot := AVFS.Root;

  var LDocs := MkDir(LRoot, 'Documents');
    var LWork := MkDir(LDocs, 'Work');
      MkFile(LWork, 'report_2026.docx', 182400);
      MkFile(LWork, 'budget.xlsx', 94208);
      MkFile(LWork, 'presentation.pptx', 3145728);
    var LPersonal := MkDir(LDocs, 'Personal');
      MkFile(LPersonal, 'notes.txt', 4096);
      MkFile(LPersonal, 'travel_plan.pdf', 512000);

  var LPics := MkDir(LRoot, 'Pictures');
    MkFile(LPics, 'vacation_2025.jpg', 4718592);
    MkFile(LPics, 'profile.png', 245760);
    var LScreenshots := MkDir(LPics, 'Screenshots');
      MkFile(LScreenshots, 'desktop_2026-01-10.png', 819200);
      MkFile(LScreenshots, 'error_log.png', 102400);

  var LCode := MkDir(LRoot, 'Projects');
    var LBlinki := MkDir(LCode, 'Blinki');
      MkFile(LBlinki, 'README.md', 8192);
      MkFile(LBlinki, 'LICENSE', 1080);
      var LSource := MkDir(LBlinki, 'Source');
        MkFile(LSource, 'Blinki.Core.App.pas', 32768);
        MkFile(LSource, 'Blinki.Core.Widget.pas', 24576);
    var LWebApp := MkDir(LCode, 'WebApp');
      MkFile(LWebApp, 'index.html', 4096);
      MkFile(LWebApp, 'app.js', 65536);
      MkFile(LWebApp, 'styles.css', 12288);

  var LDownloads := MkDir(LRoot, 'Downloads');
    MkFile(LDownloads, 'setup_v2.exe', 52428800);
    MkFile(LDownloads, 'archive.zip', 10485760);
    MkFile(LDownloads, 'manual.pdf', 2097152);

  MkFile(LRoot, '.profile', 512);
  MkFile(LRoot, '.bashrc', 1024);

  // Sort all nodes
  LRoot.SortChildren;
  LDocs.SortChildren; LWork.SortChildren; LPersonal.SortChildren;
  LPics.SortChildren; LScreenshots.SortChildren;
  LCode.SortChildren; LBlinki.SortChildren; LSource.SortChildren; LWebApp.SortChildren;
  LDownloads.SortChildren;
end;

end.
