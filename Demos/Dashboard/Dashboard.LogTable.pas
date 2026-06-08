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
{   Unit:        Dashboard.LogTable.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Dashboard demo — TDashboardLogTable: the scrollable log viewer widget.
///   Renders a header row and the log entries with per-column colour coding
///   (Time, Level, Host, Service, Message each use their own palette entry).
///   The widget is focusable; Up/Down/PgUp/PgDn/Home/End scroll the viewport.
///   AutoFollow = True causes the viewport to track the newest entries.
/// </summary>
unit Dashboard.LogTable;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  System.Generics.Collections,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Geometry,
  Blinki.Core.Widget,
  Dashboard.Model;

type

  /// <summary>
  ///   Event fired when the user activates a log entry (Enter key or double-click).
  /// </summary>
  TLogActivateEvent = reference to procedure(const AEntry: TLogEntry);

{ TDashboardLogTable }

  /// <summary>
  ///   Custom log-table widget with per-column colour coding, keyboard and
  ///   mouse navigation.
  ///   Holds a reference to FModel.LogEntries (not owned). AutoFollow = True
  ///   keeps the viewport pinned to the most recent entries.
  ///   Up/Down/PgUp/PgDn/Home/End move the row cursor; the viewport follows.
  ///   Mouse wheel scrolls the viewport; left-click selects a row.
  ///   Enter activates the selected row (fires OnActivate).
  /// </summary>
  TDashboardLogTable = class(TTuiWidget)
  strict private
    FAutoFollow: Boolean;
    FItems: TList<TLogEntry>;
    FOnActivate: TLogActivateEvent;
    FScrollOffset: Integer;
    FSectionName: string;
    FSelectedIndex: Integer;
    procedure ClampScroll;
    procedure EnsureSelectedVisible;
    function VisibleRows: Integer;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
  public
    /// <summary>
    ///   Creates the log table. AItems is a reference to the model list (not owned).
    /// </summary>
    constructor Create(AParent: TTuiWidget; AItems: TList<TLogEntry>);
    /// <summary>
    ///   Scrolls the viewport to show the last entries in the list.
    /// </summary>
    procedure ScrollToBottom;
    /// <summary>
    ///   When True, the viewport follows new entries appended to the list.
    ///   Automatically cleared when the user scrolls up manually.
    /// </summary>
    property AutoFollow: Boolean read FAutoFollow write FAutoFollow;
    /// <summary>
    ///   Fired when the user presses Enter on a selected row.
    ///   The host should open a detail overlay inside this callback.
    /// </summary>
    property OnActivate: TLogActivateEvent read FOnActivate write FOnActivate;
    /// <summary>
    ///   Short name used by the status bar.
    /// </summary>
    property SectionName: string read FSectionName;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Dashboard.Consts,
  Dashboard.Helpers;

{ TDashboardLogTable }

constructor TDashboardLogTable.Create(AParent: TTuiWidget; AItems: TList<TLogEntry>);
begin
  inherited Create(AParent);
  FItems := AItems;
  FAutoFollow := True;
  FSectionName := 'Logs';
  FSelectedIndex := -1;
end;

procedure TDashboardLogTable.DoInit;
begin
  SetFocusable(True);
end;

function TDashboardLogTable.VisibleRows: Integer;
begin
  if LastRect.IsEmpty then
    Exit(0);
  var LInner := LastRect.Interior;
  Result := LInner.Height - 1; // subtract 1 for the header row
  if Result < 0 then
    Result := 0;
end;

procedure TDashboardLogTable.ClampScroll;
begin
  var LVis := VisibleRows;
  var LMax := FItems.Count - LVis;
  if LMax < 0 then
    LMax := 0;
  if FScrollOffset < 0 then
    FScrollOffset := 0;
  if FScrollOffset > LMax then
    FScrollOffset := LMax;
end;

procedure TDashboardLogTable.EnsureSelectedVisible;
begin
  if FSelectedIndex < 0 then
    Exit;
  var LVis := VisibleRows;
  if LVis <= 0 then
    Exit;
  if FSelectedIndex < FScrollOffset then
    FScrollOffset := FSelectedIndex
  else if FSelectedIndex >= FScrollOffset + LVis then
    FScrollOffset := FSelectedIndex - LVis + 1;
  ClampScroll;
end;

procedure TDashboardLogTable.ScrollToBottom;
begin
  var LVis := VisibleRows;
  FScrollOffset := FItems.Count - LVis;
  if FScrollOffset < 0 then
    FScrollOffset := 0;
end;

procedure TDashboardLogTable.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
var
  LBorderStyle, LHdrStyle, LBgStyle: TTuiStyle;
  LInner: TRect;
  LHdrY, LCol2, LCol3, LCol4, LCol5: Integer;
  LMsgMaxW: Integer;
begin
  if Focused then
    LBorderStyle := TTuiStyle.Create(CColorBorderFocus, CColorBlack)
  else
    LBorderStyle := TTuiStyle.Create(CColorBorderNormal, CColorBlack);

  LHdrStyle := TTuiStyle.Create(CColorDim, CColorBlack);
  LBgStyle := TTuiStyle.Create(CColorText, CColorBlack);

  ACanvas.DrawBox(ARect, bsRounded, '', LBorderStyle);
  LInner := ARect.Interior;
  if LInner.IsEmpty then
    Exit;

  ACanvas.FillRect(LInner, ' ', LBgStyle);

  ACanvas.PushClip(LInner);
  try
    // Column start positions (0-based from LInner.Left)
    LCol2 := LInner.Left + CColWidthTime + 1;    // Level starts here
    LCol3 := LCol2 + CColWidthLevel + 1;          // Host starts here
    LCol4 := LCol3 + CColWidthHost + 1;           // Service starts here
    LCol5 := LCol4 + CColWidthService + 1;        // Message starts here
    LMsgMaxW := LInner.Right - LCol5;

    // Header row
    LHdrY := LInner.Top;
    ACanvas.WriteAt(LInner.Left, LHdrY, PadRight(CColHdrTime, CColWidthTime), LHdrStyle);
    ACanvas.WriteAt(LCol2, LHdrY, PadRight(CColHdrLevel, CColWidthLevel), LHdrStyle);
    ACanvas.WriteAt(LCol3, LHdrY, PadRight(CColHdrHost, CColWidthHost), LHdrStyle);
    ACanvas.WriteAt(LCol4, LHdrY, PadRight(CColHdrService, CColWidthService), LHdrStyle);
    if LMsgMaxW > 0 then
      ACanvas.WriteAt(LCol5, LHdrY, TruncateStr(CColHdrMessage, LMsgMaxW), LHdrStyle);

    // Data rows
    ClampScroll;
    var LVis := LInner.Height - 1;
    for var LI := 0 to LVis - 1 do
    begin
      var LDataIdx := FScrollOffset + LI;
      if LDataIdx >= FItems.Count then
        Break;

      var LY := LInner.Top + 1 + LI;
      if LY >= LInner.Bottom then
        Break;

      var LEntry := FItems[LDataIdx];
      var LSelected := (LDataIdx = FSelectedIndex);
      var LHlBg := CColorBorderFocus;

      var LTimeStyle: TTuiStyle;
      var LLvlStyle:  TTuiStyle;
      var LHostStyle: TTuiStyle;
      var LSvcStyle: TTuiStyle;
      var LMsgStyle: TTuiStyle;
      if LSelected then
      begin
        LTimeStyle := TTuiStyle.Create(CColorBlack, LHlBg, [taBold]);
        LLvlStyle := TTuiStyle.Create(LevelColor(LEntry.Level), LHlBg, [taBold]);
        LHostStyle := TTuiStyle.Create(CColorBlack, LHlBg, [taBold]);
        LSvcStyle := TTuiStyle.Create(CColorBlack, LHlBg, [taBold]);
        LMsgStyle := TTuiStyle.Create(CColorBlack, LHlBg, [taBold]);
      end
      else
      begin
        LTimeStyle := TTuiStyle.Create(CColorTime, CColorBlack);
        LLvlStyle := LevelStyle(LEntry.Level);
        LHostStyle := TTuiStyle.Create(CColorHost, CColorBlack);
        LSvcStyle := TTuiStyle.Create(CColorService, CColorBlack);
        LMsgStyle := TTuiStyle.Create(CColorMessage, CColorBlack);
      end;

      ACanvas.WriteAt(LInner.Left, LY,
        PadRight(TruncateStr(LEntry.Time, CColWidthTime), CColWidthTime), LTimeStyle);
      ACanvas.WriteAt(LCol2, LY,
        PadRight(TruncateStr(LEntry.Level, CColWidthLevel), CColWidthLevel), LLvlStyle);
      ACanvas.WriteAt(LCol3, LY,
        PadRight(TruncateStr(LEntry.Host, CColWidthHost), CColWidthHost), LHostStyle);
      ACanvas.WriteAt(LCol4, LY,
        PadRight(TruncateStr(LEntry.Service, CColWidthService), CColWidthService), LSvcStyle);
      if LMsgMaxW > 0 then
        ACanvas.WriteAt(LCol5, LY,
          TruncateStr(LEntry.Message, LMsgMaxW), LMsgStyle);
    end;
  finally
    ACanvas.PopClip;
  end;
end;

function TDashboardLogTable.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;

  // --- Mouse events: wheel scrolls the viewport; left-click selects a row ---
  if AEvent.Kind = ekMouse then
  begin
    var LMouse := AEvent.Mouse;
    case LMouse.Kind of
      mekWheel:
      begin
        var LVis := VisibleRows;
        var LMax := FItems.Count - LVis;
        if LMax < 0 then
          LMax := 0;
        if LMouse.WheelDelta > 0 then
        begin
          // Scroll up
          FScrollOffset := FScrollOffset - 3;
          if FScrollOffset < 0 then
            FScrollOffset := 0;
          FAutoFollow := False;
        end
        else if LMouse.WheelDelta < 0 then
        begin
          // Scroll down
          FScrollOffset := FScrollOffset + 3;
          if FScrollOffset > LMax then
            FScrollOffset := LMax;
          FAutoFollow := (FScrollOffset >= LMax);
        end;
        Invalidate;
        Result := True;
      end;
      mekDown:
        if LMouse.Button = mbLeft then
        begin
          // Map the click Y position to a data row index
          var LRelY := LMouse.Y - LastRect.Interior.Top - 1; // -1 for header row
          var LDataIdx := FScrollOffset + LRelY;
          if (LRelY >= 0) and (LDataIdx >= 0) and (LDataIdx < FItems.Count) then
          begin
            FSelectedIndex := LDataIdx;
            Invalidate;
            Result := True;
          end;
        end;
    end;
    Exit;
  end;

  if AEvent.Kind <> ekKey then
    Exit;

  // --- Keyboard: cursor moves the selection; viewport follows ---
  case AEvent.Key.Code of
    kcUp:
    begin
      if FItems.Count > 0 then
      begin
        if FSelectedIndex < 0 then
          FSelectedIndex := FScrollOffset
        else if FSelectedIndex > 0 then
          Dec(FSelectedIndex);
        FAutoFollow := False;
        EnsureSelectedVisible;
        Invalidate;
      end;
      Result := True;
    end;
    kcDown:
    begin
      if FItems.Count > 0 then
      begin
        if FSelectedIndex < 0 then
          FSelectedIndex := FScrollOffset
        else if FSelectedIndex < FItems.Count - 1 then
          Inc(FSelectedIndex);
        FAutoFollow := (FSelectedIndex = FItems.Count - 1);
        EnsureSelectedVisible;
        Invalidate;
      end;
      Result := True;
    end;
    kcPageUp:
    begin
      if FItems.Count > 0 then
      begin
        var LStep := VisibleRows;
        if LStep < 1 then
          LStep := 1;
        if FSelectedIndex < 0 then
          FSelectedIndex := FScrollOffset
        else
        begin
          FSelectedIndex := FSelectedIndex - LStep;
          if FSelectedIndex < 0 then
            FSelectedIndex := 0;
        end;
        FAutoFollow := False;
        EnsureSelectedVisible;
        Invalidate;
      end;
      Result := True;
    end;
    kcPageDown:
    begin
      if FItems.Count > 0 then
      begin
        var LStep := VisibleRows;
        if LStep < 1 then
          LStep := 1;
        if FSelectedIndex < 0 then
          FSelectedIndex := FScrollOffset
        else
        begin
          FSelectedIndex := FSelectedIndex + LStep;
          if FSelectedIndex >= FItems.Count then
            FSelectedIndex := FItems.Count - 1;
        end;
        FAutoFollow := (FSelectedIndex = FItems.Count - 1);
        EnsureSelectedVisible;
        Invalidate;
      end;
      Result := True;
    end;
    kcHome:
    begin
      if FItems.Count > 0 then
        FSelectedIndex := 0;
      FAutoFollow := False;
      EnsureSelectedVisible;
      Invalidate;
      Result := True;
    end;
    kcEnd:
    begin
      if FItems.Count > 0 then
        FSelectedIndex := FItems.Count - 1;
      FAutoFollow := True;
      EnsureSelectedVisible;
      Invalidate;
      Result := True;
    end;
    kcEnter:
    begin
      if (FSelectedIndex >= 0) and (FSelectedIndex < FItems.Count) and
         Assigned(FOnActivate) then
        FOnActivate(FItems[FSelectedIndex]);
      Result := True;
    end;
  end;
end;

end.
