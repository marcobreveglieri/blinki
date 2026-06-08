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
{   Unit:        DelphiDay.dpr                                   }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   DelphiDay -- ASCII-art DelphiDay 25th Anniversary smoke test.
///
///   Renders a centred logo on a black background using Blinki canvas
///   primitives:
///     - DELPHIDAY in 5-row block-pixel glyphs (white on black)
///     - Italian tricolour bar (green / white / red) below the lettering
///     - "italian conference" subtitle justified to the full text width
///     - 25th Anniversary golden coccarda (twin decorative rings) to the
///       left, with an animated sinusoidal gold shimmer driven by DoTick
///       and "25" rendered as block-pixel digits inside the ring
///     - Typewriter banner below the logo cycling through phrases with
///       a blinking cursor and backspace-erase transition between phrases
///
///   Press Q or Esc to quit.
/// </summary>
program DelphiDay;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  System.Math,
  Blinki.Core.App,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Geometry,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  Blinki.FX.Gradient;

type
  TLetterGlyph = array[0..4] of string;

  // Typewriter animation states.
  TTwState = (tsTyping, tsHolding, tsErasing, tsPausing);

  /// <summary>
  ///   Full-screen decorative widget. Renders the DelphiDay 25th
  ///   Anniversary logo with a sinusoidal golden shimmer on the coccarda.
  ///   Not focusable; drives animation via DoTick.
  /// </summary>
  TDelphiDayBanner = class(TTuiWidget)
  strict private
    FBlinkAccumMs: Single;
    FBlinkOn: Boolean;
    FPhaseMs: Single;
    FTwAccumMs: Single;
    FTwPhraseIdx: Integer;
    FTwState: TTwState;
    FTwStateMs: Single;
    FTwVisible: Integer;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    constructor Create(AParent: TTuiWidget = nil);
  end;

const
  // Glow animation period in milliseconds.
  CGlowPeriodMs = 2200.0;

  // Inner ring radius (rows); outer fringe extends to CRoutRows.
  CRinRows = 5;
  CRoutRows = 7;

  // Horizontal aspect-ratio correction (terminal cells are ~2x taller).
  CKx = 2.0;

  // Gap (columns) between the coccarda bounding box and the text block.
  CGapCols = 3;

  // Gap (columns) between adjacent letters in the block font.
  CLetterGap = 1;

  // Block-pixel glyphs: 0=D, 1=E, 2=L, 3=P, 4=H, 5=I, 6=A, 7=Y.
  // Each entry has 5 rows; '█'=filled cell, ' '=empty cell.
  CFontGlyphs: array[0..7] of TLetterGlyph = (
    // D (4 wide)
    ('███ ', '█  █', '█  █', '█  █', '███ '),
    // E (4 wide)
    ('████', '█   ', '███ ', '█   ', '████'),
    // L (4 wide)
    ('█   ', '█   ', '█   ', '█   ', '████'),
    // P (4 wide)
    ('███ ', '█  █', '███ ', '█   ', '█   '),
    // H (4 wide)
    ('█  █', '█  █', '████', '█  █', '█  █'),
    // I (4 wide)
    ('████', ' █  ', ' █  ', ' █  ', '████'),
    // A (4 wide)
    (' ██ ', '█  █', '████', '█  █', '█  █'),
    // Y (4 wide)
    ('█  █', '█  █', ' ██ ', ' █  ', ' █  ')
  );

  // Block-pixel digit glyphs: 0=digit '2', 1=digit '5'.
  // Each entry has 5 rows; '█'=filled cell, ' '=empty cell.
  CDigitGlyphs: array[0..1] of TLetterGlyph = (
    // 2 (4 wide)
    ('███ ', '   █', ' ██ ', '█   ', '████'),
    // 5 (4 wide)
    ('████', '█   ', '███ ', '   █', '███ ')
  );

  // Letter index sequence spelling D-E-L-P-H-I-D-A-Y (D reused at pos 6).
  CWordLetters: array[0..8] of Integer = (0, 1, 2, 3, 4, 5, 0, 6, 7);

  // Typewriter phrases displayed below the logo (customise as needed).
  CTwPhrases: array[0..3] of string = (
    'Welcome Delphi developers!',
    'Delphi Day rulez!',
    'Made with Blinki TUI',
    'The Delphi community rocks!'
  );

  // Typewriter animation timings.
  CTwCharsPerSec = 18;       // typing speed (characters per second)
  CTwEraseCharsPerSec = 30;  // erasing speed (characters per second)
  CTwHoldMs = 1600.0;        // pause duration at full text (ms)
  CTwPauseMs = 500.0;        // pause duration at empty row before next phrase (ms)

// Returns a spike glyph for the outer fringe based on a normalised angle
// in [0, 2) (where 0 and 2 both correspond to 0 radians).
function SpikeChar(ANorm: Single): string;
begin
  if (ANorm < 0.125) or (ANorm >= 1.875) then
    Result := '-'
  else if ANorm < 0.375 then
    Result := '\'
  else if ANorm < 0.625 then
    Result := '|'
  else if ANorm < 0.875 then
    Result := '/'
  else if ANorm < 1.125 then
    Result := '-'
  else if ANorm < 1.375 then
    Result := '\'
  else if ANorm < 1.625 then
    Result := '|'
  else
    Result := '/';
end;

constructor TDelphiDayBanner.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FBlinkOn := True;
  FTwState := tsTyping;
end;

procedure TDelphiDayBanner.DoTick(AElapsedMs: Integer);
begin
  // Glow phase update
  FPhaseMs := FPhaseMs + AElapsedMs;
  if FPhaseMs >= CGlowPeriodMs then
    FPhaseMs := FPhaseMs - CGlowPeriodMs;

  // Blinking cursor toggle every 500 ms (active in all typewriter states)
  FBlinkAccumMs := FBlinkAccumMs + AElapsedMs;
  if FBlinkAccumMs >= 500.0 then
  begin
    FBlinkAccumMs := FBlinkAccumMs - 500.0;
    FBlinkOn := not FBlinkOn;
  end;

  // Typewriter state machine
  var LPhrase := CTwPhrases[FTwPhraseIdx];
  case FTwState of
    tsTyping:
    begin
      FTwAccumMs := FTwAccumMs + AElapsedMs;
      var LStep := 1000.0 / Max(1, CTwCharsPerSec);
      while FTwAccumMs >= LStep do
      begin
        FTwAccumMs := FTwAccumMs - LStep;
        if FTwVisible < Length(LPhrase) then
          Inc(FTwVisible);
      end;
      if FTwVisible >= Length(LPhrase) then
      begin
        FTwState := tsHolding;
        FTwStateMs := 0.0;
        FTwAccumMs := 0.0;
      end;
    end;
    tsHolding:
    begin
      FTwStateMs := FTwStateMs + AElapsedMs;
      if FTwStateMs >= CTwHoldMs then
      begin
        FTwState := tsErasing;
        FTwStateMs := 0.0;
        FTwAccumMs := 0.0;
      end;
    end;
    tsErasing:
    begin
      FTwAccumMs := FTwAccumMs + AElapsedMs;
      var LEraseStep := 1000.0 / Max(1, CTwEraseCharsPerSec);
      while FTwAccumMs >= LEraseStep do
      begin
        FTwAccumMs := FTwAccumMs - LEraseStep;
        if FTwVisible > 0 then
          Dec(FTwVisible);
      end;
      if FTwVisible <= 0 then
      begin
        FTwState := tsPausing;
        FTwStateMs := 0.0;
        FTwAccumMs := 0.0;
      end;
    end;
    tsPausing:
    begin
      FTwStateMs := FTwStateMs + AElapsedMs;
      if FTwStateMs >= CTwPauseMs then
      begin
        FTwPhraseIdx := (FTwPhraseIdx + 1) mod Length(CTwPhrases);
        FTwVisible := 0;
        FTwState := tsTyping;
        FTwStateMs := 0.0;
        FTwAccumMs := 0.0;
      end;
    end;
  end;

  Invalidate;
end;

procedure TDelphiDayBanner.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  // --- Colour palette (all ckRGB so LerpColor works without raising ETuiFX) ---
  var LBlack := TTuiColor.RGB(0, 0, 0);
  var LGoldDark := TTuiColor.RGB(120, 80, 0);
  var LGoldBright := TTuiColor.RGB(255, 215, 0);
  var LWhite := TTuiColor.RGB(245, 245, 245);
  var LGreen := TTuiColor.RGB(0, 146, 70);
  var LWhiteFlag := TTuiColor.RGB(241, 242, 241);
  var LRed := TTuiColor.RGB(206, 43, 55);
  var LSubColor := TTuiColor.RGB(200, 200, 200);

  // Fill entire background black
  ACanvas.FillRect(ARect, ' ', TTuiStyle.Create(TTuiColor.Default, LBlack));

  // --- Coccarda bounding box dimensions ---
  var LWreathW := Round((CRoutRows + 1) * 2 * CKx);
  var LWreathH := (CRoutRows + 1) * 2;

  // --- Measure DELPHIDAY text block width (9 letters) ---
  var LTextW := 0;
  for var LMI := 0 to 8 do
  begin
    Inc(LTextW, Length(CFontGlyphs[CWordLetters[LMI]][0]));
    if LMI < 8 then
      Inc(LTextW, CLetterGap);
  end;

  // --- Composition origin: centred in ARect ---
  var LTotalW := LWreathW + CGapCols + LTextW;
  // Vertical extent: wreath + ANNIVERSARY row + gap + typewriter row
  var LTotalH := LWreathH + 3;
  var LOrigX := ARect.Left + Max(0, (ARect.Width - LTotalW) div 2);
  var LOrigY := ARect.Top + Max(0, (ARect.Height - LTotalH) div 2);

  // Coccarda centre cell
  var LCX := LOrigX + LWreathW div 2;
  var LCY := LOrigY + LWreathH div 2;

  // Text block position (text height = 5 font + 1 gap + 1 tricolour + 1 gap + 1 subtitle = 9)
  var LTextBlockH := 9;
  var LTextX := LOrigX + LWreathW + CGapCols;
  var LTextY := LOrigY + Max(0, (LWreathH - LTextBlockH) div 2);

  // Current glow phase in radians
  var LPhase := (FPhaseMs / CGlowPeriodMs) * 2 * Pi;

  // --- Inner ring: 36 filled blocks at radius CRinRows ---
  for var LRI := 0 to 35 do
  begin
    var LAngle := LRI * (2 * Pi / 36);
    var LX := LCX + Round(CKx * CRinRows * Cos(LAngle));
    var LY := LCY + Round(CRinRows * Sin(LAngle));
    var LT := (Sin(LPhase + LAngle * 2.0) + 1.0) / 2.0;
    var LFg := LerpColor(LGoldDark, LGoldBright, LT);
    ACanvas.WriteAt(LX, LY, '█', TTuiStyle.Create(LFg, LBlack, [taBold]));
  end;

  // --- Outer fringe: 24 radiating spikes from CRinRows+1 to CRoutRows ---
  for var LFI := 0 to 23 do
  begin
    var LAngle := LFI * (2 * Pi / 24);
    var LNorm := LAngle / Pi; // normalised to [0, 2)
    var LSpikeStr := SpikeChar(LNorm);
    for var LR := CRinRows + 1 to CRoutRows do
    begin
      var LX := LCX + Round(CKx * LR * Cos(LAngle));
      var LY := LCY + Round(LR * Sin(LAngle));
      var LT := (Sin(LPhase + LAngle * 2.0 + LR * 0.3) + 1.0) / 2.0;
      var LFg := LerpColor(LGoldDark, LGoldBright, LT);
      ACanvas.WriteAt(LX, LY, LSpikeStr, TTuiStyle.Create(LFg, LBlack, [taBold]));
    end;
  end;

  // --- "25" block-pixel digits centred inside the coccarda ---
  var L25W := Length(CDigitGlyphs[0][0]) + CLetterGap + Length(CDigitGlyphs[1][0]);
  var L25OrigX := LCX - L25W div 2;
  var L25PenX := L25OrigX;
  var L25Y := LCY - 2;
  for var LDI := 0 to 1 do
  begin
    var LDigitW := Length(CDigitGlyphs[LDI][0]);
    for var LRow := 0 to 4 do
    begin
      var LLine := CDigitGlyphs[LDI][LRow];
      for var LCol := 1 to Length(LLine) do
      begin
        if LLine[LCol] = '█' then
          ACanvas.WriteAt(L25PenX + LCol - 1, L25Y + LRow, '█',
            TTuiStyle.Create(LGoldBright, LBlack, [taBold]));
      end;
    end;
    Inc(L25PenX, LDigitW + CLetterGap);
  end;
  // "th" superscript immediately to the right of "25", at top row
  ACanvas.WriteAt(L25OrigX + L25W, L25Y, 'th',
    TTuiStyle.Create(LGoldBright, LBlack, [taBold]));

  // --- "ANNIVERSARY" one row below the wreath bounding box ---
  var LAnniv := 'ANNIVERSARY';
  ACanvas.WriteAt(LCX - Length(LAnniv) div 2, LOrigY + LWreathH,
    LAnniv, TTuiStyle.Create(LGoldBright, LBlack, [taBold]));

  // --- DELPHIDAY block-pixel font ---
  var LPenX := LTextX;
  for var LLI := 0 to 8 do
  begin
    var LGlyph := CWordLetters[LLI];
    var LLetterW := Length(CFontGlyphs[LGlyph][0]);
    for var LRow := 0 to 4 do
    begin
      var LLine := CFontGlyphs[LGlyph][LRow];
      for var LCol := 1 to Length(LLine) do
      begin
        if LLine[LCol] = '█' then
          ACanvas.WriteAt(LPenX + LCol - 1, LTextY + LRow, '█',
            TTuiStyle.Create(LWhite, LBlack, [taBold]));
      end;
    end;
    Inc(LPenX, LLetterW + CLetterGap);
  end;

  // --- Italian tricolour bar (1 row, 1 gap below letter font) ---
  var LFlagY := LTextY + 6;
  var LSec := LTextW div 3;
  ACanvas.FillRect(TRect.Create(LTextX, LFlagY, LTextX + LSec, LFlagY + 1),
    ' ', TTuiStyle.Create(TTuiColor.Default, LGreen));
  ACanvas.FillRect(TRect.Create(LTextX + LSec, LFlagY, LTextX + 2 * LSec, LFlagY + 1),
    ' ', TTuiStyle.Create(TTuiColor.Default, LWhiteFlag));
  ACanvas.FillRect(TRect.Create(LTextX + 2 * LSec, LFlagY, LTextX + LTextW, LFlagY + 1),
    ' ', TTuiStyle.Create(TTuiColor.Default, LRed));

  // --- "italian conference" subtitle: spaced letters, wider word gap, centred ---
  var LSub := 'i t a l i a n   c o n f e r e n c e';
  var LSubX := LTextX + Max(0, (LTextW - Length(LSub)) div 2);
  ACanvas.WriteAt(LSubX, LFlagY + 2, LSub, TTuiStyle.Create(LSubColor, LBlack));

  // --- Typewriter banner two rows below the logo ---
  var LBottom := Max(LOrigY + LWreathH, LFlagY + 2);
  var LTwY := LBottom + 2;
  var LTwPhrase := CTwPhrases[FTwPhraseIdx];
  // Anchor X centred on the DELPHIDAY text block; position stays stable while typing
  var LTwBaseX := LTextX + Max(0, (LTextW - Length(LTwPhrase) - 1) div 2);
  var LTwText := Copy(LTwPhrase, 1, FTwVisible);
  if Length(LTwText) > 0 then
    ACanvas.WriteAt(LTwBaseX, LTwY, LTwText, TTuiStyle.Create(LWhite, LBlack));
  if FBlinkOn then
    ACanvas.WriteAt(LTwBaseX + FTwVisible, LTwY, '_',
      TTuiStyle.Create(LGoldBright, LBlack, [taInverse]));
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  var LApp := TTuiApp.Create;
  try
    var LBanner := TDelphiDayBanner.Create;
    LApp.SetRoot(LBanner);
    LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        if (AKey.Code = kcEscape) or
           ((AKey.Code = kcChar) and (UpCase(AKey.Character) = 'Q')) then
          LApp.Quit;
      end;
    LApp.Run;
  finally
    LApp.Free;
  end;
end.
