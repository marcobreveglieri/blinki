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
{   Unit:        CryptoTracker.dpr                              }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   CryptoTrackerDemo -- Entry point.
///   Builds the widget tree (Markets watchlist | Candlestick chart),
///   wires live-price simulation via OnTimer, and handles global shortcuts.
///
///   Widget tree:
///     TTuiVStack (root)
///       TTuiHStack (Fill 1)
///         TCryptoWatchlist  Fixed(36)   -- scrollable asset list
///         TCryptoChart      Fill(1)     -- OHLC candles + trend bar
///       TCryptoStatusBar    Fixed(1)    -- source / timeframe / hints
///
///   Keys:
///     Up/Down/PgUp/PgDn  -- navigate watchlist
///     1/2/3/4            -- switch timeframe (1H/24H/7D/30D)
///     T                  -- toggle Dark/Light theme
///     Esc / Q            -- quit
/// </summary>
program CryptoTracker;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Blinki.Core.App,
  Blinki.Core.Event,
  Blinki.Core.Geometry,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  Blinki.Layout.Stack,
  CryptoTracker.Chart in 'CryptoTracker.Chart.pas',
  CryptoTracker.Consts in 'CryptoTracker.Consts.pas',
  CryptoTracker.Helpers in 'CryptoTracker.Helpers.pas',
  CryptoTracker.Model in 'CryptoTracker.Model.pas',
  CryptoTracker.StatusBar in 'CryptoTracker.StatusBar.pas',
  CryptoTracker.Watchlist in 'CryptoTracker.Watchlist.pas';

begin
  ReportMemoryLeaksOnShutdown := True;

  var LModel := TCryptoModel.Create;
  var LApp := TTuiApp.Create;
  try
    LApp.Theme := TTuiTheme.Dark;
    LModel.Seed;

    // ---- Widget tree ----
    var LRoot := TTuiVStack.Create;

    var LHStack := TTuiHStack.Create(LRoot);
    LHStack.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    var LWatchlist := TCryptoWatchlist.Create(LHStack, LModel);
    LWatchlist.LayoutConstraint := TTuiLayoutConstraint.Fixed(CWatchlistWidth);

    var LChart := TCryptoChart.Create(LHStack);
    // LChart.LayoutConstraint defaults to Fill(1) -- takes remaining width

    var LStatusBar := TCryptoStatusBar.Create(LRoot);
    LStatusBar.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- Shared state captured by closures ----
    var LTimeframe := tfMonth; // 30D active by default (matches the screenshot)
    var LTickAcc := 0;

    // ---- Chart refresh helper ----
    var LRefreshChart: TProc :=
      procedure
      begin
        var LIdx := LWatchlist.ItemIndex;
        if (LIdx < 0) or (LIdx >= LModel.AssetCount) then
          Exit;
        var LAsset := LModel.GetAsset(LIdx);
        var LCount := LChart.VisibleCandleCount;
        var LCandles := LModel.GenerateCandles(LIdx, LTimeframe, LCount);
        LChart.SetData(LAsset.Symbol, LCandles);
      end;

    // ---- Watchlist selection → update chart ----
    LWatchlist.OnChange :=
      procedure(AIndex: Integer)
      begin
        LRefreshChart();
      end;

    // ---- Timer: live price oscillation every CTickIntervalMs ----
    LApp.OnTimer :=
      procedure(AElapsedMs: Integer)
      begin
        LTickAcc := LTickAcc + AElapsedMs;
        if LTickAcc < CTickIntervalMs then
          Exit;
        LTickAcc := 0;
        LModel.Tick;
        LWatchlist.Invalidate;
        LRefreshChart();
      end;

    // ---- Global key handling ----
    LApp.OnKeyPress :=
      procedure(const AKey: TTuiKeyEvent)
      begin
        case AKey.Code of
          kcEscape:
            LApp.Quit;
          kcChar:
            case UpCase(AKey.Character) of
              'Q': LApp.Quit;
              'T':
              begin
                if LApp.Theme.Background.R < 128 then
                  LApp.Theme := TTuiTheme.Light
                else
                  LApp.Theme := TTuiTheme.Dark;
              end;
              '1':
              begin
                LTimeframe := tfHour;
                LStatusBar.ActiveTimeframe := tfHour;
                LRefreshChart();
              end;
              '2':
              begin
                LTimeframe := tfDay;
                LStatusBar.ActiveTimeframe := tfDay;
                LRefreshChart();
              end;
              '3':
              begin
                LTimeframe := tfWeek;
                LStatusBar.ActiveTimeframe := tfWeek;
                LRefreshChart();
              end;
              '4':
              begin
                LTimeframe := tfMonth;
                LStatusBar.ActiveTimeframe := tfMonth;
                LRefreshChart();
              end;
            end;
        end;
      end;

    // ---- Initial state ----
    LStatusBar.ActiveTimeframe := LTimeframe;
    LRefreshChart(); // populate chart before the first frame

    LApp.SetRoot(LRoot);
    LApp.Run;
  finally
    LApp.Free;
    LModel.Free;
  end;
end.
