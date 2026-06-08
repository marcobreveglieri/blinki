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
{   Unit:        Dashboard.Consts.pas                           }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Dashboard demo — panel titles, column labels, glyph characters,
///   timing constants, and the colour palette used across all widgets.
/// </summary>
unit Dashboard.Consts;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  Blinki.Core.Style;

const
  // Timing
  CTickIntervalMs = 1000;

  // Panel titles
  CPanelTopWords      = ' Top Words ';
  CPanelTopAttributes = ' Top Attributes ';
  CPanelLogPatterns   = ' Log Patterns ';
  CPanelLogCounts     = ' Log Counts ';

  // Table column headers
  CColHdrTime    = 'Time';
  CColHdrLevel   = 'Level';
  CColHdrHost    = 'Host';
  CColHdrService = 'Service';
  CColHdrMessage = 'Message';

  // Table column widths (chars)
  CColWidthTime    = 8;
  CColWidthLevel   = 5;
  CColWidthHost    = 12;
  CColWidthService = 14;

  // Severity labels
  CSevFatal = 'FATAL';
  CSevError = 'ERROR';
  CSevWarn  = 'WARN';
  CSevInfo  = 'INFO';
  CSevDebug = 'DEBUG';
  CSevTrace = 'TRACE';
  CSevTotal = 'TOTAL';

  // Glyph characters — Unicode box-drawing and block elements
  CGlyphBlockFull  = #$2588; // █  full block
  CGlyphBlockShade = #$2591; // ░  light shade
  CGlyphVBar       = #$2502; // │  vertical bar separator
  CGlyphHRule      = #$2500; // ─  horizontal rule

  // Sub-cell vertical block characters U+2581..U+2587 (1/8 .. 7/8 height)
  CGlyphBlock1 = #$2581; // ▁
  CGlyphBlock2 = #$2582; // ▂
  CGlyphBlock3 = #$2583; // ▃
  CGlyphBlock4 = #$2584; // ▄
  CGlyphBlock5 = #$2585; // ▅
  CGlyphBlock6 = #$2586; // ▆
  CGlyphBlock7 = #$2587; // ▇

  // Status bar hint text
  CStatusHints = 'Click sections'#$20#$2022' Wheel: scroll '#$2022' Space: Pause '#$2022
               + ' Tab: Navigate '#$2022' i: Statistics '#$2022' Enter: Select '#$2022' ?/h';
  CUpdateLabel = 'Update: 1s';
  CPausedLabel = 'PAUSED';

  // Number of histogram bars in the Log Counts panel
  CHistogramBars = 16;

  // Inner bar width (chars between │ delimiters) for horizontal bars
  CBarInnerWidth = 10;

  // Maximum heat strip width for the Log Patterns panel
  CMaxHeatStripWidth = 12;

  // Colour palette — typed constants of kind ckRGB
  CColorTitle:        TTuiColor = (Kind: ckRGB; R: 92;  G: 160; B: 230);
  CColorBorderNormal: TTuiColor = (Kind: ckRGB; R: 90;  G: 90;  B: 90);
  CColorBorderFocus:  TTuiColor = (Kind: ckRGB; R: 60;  G: 140; B: 240);
  CColorBarFull:      TTuiColor = (Kind: ckRGB; R: 220; G: 220; B: 220);
  CColorBarShade:     TTuiColor = (Kind: ckRGB; R: 110; G: 110; B: 110);
  CColorHistogram:    TTuiColor = (Kind: ckRGB; R: 70;  G: 150; B: 235);
  CColorSevFatal:     TTuiColor = (Kind: ckRGB; R: 230; G: 100; B: 210);
  CColorSevError:     TTuiColor = (Kind: ckRGB; R: 240; G: 80;  B: 80);
  CColorSevWarn:      TTuiColor = (Kind: ckRGB; R: 235; G: 150; B: 60);
  CColorSevInfo:      TTuiColor = (Kind: ckRGB; R: 90;  G: 160; B: 235);
  CColorSevDebug:     TTuiColor = (Kind: ckRGB; R: 120; G: 120; B: 120);
  CColorSevTrace:     TTuiColor = (Kind: ckRGB; R: 100; G: 100; B: 100);
  CColorSevTotal:     TTuiColor = (Kind: ckRGB; R: 220; G: 220; B: 220);
  CColorTime:         TTuiColor = (Kind: ckRGB; R: 200; G: 200; B: 200);
  CColorHost:         TTuiColor = (Kind: ckRGB; R: 130; G: 130; B: 130);
  CColorService:      TTuiColor = (Kind: ckRGB; R: 78;  G: 201; B: 176);
  CColorMessage:      TTuiColor = (Kind: ckRGB; R: 210; G: 165; B: 90);
  CColorStatusBg:     TTuiColor = (Kind: ckRGB; R: 20;  G: 30;  B: 120);
  CColorStatusText:   TTuiColor = (Kind: ckRGB; R: 220; G: 220; B: 220);
  CColorBlack:        TTuiColor = (Kind: ckRGB; R: 0;   G: 0;   B: 0);
  CColorText:         TTuiColor = (Kind: ckRGB; R: 200; G: 200; B: 200);
  CColorDim:          TTuiColor = (Kind: ckRGB; R: 140; G: 140; B: 140);

implementation

end.
