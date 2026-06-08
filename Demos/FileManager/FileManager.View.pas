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
{   Unit:        FileManager.View.pas                            }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   FileManagerDemo -- TFilePanelView custom widget.
///   Displays a single VFS folder with keyboard and mouse navigation.
///   Folders are entered on activation; OnActivate fires for file nodes only.
/// </summary>
unit FileManager.View;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  FileManager.Model;

type

{ TFileManagerHeader }

  /// <summary>
  ///   Single-row header bar for the FileManager demo.
  ///   Renders the title with a left-to-right RGB gradient and the command
  ///   hints in a dimmed style. When OverrideText is set (e.g. "terminal too
  ///   small"), it replaces both title and commands with plain text.
  /// </summary>
  TFileManagerHeader = class(TTuiWidget)
  strict private
    FBgStyle: TTuiStyle;
    FCommands: string;
    FCmdStyle: TTuiStyle;
    FOverrideText: string;
    FTitle: string;
    procedure RebuildStyles;
    procedure SetCommands(const AValue: string);
    procedure SetOverrideText(const AValue: string);
    procedure SetTitle(const AValue: string);
  protected
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Command hints rendered to the right of the title.
    /// </summary>
    property Commands: string read FCommands write SetCommands;
    /// <summary>
    ///   When non-empty, replaces the gradient title and commands with this
    ///   plain text (used for the "terminal too small" warning).
    /// </summary>
    property OverrideText: string read FOverrideText write SetOverrideText;
    /// <summary>
    ///   Title text rendered with a colour gradient (bold).
    /// </summary>
    property Title: string read FTitle write SetTitle;
  end;

  /// <summary>
  ///   File panel widget for the bipane file manager.
  ///   Displays a single VFS folder with keyboard and mouse navigation.
  ///   Folders are entered internally on activation; OnActivate fires for
  ///   file nodes only (Enter or double-click on a file).
  /// </summary>
  TFilePanelView = class(TTuiWidget)
  strict private
    FBorderFocusedStyle: TTuiStyle;
    FBorderStyle: TTuiStyle;
    FCurrentFolder: TVfsNode;       // non-owning reference
    FFolderStyle: TTuiStyle;
    FHeaderStyle: TTuiStyle;
    FLastClickDisplayIdx: Integer;
    FLastClickMs: Int64;
    FLastVisibleRows: Integer;
    FNormalStyle: TTuiStyle;
    FOnActivate: TProc<TVfsNode>;
    FScrollOffset: Integer;
    FSelectedFocusedStyle: TTuiStyle;
    FSelectedIndex: Integer;
    FSelectedStyle: TTuiStyle;
    FTimerMs: Int64;
    procedure Activate;
    procedure AdjustScroll;
    function GetSelectedNode: TVfsNode;
    function ItemCount: Integer;
    procedure RebuildStyles;
    procedure SelectItem(ADI: Integer);
    function ShowsDotDot: Boolean;
  protected
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Navigates the panel to the given folder and resets selection and scroll.
    /// </summary>
    procedure SetCurrentFolder(AFolder: TVfsNode);
    /// <summary>
    ///   The folder currently displayed by this panel.
    /// </summary>
    property CurrentFolder: TVfsNode read FCurrentFolder;
    /// <summary>
    ///   Fired when the user activates a file node (Enter or double-click).
    ///   Not fired for folder navigation, which is handled internally.
    /// </summary>
    property OnActivate: TProc<TVfsNode> read FOnActivate write FOnActivate;
    /// <summary>
    ///   Clamps the selection to the valid range and redraws.
    ///   Call this after the VFS tree was modified externally (delete, move, etc.).
    /// </summary>
    procedure Refresh;
    /// <summary>
    ///   The currently selected VFS node, or nil when ".." or nothing is selected.
    /// </summary>
    property SelectedNode: TVfsNode read GetSelectedNode;
  end;

implementation

uses
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.FX.Gradient,
  FileManager.Helpers;

{ TFileManagerHeader }

constructor TFileManagerHeader.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  RebuildStyles;
end;

procedure TFileManagerHeader.RebuildStyles;
begin
  FBgStyle := TTuiStyle.Create(Theme.Text, Theme.Background);
  FCmdStyle := TTuiStyle.Create(Theme.TextDim, Theme.Background);
end;

procedure TFileManagerHeader.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TFileManagerHeader.SetCommands(const AValue: string);
begin
  if FCommands = AValue then
    Exit;
  FCommands := AValue;
  Invalidate;
end;

procedure TFileManagerHeader.SetOverrideText(const AValue: string);
begin
  if FOverrideText = AValue then
    Exit;
  FOverrideText := AValue;
  Invalidate;
end;

procedure TFileManagerHeader.SetTitle(const AValue: string);
begin
  if FTitle = AValue then
    Exit;
  FTitle := AValue;
  Invalidate;
end;

procedure TFileManagerHeader.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  ACanvas.FillRect(ARect, ' ', FBgStyle);
  if FOverrideText <> '' then
  begin
    ACanvas.WriteAt(ARect.Left, ARect.Top, FOverrideText, FCmdStyle);
    Exit;
  end;
  if FTitle <> '' then
    DrawGradient(ACanvas, ARect.Left + 1, ARect.Top, FTitle,
      Theme.Primary, Theme.Secondary, Theme.Background, [taBold]);
  var LCmdX := ARect.Left + 1 + Length(FTitle) + 4;
  if (LCmdX < ARect.Right) and (FCommands <> '') then
    ACanvas.WriteAt(LCmdX, ARect.Top, FCommands, FCmdStyle);
end;

{ TFilePanelView }

constructor TFilePanelView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FLastClickDisplayIdx := -1;  // sentinel: no previous click
  RebuildStyles;
end;

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

procedure TFilePanelView.RebuildStyles;
begin
  FBorderStyle := TTuiStyle.Create(Theme.Border, Theme.Background);
  FBorderFocusedStyle := TTuiStyle.Create(Theme.Primary, Theme.Background);
  FFolderStyle := TTuiStyle.Create(Theme.Primary, Theme.Surface, [taBold]);
  FHeaderStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface, [taBold]);
  FNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  FSelectedFocusedStyle := TTuiStyle.Create(Theme.Background, Theme.Primary);
  FSelectedStyle := TTuiStyle.Create(Theme.Text, Theme.Border);
end;

function TFilePanelView.ShowsDotDot: Boolean;
begin
  Result := Assigned(FCurrentFolder) and Assigned(FCurrentFolder.Parent);
end;

function TFilePanelView.ItemCount: Integer;
begin
  Result := 0;
  if not Assigned(FCurrentFolder) then
    Exit;
  Result := FCurrentFolder.ChildCount;
  if ShowsDotDot then
    Inc(Result);
end;

procedure TFilePanelView.AdjustScroll;
begin
  if FLastVisibleRows <= 0 then
    Exit;
  if FSelectedIndex < FScrollOffset then
    FScrollOffset := FSelectedIndex;
  if FSelectedIndex >= FScrollOffset + FLastVisibleRows then
    FScrollOffset := FSelectedIndex - FLastVisibleRows + 1;
  if FScrollOffset < 0 then
    FScrollOffset := 0;
end;

procedure TFilePanelView.SelectItem(ADI: Integer);
begin
  var LCount := ItemCount;
  if LCount = 0 then
    Exit;
  if ADI < 0 then
    ADI := 0;
  if ADI >= LCount then
    ADI := LCount - 1;
  if FSelectedIndex = ADI then
    Exit;
  FSelectedIndex := ADI;
  AdjustScroll;
  Invalidate;
end;

procedure TFilePanelView.Activate;
begin
  if not Assigned(FCurrentFolder) then
    Exit;
  var LShowDotDot := ShowsDotDot;
  if LShowDotDot and (FSelectedIndex = 0) then
  begin
    // Navigate to parent folder
    FCurrentFolder := FCurrentFolder.Parent;
    FSelectedIndex := 0;
    FScrollOffset := 0;
    Invalidate;
    Exit;
  end;
  var LBase := 0;
  if LShowDotDot then
    LBase := 1;
  var LChildIdx := FSelectedIndex - LBase;
  if (LChildIdx < 0) or (LChildIdx >= FCurrentFolder.ChildCount) then
    Exit;
  var LNode := FCurrentFolder.Children[LChildIdx];
  if LNode.Kind = vkFolder then
  begin
    // Navigate into the folder
    FCurrentFolder := LNode;
    FSelectedIndex := 0;
    FScrollOffset := 0;
    Invalidate;
  end
  else if Assigned(FOnActivate) then
    FOnActivate(LNode);
end;

function TFilePanelView.GetSelectedNode: TVfsNode;
begin
  Result := nil;
  if not Assigned(FCurrentFolder) then
    Exit;
  var LShowDotDot := ShowsDotDot;
  if LShowDotDot and (FSelectedIndex = 0) then
    Exit; // ".." is selected; no real node
  var LBase := 0;
  if LShowDotDot then
    LBase := 1;
  var LChildIdx := FSelectedIndex - LBase;
  if (LChildIdx >= 0) and (LChildIdx < FCurrentFolder.ChildCount) then
    Result := FCurrentFolder.Children[LChildIdx];
end;

// ---------------------------------------------------------------------------
// TTuiWidget overrides
// ---------------------------------------------------------------------------

procedure TFilePanelView.DoInit;
begin
  SetFocusable(True);
end;

procedure TFilePanelView.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TFilePanelView.DoTick(AElapsedMs: Integer);
begin
  Inc(FTimerMs, AElapsedMs);
end;

procedure TFilePanelView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  // Compute column layout
  var LInnerW := ARect.Width - 2;            // width inside box borders
  var LShowCols := LInnerW >= 28;            // show Size+Date columns only if wide enough
  var LNameW: Integer;
  if LShowCols then
    LNameW := Max(1, LInnerW - 26)           // 26 = 1(sep)+8(size)+1(sep)+16(date)
  else
    LNameW := Max(1, LInnerW);

  // Visible item rows: total height minus top border, header row, bottom border
  FLastVisibleRows := Max(0, ARect.Height - 3);

  // Draw the box border with the current folder path as title
  var LBorderStyle: TTuiStyle;
  if Focused then
    LBorderStyle := FBorderFocusedStyle
  else
    LBorderStyle := FBorderStyle;

  var LTitle: string;
  if Assigned(FCurrentFolder) then
    LTitle := ' ' + FCurrentFolder.FullPath + ' '
  else
    LTitle := ' / ';
  ACanvas.DrawBox(ARect, bsRounded, LTitle, LBorderStyle);

  if ARect.Height < 3 then
    Exit; // too small to render content

  // Header row at ARect.Top + 1 (first inner row)
  var LInnerLeft := ARect.Left + 1;
  var LHdrY := ARect.Top + 1;
  var LHdrRect := TRect.Create(LInnerLeft, LHdrY, ARect.Right - 1, LHdrY + 1);
  ACanvas.FillRect(LHdrRect, ' ', FHeaderStyle);
  var LNameHdr := 'Name';
  if LNameW > Length(LNameHdr) then
    LNameHdr := LNameHdr + StringOfChar(' ', LNameW - Length(LNameHdr));
  ACanvas.WriteAt(LInnerLeft, LHdrY, Copy(LNameHdr, 1, LNameW), FHeaderStyle);
  if LShowCols then
  begin
    ACanvas.WriteAt(LInnerLeft + LNameW + 1, LHdrY, '    Size', FHeaderStyle);
    ACanvas.WriteAt(LInnerLeft + LNameW + 10, LHdrY, ' Modified       ', FHeaderStyle);
  end;

  if FLastVisibleRows <= 0 then
    Exit;

  AdjustScroll;

  // Compute item list parameters once
  var LShowDotDot := ShowsDotDot;
  var LBase := 0;
  if LShowDotDot then
    LBase := 1;
  var LCount := ItemCount;

  // Draw visible item rows
  for var LRow := 0 to FLastVisibleRows - 1 do
  begin
    var LDI := FScrollOffset + LRow;
    if LDI >= LCount then
      Break;

    var LY := ARect.Top + 2 + LRow;
    var LIsDotDot := LShowDotDot and (LDI = 0);

    // Resolve the VFS node for this display index
    var LNode: TVfsNode := nil;
    if not LIsDotDot then
      LNode := FCurrentFolder.Children[LDI - LBase];

    // Choose the rendering style
    var LIsSelected := (LDI = FSelectedIndex);
    var LStyle: TTuiStyle;
    if LIsSelected then
    begin
      if Focused then
        LStyle := FSelectedFocusedStyle
      else
        LStyle := FSelectedStyle;
    end
    else if LIsDotDot or (Assigned(LNode) and (LNode.Kind = vkFolder)) then
      LStyle := FFolderStyle
    else
      LStyle := FNormalStyle;

    // Fill the row background inside the box
    var LRowRect := TRect.Create(LInnerLeft, LY, ARect.Right - 1, LY + 1);
    ACanvas.FillRect(LRowRect, ' ', LStyle);

    // Build and write the name string (left-aligned, truncated with ~ if too long)
    var LName: string;
    if LIsDotDot then
      LName := '..'
    else if LNode.Kind = vkFolder then
      LName := '[' + LNode.Name + ']'
    else
      LName := LNode.Name;
    if Length(LName) > LNameW then
      LName := Copy(LName, 1, LNameW - 1) + '~';
    ACanvas.WriteAt(LInnerLeft, LY, LName, LStyle);

    // Write size and date columns (not for "..")
    if LShowCols and not LIsDotDot then
    begin
      var LSizeStr: string;
      if LNode.Kind = vkFolder then
        LSizeStr := '   <DIR>'
      else
      begin
        var LFmt := FormatSize(LNode.Size);
        LSizeStr := StringOfChar(' ', Max(0, 8 - Length(LFmt))) + LFmt;
        if Length(LSizeStr) > 8 then
          LSizeStr := Copy(LSizeStr, 1, 8);
      end;
      ACanvas.WriteAt(LInnerLeft + LNameW + 1, LY, LSizeStr, LStyle);
      ACanvas.WriteAt(LInnerLeft + LNameW + 10, LY, FormatDate(LNode.Modified), LStyle);
    end;
  end;
end;

function TFilePanelView.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;

  if AEvent.Kind = ekMouse then
  begin
    case AEvent.Mouse.Kind of
      mekDown:
      begin
        if not Assigned(FCurrentFolder) then
          Exit;
        // Map the clicked Y coordinate back to a display index
        var LDI := FScrollOffset + (AEvent.Mouse.Y - (LastRect.Top + 2));
        if (LDI >= 0) and (LDI < ItemCount) then
        begin
          var LIsDouble := (LDI = FLastClickDisplayIdx) and
                           ((FTimerMs - FLastClickMs) < 400);
          FLastClickMs := FTimerMs;
          FLastClickDisplayIdx := LDI;
          SelectItem(LDI);
          if LIsDouble then
            Activate;
          Result := True;
        end;
      end;
      mekWheel:
      begin
        var LMaxOff := Max(0, ItemCount - FLastVisibleRows);
        if AEvent.Mouse.WheelDelta > 0 then
          FScrollOffset := Max(0, FScrollOffset - 3)
        else
          FScrollOffset := Min(LMaxOff, FScrollOffset + 3);
        Invalidate;
        Result := True;
      end;
    end;
    Exit;
  end;

  if AEvent.Kind <> ekKey then
    Exit;
  if not Assigned(FCurrentFolder) then
    Exit;

  var LCount := ItemCount;
  if LCount = 0 then
    Exit;

  var LPageStep := Max(1, FLastVisibleRows);

  case AEvent.Key.Code of
    kcUp:
    begin
      SelectItem(Max(0, FSelectedIndex - 1));
      Result := True;
    end;
    kcDown:
    begin
      SelectItem(Min(LCount - 1, FSelectedIndex + 1));
      Result := True;
    end;
    kcHome:
    begin
      SelectItem(0);
      Result := True;
    end;
    kcEnd:
    begin
      SelectItem(LCount - 1);
      Result := True;
    end;
    kcPageUp:
    begin
      SelectItem(Max(0, FSelectedIndex - LPageStep));
      Result := True;
    end;
    kcPageDown:
    begin
      SelectItem(Min(LCount - 1, FSelectedIndex + LPageStep));
      Result := True;
    end;
    kcEnter:
    begin
      Activate;
      Result := True;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Public interface
// ---------------------------------------------------------------------------

procedure TFilePanelView.SetCurrentFolder(AFolder: TVfsNode);
begin
  if FCurrentFolder = AFolder then
    Exit;
  FCurrentFolder := AFolder;
  FSelectedIndex := 0;
  FScrollOffset := 0;
  Invalidate;
end;

procedure TFilePanelView.Refresh;
begin
  var LCount := ItemCount;
  if FSelectedIndex >= LCount then
    FSelectedIndex := Max(0, LCount - 1);
  AdjustScroll;
  Invalidate;
end;

end.
