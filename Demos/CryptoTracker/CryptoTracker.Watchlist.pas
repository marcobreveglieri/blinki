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
{   Unit:        CryptoTracker.Watchlist.pas                    }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   CryptoTrackerDemo -- TCryptoWatchlist: custom scrollable list widget
///   that renders the left-side panel with asset symbols, live prices and
///   percentage changes. The selected row is highlighted in violet.
/// </summary>
unit CryptoTracker.Watchlist;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Geometry,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  CryptoTracker.Model;

type

{ TCryptoWatchlist }

  /// <summary>
  ///   Three-column scrollable asset list (Symbol | Price | Change%).
  ///   Arrow keys and PgUp/PgDn navigate the selection; the selected row is
  ///   rendered in Theme.Secondary on Theme.Surface background.
  ///   Fires OnChange(NewIndex) whenever the selected item changes.
  /// </summary>
  TCryptoWatchlist = class(TTuiWidget)
  strict private
    FDimStyle: TTuiStyle;
    FItemIndex: Integer;
    FModel: TCryptoModel;
    FNormalStyle: TTuiStyle;
    FOnChange: TProc<Integer>;
    FSelectedStyle: TTuiStyle;
    FTopIndex: Integer;
    procedure AdjustViewport(AVisibleRows: Integer);
    procedure SetItemIndex(AValue: Integer);
    function VisibleRows: Integer;
  protected
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Creates the watchlist and binds it to the given model reference.
    ///   The watchlist does NOT take ownership of AModel.
    /// </summary>
    constructor Create(AParent: TTuiWidget; AModel: TCryptoModel);
    /// <summary>
    ///   0-based index of the currently selected asset (-1 = none).
    ///   Setting this property scrolls the viewport to keep the item visible.
    /// </summary>
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
    /// <summary>
    ///   Fired when the user navigates to a different row.
    ///   The integer argument is the new selected index.
    /// </summary>
    property OnChange: TProc<Integer> read FOnChange write FOnChange;
  end;

implementation

uses
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  CryptoTracker.Consts,
  CryptoTracker.Helpers;

{ TCryptoWatchlist }

constructor TCryptoWatchlist.Create(AParent: TTuiWidget; AModel: TCryptoModel);
begin
  inherited Create(AParent);
  FModel := AModel;
  FItemIndex := 0;
  FNormalStyle := TTuiStyle.Create(TTuiTheme.Dark.Text, TTuiTheme.Dark.Background);
  FDimStyle := TTuiStyle.Create(TTuiTheme.Dark.TextDim, TTuiTheme.Dark.Background);
  FSelectedStyle := TTuiStyle.Create(
    TTuiTheme.Dark.Secondary, TTuiTheme.Dark.Surface, [taBold]);
end;

procedure TCryptoWatchlist.AdjustViewport(AVisibleRows: Integer);
begin
  if AVisibleRows < 1 then
    AVisibleRows := 1;
  if FItemIndex < FTopIndex then
    FTopIndex := FItemIndex;
  if FItemIndex >= FTopIndex + AVisibleRows then
    FTopIndex := FItemIndex - AVisibleRows + 1;
  if FTopIndex < 0 then
    FTopIndex := 0;
end;

procedure TCryptoWatchlist.SetItemIndex(AValue: Integer);
begin
  if AValue < 0 then
    AValue := 0;
  if (FModel <> nil) and (AValue >= FModel.AssetCount) then
    AValue := FModel.AssetCount - 1;
  if FItemIndex = AValue then
    Exit;
  FItemIndex := AValue;
  AdjustViewport(VisibleRows);
  Invalidate;
end;

function TCryptoWatchlist.VisibleRows: Integer;
begin
  if LastRect.IsEmpty then
    Result := 20
  else
    Result := LastRect.Height - 2; // subtract border rows
  if Result < 1 then
    Result := 1;
end;

procedure TCryptoWatchlist.DoApplyTheme(const ATheme: TTuiTheme);
begin
  FNormalStyle := TTuiStyle.Create(ATheme.Text, ATheme.Background);
  FDimStyle := TTuiStyle.Create(ATheme.TextDim, ATheme.Background);
  FSelectedStyle := TTuiStyle.Create(ATheme.Secondary, ATheme.Surface, [taBold]);
end;

function TCryptoWatchlist.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
var
  LRows: Integer;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  LRows := VisibleRows;
  case AEvent.Key.Code of
    kcUp:
    begin
      if FItemIndex > 0 then
      begin
        Dec(FItemIndex);
        AdjustViewport(LRows);
        Invalidate;
        if Assigned(FOnChange) then
          FOnChange(FItemIndex);
      end;
      Result := True;
    end;
    kcDown:
    begin
      if FItemIndex < FModel.AssetCount - 1 then
      begin
        Inc(FItemIndex);
        AdjustViewport(LRows);
        Invalidate;
        if Assigned(FOnChange) then
          FOnChange(FItemIndex);
      end;
      Result := True;
    end;
    kcHome:
    begin
      if FItemIndex <> 0 then
      begin
        FItemIndex := 0;
        FTopIndex := 0;
        Invalidate;
        if Assigned(FOnChange) then
          FOnChange(FItemIndex);
      end;
      Result := True;
    end;
    kcEnd:
    begin
      var LLast := FModel.AssetCount - 1;
      if FItemIndex <> LLast then
      begin
        FItemIndex := LLast;
        AdjustViewport(LRows);
        Invalidate;
        if Assigned(FOnChange) then
          FOnChange(FItemIndex);
      end;
      Result := True;
    end;
    kcPageUp:
    begin
      var LNew := FItemIndex - LRows;
      if LNew < 0 then
        LNew := 0;
      if LNew <> FItemIndex then
      begin
        FItemIndex := LNew;
        AdjustViewport(LRows);
        Invalidate;
        if Assigned(FOnChange) then
          FOnChange(FItemIndex);
      end;
      Result := True;
    end;
    kcPageDown:
    begin
      var LNew := FItemIndex + LRows;
      if LNew >= FModel.AssetCount then
        LNew := FModel.AssetCount - 1;
      if LNew <> FItemIndex then
      begin
        FItemIndex := LNew;
        AdjustViewport(LRows);
        Invalidate;
        if Assigned(FOnChange) then
          FOnChange(FItemIndex);
      end;
      Result := True;
    end;
  end;
end;

procedure TCryptoWatchlist.DoInit;
begin
  SetFocusable(True);
end;

procedure TCryptoWatchlist.DoRender(const ACanvas: TTuiCanvas;
  const ARect: TRect);
const
  // Column offsets relative to LInner.Left
  CSymbolOffset = 0;
  CSymbolWidth = 14;
  CPriceOffset = 15; // CSymbolWidth + 1 space
  CPriceWidth = 9;
  CChangeOffset = 25; // CPriceOffset + CPriceWidth + 1 space
  CChangeWidth = 9;
var
  LBorderStyle: TTuiStyle;
  LInner: TRect;
  LVisibleRows: Integer;
begin
  // Draw border — Primary when focused, Border when not
  if Focused then
    LBorderStyle := TTuiStyle.Create(Theme.Primary, Theme.Background)
  else
    LBorderStyle := TTuiStyle.Create(Theme.Border, Theme.Background);
  ACanvas.DrawBox(ARect, bsRounded, CMarketsTitle, LBorderStyle);

  LInner := ARect.Interior;
  ACanvas.PushClip(LInner);
  try
    LVisibleRows := LInner.Height;
    for var LI := FTopIndex to FTopIndex + LVisibleRows - 1 do
    begin
      if LI >= FModel.AssetCount then
        Break;
      var LAsset := FModel.GetAsset(LI);
      var LRowY := LInner.Top + (LI - FTopIndex);
      var LIsSelected := (LI = FItemIndex);

      if LIsSelected then
      begin
        // Highlight background across the full inner row
        ACanvas.FillRect(
          TRect.Create(LInner.Left, LRowY, LInner.Right, LRowY + 1),
          ' ', FSelectedStyle);
        // Symbol (left-aligned, truncated to CSymbolWidth)
        var LSym := Copy(LAsset.Symbol, 1, CSymbolWidth);
        ACanvas.WriteAt(LInner.Left + CSymbolOffset, LRowY, LSym, FSelectedStyle);
        // Price (right-aligned)
        var LPriceStr := FormatPrice(LAsset.Price).PadLeft(CPriceWidth);
        ACanvas.WriteAt(LInner.Left + CPriceOffset, LRowY,
          Copy(LPriceStr, 1, CPriceWidth), FSelectedStyle);
        // Change% (right-aligned, same violet style for selected row)
        var LChangeStr := FormatPercent(LAsset.ChangePct).PadLeft(CChangeWidth);
        ACanvas.WriteAt(LInner.Left + CChangeOffset, LRowY,
          Copy(LChangeStr, 1, CChangeWidth), FSelectedStyle);
      end
      else
      begin
        // Symbol and price in normal style
        var LSym := Copy(LAsset.Symbol, 1, CSymbolWidth);
        ACanvas.WriteAt(LInner.Left + CSymbolOffset, LRowY, LSym, FNormalStyle);
        var LPriceStr := FormatPrice(LAsset.Price).PadLeft(CPriceWidth);
        ACanvas.WriteAt(LInner.Left + CPriceOffset, LRowY,
          Copy(LPriceStr, 1, CPriceWidth), FNormalStyle);
        // Change% in green (success) or red (error)
        var LChangeColor := ChangeColor(Theme, LAsset.ChangePct);
        var LChangeStyle := TTuiStyle.Create(LChangeColor, Theme.Background);
        var LChangeStr := FormatPercent(LAsset.ChangePct).PadLeft(CChangeWidth);
        ACanvas.WriteAt(LInner.Left + CChangeOffset, LRowY,
          Copy(LChangeStr, 1, CChangeWidth), LChangeStyle);
      end;
    end;
  finally
    ACanvas.PopClip;
  end;
end;

end.
