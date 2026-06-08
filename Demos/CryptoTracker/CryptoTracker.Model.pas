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
{   Unit:        CryptoTracker.Model.pas                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   CryptoTrackerDemo -- Domain types: TAssetKind, TTimeframe,
///   TCryptoCandle, TCryptoAsset, and TCryptoModel.
///   Zero UI dependencies; all data is simulated in memory.
/// </summary>
unit CryptoTracker.Model;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Generics.Collections;

type

  /// <summary>
  ///   Broad category of a tracked financial instrument.
  /// </summary>
  TAssetKind = (akCrypto, akIndex, akStock);

  /// <summary>
  ///   Chart time-frame selector (matches the four status-bar tabs).
  /// </summary>
  TTimeframe = (tfHour, tfDay, tfWeek, tfMonth);

  /// <summary>
  ///   Immutable OHLC value record for a single chart candle.
  /// </summary>
  TCryptoCandle = record
    Close: Double;
    High: Double;
    Low: Double;
    Open: Double;
    /// <summary>
    ///   Creates a fully-initialized TCryptoCandle value.
    /// </summary>
    class function Make(AOpen, AHigh, ALow, AClose: Double): TCryptoCandle; static;
  end;

  /// <summary>
  ///   Snapshot of a tracked financial instrument with live and base prices.
  /// </summary>
  TCryptoAsset = record
    BasePrice: Double;
    ChangePct: Double;
    Kind: TAssetKind;
    Price: Double;
    Symbol: string;
    /// <summary>
    ///   Creates a fully-initialized TCryptoAsset record.
    ///   BasePrice and Price are both set to ABasePrice at construction.
    /// </summary>
    class function Make(const ASymbol: string; ABasePrice, AChangePct: Double;
      AKind: TAssetKind): TCryptoAsset; static;
  end;

  /// <summary>
  ///   In-memory registry of tracked financial assets.
  ///   Provides deterministic candle generation via a seeded LCG, and a
  ///   Tick method that applies small live-price oscillations each timer step.
  /// </summary>
  TCryptoModel = class
  strict private
    FAssets: TList<TCryptoAsset>;
    FTickCount: Integer;
    function SeedFor(const ASymbol: string; ATimeframe: TTimeframe): Cardinal;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Returns the total number of tracked assets.
    /// </summary>
    function AssetCount: Integer;
    /// <summary>
    ///   Returns the asset at the given index (0-based).
    /// </summary>
    function GetAsset(AIndex: Integer): TCryptoAsset;
    /// <summary>
    ///   Generates ACount OHLC candles for the asset at AIndex using a
    ///   deterministic backwards random walk anchored at the current live price.
    ///   The same symbol+timeframe pair always produces the same chart shape.
    /// </summary>
    function GenerateCandles(AIndex: Integer; ATimeframe: TTimeframe;
      ACount: Integer): TArray<TCryptoCandle>;
    /// <summary>
    ///   Populates the asset list with the ~37 instruments shown in the
    ///   reference screenshot (crypto, US stocks, NSE stocks, indices).
    /// </summary>
    procedure Seed;
    /// <summary>
    ///   Applies a small deterministic price oscillation to every asset.
    ///   Call once per timer tick to simulate live market data.
    /// </summary>
    procedure Tick;
  end;

implementation

uses
  System.Math,
  System.SysUtils;

{ TCryptoCandle }

class function TCryptoCandle.Make(AOpen, AHigh, ALow, AClose: Double): TCryptoCandle;
begin
  Result.Close := AClose;
  Result.High := AHigh;
  Result.Low := ALow;
  Result.Open := AOpen;
end;

{ TCryptoAsset }

class function TCryptoAsset.Make(const ASymbol: string; ABasePrice,
  AChangePct: Double; AKind: TAssetKind): TCryptoAsset;
begin
  Result.BasePrice := ABasePrice;
  Result.ChangePct := AChangePct;
  Result.Kind := AKind;
  Result.Price := ABasePrice;
  Result.Symbol := ASymbol;
end;

{ TCryptoModel }

constructor TCryptoModel.Create;
begin
  inherited Create;
  FAssets := TList<TCryptoAsset>.Create;
end;

destructor TCryptoModel.Destroy;
begin
  FAssets.Free;
  inherited Destroy;
end;

function TCryptoModel.AssetCount: Integer;
begin
  Result := FAssets.Count;
end;

function TCryptoModel.GetAsset(AIndex: Integer): TCryptoAsset;
begin
  Result := FAssets[AIndex];
end;

function TCryptoModel.SeedFor(const ASymbol: string;
  ATimeframe: TTimeframe): Cardinal;
begin
  // FNV-1a 32-bit hash of the symbol string
  Result := 2166136261;
  for var LCh in ASymbol do
  begin
    Result := Result xor Cardinal(Ord(LCh));
    Result := Cardinal(Int64(Result) * 16777619);
  end;
  // XOR with timeframe ordinal to differentiate timeframes for the same symbol
  Result := Result xor Cardinal(Int64(Ord(ATimeframe)) * 2654435761);
end;

function TCryptoModel.GenerateCandles(AIndex: Integer; ATimeframe: TTimeframe;
  ACount: Integer): TArray<TCryptoCandle>;
const
  // Per-timeframe volatility (fraction of price per candle step)
  CVolatility: array[TTimeframe] of Double = (0.008, 0.025, 0.06, 0.15);
var
  LAsset: TCryptoAsset;
  LState: Cardinal;
  LPrices: TArray<Double>;
  LStep, LRand: Double;
begin
  if ACount < 1 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  LAsset := FAssets[AIndex];
  LState := SeedFor(LAsset.Symbol, ATimeframe);
  SetLength(LPrices, ACount + 1);
  // Backwards random walk: LPrices[ACount] is the live price (rightmost/newest)
  LPrices[ACount] := LAsset.Price;
  for var LI := ACount - 1 downto 0 do
  begin
    LState := Cardinal(Int64(LState) * $6C62272E + $7F4A7C15);
    LRand := (LState and $FFFF) / 65535.0; // 0..1
    // Step in range +/-volatility, biased toward previous for mean-reversion
    LStep := (LRand - 0.5) * 2.0 * CVolatility[ATimeframe];
    LPrices[LI] := LPrices[LI + 1] / (1.0 + LStep);
    if LPrices[LI] < LAsset.Price * 0.001 then
      LPrices[LI] := LAsset.Price * 0.001;
  end;
  // Build OHLC candles (oldest first)
  SetLength(Result, ACount);
  for var LI := 0 to ACount - 1 do
  begin
    var LOpen := LPrices[LI];
    var LClose := LPrices[LI + 1];
    var LBodyRange := Abs(LClose - LOpen);
    LState := Cardinal(Int64(LState) * $6C62272E + $7F4A7C15);
    var LRandH := (LState and $FF) / 255.0;
    LState := Cardinal(Int64(LState) * $6C62272E + $7F4A7C15);
    var LRandL := (LState and $FF) / 255.0;
    var LHigh := Max(LOpen, LClose) + LBodyRange * (0.1 + LRandH * 0.4);
    var LLow := Min(LOpen, LClose) - LBodyRange * (0.1 + LRandL * 0.4);
    Result[LI] := TCryptoCandle.Make(LOpen, LHigh, LLow, LClose);
  end;
end;

procedure TCryptoModel.Seed;
begin
  FAssets.Clear;
  // Crypto
  FAssets.Add(TCryptoAsset.Make('ETH-USD', 3297.00, 0.12, akCrypto));
  FAssets.Add(TCryptoAsset.Make('SOL-USD', 141.93, -1.35, akCrypto));
  FAssets.Add(TCryptoAsset.Make('XRP-USD', 2.07, -1.29, akCrypto));
  // US stocks
  FAssets.Add(TCryptoAsset.Make('AAPL', 258.21, -0.92, akStock));
  FAssets.Add(TCryptoAsset.Make('AMZN', 238.18, 0.11, akStock));
  FAssets.Add(TCryptoAsset.Make('AMD', 227.92, -2.51, akStock));
  FAssets.Add(TCryptoAsset.Make('CRM', 233.53, -2.01, akStock));
  FAssets.Add(TCryptoAsset.Make('GOOGL', 332.78, -0.31, akStock));
  FAssets.Add(TCryptoAsset.Make('META', 620.80, 0.43, akStock));
  FAssets.Add(TCryptoAsset.Make('MSFT', 456.66, -0.97, akStock));
  FAssets.Add(TCryptoAsset.Make('NFLX', 88.05, -1.60, akStock));
  FAssets.Add(TCryptoAsset.Make('NVDA', 187.05, -0.04, akStock));
  FAssets.Add(TCryptoAsset.Make('TSLA', 438.57, -1.06, akStock));
  // NSE stocks
  FAssets.Add(TCryptoAsset.Make('ASIANPAINT.NS', 2807.00, -0.09, akStock));
  FAssets.Add(TCryptoAsset.Make('AXISBANK.NS', 1294.00, -0.36, akStock));
  FAssets.Add(TCryptoAsset.Make('BAJFINANCE.NS', 948.90, 0.04, akStock));
  FAssets.Add(TCryptoAsset.Make('BHARTIARTL.NS', 1999.00, 0.10, akStock));
  FAssets.Add(TCryptoAsset.Make('HDFCBANK.NS', 925.90, -6.88, akStock));
  FAssets.Add(TCryptoAsset.Make('HINDUNILVR.NS', 2358.00, 2.89, akStock));
  FAssets.Add(TCryptoAsset.Make('ICICIBANK.NS', 1410.00, 3.37, akStock));
  FAssets.Add(TCryptoAsset.Make('INFY.NS', 1675.00, 5.39, akStock));
  FAssets.Add(TCryptoAsset.Make('ITC.NS', 333.85, -0.54, akStock));
  FAssets.Add(TCryptoAsset.Make('KOTAKBANK.NS', 424.70, 0.52, akStock));
  FAssets.Add(TCryptoAsset.Make('LT.NS', 3880.00, 0.14, akStock));
  FAssets.Add(TCryptoAsset.Make('MARUTI.NS', 16086.00, 0.06, akStock));
  FAssets.Add(TCryptoAsset.Make('RELIANCE.NS', 1467.00, -4.82, akStock));
  FAssets.Add(TCryptoAsset.Make('SBIN.NS', 1034.00, 0.21, akStock));
  FAssets.Add(TCryptoAsset.Make('SUNPHARMA.NS', 1678.00, -1.04, akStock));
  FAssets.Add(TCryptoAsset.Make('TCS.NS', 3195.00, -0.47, akStock));
  FAssets.Add(TCryptoAsset.Make('TITAN.NS', 4213.00, -0.45, akStock));
  FAssets.Add(TCryptoAsset.Make('ULTRACEMCO.NS', 12245.00, 0.21, akStock));
  FAssets.Add(TCryptoAsset.Make('WIPRO.NS', 268.25, 0.52, akStock));
  // Indices
  FAssets.Add(TCryptoAsset.Make('^BSESN', 83657.00, 0.00, akIndex));
  FAssets.Add(TCryptoAsset.Make('^DJI', 49442.00, 0.32, akIndex));
  FAssets.Add(TCryptoAsset.Make('^GSPC', 6944.00, -0.32, akIndex));
  FAssets.Add(TCryptoAsset.Make('^IXIC', 23530.00, -0.53, akIndex));
  FAssets.Add(TCryptoAsset.Make('^NSEI', 25728.00, -0.01, akIndex));
end;

procedure TCryptoModel.Tick;
var
  LState: Cardinal;
  LDelta: Double;
  LAsset: TCryptoAsset;
begin
  Inc(FTickCount);
  // Deterministic per-tick seed from tick counter
  LState := Cardinal(Int64(FTickCount) * $9E3779B9);
  for var LI := 0 to FAssets.Count - 1 do
  begin
    // Advance LCG with per-asset perturbation for independent oscillation
    LState := Cardinal(Int64(LState) * $6C62272E + Int64(LI) * $9E3779B9 + 1);
    // Delta in range -0.0015..+0.0015 (~+/-0.15% per tick)
    LDelta := (Integer(LState and $FFFF) - $8000) / $8000 * 0.0015;
    LAsset := FAssets[LI];
    LAsset.Price := LAsset.Price * (1.0 + LDelta);
    // Clamp price to +/-25% of base price
    if LAsset.Price < LAsset.BasePrice * 0.75 then
      LAsset.Price := LAsset.BasePrice * 0.75;
    if LAsset.Price > LAsset.BasePrice * 1.25 then
      LAsset.Price := LAsset.BasePrice * 1.25;
    LAsset.ChangePct := (LAsset.Price / LAsset.BasePrice - 1.0) * 100.0;
    FAssets[LI] := LAsset;
  end;
end;

end.
