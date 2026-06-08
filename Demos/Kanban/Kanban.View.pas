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
{   Unit:        Kanban.View.pas                                 }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   KanbanDemo -- TKanbanView: full-board Kanban widget with 4 columns,
///   card rendering, keyboard navigation, and move/CRUD callbacks.
/// </summary>
unit Kanban.View;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  Kanban.Model;

type

{ TKanbanView }

  /// <summary>
  ///   Custom board widget: renders 4 side-by-side Kanban columns with card
  ///   boxes, badge and priority dot, and dispatches navigation and CRUD
  ///   callbacks on keyboard input. All drawing is done directly on the canvas
  ///   — no child widgets are created.
  /// </summary>
  TKanbanView = class(TTuiWidget)
  strict private
    FBadgeAutoStyle: TTuiStyle;
    FBadgePairStyle: TTuiStyle;
    FBorderNormalStyle: TTuiStyle;
    FBorderSelectedStyle: array[TKanbanStatus] of TTuiStyle;
    FCardBgStyle: TTuiStyle;
    FColumnHeaderStyle: array[TKanbanStatus] of TTuiStyle;
    FColumnTasks: array[TKanbanStatus] of TArray<TKanbanTask>;
    FModel: TKanbanModel;
    FOnChangeKind: TProc<TKanbanTask, TKanbanKind>;
    FOnChangePriority: TProc<TKanbanTask, TKanbanPriority>;
    FOnMoveTask: TProc<TKanbanTask, TKanbanStatus>;
    FOnRequestDelete: TProc<TKanbanTask>;
    FOnRequestEdit: TProc<TKanbanTask>;
    FOnRequestNew: TProc<TKanbanStatus>;
    FSelColumn: Integer;
    FSelRow: Integer;
    FSeparatorStyle: TTuiStyle;
    FTitleNormalStyle: TTuiStyle;
    FTitleSelectedStyle: TTuiStyle;
    procedure ClampSelection;
    procedure RebuildStyles(const ATheme: TTuiTheme);
    procedure RenderColumn(const ACanvas: TTuiCanvas; const AColRect: TRect;
      AStatus: TKanbanStatus; AIsCurrentCol: Boolean);
  protected
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Rebuilds the per-column task caches from the model and invalidates.
    /// </summary>
    procedure RefreshFromModel;
    /// <summary>
    ///   Sets the focused column to the given status and optionally positions
    ///   the selection on the last card in that column. Call after
    ///   RefreshFromModel when following a moved task to its destination column.
    /// </summary>
    procedure SelectColumn(AStatus: TKanbanStatus; ASelectLast: Boolean);
    /// <summary>
    ///   Returns the TKanbanStatus of the currently focused column.
    /// </summary>
    function SelectedStatus: TKanbanStatus;
    /// <summary>
    ///   Returns True and sets ATask to the focused card when one exists.
    /// </summary>
    function SelectedTask(out ATask: TKanbanTask): Boolean;
    /// <summary>
    ///   Binds the widget to a model. Does not take ownership.
    /// </summary>
    procedure SetModel(AModel: TKanbanModel);
    /// <summary>
    ///   Fired when the user presses 'k' to cycle the Kind of the focused task.
    /// </summary>
    property OnChangeKind: TProc<TKanbanTask, TKanbanKind>
      read FOnChangeKind write FOnChangeKind;
    /// <summary>
    ///   Fired when the user presses 'p' to cycle the Priority of the focused task.
    /// </summary>
    property OnChangePriority: TProc<TKanbanTask, TKanbanPriority>
      read FOnChangePriority write FOnChangePriority;
    /// <summary>
    ///   Fired when the user presses Shift+Left or Shift+Right to move a task.
    /// </summary>
    property OnMoveTask: TProc<TKanbanTask, TKanbanStatus>
      read FOnMoveTask write FOnMoveTask;
    /// <summary>
    ///   Fired when the user presses 'd' to request deletion of the focused task.
    /// </summary>
    property OnRequestDelete: TProc<TKanbanTask>
      read FOnRequestDelete write FOnRequestDelete;
    /// <summary>
    ///   Fired when the user presses 'e' to request editing of the focused task.
    /// </summary>
    property OnRequestEdit: TProc<TKanbanTask>
      read FOnRequestEdit write FOnRequestEdit;
    /// <summary>
    ///   Fired when the user presses 'n' to request a new task in the focused column.
    /// </summary>
    property OnRequestNew: TProc<TKanbanStatus>
      read FOnRequestNew write FOnRequestNew;
  end;

implementation

uses
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Kanban.Consts,
  Kanban.Helpers;

{ TKanbanView }

constructor TKanbanView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
end;

procedure TKanbanView.DoInit;
begin
  SetFocusable(True);
end;

procedure TKanbanView.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles(ATheme);
  inherited DoApplyTheme(ATheme);
end;

procedure TKanbanView.RebuildStyles(const ATheme: TTuiTheme);
begin
  FBadgeAutoStyle := TTuiStyle.Create(KindBadgeColor(kkAuto, ATheme), ATheme.Surface);
  FBadgePairStyle := TTuiStyle.Create(KindBadgeColor(kkPair, ATheme), ATheme.Surface);
  FBorderNormalStyle := TTuiStyle.Create(ATheme.Border, ATheme.Surface);
  FCardBgStyle := TTuiStyle.Create(ATheme.Text, ATheme.Surface);
  FSeparatorStyle := TTuiStyle.Create(ATheme.Border, ATheme.Background);
  FTitleNormalStyle := TTuiStyle.Create(ATheme.Text, ATheme.Surface);
  FTitleSelectedStyle := TTuiStyle.Create(ATheme.Text, ATheme.Surface, [taBold]);
  for var LStatus := Low(TKanbanStatus) to High(TKanbanStatus) do
  begin
    var LAccent := StatusAccentColor(LStatus, ATheme);
    FColumnHeaderStyle[LStatus] := TTuiStyle.Create(ATheme.Background, LAccent, [taBold]);
    FBorderSelectedStyle[LStatus] := TTuiStyle.Create(LAccent, ATheme.Surface, [taBold]);
  end;
end;

procedure TKanbanView.ClampSelection;
begin
  var LStatus := TKanbanStatus(FSelColumn);
  var LCount := Length(FColumnTasks[LStatus]);
  FSelRow := Max(0, Min(FSelRow, LCount - 1));
end;

procedure TKanbanView.SelectColumn(AStatus: TKanbanStatus; ASelectLast: Boolean);
begin
  FSelColumn := Ord(AStatus);
  if ASelectLast then
    FSelRow := Max(0, Length(FColumnTasks[AStatus]) - 1)
  else
    ClampSelection;
  Invalidate;
end;

procedure TKanbanView.SetModel(AModel: TKanbanModel);
begin
  FModel := AModel;
  RefreshFromModel;
end;

procedure TKanbanView.RefreshFromModel;
begin
  if not Assigned(FModel) then
    Exit;
  for var LStatus := Low(TKanbanStatus) to High(TKanbanStatus) do
    FColumnTasks[LStatus] := FModel.TasksByStatus(LStatus);
  ClampSelection;
  Invalidate;
end;

function TKanbanView.SelectedStatus: TKanbanStatus;
begin
  Result := TKanbanStatus(FSelColumn);
end;

function TKanbanView.SelectedTask(out ATask: TKanbanTask): Boolean;
begin
  var LStatus := TKanbanStatus(FSelColumn);
  var LTasks := FColumnTasks[LStatus];
  if (FSelRow >= 0) and (FSelRow < Length(LTasks)) then
  begin
    ATask := LTasks[FSelRow];
    Result := True;
  end
  else
    Result := False;
end;

procedure TKanbanView.RenderColumn(const ACanvas: TTuiCanvas;
  const AColRect: TRect; AStatus: TKanbanStatus; AIsCurrentCol: Boolean);
begin
  var LIsLastCol := AStatus = ksDone;

  // --- header row: vivid accent band per column ---
  ACanvas.FillRect(
    TRect.Create(AColRect.Left, AColRect.Top, AColRect.Right, AColRect.Top + 1),
    ' ', FColumnHeaderStyle[AStatus]);

  var LTasks := FColumnTasks[AStatus];
  var LTaskCount := Length(LTasks);
  var LHeaderText := StatusColumnTitle(AStatus) + '  ' + IntToStr(LTaskCount);

  // Centered title: bold, Theme.Background foreground on vivid accent band
  var LHeaderX := AColRect.Left + Max(0, (AColRect.Width - Length(LHeaderText)) div 2);
  ACanvas.WriteAt(LHeaderX, AColRect.Top, LHeaderText, FColumnHeaderStyle[AStatus]);

  // --- vertical separator to the right (all columns except the last) ---
  if not LIsLastCol then
  begin
    for var LY := AColRect.Top to AColRect.Bottom - 1 do
      ACanvas.WriteAt(AColRect.Right - 1, LY, '│', FSeparatorStyle);
  end;

  // --- cards, starting at row 2 of the column ---
  var LCardY := AColRect.Top + 2;

  // Determine horizontal extents for card box
  var LCardLeft := AColRect.Left + 1;
  var LCardRight: Integer;
  if LIsLastCol then
    LCardRight := AColRect.Right - 1
  else
    LCardRight := AColRect.Right - 2;

  for var LIdx := 0 to LTaskCount - 1 do
  begin
    // Each card is 4 rows tall; stop if there is not enough vertical space
    if LCardY + 4 > AColRect.Bottom then
      Break;

    var LTask := LTasks[LIdx];
    var LCardRect := TRect.Create(LCardLeft, LCardY, LCardRight, LCardY + 4);

    // Determine border style: selected card in active column uses status accent
    var LBorderStyle: TTuiStyle;
    if AIsCurrentCol and (LIdx = FSelRow) then
      LBorderStyle := FBorderSelectedStyle[AStatus]
    else
      LBorderStyle := FBorderNormalStyle;

    // Fill card background (inner area, inside the border)
    ACanvas.FillRect(
      TRect.Create(LCardRect.Left + 1, LCardRect.Top + 1,
        LCardRect.Right - 1, LCardRect.Bottom - 1),
      ' ', FCardBgStyle);

    // Draw card border
    ACanvas.DrawBox(LCardRect, bsRounded, '', LBorderStyle);

    // Row 1: task title (truncated to fit inner width)
    var LInnerWidth := LCardRect.Width - 2;
    if LInnerWidth < 1 then
      LInnerWidth := 1;

    var LTitle := LTask.Title;
    if Length(LTitle) > LInnerWidth then
    begin
      if LInnerWidth > 3 then
        LTitle := Copy(LTitle, 1, LInnerWidth - 3) + '...'
      else
        LTitle := Copy(LTitle, 1, LInnerWidth);
    end;

    var LTitleStyle: TTuiStyle;
    if AIsCurrentCol and (LIdx = FSelRow) then
      LTitleStyle := FTitleSelectedStyle
    else
      LTitleStyle := FTitleNormalStyle;

    ACanvas.WriteAt(LCardRect.Left + 1, LCardRect.Top + 1, LTitle, LTitleStyle);

    // Row 2: kind badge + priority dot
    var LBadgeText := '[' + KindBadgeText(LTask.Kind) + ']';
    var LBadgeStyle: TTuiStyle;
    if LTask.Kind = kkAuto then
      LBadgeStyle := FBadgeAutoStyle
    else
      LBadgeStyle := FBadgePairStyle;

    ACanvas.WriteAt(LCardRect.Left + 1, LCardRect.Top + 2, LBadgeText, LBadgeStyle);

    // Priority dot — placed after the badge with one space gap
    var LDotStyle := TTuiStyle.Create(
      PriorityDotColor(LTask.Priority, Theme), Theme.Surface);
    ACanvas.WriteAt(
      LCardRect.Left + 1 + Length(LBadgeText) + 1,
      LCardRect.Top + 2,
      CGlyphDot,
      LDotStyle);

    Inc(LCardY, 5); // 4 rows card + 1 gap row
  end;
end;

procedure TKanbanView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
var
  LColW: Integer;
  LStatusIdx: Integer;
  LStatus: TKanbanStatus;
  LColLeft: Integer;
  LColRight: Integer;
  LColRect: TRect;
begin
  if ARect.IsEmpty then
    Exit;

  // Fill background
  ACanvas.FillRect(ARect, ' ',
    TTuiStyle.Create(Theme.Text, Theme.Background));

  LColW := ARect.Width div CKanbanColumnCount;

  for LStatusIdx := 0 to CKanbanColumnCount - 1 do
  begin
    LStatus := TKanbanStatus(LStatusIdx);
    LColLeft := ARect.Left + LStatusIdx * LColW;

    // Last column stretches to ARect.Right to absorb rounding remainder
    if LStatusIdx = CKanbanColumnCount - 1 then
      LColRight := ARect.Right
    else
      LColRight := LColLeft + LColW;

    LColRect := TRect.Create(LColLeft, ARect.Top, LColRight, ARect.Bottom);

    ACanvas.PushClip(LColRect);
    try
      RenderColumn(ACanvas, LColRect, LStatus, LStatusIdx = FSelColumn);
    finally
      ACanvas.PopClip;
    end;
  end;
end;

function TKanbanView.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
var
  LTask: TKanbanTask;
  LCount: Integer;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;

  case AEvent.Key.Code of
    kcLeft:
    begin
      if kmShift in AEvent.Key.Modifiers then
      begin
        // Move focused task one column to the left
        if (FSelColumn > 0) and SelectedTask(LTask) then
        begin
          if Assigned(FOnMoveTask) then
            FOnMoveTask(LTask, TKanbanStatus(FSelColumn - 1));
          Result := True;
        end;
      end
      else
      begin
        // Navigate to the left column
        if FSelColumn > 0 then
        begin
          Dec(FSelColumn);
          ClampSelection;
          Invalidate;
        end;
        Result := True;
      end;
    end;

    kcRight:
    begin
      if kmShift in AEvent.Key.Modifiers then
      begin
        // Move focused task one column to the right
        if (FSelColumn < CKanbanColumnCount - 1) and SelectedTask(LTask) then
        begin
          if Assigned(FOnMoveTask) then
            FOnMoveTask(LTask, TKanbanStatus(FSelColumn + 1));
          Result := True;
        end;
      end
      else
      begin
        // Navigate to the right column
        if FSelColumn < CKanbanColumnCount - 1 then
        begin
          Inc(FSelColumn);
          ClampSelection;
          Invalidate;
        end;
        Result := True;
      end;
    end;

    kcUp:
    begin
      LCount := Length(FColumnTasks[TKanbanStatus(FSelColumn)]);
      if (FSelRow > 0) and (LCount > 0) then
      begin
        Dec(FSelRow);
        Invalidate;
      end;
      Result := True;
    end;

    kcDown:
    begin
      LCount := Length(FColumnTasks[TKanbanStatus(FSelColumn)]);
      if FSelRow < LCount - 1 then
      begin
        Inc(FSelRow);
        Invalidate;
      end;
      Result := True;
    end;

    kcChar:
    begin
      case AEvent.Key.Character of
        'n', 'N':
        begin
          if Assigned(FOnRequestNew) then
            FOnRequestNew(SelectedStatus);
          Result := True;
        end;
        'e', 'E':
        begin
          if SelectedTask(LTask) and Assigned(FOnRequestEdit) then
            FOnRequestEdit(LTask);
          Result := True;
        end;
        'p', 'P':
        begin
          if SelectedTask(LTask) and Assigned(FOnChangePriority) then
          begin
            var LNewPriority := TKanbanPriority(
              (Ord(LTask.Priority) + 1) mod (Ord(High(TKanbanPriority)) + 1));
            FOnChangePriority(LTask, LNewPriority);
          end;
          Result := True;
        end;
        'k', 'K':
        begin
          if SelectedTask(LTask) and Assigned(FOnChangeKind) then
          begin
            var LNewKind := TKanbanKind(
              (Ord(LTask.Kind) + 1) mod (Ord(High(TKanbanKind)) + 1));
            FOnChangeKind(LTask, LNewKind);
          end;
          Result := True;
        end;
        'd', 'D':
        begin
          if SelectedTask(LTask) and Assigned(FOnRequestDelete) then
            FOnRequestDelete(LTask);
          Result := True;
        end;
      end;
    end;
  end;
end;

end.
