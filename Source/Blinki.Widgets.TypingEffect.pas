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
{   Unit:        Blinki.Widgets.TypingEffect.pas                 }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget TTuiTypingEffect: displays text character by character, simulating typing.
/// </summary>
unit Blinki.Widgets.TypingEffect;

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

type

{ TTuiTypingEffect }

  /// <summary>
  ///   Non-focusable widget that reveals text one character at a time via DoTick.
  ///   The blinking cursor (_) appears after the last visible character while the
  ///   animation is active. Reset() restarts the animation from the beginning.
  ///   Text is limited to a single line; use multiple instances for multi-line text.
  /// </summary>
  TTuiTypingEffect = class(TTuiWidget)
  strict private
    FText: string;
    FCharsPerSecond: Integer;
    FActive: Boolean;
    FVisibleCount: Integer;
    FAccumMs: Integer;
    FBlinkAccum: Integer;
    FBlinkOn: Boolean;
    FOnComplete: TProc;
    FTextStyle: TTuiStyle;
    FStyleOverride: Boolean;
    procedure SetText(const AValue: string);
    procedure SetCharsPerSecond(AValue: Integer);
    procedure SetTextStyle(const AValue: TTuiStyle);
    procedure RebuildStyle;
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    /// <summary>
    ///   Creates the widget. CharsPerSecond defaults to 30. Animation starts immediately.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Restarts the animation from the beginning.
    /// </summary>
    procedure Reset;
    /// <summary>
    ///   Full text to be revealed. Changing the value restarts the animation.
    /// </summary>
    property Text: string read FText write SetText;
    /// <summary>
    ///   Reveal speed in characters per second. Default: 30.
    /// </summary>
    property CharsPerSecond: Integer read FCharsPerSecond write SetCharsPerSecond;
    /// <summary>
    ///   True while the animation is still in progress.
    /// </summary>
    property Active: Boolean read FActive;
    /// <summary>
    ///   Invoked when the last character becomes visible.
    /// </summary>
    property OnComplete: TProc read FOnComplete write FOnComplete;
    /// <summary>
    ///   Text style. Assigning a value disables automatic updates from the theme.
    /// </summary>
    property TextStyle: TTuiStyle read FTextStyle write SetTextStyle;
  end;

implementation

uses
  System.Math,
  Blinki.Core.Event;

{ TTuiTypingEffect }

constructor TTuiTypingEffect.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FCharsPerSecond := 30;
  FActive := True;
  FBlinkOn := True;
  RebuildStyle;
end;

procedure TTuiTypingEffect.RebuildStyle;
begin
  if not FStyleOverride then
    FTextStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
end;

procedure TTuiTypingEffect.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyle;
end;

procedure TTuiTypingEffect.Reset;
begin
  FActive := True;
  FVisibleCount := 0;
  FAccumMs := 0;
  FBlinkAccum := 0;
  FBlinkOn := True;
  Invalidate;
end;

procedure TTuiTypingEffect.DoTick(AElapsedMs: Integer);
begin
  if FActive then
  begin
    Inc(FAccumMs, AElapsedMs);
    var LStep := 1000 div Max(1, FCharsPerSecond);
    while FAccumMs >= LStep do
    begin
      Dec(FAccumMs, LStep);
      if FVisibleCount < Length(FText) then
      begin
        Inc(FVisibleCount);
        if FVisibleCount >= Length(FText) then
        begin
          FActive := False;
          if Assigned(FOnComplete) then
            FOnComplete;
        end;
      end;
    end;
    Invalidate;
  end;

  // Blinking cursor always active during the animation
  if FActive then
  begin
    Inc(FBlinkAccum, AElapsedMs);
    if FBlinkAccum >= 500 then
    begin
      Dec(FBlinkAccum, 500);
      FBlinkOn := not FBlinkOn;
      Invalidate;
    end;
  end;
end;

procedure TTuiTypingEffect.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  ACanvas.FillRect(ARect, ' ', FTextStyle);

  var LWidth := ARect.Width;
  var LVisible := Copy(FText, 1, FVisibleCount);

  if Length(LVisible) > LWidth then
    LVisible := Copy(LVisible, Length(LVisible) - LWidth + 1, LWidth);

  ACanvas.WriteAt(ARect.Left, ARect.Top, LVisible, FTextStyle);

  // Cursor after the last visible character
  if FActive and FBlinkOn then
  begin
    var LCursor := '_';
    ACanvas.WriteAt(ARect.Left + Min(Length(LVisible), LWidth - 1), ARect.Top,
      LCursor, TTuiStyle.Create(FTextStyle.Foreground, FTextStyle.Background, [taInverse]));
  end;
end;

procedure TTuiTypingEffect.SetText(const AValue: string);
begin
  if FText = AValue then
    Exit;
  FText := AValue;
  Reset;
end;

procedure TTuiTypingEffect.SetCharsPerSecond(AValue: Integer);
begin
  if AValue < 1 then
    AValue := 1;
  if FCharsPerSecond = AValue then
    Exit;
  FCharsPerSecond := AValue;
end;

procedure TTuiTypingEffect.SetTextStyle(const AValue: TTuiStyle);
begin
  if FTextStyle = AValue then
    Exit;
  FTextStyle := AValue;
  FStyleOverride := True;
  Invalidate;
end;

end.
