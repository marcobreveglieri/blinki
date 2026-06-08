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
{   Unit:        ResTui.BodyPanel.pas                            }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Body panel widget for the ResTui demo.
///   Combines a body-kind selector (None / Raw / JSON) with an inline
///   multiline text editor for the request body content.
/// </summary>
unit ResTui.BodyPanel;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Classes,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Widget,
  ResTui.Model;

type

{ TResTuiBodyPanel }

  /// <summary>
  ///   Custom widget that renders a body-kind selector on the first row and a
  ///   multiline text editor in the remaining area.
  ///   Left/Right cycle the body kind; arrow keys, printable characters,
  ///   Backspace, Delete, and Enter edit the body text.
  /// </summary>
  TResTuiBodyPanel = class(TTuiWidget)
  strict private
    FBodyKind: TResTuiBodyKind;
    FBodyLines: TStringList;
    FCursorCol: Integer;
    FCursorRow: Integer;
    FLeftCol: Integer;
    FTopLine: Integer;
    // Clamps FCursorCol to the length of the current cursor row
    procedure ClampCursorCol;
    // Ensures the cursor is visible by adjusting FTopLine and FLeftCol
    procedure ScrollToCursor(AViewRows, AViewCols: Integer);
  protected
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
  public
    /// <summary>
    ///   Creates the body panel widget. AParent receives ownership.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Destroys the body panel and its internal string list.
    /// </summary>
    destructor Destroy; override;
    /// <summary>
    ///   Loads body content, splitting AContent on line breaks.
    /// </summary>
    procedure LoadBody(AKind: TResTuiBodyKind; const AContent: string);
    /// <summary>
    ///   Returns the currently selected body kind.
    /// </summary>
    function GetBodyKind: TResTuiBodyKind;
    /// <summary>
    ///   Returns the body text as a single string with CRLF line endings.
    /// </summary>
    function GetBodyContent: string;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  Blinki.Core.Ansi,
  Blinki.Core.Geometry,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  ResTui.Consts;

{ Constants }

const
  CBodyKindNames: array[TResTuiBodyKind] of string = (
    'None', 'Raw', 'JSON'
  );

{ TResTuiBodyPanel }

constructor TResTuiBodyPanel.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FBodyKind := bkNone;
  FBodyLines := TStringList.Create;
  FBodyLines.Add('');
  // Cursor and scroll start at 0,0 — Delphi zero-initialises integers
end;

destructor TResTuiBodyPanel.Destroy;
begin
  FBodyLines.Free;
  inherited Destroy;
end;

procedure TResTuiBodyPanel.DoInit;
begin
  SetFocusable(True);
end;

procedure TResTuiBodyPanel.ClampCursorCol;
begin
  if FCursorRow < FBodyLines.Count then
  begin
    var LLen := Length(FBodyLines[FCursorRow]);
    if FCursorCol > LLen then
      FCursorCol := LLen;
  end
  else
    FCursorCol := 0;
end;

procedure TResTuiBodyPanel.ScrollToCursor(AViewRows, AViewCols: Integer);
begin
  // Vertical scroll
  if FCursorRow < FTopLine then
    FTopLine := FCursorRow
  else if FCursorRow >= FTopLine + AViewRows then
    FTopLine := FCursorRow - AViewRows + 1;

  // Horizontal scroll
  if FCursorCol < FLeftCol then
    FLeftCol := FCursorCol
  else if FCursorCol >= FLeftCol + AViewCols then
    FLeftCol := FCursorCol - AViewCols + 1;
end;

procedure TResTuiBodyPanel.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  var LInner := ARect.Interior;
  if LInner.IsEmpty then
    Exit;

  var LBorderColor := CColorBorderNormal;
  if Focused then
    LBorderColor := CColorBorderFocus;
  var LBorderStyle := TTuiStyle.Create(LBorderColor, Theme.Surface);
  var LSurfaceStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  var LLabelStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
  var LNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  var LSelectedStyle := TTuiStyle.Create(Theme.Surface, Theme.Primary);
  var LCursorStyle := TTuiStyle.Create(Theme.Text, Theme.Primary);

  // Fill background and draw border with title
  ACanvas.FillRect(ARect, ' ', LSurfaceStyle);
  ACanvas.DrawBox(ARect, bsRounded, CPanelBody, LBorderStyle);

  var LWidth := LInner.Width;
  var LX := LInner.Left;
  var LY := LInner.Top;

  // Row 0 inside the border: body kind selector
  ACanvas.WriteAt(LX, LY, 'Body type: ', LLabelStyle);
  var LTypeX := LX + 11;

  for var LKind := Low(TResTuiBodyKind) to High(TResTuiBodyKind) do
  begin
    var LName := ' ' + CBodyKindNames[LKind] + ' ';
    if LKind = FBodyKind then
      ACanvas.WriteAt(LTypeX, LY, LName, LSelectedStyle)
    else
      ACanvas.WriteAt(LTypeX, LY, LName, LNormalStyle);
    Inc(LTypeX, Length(LName));
    if LKind < High(TResTuiBodyKind) then
    begin
      ACanvas.WriteAt(LTypeX, LY, '|', LLabelStyle);
      Inc(LTypeX);
    end;
  end;

  // Separator line (row 1 inside border)
  if LInner.Height < 2 then
    Exit;
  var LSepStyle := TTuiStyle.Create(Theme.Border, Theme.Surface);
  ACanvas.FillRect(
    TRect.Create(LX, LY + 1, LX + LWidth, LY + 2),
    TTuiAnsi.BoxCharset(bsRounded).Horizontal,
    LSepStyle
  );

  // Text editing area (row 2+ inside border)
  if LInner.Height < 3 then
    Exit;

  var LTextTop := LY + 2;
  var LViewRows := LInner.Bottom - LTextTop;
  var LViewCols := LWidth;

  if LViewRows <= 0 then
    Exit;

  // When not focused, body kind None shows a hint instead of an editor
  if (FBodyKind = bkNone) and not Focused then
  begin
    var LHintStyle := TTuiStyle.Create(Theme.TextDim, Theme.Surface);
    ACanvas.WriteAt(LX, LTextTop, 'No body content', LHintStyle);
    Exit;
  end;

  // Render visible lines
  ACanvas.PushClip(TRect.Create(LX, LTextTop, LX + LViewCols, LTextTop + LViewRows));
  try
    for var LRow := 0 to LViewRows - 1 do
    begin
      var LLineIndex := FTopLine + LRow;
      var LRenderY := LTextTop + LRow;

      if LLineIndex >= FBodyLines.Count then
        Break;

      var LLine := FBodyLines[LLineIndex];
      // Apply horizontal scroll
      var LVisible: string;
      if FLeftCol < Length(LLine) then
        LVisible := Copy(LLine, FLeftCol + 1, LViewCols)
      else
        LVisible := '';

      if Length(LVisible) > 0 then
        ACanvas.WriteAt(LX, LRenderY, LVisible, LNormalStyle);

      // Draw cursor on the active row when focused
      if Focused and (LLineIndex = FCursorRow) then
      begin
        var LCursorScreenCol := FCursorCol - FLeftCol;
        if (LCursorScreenCol >= 0) and (LCursorScreenCol < LViewCols) then
        begin
          var LCursorCh := ' ';
          if FCursorCol < Length(LLine) then
            LCursorCh := LLine[FCursorCol + 1];
          ACanvas.WriteAt(LX + LCursorScreenCol, LRenderY, LCursorCh, LCursorStyle);
        end;
      end;
    end;
  finally
    ACanvas.PopClip;
  end;
end;

function TResTuiBodyPanel.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;

  var LKey := AEvent.Key;

  // --- Body kind selector (Left/Right always available) ---
  if LKey.Code = kcLeft then
  begin
    if FBodyKind = Low(TResTuiBodyKind) then
      FBodyKind := High(TResTuiBodyKind)
    else
      FBodyKind := Pred(FBodyKind);
    Invalidate;
    Exit(True);
  end;

  if LKey.Code = kcRight then
  begin
    if FBodyKind = High(TResTuiBodyKind) then
      FBodyKind := Low(TResTuiBodyKind)
    else
      FBodyKind := Succ(FBodyKind);
    Invalidate;
    Exit(True);
  end;

  // --- Text editing (only when body kind is not None) ---
  if FBodyKind = bkNone then
    Exit;

  // We need view dimensions for scrolling; use LastRect
  var LInner := LastRect.Interior;
  var LViewRows := Max(1, LInner.Height - 2); // subtract kind row + separator
  var LViewCols := Max(1, LInner.Width);

  case LKey.Code of
    kcUp:
    begin
      if FCursorRow > 0 then
      begin
        Dec(FCursorRow);
        ClampCursorCol;
        ScrollToCursor(LViewRows, LViewCols);
        Invalidate;
        Result := True;
      end;
    end;

    kcDown:
    begin
      if FCursorRow < FBodyLines.Count - 1 then
      begin
        Inc(FCursorRow);
        ClampCursorCol;
        ScrollToCursor(LViewRows, LViewCols);
        Invalidate;
        Result := True;
      end;
    end;

    kcLeft:
    begin
      if FCursorCol > 0 then
      begin
        Dec(FCursorCol);
        ScrollToCursor(LViewRows, LViewCols);
        Invalidate;
        Result := True;
      end
      else if FCursorRow > 0 then
      begin
        Dec(FCursorRow);
        FCursorCol := Length(FBodyLines[FCursorRow]);
        ScrollToCursor(LViewRows, LViewCols);
        Invalidate;
        Result := True;
      end;
    end;

    kcRight:
    begin
      if FCursorRow < FBodyLines.Count then
      begin
        var LLineLen := Length(FBodyLines[FCursorRow]);
        if FCursorCol < LLineLen then
        begin
          Inc(FCursorCol);
          ScrollToCursor(LViewRows, LViewCols);
          Invalidate;
          Result := True;
        end
        else if FCursorRow < FBodyLines.Count - 1 then
        begin
          Inc(FCursorRow);
          FCursorCol := 0;
          ScrollToCursor(LViewRows, LViewCols);
          Invalidate;
          Result := True;
        end;
      end;
    end;

    kcHome:
    begin
      FCursorCol := 0;
      ScrollToCursor(LViewRows, LViewCols);
      Invalidate;
      Result := True;
    end;

    kcEnd:
    begin
      if FCursorRow < FBodyLines.Count then
        FCursorCol := Length(FBodyLines[FCursorRow]);
      ScrollToCursor(LViewRows, LViewCols);
      Invalidate;
      Result := True;
    end;

    kcEnter:
    begin
      // Split the current line at the cursor
      var LCurrentLine := FBodyLines[FCursorRow];
      var LBefore := Copy(LCurrentLine, 1, FCursorCol);
      var LAfter := Copy(LCurrentLine, FCursorCol + 1, MaxInt);
      FBodyLines[FCursorRow] := LBefore;
      FBodyLines.Insert(FCursorRow + 1, LAfter);
      Inc(FCursorRow);
      FCursorCol := 0;
      ScrollToCursor(LViewRows, LViewCols);
      Invalidate;
      Result := True;
    end;

    kcBackspace:
    begin
      if FCursorCol > 0 then
      begin
        var LLine := FBodyLines[FCursorRow];
        Delete(LLine, FCursorCol, 1);
        FBodyLines[FCursorRow] := LLine;
        Dec(FCursorCol);
        ScrollToCursor(LViewRows, LViewCols);
        Invalidate;
        Result := True;
      end
      else if FCursorRow > 0 then
      begin
        // Merge current line into the previous one
        var LPrevLen := Length(FBodyLines[FCursorRow - 1]);
        FBodyLines[FCursorRow - 1] := FBodyLines[FCursorRow - 1] + FBodyLines[FCursorRow];
        FBodyLines.Delete(FCursorRow);
        Dec(FCursorRow);
        FCursorCol := LPrevLen;
        ScrollToCursor(LViewRows, LViewCols);
        Invalidate;
        Result := True;
      end;
    end;

    kcDelete:
    begin
      if FCursorRow < FBodyLines.Count then
      begin
        var LLine := FBodyLines[FCursorRow];
        if FCursorCol < Length(LLine) then
        begin
          Delete(LLine, FCursorCol + 1, 1);
          FBodyLines[FCursorRow] := LLine;
          Invalidate;
          Result := True;
        end
        else if FCursorRow < FBodyLines.Count - 1 then
        begin
          // Merge next line into current
          FBodyLines[FCursorRow] := FBodyLines[FCursorRow] + FBodyLines[FCursorRow + 1];
          FBodyLines.Delete(FCursorRow + 1);
          Invalidate;
          Result := True;
        end;
      end;
    end;

    kcChar:
    begin
      if LKey.IsPrintable then
      begin
        if FCursorRow >= FBodyLines.Count then
          FBodyLines.Add('');
        var LLine := FBodyLines[FCursorRow];
        Insert(LKey.Character, LLine, FCursorCol + 1);
        FBodyLines[FCursorRow] := LLine;
        Inc(FCursorCol);
        ScrollToCursor(LViewRows, LViewCols);
        Invalidate;
        Result := True;
      end;
    end;
  end;
end;

procedure TResTuiBodyPanel.LoadBody(AKind: TResTuiBodyKind; const AContent: string);
begin
  FBodyKind := AKind;
  FBodyLines.Clear;
  if AContent = '' then
    FBodyLines.Add('')
  else
    FBodyLines.Text := AContent;
  // Remove trailing empty entry that TStringList.Text may append
  if (FBodyLines.Count > 1) and (FBodyLines[FBodyLines.Count - 1] = '') then
    FBodyLines.Delete(FBodyLines.Count - 1);
  if FBodyLines.Count = 0 then
    FBodyLines.Add('');
  FCursorRow := 0;
  FCursorCol := 0;
  FTopLine := 0;
  FLeftCol := 0;
  Invalidate;
end;

function TResTuiBodyPanel.GetBodyKind: TResTuiBodyKind;
begin
  Result := FBodyKind;
end;

function TResTuiBodyPanel.GetBodyContent: string;
begin
  Result := FBodyLines.Text;
  // Trim the trailing line break that TStringList.Text appends
  Result := TrimRight(Result);
end;

end.
