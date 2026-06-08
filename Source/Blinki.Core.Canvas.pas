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
{   Unit:        Blinki.Core.Canvas.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Double-buffer canvas with diff renderer for the Blinki library.
///   TTuiCanvas abstracts anti-flicker rendering: WriteAt/FillRect/DrawBox
///   write into the back buffer; Flush emits only the changed cells to the
///   backend as a single atomic Backend.Write call per frame.
/// </summary>
/// <remarks>
///   Coordinates are 0-based (X = column, Y = row). The conversion to
///   1-based ANSI coordinates is performed internally by Flush.
///   TTuiCanvas is not thread-safe: it must be used exclusively from the
///   event-loop thread.
/// </remarks>
unit Blinki.Core.Canvas;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections,
  System.Types,
  Blinki.Core.Ansi,
  Blinki.Core.Console,
  Blinki.Core.Render,
  Blinki.Core.Style;

type

{ TTuiCanvas }

  /// <summary>
  ///   Double-buffer (front/back) canvas with diff renderer.
  ///
  ///   Typical usage per event-loop tick:
  ///     Canvas.HandleResize;           // idempotent, no cost if nothing has changed
  ///     Canvas.Clear;                  // clears the back buffer
  ///     Canvas.DrawBox(...);           // draws onto the back buffer
  ///     Canvas.WriteAt(...);           // writes onto the back buffer
  ///     Canvas.Flush;                  // emits only the changed cells
  /// </summary>
  TTuiCanvas = class
  strict private
    FBackend: ITuiConsoleBackend;
    FFront: TTuiFrameBuffer;
    FBack: TTuiFrameBuffer;
    FDirty: Boolean;
    FClipStack: TStack<TRect>;
    function  GetWidth: Integer; inline;
    function  GetHeight: Integer; inline;
    procedure WriteCell(AX, AY: Integer; const ACell: TTuiCell);
    function  ClampRect(const ARect: TRect): TRect;
    function  ActiveClipRect: TRect; inline;
    function  BuildFlushSequence: string;
  public
    /// <summary>
    ///   Creates a TTuiCanvas connected to the given backend.
    ///   Initialises both buffers to the current terminal dimensions.
    /// </summary>
    constructor Create(const ABackend: ITuiConsoleBackend);
    destructor Destroy; override;

    /// <summary>
    ///   Clears the back buffer: fills with spaces using the terminal default style.
    /// </summary>
    procedure Clear; overload;

    /// <summary>
    ///   Clears the back buffer: fills with spaces using the given style.
    /// </summary>
    procedure Clear(const AStyle: TTuiStyle); overload;

    /// <summary>
    ///   Clears the back buffer: fills with AFiller repeated using the given style.
    /// </summary>
    procedure Clear(AFiller: Char; const AStyle: TTuiStyle); overload;

    /// <summary>
    ///   Writes AText starting at (AX, AY) using AStyle. Coordinates are 0-based.
    ///   Characters that fall outside the canvas bounds are silently discarded.
    /// </summary>
    procedure WriteAt(AX, AY: Integer; const AText: string; const AStyle: TTuiStyle);

    /// <summary>
    ///   Fills the area ARect (0-based, half-open as per RTL TRect) with
    ///   AFiller and AStyle. The area is clamped to the canvas bounds.
    /// </summary>
    procedure FillRect(const ARect: TRect; AFiller: Char; const AStyle: TTuiStyle);

    /// <summary>
    ///   Draws a rectangular border in ABoxStyle style within ARect.
    ///   ATitle (if non-empty) is centred on the top edge and truncated if
    ///   necessary. The interior of the box is left unchanged.
    /// </summary>
    procedure DrawBox(const ARect: TRect; ABoxStyle: TTuiBoxStyle;
      const ATitle: string; const AStyle: TTuiStyle);

    /// <summary>
    ///   Computes the diff between the back and front buffers, then emits a
    ///   single batched ANSI string to the backend — CursorTo only on
    ///   non-adjacent jumps, SGR only on style changes. Updates the front
    ///   buffer afterwards. No write is performed when back equals front.
    /// </summary>
    procedure Flush;

    /// <summary>
    ///   Resizes both buffers to ANewSize. On resize, emits ClearScreen to 
    ///   eliminate visual artefacts.
    /// </summary>
    procedure UpdateSize(const ANewSize: TSize);

    /// <summary>
    ///   Queries Backend.GetSize and resizes both buffers if the dimensions have
    ///   changed. Idempotent: no cost when no resize has occurred.
    /// </summary>
    procedure HandleResize;

    /// <summary>
    ///   Number of columns in the canvas (updated by HandleResize).
    /// </summary>
    property Width: Integer read GetWidth;

    /// <summary>
    ///   Number of rows in the canvas (updated by HandleResize).
    /// </summary>
    property Height: Integer read GetHeight;

    /// <summary>
    ///   Adds the taDim attribute to every back-buffer cell in ARect without
    ///   altering the character or colour. Call after rendering the root tree and
    ///   before rendering a modal to produce a real dim effect over existing content.
    ///   The area is clamped to the canvas bounds.
    /// </summary>
    procedure DimRect(const ARect: TRect);

    /// <summary>
    ///   Activates a rectangular clip that constrains subsequent drawing
    ///   operations (WriteAt, FillRect, DrawBox) to the intersection of ARect
    ///   with the current clip. Every PushClip must be balanced by a PopClip.
    /// </summary>
    procedure PushClip(const ARect: TRect);
    /// <summary>
    ///   Removes the active rectangular clip. No-op when the stack is empty.
    /// </summary>
    procedure PopClip;
  end;

implementation

uses
  System.Math,
  System.SysUtils;

{ TTuiCanvas }

constructor TTuiCanvas.Create(const ABackend: ITuiConsoleBackend);
begin
  inherited Create;
  FBackend := ABackend;
  FClipStack := TStack<TRect>.Create;
  var LSize := FBackend.GetSize;
  FFront := TTuiFrameBuffer.Create(LSize.cx, LSize.cy);
  FBack := TTuiFrameBuffer.Create(LSize.cx, LSize.cy);
end;

destructor TTuiCanvas.Destroy;
begin
  if Assigned(FClipStack) then
    FreeAndNil(FClipStack);
  if Assigned(FBack) then
    FreeAndNil(FBack);
  if Assigned(FFront) then
    FreeAndNil(FFront);
  inherited Destroy;
end;

function TTuiCanvas.GetWidth: Integer;
begin
  Result := FBack.Width;
end;

function TTuiCanvas.GetHeight: Integer;
begin
  Result := FBack.Height;
end;

function TTuiCanvas.ActiveClipRect: TRect;
begin
  if FClipStack.Count > 0 then
    Result := FClipStack.Peek
  else
    Result := TRect.Create(0, 0, FBack.Width, FBack.Height);
end;

procedure TTuiCanvas.WriteCell(AX, AY: Integer; const ACell: TTuiCell);
begin
  var LClip := ActiveClipRect;
  if (AX >= LClip.Left) and (AX < LClip.Right) and
     (AY >= LClip.Top)  and (AY < LClip.Bottom) then
  begin
    FBack[AX, AY] := ACell;
    FDirty := True;
  end;
end;

function TTuiCanvas.ClampRect(const ARect: TRect): TRect;
begin
  var LClip := ActiveClipRect;
  Result.Left := Max(ARect.Left, LClip.Left);
  Result.Top := Max(ARect.Top, LClip.Top);
  Result.Right := Min(ARect.Right, LClip.Right);
  Result.Bottom := Min(ARect.Bottom, LClip.Bottom);
end;

procedure TTuiCanvas.DimRect(const ARect: TRect);
begin
  var LRect := ClampRect(ARect);
  if LRect.IsEmpty then
    Exit;
  for var LY := LRect.Top to LRect.Bottom - 1 do
    for var LX := LRect.Left to LRect.Right - 1 do
    begin
      var LCell := FBack[LX, LY];
      LCell.Style.Attributes := LCell.Style.Attributes + [taDim];
      FBack[LX, LY] := LCell;
    end;
  FDirty := True;
end;

procedure TTuiCanvas.PushClip(const ARect: TRect);
begin
  var LCurrent := ActiveClipRect;
  var LNew: TRect;
  LNew := TRect.Create(
    Max(ARect.Left, LCurrent.Left),
    Max(ARect.Top, LCurrent.Top),
    Min(ARect.Right, LCurrent.Right),
    Min(ARect.Bottom, LCurrent.Bottom)
  );
  FClipStack.Push(LNew);
end;

procedure TTuiCanvas.PopClip;
begin
  if FClipStack.Count > 0 then
    FClipStack.Pop;
end;

procedure TTuiCanvas.Clear;
begin
  FBack.Clear(TTuiCell.Blank);
  FDirty := True;
end;

procedure TTuiCanvas.Clear(const AStyle: TTuiStyle);
begin
  FBack.Clear(TTuiCell.Make(' ', AStyle));
  FDirty := True;
end;

procedure TTuiCanvas.Clear(AFiller: Char; const AStyle: TTuiStyle);
begin
  FBack.Clear(TTuiCell.Make(AFiller, AStyle));
  FDirty := True;
end;

procedure TTuiCanvas.WriteAt(AX, AY: Integer; const AText: string; const AStyle: TTuiStyle);
begin
  var LColOffset := 0;
  for var LIndex := 1 to Length(AText) do
  begin
    var LChar := AText[LIndex];
    WriteCell(AX + LColOffset, AY, TTuiCell.Make(LChar, AStyle));
    if TTuiAnsi.IsWideChar(LChar) then
      Inc(LColOffset, 2)
    else
      Inc(LColOffset, 1);
  end;
end;

procedure TTuiCanvas.FillRect(const ARect: TRect; AFiller: Char; const AStyle: TTuiStyle);
begin
  var LRect := ClampRect(ARect);
  if LRect.IsEmpty then
    Exit;
  var LCell := TTuiCell.Make(AFiller, AStyle);
  for var LY := LRect.Top to LRect.Bottom - 1 do
    for var LX := LRect.Left to LRect.Right - 1 do
      FBack[LX, LY] := LCell;
  FDirty := True;
end;

procedure TTuiCanvas.DrawBox(const ARect: TRect; ABoxStyle: TTuiBoxStyle;
  const ATitle: string; const AStyle: TTuiStyle);
//var
//  LX, LY: Integer;
//  LTopLine: string;
//  LPadLeft: Integer;
begin
  if (ARect.Width < 2) or (ARect.Height < 2) then
    Exit;

  var LChars := TTuiAnsi.BoxCharset(ABoxStyle);
  var LInnerWidth := ARect.Width - 2;

  // Top row with optional centred title
  var LTopLine: string;
  if (ATitle <> '') and (LInnerWidth > 2) then
  begin
    var LTitleStr := ' ' + ATitle + ' ';
    var LTitleLen := Length(LTitleStr);
    if LTitleLen > LInnerWidth then
    begin
      LTitleLen := LInnerWidth;
      LTitleStr := Copy(LTitleStr, 1, LTitleLen);
    end;
    var LPadLeft := (LInnerWidth - LTitleLen) div 2;
    LTopLine := LChars.TopLeft;
    for var LIndex := 1 to LPadLeft do
      LTopLine := LTopLine + LChars.Horizontal;
    LTopLine := LTopLine + LTitleStr;
    while Length(LTopLine) < ARect.Width - 1 do
      LTopLine := LTopLine + LChars.Horizontal;
    LTopLine := LTopLine + LChars.TopRight;
  end
  else
  begin
    LTopLine := LChars.TopLeft;
    for var LIndex := 1 to LInnerWidth do
      LTopLine := LTopLine + LChars.Horizontal;
    LTopLine := LTopLine + LChars.TopRight;
  end;

  begin
    var LY := ARect.Top;
    for var LX := 0 to Length(LTopLine) - 1 do
      WriteCell(ARect.Left + LX, LY, TTuiCell.Make(LTopLine[LX + 1], AStyle));

    // Side rows
    for LY := ARect.Top + 1 to ARect.Bottom - 2 do
    begin
      WriteCell(ARect.Left,        LY, TTuiCell.Make(LChars.Vertical, AStyle));
      WriteCell(ARect.Right - 1,   LY, TTuiCell.Make(LChars.Vertical, AStyle));
    end;
  end;

  // Bottom row
  begin
    var LY := ARect.Bottom - 1;
    WriteCell(ARect.Left, LY, TTuiCell.Make(LChars.BottomLeft, AStyle));
    for var LX := 1 to LInnerWidth do
      WriteCell(ARect.Left + LX, LY, TTuiCell.Make(LChars.Horizontal, AStyle));
    WriteCell(ARect.Right - 1, LY, TTuiCell.Make(LChars.BottomRight, AStyle));
  end;
end;

function TTuiCanvas.BuildFlushSequence: string;
begin
  var LBuilder := TStringBuilder.Create(FBack.Width * FBack.Height * 8);
  try
    var LHasChanges := False;
    var LLastX := -2;
    var LLastY := -1;
    var LLastStyle := TTuiStyle.Default;

    for var LY := 0 to FBack.Height - 1 do
      for var LX := 0 to FBack.Width - 1 do
      begin
        var LCell := FBack[LX, LY];
        if LCell = FFront[LX, LY] then
          Continue;

        if not LHasChanges then
        begin
          // Initial reset: ensures a known terminal state before the first character
          LBuilder.Append(TTuiAnsi.Reset);
          LHasChanges := True;
        end;

        // CursorTo only if not in the cell adjacent to the previous one
        if (LY <> LLastY) or (LX <> LLastX + 1) then
          LBuilder.Append(TTuiAnsi.CursorTo(LY + 1, LX + 1));

        LBuilder.Append(TTuiAnsi.ApplyStyleDelta(LLastStyle, LCell.Style));
        LBuilder.Append(LCell.Character);

        // Wide char (2 col): LX+1 is not visually adjacent; force CursorTo.
        if TTuiAnsi.IsWideChar(LCell.Character) then
          LLastX := LX + 1
        else
          LLastX := LX;
        LLastY := LY;
        LLastStyle := LCell.Style;
      end;

    if LHasChanges then
      LBuilder.Append(TTuiAnsi.Reset);

    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

procedure TTuiCanvas.Flush;
begin
  if not FDirty then
    Exit;

  var LSequence := BuildFlushSequence;
  if LSequence <> '' then
  begin
    FBackend.Write(LSequence);
    FBackend.Flush;
  end;

  FFront.CopyFrom(FBack);
  FDirty := False;
end;

procedure TTuiCanvas.UpdateSize(const ANewSize: TSize);
begin
  if (ANewSize.cx = FBack.Width) and (ANewSize.cy = FBack.Height) then
    Exit;
  // ClearScreen before resize to eliminate visual artefacts from the previous content
  FBackend.Write(TTuiAnsi.ClearScreen);
  FBackend.Flush;
  FBack.Resize(ANewSize.cx, ANewSize.cy);
  FFront.Resize(ANewSize.cx, ANewSize.cy);
  FDirty := True;
end;

procedure TTuiCanvas.HandleResize;
begin
  UpdateSize(FBackend.GetSize);
end;

end.
