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
{   Unit:        CryptoTracker.Consts.pas                       }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   CryptoTrackerDemo -- String constants, glyph characters, and UI labels
///   used across the demo widgets and the main program.
/// </summary>
unit CryptoTracker.Consts;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

const

  /// <summary>
  ///   Application title shown in the header.
  /// </summary>
  CAppTitle = ' CryptoTracker ';

  /// <summary>
  ///   Data-source attribution shown in the status bar left section.
  /// </summary>
  CStatusSource = #$25CB + ' Multi (CoinGecko + Yahoo)';

  /// <summary>
  ///   Shortcut hints shown in the status bar right section.
  /// </summary>
  CStatusHints = 'T Theme   q Quit';

  /// <summary>
  ///   Title of the watchlist panel.
  /// </summary>
  CMarketsTitle = ' Markets ';

  /// <summary>
  ///   Label for the trend mini-bar strip inside the chart.
  /// </summary>
  CTrendLabel = 'Trend';

  /// <summary>
  ///   Labels for each timeframe selector in the status bar.
  /// </summary>
  CTimeframeLabels: array[0..3] of string = ('1H', '24H', '7D', '30D');

  /// <summary>
  ///   Default fallback candle count used before the first render.
  /// </summary>
  CDefaultCandleCount = 60;

  /// <summary>
  ///   Width reserved in the chart for the price Y-axis labels.
  /// </summary>
  CPriceLabelWidth = 10;

  /// <summary>
  ///   Fixed column width of the watchlist panel (including border).
  /// </summary>
  CWatchlistWidth = 36;

  /// <summary>
  ///   Timer accumulator threshold in milliseconds for a live price tick.
  /// </summary>
  CTickIntervalMs = 1500;

implementation

end.
