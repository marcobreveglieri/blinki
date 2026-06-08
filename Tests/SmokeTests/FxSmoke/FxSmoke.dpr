/// <summary>
///   FxSmoke -- Smoke test Phase 9A: FX Effects.
///
///   Verifica i requisiti FX-01..FX-04:
///   - FX-01: DrawGradient (via widget GradientLabel locale)
///   - FX-02: TTuiTypingEffect (text revealed character by character)
///   - FX-03: TTuiWaveAnimation (sinusoidal wave over the colors)
///   - FX-04: TTuiMatrixRain (full-area character rain)
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
///       LHeader (TTuiLabel)      Fixed(1)
///       LTabs (TTuiTabs)         Fill(1)
///         Tab 'Gradient'  -> LGradBox (TTuiBox) -> LGradStack (VStack con 3 GradLabel)
///         Tab 'Typing'    -> LTypingBox (TTuiBox) -> LTyping (TTuiTypingEffect)
///         Tab 'Wave'      -> LWaveBox (TTuiBox) -> LWave (TTuiWaveAnimation)
///         Tab 'Matrix'    -> LMatrix (TTuiMatrixRain)
///       LFooter (TTuiLabel)      Fixed(1)
/// </summary>
program FxSmoke;

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
  ///   Local widget that draws a banner with a horizontal RGB gradient.
  ///   Uses DrawGradient from Blinki.FX.Gradient to color text character by character.
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
  FText  := AText;
  FFrom  := AFrom;
  FTo    := ATo;
  FAttrs := AAttrs;
end;

procedure TGradBanner.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
var
  LText: string;
  LCX: Integer;
begin
  if ARect.IsEmpty then Exit;
  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(TTuiColor.Default, Theme.Surface));
  LText := FText;
  if Length(LText) > ARect.Width then
    LText := Copy(LText, 1, ARect.Width);
  LCX := ARect.Left + (ARect.Width - Length(LText)) div 2;
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

  LApp  := TTuiApp.Create;
  LRoot := TTuiVStack.Create;
  try
    LHeader      := TTuiLabel.Create(LRoot);
    LHeader.Text := ' Blinki Phase 9A -- FX Effects | Tab=focus  Left/Right=tab  R=reset  T=theme  Q=quit';
    LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

    LTabs := TTuiTabs.Create(LRoot);
    LTabs.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

    // ---- Tab 1: Gradient ----
    LGradBox       := TTuiBox.Create(nil);
    LGradBox.Title := ' Gradient (FX-01) ';
    LGradBox.BoxStyle := bsRounded;

    LGradStack := TTuiVStack.Create(LGradBox);

    TGradBanner.Create(
      'Blinki Framework -- True Color Gradient Demo',
      TTuiColor.RGB(255, 64, 64), TTuiColor.RGB(64, 64, 255),
      [taBold], LGradStack);

    TGradBanner.Create(
      'Delphi Day 2026 -- TUI Library',
      TTuiColor.RGB(64, 200, 64), TTuiColor.RGB(200, 200, 64),
      [taBold], LGradStack);

    TGradBanner.Create(
      'Build stunning terminal apps with pure Delphi',
      TTuiColor.RGB(200, 64, 200), TTuiColor.RGB(64, 200, 200),
      [taBold, taItalic], LGradStack);

    LTabs.AddTab('Gradient', LGradBox);

    // ---- Tab 2: Typing ----
    LTypingBox       := TTuiBox.Create(nil);
    LTypingBox.Title := ' Typing Effect (FX-02) ';
    LTypingBox.BoxStyle := bsRounded;

    LTyping := TTuiTypingEffect.Create(LTypingBox);
    LTyping.Text          := 'Generating Delphi TUI components... done. Ready for Delphi Day 2026!';
    LTyping.CharsPerSecond := 25;

    LTabs.AddTab('Typing', LTypingBox);

    // ---- Tab 3: Wave ----
    LWaveBox       := TTuiBox.Create(nil);
    LWaveBox.Title := ' Wave Animation (FX-03) ';
    LWaveBox.BoxStyle := bsRounded;

    LWave           := TTuiWaveAnimation.Create(LWaveBox);
    LWave.Text      := '   Delphi Day 2026 --- Blinki TUI Library   ';
    LWave.BaseColor := TTuiColor.RGB(0, 128, 255);
    LWave.PeakColor := TTuiColor.RGB(255, 200, 0);
    LWave.Speed     := 1.2;

    LTabs.AddTab('Wave', LWaveBox);

    // ---- Tab 4: Matrix ----
    LMatrix := TTuiMatrixRain.Create(nil);
    LTabs.AddTab('Matrix', LMatrix);

    // Footer
    LFooter      := TTuiLabel.Create(LRoot);
    LFooter.Text := ' Use Left/Right to switch effects. R resets Typing.';
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
