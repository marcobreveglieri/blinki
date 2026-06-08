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
{   Unit:        Blinki.Widgets.Spinner.pas                      }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiSpinner: waiting animation cycling through rotating Unicode frames.
/// </summary>
unit Blinki.Widgets.Spinner;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget;

const
  /// <summary>
  ///   Braille dot-spin animation frames (10 frames, U+280B..U+280F range).
  ///   Exposed here so that non-widget code (e.g. CLI wizards) can use the same
  ///   canonical frame sequence without duplicating it.
  /// </summary>
  CTuiSpinnerDotsFrames: array[0..9] of string = (
    #$280B, #$2819, #$2839, #$2838, #$283C,
    #$2834, #$2826, #$2827, #$2807, #$280F);

type

  { TTuiSpinnerStyle }

  /// <summary>
  ///   Animation style of the spinner.
  /// </summary>
  TTuiSpinnerStyle = (
    /// <summary>
    ///   Braille dots (10 frames).
    /// </summary>
    ssDots,
    /// <summary>
    ///   Rotating dash (4 frames).
    /// </summary>
    ssLine,
    /// <summary>
    ///   Circle (4 frames).
    /// </summary>
    ssCircle,
    /// <summary>
    ///   Rotating arrow (8 frames).
    /// </summary>
    ssArrow,
    /// <summary>
    ///   Braille bounce (8 frames).
    /// </summary>
    ssBounce
  );

{ TTuiSpinner }

  /// <summary>
  ///   Animated widget that cycles through Unicode frames. Advances automatically via DoTick.
  ///   The frame colour is updated from the theme on change. The optional SpinnerLabel is
  ///   rendered to the right of the current frame.
  /// </summary>
  TTuiSpinner = class(TTuiWidget)
  strict private
    FStyle: TTuiSpinnerStyle;
    FColor: TTuiColor;
    FLabel: string;
    FFrameDelayMs: Integer;
    FAccumMs: Integer;
    FFrameIndex: Integer;
    FColorOverride: Boolean;
    procedure SetStyle(AValue: TTuiSpinnerStyle);
    procedure SetColor(const AValue: TTuiColor);
    procedure SetSpinnerLabel(const AValue: string);
    procedure SetFrameDelayMs(AValue: Integer);
    function CurrentFrame: string;
    function FrameCount: Integer;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    /// <summary>
    ///   Creates the spinner. Default style: ssDots; FrameDelayMs: 80.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Animation style. Changing the style resets the current frame index.
    /// </summary>
    property Style: TTuiSpinnerStyle read FStyle write SetStyle;
    /// <summary>
    ///   Colour of the animated frame. Once set explicitly, the theme no longer overrides it.
    /// </summary>
    property Color: TTuiColor read FColor write SetColor;
    /// <summary>
    ///   Text displayed to the right of the current frame. Empty string means spinner only.
    /// </summary>
    property SpinnerLabel: string read FLabel write SetSpinnerLabel;
    /// <summary>
    ///   Milliseconds between frames. Default: 80 (~12 fps).
    /// </summary>
    property FrameDelayMs: Integer read FFrameDelayMs write SetFrameDelayMs;
  end;

implementation

uses
  Blinki.Core.Event;

const

  // CTuiSpinnerDotsFrames is now defined in the interface section and used directly.

  // Lines spinner
  CFramesLine:   array[0..3] of string = ('|', '/', '-', '\');

  // Circle quarters — U+25D0..U+25D3
  CFramesCircle: array[0..3] of string = (#$25D0, #$25D3, #$25D1, #$25D2);

  // Directional arrows — U+2190..U+2199
  CFramesArrow:  array[0..7] of string = (
    #$2190, #$2196, #$2191, #$2197,
    #$2192, #$2198, #$2193, #$2199);

  // Braille bounce — U+2801..U+2880 range
  CFramesBounce: array[0..7] of string = (
    #$2801, #$2802, #$2804, #$2840,
    #$2880, #$2820, #$2810, #$2808);

{ TTuiSpinner }

constructor TTuiSpinner.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FFrameDelayMs := 80;
  FColor := Theme.Primary;
  FStyle := ssDots;
end;

function TTuiSpinner.FrameCount: Integer;
begin
  case FStyle of
    ssDots:
      Result := Length(CTuiSpinnerDotsFrames);
    ssLine:
      Result := Length(CFramesLine);
    ssCircle:
      Result := Length(CFramesCircle);
    ssArrow:
      Result := Length(CFramesArrow);
    ssBounce:
      Result := Length(CFramesBounce);
  else
    Result := 1;
  end;
end;

function TTuiSpinner.CurrentFrame: string;
begin
  var LIdx := FFrameIndex;
  case FStyle of
    ssDots:
      Result := CTuiSpinnerDotsFrames[LIdx];
    ssLine:
      Result := CFramesLine[LIdx];
    ssCircle:
      Result := CFramesCircle[LIdx];
    ssArrow:
      Result := CFramesArrow[LIdx];
    ssBounce:
      Result := CFramesBounce[LIdx];
  else
    Result := '?';
  end;
end;

procedure TTuiSpinner.DoApplyTheme(const ATheme: TTuiTheme);
begin
  if not FColorOverride then
    FColor := ATheme.Primary;
end;

procedure TTuiSpinner.DoTick(AElapsedMs: Integer);
begin
  Inc(FAccumMs, AElapsedMs);
  if FAccumMs >= FFrameDelayMs then
  begin
    FAccumMs := FAccumMs mod FFrameDelayMs;
    FFrameIndex := (FFrameIndex + 1) mod FrameCount;
    Invalidate;
  end;
end;

procedure TTuiSpinner.SetStyle(AValue: TTuiSpinnerStyle);
begin
  if FStyle = AValue then
    Exit;
  FStyle := AValue;
  FFrameIndex := 0;
  FAccumMs := 0;
  Invalidate;
end;

procedure TTuiSpinner.SetColor(const AValue: TTuiColor);
begin
  if FColor = AValue then
    Exit;
  FColor := AValue;
  FColorOverride := True;
  Invalidate;
end;

procedure TTuiSpinner.SetSpinnerLabel(const AValue: string);
begin
  if FLabel = AValue then
    Exit;
  FLabel := AValue;
  Invalidate;
end;

procedure TTuiSpinner.SetFrameDelayMs(AValue: Integer);
begin
  if AValue < 1 then
    AValue := 1;
  if FFrameDelayMs = AValue then
    Exit;
  FFrameDelayMs := AValue;
end;

procedure TTuiSpinner.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  var LText := CurrentFrame;
  if FLabel <> '' then
    LText := LText + ' ' + FLabel;
  if Length(LText) > ARect.Width then
    LText := Copy(LText, 1, ARect.Width);
  var LStyle := TTuiStyle.Create(FColor,       Theme.Background);
  var LBgStyle := TTuiStyle.Create(Theme.Text,   Theme.Background);
  ACanvas.FillRect(ARect, ' ', LBgStyle);
  ACanvas.WriteAt(ARect.Left, ARect.Top, LText, LStyle);
end;

end.
