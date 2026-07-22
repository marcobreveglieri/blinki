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
{   Unit:        Blinki.Widgets.Table.pas                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TTuiTable widget: data table with colorable header, auto-sizing columns,
///   vertical viewport scroll, interactive and programmatic per-column sort.
/// </summary>
unit Blinki.Widgets.Table;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget;

type

{ TTuiTableAlignment }

  /// <summary>
  ///   Horizontal text alignment within a column.
  /// </summary>
  TTuiTableAlignment = (
    /// <summary>
    ///   Text aligned to the left (default).
    /// </summary>
    taLeft,
    /// <summary>
    ///   Text centered.
    /// </summary>
    taCenter,
    /// <summary>
    ///   Text aligned to the right.
    /// </summary>
    taRight
  );

{ TTuiTableSortDir }

  /// <summary>
  ///   Sort direction for a column.
  /// </summary>
  TTuiTableSortDir = (
    /// <summary>
    ///   No active sort.
    /// </summary>
    sdNone,
    /// <summary>
    ///   Ascending sort order.
    /// </summary>
    sdAsc,
    /// <summary>
    ///   Descending sort order.
    /// </summary>
    sdDesc
  );

{ TTuiTableColumn }

  /// <summary>
  ///   Definition of a table column.
  /// </summary>
  TTuiTableColumn = record
    /// <summary>
    ///   Column header caption.
    /// </summary>
    Caption: string;
    /// <summary>
    ///   Width in characters. 0 = auto-sized from content.
    /// </summary>
    Width: Integer;
    /// <summary>
    ///   Text alignment within the column.
    /// </summary>
    Alignment: TTuiTableAlignment;
  end;

{ TTuiTable }

  /// <summary>
  ///   Keyboard-navigable data table. Supports colorable header, auto-sizing columns,
  ///   viewport scroll (TTuiSelect pattern), interactive sort (Left/Right to change
  ///   column, S to cycle direction) and programmatic sort via Sort(). Becomes
  ///   focusable in DoInit.
  /// </summary>
  TTuiTable = class(TTuiWidget)
  strict private
    FColumns: array of TTuiTableColumn;
    FColCount: Integer;
    FRows: TList<TArray<string>>;
    FItemIndex: Integer;
    FViewOffset: Integer;
    FLastViewHeight: Integer;
    FSortColumn: Integer;
    FSortDir: TTuiTableSortDir;
    FSortFocus: Integer;
    FShowHeader: Boolean;
    FShowBorder: Boolean;
    FOnSelectionChanged: TProc<Integer>;
    FOnRowActivated: TProc<Integer>;
    FHeaderNormalStyle: TTuiStyle;
    FHeaderFocusStyle: TTuiStyle;
    FRowNormalStyle: TTuiStyle;
    FRowSelectedStyle: TTuiStyle;
    FRowSelectedFocusedStyle: TTuiStyle;
    FSepStyle: TTuiStyle;
    // Cache for ComputeWidths: valid only for FWidthsCacheContentW and
    // invalidated by AddColumn/AddRow/ClearRows (the only row/column
    // mutators). Sorting does not invalidate it: reordering rows does not
    // change any cell's visible length.
    FWidthsCache: TArray<Integer>;
    FWidthsCacheValid: Boolean;
    FWidthsCacheContentW: Integer;
    procedure SetItemIndex(AValue: Integer);
    procedure SetSortColumn(AValue: Integer);
    procedure SetSortDir(AValue: TTuiTableSortDir);
    procedure SetShowHeader(AValue: Boolean);
    procedure SetShowBorder(AValue: Boolean);
    procedure ComputeWidths(AContentW: Integer; out AWidths: TArray<Integer>);
    procedure AdjustViewOffset(AViewH: Integer);
    procedure ApplySort;
    function  RowsMatch(const A, B: TArray<string>): Boolean;
    procedure RebuildStyles;
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function  DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the table. ItemIndex: -1; SortColumn: -1; ShowHeader: True; ShowBorder: True.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <inheritdoc/>
    destructor Destroy; override;
    /// <summary>
    ///   Adds a column with Width=0 (auto) and the specified alignment.
    /// </summary>
    procedure AddColumn(const ACaption: string; AWidth: Integer = 0;
      AAlign: TTuiTableAlignment = taLeft);
    /// <summary>
    ///   Adds a data row. Cells beyond the column count are ignored.
    /// </summary>
    procedure AddRow(const AValues: array of string);
    /// <summary>
    ///   Removes all data rows. Resets ItemIndex and scroll offset to zero.
    /// </summary>
    procedure ClearRows;
    /// <summary>
    ///   Sorts the table by column AColumn in the given ADirection.
    /// </summary>
    procedure Sort(AColumn: Integer; ADirection: TTuiTableSortDir);
    /// <summary>
    ///   Index of the selected row (-1 = none).
    /// </summary>
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
    /// <summary>
    ///   Currently sorted column (-1 = none).
    /// </summary>
    property SortColumn: Integer read FSortColumn write SetSortColumn;
    /// <summary>
    ///   Current sort direction.
    /// </summary>
    property SortDir: TTuiTableSortDir read FSortDir write SetSortDir;
    /// <summary>
    ///   When True (default), shows the header row with column captions.
    /// </summary>
    property ShowHeader: Boolean read FShowHeader write SetShowHeader;
    /// <summary>
    ///   When True (default), draws the outer border (DrawBox Rounded).
    /// </summary>
    property ShowBorder: Boolean read FShowBorder write SetShowBorder;
    /// <summary>
    ///   Fired when the selection changes; receives the new index.
    /// </summary>
    property OnSelectionChanged: TProc<Integer> read FOnSelectionChanged write FOnSelectionChanged;
    /// <summary>
    ///   Fired when the user presses Enter on a row; receives the row index.
    /// </summary>
    property OnRowActivated: TProc<Integer> read FOnRowActivated write FOnRowActivated;
  end;

implementation

uses
  System.Generics.Defaults,
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Input;

/// <summary>
///   Align the text in a cell given a width in characters.
/// </summary>
function CellText(const AText: string; AWidth: Integer;
  AAlign: TTuiTableAlignment): string;
begin
  if AWidth <= 0 then
  begin
    Result := '';
    Exit;
  end;
  var LTrunc := TTuiAnsi.TruncateToWidth(AText, AWidth);
  var LVisibleLen := TTuiAnsi.VisibleLength(LTrunc);
  case AAlign of
    taLeft:
      Result := LTrunc + StringOfChar(' ', AWidth - LVisibleLen);
    taRight:
      Result := StringOfChar(' ', AWidth - LVisibleLen) + LTrunc;
    taCenter:
    begin
      var LPad := (AWidth - LVisibleLen) div 2;
      Result := StringOfChar(' ', LPad) + LTrunc
              + StringOfChar(' ', AWidth - LVisibleLen - LPad);
    end;
  else
    Result := LTrunc + StringOfChar(' ', AWidth - LVisibleLen);
  end;
end;

{ TTuiTable }

constructor TTuiTable.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FRows := TList<TArray<string>>.Create;
  FItemIndex := -1;
  FSortColumn := -1;
  FShowHeader := True;
  FShowBorder := True;
  FSortDir := sdNone;
  RebuildStyles;
end;

destructor TTuiTable.Destroy;
begin
  if Assigned(FRows) then
    FreeAndNil(FRows);
  inherited Destroy;
end;

procedure TTuiTable.RebuildStyles;
begin
  FHeaderNormalStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
  FHeaderFocusStyle := TTuiStyle.Create(Theme.Primary, Theme.Surface, [taBold]);
  FRowNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  FRowSelectedStyle := TTuiStyle.Create(Theme.Text, Theme.Border);
  FRowSelectedFocusedStyle := TTuiStyle.Create(Theme.Background, Theme.Primary);
  FSepStyle := TTuiStyle.Create(Theme.Border, Theme.Surface);
end;

procedure TTuiTable.DoInit;
begin
  SetFocusable(True);
  if (FItemIndex = -1) and (FRows.Count > 0) then
    FItemIndex := 0;
end;

procedure TTuiTable.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TTuiTable.AddColumn(const ACaption: string; AWidth: Integer;
  AAlign: TTuiTableAlignment);
begin
  var LCol: TTuiTableColumn;
  LCol.Caption := ACaption;
  LCol.Width := AWidth;
  LCol.Alignment := AAlign;
  if FColCount >= Length(FColumns) then
    SetLength(FColumns, Max(4, FColCount * 2));
  FColumns[FColCount] := LCol;
  Inc(FColCount);
  if FSortFocus >= FColCount then
    FSortFocus := FColCount - 1;
  FWidthsCacheValid := False;
  Invalidate;
end;

procedure TTuiTable.AddRow(const AValues: array of string);
begin
  var LLen := Length(AValues);
  var LRow: TArray<string>;
  SetLength(LRow, LLen);
  for var LIndex := 0 to LLen - 1 do
    LRow[LIndex] := AValues[LIndex];
  FRows.Add(LRow);
  if (FItemIndex = -1) and (FRows.Count = 1) then
    FItemIndex := 0;
  FWidthsCacheValid := False;
  Invalidate;
end;

procedure TTuiTable.ClearRows;
begin
  FRows.Clear;
  FItemIndex := -1;
  FViewOffset := 0;
  FWidthsCacheValid := False;
  Invalidate;
end;

procedure TTuiTable.Sort(AColumn: Integer; ADirection: TTuiTableSortDir);
begin
  if AColumn < 0 then
    AColumn := -1;
  if AColumn >= FColCount then
    AColumn := FColCount - 1;
  FSortColumn := AColumn;
  FSortDir := ADirection;
  if AColumn >= 0 then
    FSortFocus := AColumn;
  ApplySort;
end;

function TTuiTable.RowsMatch(const A, B: TArray<string>): Boolean;
begin
  Result := False;
  if Length(A) <> Length(B) then
    Exit;
  for var LIndex := 0 to Length(A) - 1 do
    if A[LIndex] <> B[LIndex] then
      Exit;
  Result := True;
end;

procedure TTuiTable.ApplySort;
begin
  if (FSortColumn < 0) or (FSortDir = sdNone) then
  begin
    Invalidate;
    Exit;
  end;

  var LSaved: TArray<string>;
  if (FItemIndex >= 0) and (FItemIndex < FRows.Count) then
    LSaved := FRows[FItemIndex]
  else
    LSaved := nil;

  var LCol := FSortColumn;
  var LDir := FSortDir;

  FRows.Sort(TComparer<TArray<string>>.Construct(
    function(const Left, Right: TArray<string>): Integer
    begin
      if LCol >= Length(Left) then
        Result := -1
      else if LCol >= Length(Right) then
        Result := 1
      else
      begin
        var LA := Left[LCol];
        var LB := Right[LCol];
        var LAF, LBF: Double;
        if TryStrToFloat(LA, LAF) and TryStrToFloat(LB, LBF) then
          Result := CompareValue(LAF, LBF)
        else
          Result := CompareText(LA, LB);
        if LDir = sdDesc then
          Result := -Result;
      end;
    end
  ));

  if Assigned(LSaved) then
  begin
    for var LIndex := 0 to FRows.Count - 1 do
      if RowsMatch(FRows[LIndex], LSaved) then
      begin
        FItemIndex := LIndex;
        Break;
      end;
  end;

  Invalidate;
end;

procedure TTuiTable.AdjustViewOffset(AViewH: Integer);
begin
  if AViewH <= 0 then
    Exit;
  if FItemIndex < FViewOffset then
    FViewOffset := FItemIndex;
  if FItemIndex >= FViewOffset + AViewH then
    FViewOffset := FItemIndex - AViewH + 1;
  if FViewOffset < 0 then
    FViewOffset := 0;
end;

procedure TTuiTable.ComputeWidths(AContentW: Integer; out AWidths: TArray<Integer>);
begin
  // DoRender calls this every frame; the result only depends on FColumns,
  // FRows content and AContentW (see the field comment), so a cache keyed on
  // AContentW avoids rescanning every row with TTuiAnsi.VisibleLength when
  // nothing relevant has changed. AWidths aliases the cached array (dynamic
  // arrays are reference-counted) — callers must treat it as read-only,
  // which DoRender already does.
  if FWidthsCacheValid and (FWidthsCacheContentW = AContentW) then
  begin
    AWidths := FWidthsCache;
    Exit;
  end;

  SetLength(AWidths, FColCount);
  if FColCount = 0 then
  begin
    FWidthsCache := AWidths;
    FWidthsCacheContentW := AContentW;
    FWidthsCacheValid := True;
    Exit;
  end;

  var LSepTotal := Max(0, FColCount - 1);
  var LFixedSumW := 0;
  var LAutoSumW := 0;
  var LAutoCount := 0;

  for var LIndex := 0 to FColCount - 1 do
  begin
    if FColumns[LIndex].Width > 0 then
    begin
      AWidths[LIndex] := FColumns[LIndex].Width;
      Inc(LFixedSumW, AWidths[LIndex]);
    end
    else
    begin
      var LMaxW := TTuiAnsi.VisibleLength(FColumns[LIndex].Caption);
      for var LJ := 0 to FRows.Count - 1 do
        if LIndex < Length(FRows[LJ]) then
          LMaxW := Max(LMaxW, TTuiAnsi.VisibleLength(FRows[LJ][LIndex]));
      LMaxW := Min(Max(LMaxW, 1), 32);
      AWidths[LIndex] := LMaxW;
      Inc(LAutoSumW, LMaxW);
      Inc(LAutoCount);
    end;
  end;

  var LResidual := AContentW - LFixedSumW - LSepTotal;
  if LResidual < LAutoCount then
    LResidual := LAutoCount;

  if (LAutoCount > 0) and (LAutoSumW <> LResidual) then
  begin
    var LAssigned := 0;
    var LLastAuto := -1;
    for var LIndex := 0 to FColCount - 1 do
    begin
      if FColumns[LIndex].Width = 0 then
      begin
        if LAutoSumW > 0 then
          AWidths[LIndex] := Round(AWidths[LIndex] / LAutoSumW * LResidual)
        else
          AWidths[LIndex] := LResidual div LAutoCount;
        if AWidths[LIndex] < 1 then
          AWidths[LIndex] := 1;
        Inc(LAssigned, AWidths[LIndex]);
        LLastAuto := LIndex;
      end;
    end;
    if LLastAuto >= 0 then
    begin
      Inc(AWidths[LLastAuto], LResidual - LAssigned);
      if AWidths[LLastAuto] < 1 then
        AWidths[LLastAuto] := 1;
    end;
  end;

  FWidthsCache := AWidths;
  FWidthsCacheContentW := AContentW;
  FWidthsCacheValid := True;
end;

procedure TTuiTable.SetItemIndex(AValue: Integer);
begin
  if FRows.Count = 0 then
  begin
    if FItemIndex <> -1 then
    begin
      FItemIndex := -1;
      Invalidate;
    end;
    Exit;
  end;
  if AValue < 0 then
    AValue := 0;
  if AValue >= FRows.Count then
    AValue := FRows.Count - 1;
  if FItemIndex = AValue then
    Exit;
  FItemIndex := AValue;
  if Assigned(FOnSelectionChanged) then
    FOnSelectionChanged(FItemIndex);
  Invalidate;
end;

procedure TTuiTable.SetSortColumn(AValue: Integer);
begin
  if AValue < -1 then
    AValue := -1;
  if AValue >= FColCount then
    AValue := FColCount - 1;
  if FSortColumn = AValue then
    Exit;
  FSortColumn := AValue;
  ApplySort;
end;

procedure TTuiTable.SetSortDir(AValue: TTuiTableSortDir);
begin
  if FSortDir = AValue then
    Exit;
  FSortDir := AValue;
  ApplySort;
end;

procedure TTuiTable.SetShowHeader(AValue: Boolean);
begin
  if FShowHeader = AValue then
    Exit;
  FShowHeader := AValue;
  Invalidate;
end;

procedure TTuiTable.SetShowBorder(AValue: Boolean);
begin
  if FShowBorder = AValue then
    Exit;
  FShowBorder := AValue;
  Invalidate;
end;

procedure TTuiTable.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  ACanvas.FillRect(ARect, ' ', FRowNormalStyle);

  var LInner: TRect;
  if FShowBorder then
  begin
    ACanvas.DrawBox(ARect, bsRounded, '', FSepStyle);
    LInner := TRect.Create(ARect.Left + 1, ARect.Top + 1,
                           ARect.Right - 1, ARect.Bottom - 1);
  end
  else
    LInner := ARect;

  if LInner.IsEmpty or (FColCount = 0) then
    Exit;

  ACanvas.FillRect(LInner, ' ', FRowNormalStyle);
  var LWidths: TArray<Integer>;
  ComputeWidths(LInner.Width, LWidths);

  // Header
  var LHeaderRows: Integer;
  if FShowHeader then
  begin
    // Column caption row
    var LColX := LInner.Left;
    for var LI := 0 to FColCount - 1 do
    begin
      if LColX >= LInner.Right then
        Break;
      var LStyle: TTuiStyle;
      if LI = FSortFocus then
        LStyle := FHeaderFocusStyle
      else
        LStyle := FHeaderNormalStyle;
      // Compute caption with sort indicator
      var LSortMark: string;
      if (LI = FSortColumn) and (FSortDir <> sdNone) then
      begin
        if FSortDir = sdAsc then
          LSortMark := #$25B2  // ▲
        else
          LSortMark := #$25BC; // ▼
      end
      else
        LSortMark := '';
      var LCaption := FColumns[LI].Caption;
      if LSortMark <> '' then
        LCaption := LCaption + ' ' + LSortMark;
      LCaption := CellText(LCaption, LWidths[LI], taLeft);
      ACanvas.FillRect(
        TRect.Create(LColX, LInner.Top, Min(LColX + LWidths[LI], LInner.Right), LInner.Top + 1),
        ' ', LStyle);
      ACanvas.WriteAt(LColX, LInner.Top, LCaption, LStyle);
      Inc(LColX, LWidths[LI]);
      // Vertical separator
      if LI < FColCount - 1 then
      begin
        if LColX < LInner.Right then
          ACanvas.WriteAt(LColX, LInner.Top, #$2502, FSepStyle);
        Inc(LColX);
      end;
    end;

    // Horizontal separator header/body
    if LInner.Top + 1 < LInner.Bottom then
    begin
      LColX := LInner.Left;
      for var LI := 0 to FColCount - 1 do
      begin
        if LColX >= LInner.Right then
          Break;
        for var LJ := 0 to LWidths[LI] - 1 do
        begin
          if LColX + LJ < LInner.Right then
            ACanvas.WriteAt(LColX + LJ, LInner.Top + 1, #$2500, FSepStyle);
        end;
        Inc(LColX, LWidths[LI]);
        if LI < FColCount - 1 then
        begin
          if LColX < LInner.Right then
            ACanvas.WriteAt(LColX, LInner.Top + 1, #$253C, FSepStyle);
          Inc(LColX);
        end;
      end;
    end;

    LHeaderRows := 2;
  end
  else
    LHeaderRows := 0;

  var LBodyTop := LInner.Top + LHeaderRows;
  var LViewH := LInner.Bottom - LBodyTop;
  if LViewH <= 0 then
    Exit;

  FLastViewHeight := LViewH;
  if FItemIndex >= 0 then
    AdjustViewOffset(LViewH);

  // Data rows
  for var LI := FViewOffset to FViewOffset + LViewH - 1 do
  begin
    if LI >= FRows.Count then
      Break;
    var LRowY := LBodyTop + (LI - FViewOffset);
    var LRow := FRows[LI];
    // Row style
    var LRowStyle: TTuiStyle;
    if LI = FItemIndex then
    begin
      if Focused then
        LRowStyle := FRowSelectedFocusedStyle
      else
        LRowStyle := FRowSelectedStyle;
    end
    else
      LRowStyle := FRowNormalStyle;
    ACanvas.FillRect(
      TRect.Create(LInner.Left, LRowY, LInner.Right, LRowY + 1),
      ' ', LRowStyle);
    // Cells
    var LColX := LInner.Left;
    for var LJ := 0 to FColCount - 1 do
    begin
      if LColX >= LInner.Right then
        Break;
      var LCellVal: string;
      if LJ < Length(LRow) then
        LCellVal := LRow[LJ]
      else
        LCellVal := '';
      ACanvas.WriteAt(LColX, LRowY,
        CellText(LCellVal, LWidths[LJ], FColumns[LJ].Alignment), LRowStyle);
      Inc(LColX, LWidths[LJ]);
      if LJ < FColCount - 1 then
      begin
        if LColX < LInner.Right then
          ACanvas.WriteAt(LColX, LRowY, #$2502, FSepStyle);
        Inc(LColX);
      end;
    end;
  end;
end;

function TTuiTable.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  if FRows.Count = 0 then
    Exit;

  var LPageStep := Max(1, FLastViewHeight);

  case AEvent.Key.Code of
    kcUp:
      begin
        SetItemIndex(Max(0, FItemIndex - 1));
        Result := True;
      end;
    kcDown:
      begin
        SetItemIndex(Min(FRows.Count - 1, FItemIndex + 1));
        Result := True;
      end;
    kcHome:
      begin
        SetItemIndex(0);
        Result := True;
      end;
    kcEnd:
      begin
        SetItemIndex(FRows.Count - 1);
        Result := True;
      end;
    kcPageUp:
      begin
        SetItemIndex(Max(0, FItemIndex - LPageStep));
        Result := True;
      end;
    kcPageDown:
      begin
        SetItemIndex(Min(FRows.Count - 1, FItemIndex + LPageStep));
        Result := True;
      end;
    kcLeft:
      begin
        if FColCount > 0 then
        begin
          FSortFocus := (FSortFocus - 1 + FColCount) mod FColCount;
          Invalidate;
        end;
        Result := True;
      end;
    kcRight:
      begin
        if FColCount > 0 then
        begin
          FSortFocus := (FSortFocus + 1) mod FColCount;
          Invalidate;
        end;
        Result := True;
      end;
    kcEnter:
      begin
        if Assigned(FOnRowActivated) and (FItemIndex >= 0) then
          FOnRowActivated(FItemIndex);
        Result := True;
      end;
    kcChar:
      begin
        if UpCase(AEvent.Key.Character) = 'S' then
        begin
          // Cycle sort: sdNone -> sdAsc -> sdDesc -> sdNone
          if FSortColumn <> FSortFocus then
          begin
            // Column change: reset to Asc
            FSortColumn := FSortFocus;
            FSortDir := sdAsc;
          end
          else
          begin
            var LNext: TTuiTableSortDir;
            case FSortDir of
              sdNone: LNext := sdAsc;
              sdAsc:  LNext := sdDesc;
              sdDesc: LNext := sdNone;
            else      LNext := sdNone;
            end;
            FSortDir := LNext;
            if FSortDir = sdNone then
              FSortColumn := -1;
          end;
          ApplySort;
          Result := True;
        end;
      end;
  end;
end;

end.
