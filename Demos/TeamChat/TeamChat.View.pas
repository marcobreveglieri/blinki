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
{   Unit:        TeamChat.View.pas                               }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TeamChatDemo -- TChatView widget: message history with scroll, adaptive word-wrap
///   and an animated "is typing..." indicator driven by DoTick.
/// </summary>
unit TeamChat.View;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  System.Generics.Collections,
  Blinki.Core.Widget,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  TeamChat.Model;

type

{ TDisplayLine }

  /// <summary>
  ///   A single display row produced by DoRender (view-local type).
  /// </summary>
  TDisplayLine = record
    Text: string;
    Fg: TTuiColor;
    Bold: Boolean;
  end;

{ TChatView }

  /// <summary>
  ///   Custom widget for the message history.
  ///   Supports keyboard scroll, adaptive word-wrap to the width of the
  ///   assigned layout rectangle, automatic follow-tail when messages are
  ///   appended, and an animated "is typing..." indicator driven by DoTick.
  /// </summary>
  TChatView = class(TTuiWidget)
  strict private
    FCachedLines: TList<TDisplayLine>; // display-line cache; rebuilt on content/width change
    FCacheWidth: Integer; // body width for which the cache is valid; -1 = dirty
    FChannel: TChatChannel; // non-owning reference
    FFollowTail: Boolean; // True = automatically anchor to the tail
    FScrollOffset: Integer; // first visible row (used only when FFollowTail=False)
    FTypingAccumMs: Integer;
    FTypingActive: Boolean;
    FTypingAuthor: string;
    FTypingDots: Integer; // 0..2 — cycles to create the dot animation
    // metadata updated in DoRender for use in DoHandleEvent
    FLastTotalLines: Integer;
    FLastViewHeight: Integer;
  protected
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoTick(AElapsedMs: Integer); override;
  public
    constructor Create(AParent: TTuiWidget = nil);
    destructor Destroy; override;
    /// <summary>
    ///   Sets the channel to display and resets the scroll state.
    /// </summary>
    procedure SetChannel(AChannel: TChatChannel);
    /// <summary>
    ///   Adds a message to the current channel and forces a redraw.
    /// </summary>
    procedure AppendMessage(const AMsg: TChatMsg);
    /// <summary>
    ///   Starts the "is typing..." indicator for the given author.
    /// </summary>
    procedure BeginTyping(const AAuthor: string);
    /// <summary>
    ///   Turns off the "is typing..." indicator.
    /// </summary>
    procedure EndTyping;
  end;

implementation

uses
  System.Math,
  Blinki.Core.Input,
  TeamChat.Helpers;

const
  CDotCycleMs = 450;  // ms per animation dot step

{ TChatView }

constructor TChatView.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FCachedLines := TList<TDisplayLine>.Create;
  FCacheWidth := -1;
  FFollowTail := True;
  FLastViewHeight := 1;
end;

destructor TChatView.Destroy;
begin
  FCachedLines.Free;
  inherited Destroy;
end;

procedure TChatView.DoApplyTheme(const ATheme: TTuiTheme);
begin
  FCacheWidth := -1;
  inherited DoApplyTheme(ATheme);
end;

procedure TChatView.DoInit;
begin
  SetFocusable(True);
end;

procedure TChatView.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
const
  CIndent = 2;
begin
  if ARect.IsEmpty then
    Exit;

  var LBgStyle := TTuiStyle.Create(TTuiColor.Default, Theme.Surface);
  ACanvas.FillRect(ARect, ' ', LBgStyle);

  if FChannel = nil then
    Exit;

  var LViewHeight := ARect.Height;
  var LBodyWidth := ARect.Width - CIndent;
  if LBodyWidth < 1 then
    LBodyWidth := 1;

  // rebuild display-line cache when width or content changed
  if LBodyWidth <> FCacheWidth then
  begin
    FCachedLines.Clear;
    var LLine: TDisplayLine;
    for var LMsg in FChannel.Messages do
    begin
      case LMsg.Kind of
        mkSystem:
        begin
          LLine.Text := '  -- ' + LMsg.Text + ' --';
          LLine.Fg := Theme.TextDim;
          LLine.Bold := False;
          FCachedLines.Add(LLine);
        end;

        mkOther, mkMe:
        begin
          var LHdrFg: TTuiColor;
          if LMsg.Kind = mkMe then
            LHdrFg := Theme.Primary
          else
            LHdrFg := AuthorColor(LMsg.Author);

          LLine.Text := '  ' + LMsg.Author + '  ' + LMsg.Time;
          LLine.Fg := LHdrFg;
          LLine.Bold := True;
          FCachedLines.Add(LLine);

          var LWrapped := SplitIntoLines(LMsg.Text, LBodyWidth);
          for var LWrappedLine in LWrapped do
          begin
            LLine.Text := '  ' + LWrappedLine;
            LLine.Fg := Theme.Text;
            LLine.Bold := False;
            FCachedLines.Add(LLine);
          end;
        end;
      end;
    end;
    FCacheWidth := LBodyWidth;
  end;

  // typing indicator rendered live (not cached — changes every CDotCycleMs)
  var LMsgLines := FCachedLines.Count;
  var LTypingText := '';
  if FTypingActive then
  begin
    var LDots: string;
    case FTypingDots of
      0: LDots := '.  ';
      1: LDots := '.. ';
    else
      LDots := '...';
    end;
    LTypingText := '  ' + FTypingAuthor + ' is typing' + LDots;
  end;
  var LTotalLines := LMsgLines;
  if LTypingText <> '' then
    Inc(LTotalLines);

  // compute scroll offset
  var LScrollOff: Integer;
  if FFollowTail then
    LScrollOff := Max(0, LTotalLines - LViewHeight)
  else
    LScrollOff := Max(0, Min(FScrollOffset, LTotalLines - LViewHeight));

  // update render metadata (used in DoHandleEvent)
  FLastViewHeight := LViewHeight;
  FLastTotalLines := LTotalLines;

  // draw visible rows
  var LY := ARect.Top;
  var LI := LScrollOff;
  while (LI < LTotalLines) and (LY < ARect.Top + ARect.Height) do
  begin
    var LLine: TDisplayLine;
    if LI < LMsgLines then
      LLine := FCachedLines[LI]
    else
    begin
      LLine.Text := LTypingText;
      LLine.Fg := Theme.TextDim;
      LLine.Bold := False;
    end;
    var LAttrs: TTuiTextAttrs;
    if LLine.Bold then
      LAttrs := [taBold]
    else
      LAttrs := [];
    var LText := Copy(LLine.Text, 1, ARect.Width);
    ACanvas.WriteAt(ARect.Left, LY, LText,
      TTuiStyle.Create(LLine.Fg, Theme.Surface, LAttrs));
    Inc(LY);
    Inc(LI);
  end;
end;

function TChatView.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;

  var LMaxOffset := Max(0, FLastTotalLines - FLastViewHeight);

  case AEvent.Key.Code of
    kcUp:
    begin
      if FFollowTail then
      begin
        FFollowTail := False;
        FScrollOffset := Max(0, LMaxOffset - 1);
      end
      else
        FScrollOffset := Max(0, FScrollOffset - 1);
      Invalidate;
      Result := True;
    end;

    kcDown:
    begin
      if not FFollowTail then
      begin
        if FScrollOffset < LMaxOffset then
          Inc(FScrollOffset)
        else
          FFollowTail := True;
        Invalidate;
        Result := True;
      end;
    end;

    kcPageUp:
    begin
      var LStep := Max(1, FLastViewHeight - 1);
      if FFollowTail then
      begin
        FFollowTail := False;
        FScrollOffset := Max(0, LMaxOffset - LStep);
      end
      else
        FScrollOffset := Max(0, FScrollOffset - LStep);
      Invalidate;
      Result := True;
    end;

    kcPageDown:
    begin
      var LStep := Max(1, FLastViewHeight - 1);
      if not FFollowTail then
      begin
        FScrollOffset := FScrollOffset + LStep;
        if FScrollOffset >= LMaxOffset then
          FFollowTail := True;
        Invalidate;
        Result := True;
      end;
    end;

    kcHome:
    begin
      FFollowTail := False;
      FScrollOffset := 0;
      Invalidate;
      Result := True;
    end;

    kcEnd:
    begin
      FFollowTail := True;
      Invalidate;
      Result := True;
    end;
  end;
end;

procedure TChatView.DoTick(AElapsedMs: Integer);
begin
  if not FTypingActive then
    Exit;
  Inc(FTypingAccumMs, AElapsedMs);
  if FTypingAccumMs >= CDotCycleMs then
  begin
    FTypingAccumMs := 0;
    FTypingDots := (FTypingDots + 1) mod 3;
    Invalidate;
  end;
end;

procedure TChatView.SetChannel(AChannel: TChatChannel);
begin
  FChannel := AChannel;
  FCacheWidth := -1;
  FScrollOffset := 0;
  FFollowTail := True;
  FTypingActive := False;
  FTypingDots := 0;
  FTypingAccumMs := 0;
  Invalidate;
end;

procedure TChatView.AppendMessage(const AMsg: TChatMsg);
begin
  if FChannel = nil then
    Exit;
  FChannel.Messages.Add(AMsg);
  FCacheWidth := -1;
  Invalidate;
end;

procedure TChatView.BeginTyping(const AAuthor: string);
begin
  FTypingAuthor := AAuthor;
  FTypingActive := True;
  FTypingDots := 0;
  FTypingAccumMs := 0;
  Invalidate;
end;

procedure TChatView.EndTyping;
begin
  if not FTypingActive then
    Exit;
  FTypingActive := False;
  FTypingDots := 0;
  Invalidate;
end;

end.
