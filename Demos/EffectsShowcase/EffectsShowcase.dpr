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
{   Unit:        EffectsShowcase.dpr                             }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   EffectsShowcase -- Sample app SAMPLE-04: Effects Showcase.
///
///   Showcase of the visual effects of the Blinki library for Delphi Day 2026.
///   Verifies: FX-01 Gradient, FX-02 TypingEffect, FX-03 WaveAnimation, FX-04 MatrixRain.
///
///   Keys:
///     Left / Right     -- change effect (navigate the tabs)
///     Tab              -- focus on the Tabs container
///     R                -- reset the TypingEffect
///     T                -- toggle Dark / Light theme
///     Q                -- quit
///
///   Layout:
///     LRoot (TTuiVStack)
///       LHeader (TTuiLabel)         Fixed(1)
///       LTabs (TTuiTabs)            Fill(1)
///         Tab 'Gradient'  -> LGradBox (TTuiBox) with 3 TGradBanner
///         Tab 'Typing'    -> LTypingBox (TTuiBox) with TTuiTypingEffect
///         Tab 'Wave'      -> LWaveBox (TTuiBox) with TTuiWaveAnimation
///         Tab 'Matrix'    -> TTuiMatrixRain full-area
///       LFooter (TTuiLabel)         Fixed(1)
/// </summary>
program EffectsShowcase;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  System.Math,
  Blinki.Core.Input,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Event,
  Blinki.Core.Canvas,
  Blinki.Core.Geometry,
  Blinki.Core.Ansi,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Box,
  Blinki.Widgets.Tabs,
  Blinki.Widgets.TypingEffect,
  Blinki.Widgets.WaveAnimation,
  Blinki.Widgets.MatrixRain,
  Blinki.FX.Gradient,
  Blinki.Layout.Stack;

type
  /// <summary>
  ///   Local widget that draws text with a horizontal RGB gradient centered
  ///   in its own area, using DrawGradient from Blinki.FX.Gradient.
  /// </summary>
  TGradBanner = class(TTuiWidget)
  strict private
    FText: string;
    FFrom: TTuiColor;
    FTo: TTuiColor;
    FAttrs: TTuiTextAttrs;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create(const AText: string; const AFrom, ATo: TTuiColor;
      AAttrs: TTuiTextAttrs; AParent: TTuiWidget = nil);
  end;

constructor TGradBanner.Create(const AText: string; const AFrom, ATo: TTuiColor;
  AAttrs: TTuiTextAttrs; AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FText := AText;
  FFrom := AFrom;
  FTo := ATo;
  FAttrs := AAttrs;
end;

procedure TGradBanner.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(TTuiColor.Default, Theme.Surface));
  var LText := FText;
  if Length(LText) > ARect.Width then
    LText := Copy(LText, 1, ARect.Width);
  var LCX := ARect.Left + (ARect.Width - Length(LText)) div 2;
  DrawGradient(ACanvas, LCX, ARect.Top + ARect.Height div 2, LText, FFrom, FTo,
    Theme.Surface, FAttrs);
end;

var
  LApp: TTuiApp;
  LRoot: TTuiVStack;
  LHeader: TTuiLabel;
  LFooter: TTuiLabel;

  LTabs: TTuiTabs;

  // Tab Gradient
  LGradBox: TTuiBox;
  LGradStack: TTuiVStack;

  // Tab Typing
  LTypingBox: TTuiBox;
  LTyping: TTuiTypingEffect;

  // Tab Wave
  LWaveBox: TTuiBox;
  LWave: TTuiWaveAnimation;

  // Tab Matrix
  LMatrix: TTuiMatrixRain;

  LDark: Boolean;

begin
  ReportMemoryLeaksOnShutdown := True;
  LDark := True;

  LApp := TTuiApp.Create;
  LRoot := TTuiVStack.Create;
  try
    LHeader := TTuiLabel.Create(LRoot);
    LHeader.Text := ' Blinki Effects Showcase -- Delphi Day 2026 | Tab=focus  Left/Right=switch  R=reset  T=theme  Q=quit';
    LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LTabs := TTuiTabs.Create(LRoot);
    LTabs.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // ---- Tab 1: Gradient ----
    LGradBox := TTuiBox.Create(nil);
    LGradBox.Title := ' True Color Gradient (FX-01) ';
    LGradBox.BoxStyle := bsRounded;

    LGradStack := TTuiVStack.Create(LGradBox);

    TGradBanner.Create(
      'Blinki -- Terminal UI Framework for Delphi',
      TTuiColor.RGB(255, 64, 64), TTuiColor.RGB(64, 64, 255),
      [taBold], LGradStack);

    TGradBanner.Create(
      'Delphi Day 2026  --  Pure Delphi TUI Library',
      TTuiColor.RGB(64, 220, 64), TTuiColor.RGB(220, 220, 64),
      [taBold], LGradStack);

    TGradBanner.Create(
      'Build stunning terminal apps -- no dependencies -- Windows Native',
      TTuiColor.RGB(200, 64, 200), TTuiColor.RGB(64, 200, 200),
      [taBold, taItalic], LGradStack);

    TGradBanner.Create(
      'Canvas  --  Layout Engine  --  8 Interactive Widgets  --  4 FX Effects',
      TTuiColor.RGB(255, 128, 0), TTuiColor.RGB(0, 192, 255),
      [taBold], LGradStack);

    LTabs.AddTab('Gradient', LGradBox);

    // ---- Tab 2: Typing ----
    LTypingBox := TTuiBox.Create(nil);
    LTypingBox.Title := ' Typing Effect (FX-02) ';
    LTypingBox.BoxStyle := bsRounded;

    LTyping := TTuiTypingEffect.Create(LTypingBox);
    LTyping.Text := 'Loading Blinki Framework... ' +
      'Initializing canvas engine... ' +
      'Registering 22 widget types... ' +
      'Applying Dark theme... ' +
      'Starting event loop... ' +
      'Ready. Welcome to Delphi Day 2026!';
    LTyping.CharsPerSecond := 20;

    LTabs.AddTab('Typing', LTypingBox);

    // ---- Tab 3: Wave ----
    LWaveBox := TTuiBox.Create(nil);
    LWaveBox.Title := ' Wave Animation (FX-03) ';
    LWaveBox.BoxStyle := bsRounded;

    LWave := TTuiWaveAnimation.Create(LWaveBox);
    LWave.Text := '          Delphi Day 2026  ---  Blinki TUI Library  ---  Pure Delphi          ';
    LWave.BaseColor := TTuiColor.RGB(0, 100, 255);
    LWave.PeakColor := TTuiColor.RGB(255, 220, 0);
    LWave.Speed := 1.0;

    LTabs.AddTab('Wave', LWaveBox);

    // ---- Tab 4: Matrix ----
    LMatrix := TTuiMatrixRain.Create(nil);
    LTabs.AddTab('Matrix', LMatrix);

    // Footer
    LFooter := TTuiLabel.Create(LRoot);
    LFooter.Text := ' Left/Right = switch effect   R = reset Typing   T = toggle theme   Q = quit';
    LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    // ---- App setup ----
    LApp.SetRoot(LRoot);

    LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'Q') then
          LApp.Quit
        else if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'T') then
        begin
          LDark := not LDark;
          if LDark then
            LApp.Theme := TTuiTheme.Dark
          else
            LApp.Theme := TTuiTheme.Light;
        end
        else if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'R') then
          LTyping.Reset;
      end;

    LApp.Run;

  finally
    LApp.Free;
  end;
end.
