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
{   Unit:        WorldCup.Dashboard.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   WorldCupDemo -- TWorldCupDashboard: full-screen dashboard widget.
///   Renders live matches, group standings, top scorers, and a schedule
///   panel in a multi-column grid. Press B to switch to the knockout
///   bracket view. All drawing is done directly on the canvas — no
///   child widgets are created.
/// </summary>
unit WorldCup.Dashboard;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  WorldCup.Model;

type

  /// <summary>
  ///   Active rendering mode: main multi-panel dashboard or knockout bracket.
  /// </summary>
  TDashboardMode = (dmDashboard, dmBracket);

{ TWorldCupDashboard }

  /// <summary>
  ///   Main dashboard widget for the World Cup demo.
  ///   Focusable; handles Left/Right (group selection) and B (bracket toggle).
  /// </summary>
  TWorldCupDashboard = class(TTuiWidget)
  strict private
    FBgStyle: TTuiStyle;
    FBorderFocusedStyle: TTuiStyle;
    FBorderStyle: TTuiStyle;
    FDimStyle: TTuiStyle;
    FErrorStyle: TTuiStyle;
    FHeaderStyle: TTuiStyle;
    FLiveStyle: TTuiStyle;
    FModel: TWorldCupModel;
    FMode: TDashboardMode;
    FSelGroup: Integer;
    FSuccessStyle: TTuiStyle;
    FTextStyle: TTuiStyle;
    FWarnStyle: TTuiStyle;
    function TieLabel(const ATie: TBracketTie): string;
    procedure RebuildStyles(const ATheme: TTuiTheme);
    procedure RenderBanner(const ACanvas: TTuiCanvas; const ARect: TRect);
    procedure RenderBracket(const ACanvas: TTuiCanvas; const ARect: TRect);
    procedure RenderDashboard(const ACanvas: TTuiCanvas; const ARect: TRect);
    procedure RenderGroupPanel(const ACanvas: TTuiCanvas; const ARect: TRect);
    procedure RenderLivePanel(const ACanvas: TTuiCanvas; const ARect: TRect);
    procedure RenderSchedulePanel(const ACanvas: TTuiCanvas; const ARect: TRect);
    procedure RenderScorersPanel(const ACanvas: TTuiCanvas; const ARect: TRect);
  protected
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    constructor Create(AModel: TWorldCupModel; AParent: TTuiWidget = nil);
    /// <summary>
    ///   Index (0-7) of the currently displayed group in the standings panel.
    /// </summary>
    property SelectedGroup: Integer read FSelGroup;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.FX.Gradient,
  WorldCup.Consts,
  WorldCup.Helpers;

{ TWorldCupDashboard }

constructor TWorldCupDashboard.Create(AModel: TWorldCupModel;
  AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FModel := AModel;
  FMode := dmDashboard;
end;

procedure TWorldCupDashboard.DoInit;
begin
  SetFocusable(True);
end;

procedure TWorldCupDashboard.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles(ATheme);
  inherited DoApplyTheme(ATheme);
end;

procedure TWorldCupDashboard.RebuildStyles(const ATheme: TTuiTheme);
begin
  FBgStyle := TTuiStyle.Create(ATheme.Text, ATheme.Background);
  FBorderFocusedStyle := TTuiStyle.Create(ATheme.Primary, ATheme.Surface);
  FBorderStyle := TTuiStyle.Create(ATheme.Border, ATheme.Surface);
  FDimStyle := TTuiStyle.Create(ATheme.TextDim, ATheme.Background);
  FErrorStyle := TTuiStyle.Create(ATheme.Error, ATheme.Surface);
  FHeaderStyle := TTuiStyle.Create(ATheme.Background, ATheme.Primary, [taBold]);
  FLiveStyle := TTuiStyle.Create(ATheme.Success, ATheme.Surface, [taBold]);
  FSuccessStyle := TTuiStyle.Create(ATheme.Success, ATheme.Surface);
  FTextStyle := TTuiStyle.Create(ATheme.Text, ATheme.Surface);
  FWarnStyle := TTuiStyle.Create(ATheme.Warning, ATheme.Surface);
end;

function TWorldCupDashboard.TieLabel(const ATie: TBracketTie): string;
begin
  if ATie.Decided then
    Result := ATie.HomeCode + ' ' +
      FormatScore(ATie.HomeScore, ATie.AwayScore) + ' ' + ATie.AwayCode
  else
    Result := ATie.HomeCode + ' vs ' + ATie.AwayCode;
end;

function TWorldCupDashboard.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  if AEvent.Kind <> ekKey then
    Exit;
  case AEvent.Key.Code of
    kcLeft:
    begin
      if FSelGroup > 0 then
      begin
        Dec(FSelGroup);
        Invalidate;
      end;
      Result := True;
    end;
    kcRight:
    begin
      if FSelGroup < CGroupCount - 1 then
      begin
        Inc(FSelGroup);
        Invalidate;
      end;
      Result := True;
    end;
    kcChar:
    begin
      case UpCase(AEvent.Key.Character) of
        'B':
        begin
          if FMode = dmDashboard then
            FMode := dmBracket
          else
            FMode := dmDashboard;
          Invalidate;
          Result := True;
        end;
      end;
    end;
  end;
end;

procedure TWorldCupDashboard.DoRender(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  ACanvas.FillRect(ARect, ' ', FBgStyle);
  var LBannerRect := TRect.Create(ARect.Left, ARect.Top,
    ARect.Right, ARect.Top + CBannerHeight);
  RenderBanner(ACanvas, LBannerRect);
  var LBodyTop := ARect.Top + CBannerHeight;
  if FMode = dmBracket then
  begin
    var LBodyRect := TRect.Create(ARect.Left, LBodyTop,
      ARect.Right, ARect.Bottom);
    RenderBracket(ACanvas, LBodyRect);
  end
  else
  begin
    var LSchedTop := ARect.Bottom - CScheduleHeight;
    if LSchedTop > LBodyTop then
    begin
      var LTopRect := TRect.Create(ARect.Left, LBodyTop,
        ARect.Right, LSchedTop);
      RenderDashboard(ACanvas, LTopRect);
    end;
    if LSchedTop < ARect.Bottom then
    begin
      var LSchedRect := TRect.Create(ARect.Left, Max(LBodyTop, LSchedTop),
        ARect.Right, ARect.Bottom);
      RenderSchedulePanel(ACanvas, LSchedRect);
    end;
  end;
end;

procedure TWorldCupDashboard.RenderBanner(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  ACanvas.FillRect(
    TRect.Create(ARect.Left, ARect.Top, ARect.Right, ARect.Top + 1),
    ' ', TTuiStyle.Create(Theme.Primary, Theme.Background));
  var LTitle := CGlyphBall + ' ' + CAppTitle + ' ' + CGlyphBall;
  var LTitleX := ARect.Left + Max(0, (ARect.Width - Length(LTitle)) div 2);
  DrawGradient(ACanvas, LTitleX, ARect.Top, LTitle,
    TTuiColor.RGB(255, 200, 0), TTuiColor.RGB(0, 200, 80),
    Theme.Background, [taBold]);
  if ARect.Height < 2 then
    Exit;
  var LRow1 := ARect.Top + 1;
  ACanvas.FillRect(
    TRect.Create(ARect.Left, LRow1, ARect.Right, LRow1 + 1),
    ' ', FDimStyle);
  var LHint: string;
  if FMode = dmBracket then
    LHint := '  ' + CBracketTitle + '  B: Back to Dashboard'
  else
  begin
    var LGrp := Chr(Ord('A') + FSelGroup);
    LHint := '  Group ' + LGrp + '   [<][>] Navigate groups   B: Bracket   T: Theme   Q: Quit';
  end;
  ACanvas.WriteAt(ARect.Left, LRow1, LHint, FDimStyle);
end;

procedure TWorldCupDashboard.RenderDashboard(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  var LColW := ARect.Width div 3;
  var LLiveRect := TRect.Create(ARect.Left, ARect.Top,
    ARect.Left + LColW, ARect.Bottom);
  ACanvas.PushClip(LLiveRect);
  try
    RenderLivePanel(ACanvas, LLiveRect);
  finally
    ACanvas.PopClip;
  end;
  var LGroupLeft := ARect.Left + LColW;
  var LGroupRect := TRect.Create(LGroupLeft, ARect.Top,
    LGroupLeft + LColW, ARect.Bottom);
  ACanvas.PushClip(LGroupRect);
  try
    RenderGroupPanel(ACanvas, LGroupRect);
  finally
    ACanvas.PopClip;
  end;
  var LScorersRect := TRect.Create(ARect.Left + LColW * 2, ARect.Top,
    ARect.Right, ARect.Bottom);
  ACanvas.PushClip(LScorersRect);
  try
    RenderScorersPanel(ACanvas, LScorersRect);
  finally
    ACanvas.PopClip;
  end;
end;

procedure TWorldCupDashboard.RenderLivePanel(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  var LBorder: TTuiStyle;
  if Focused then
    LBorder := FBorderFocusedStyle
  else
    LBorder := FBorderStyle;
  ACanvas.FillRect(ARect, ' ', FTextStyle);
  ACanvas.DrawBox(ARect, bsRounded, CLivePanelTitle, LBorder);
  var LX := ARect.Left + 1;
  var LY := ARect.Top + 1;
  var LMaxY := ARect.Bottom - 1;
  var LInnerW := ARect.Width - 2;
  if LInnerW < 4 then
    Exit;
  var LLive := FModel.LiveMatches;
  if Length(LLive) > 0 then
  begin
    for var LMatch in LLive do
    begin
      if LY >= LMaxY then
        Break;
      var LHome := FModel.GetTeam(LMatch.HomeIdx);
      var LAway := FModel.GetTeam(LMatch.AwayIdx);
      var LLine := CGlyphLive + ' ' + LHome.Code + ' ' +
        FormatScore(LMatch.HomeScore, LMatch.AwayScore) +
        ' ' + LAway.Code + '  ' + IntToStr(LMatch.Minute) + #$27;
      if Length(LLine) > LInnerW then
        LLine := Copy(LLine, 1, LInnerW);
      ACanvas.WriteAt(LX, LY, LLine, FLiveStyle);
      Inc(LY);
      var LEvts := FModel.Events(LMatch.Id);
      var LStart := Max(0, Length(LEvts) - 4);
      for var LI := LStart to High(LEvts) do
      begin
        if LY >= LMaxY then
          Break;
        var LEvt := LEvts[LI];
        var LEvtStyle: TTuiStyle;
        var LGlyph: string;
        case LEvt.Kind of
          ekGoal:
          begin
            LEvtStyle := FSuccessStyle;
            LGlyph := CGlyphBall;
          end;
          ekRed:
          begin
            LEvtStyle := FErrorStyle;
            LGlyph := CGlyphCard;
          end;
        else
          // ekYellow
          LEvtStyle := FWarnStyle;
          LGlyph := CGlyphCard;
        end;
        var LEvtLine := '  ' + LGlyph + ' ' +
          IntToStr(LEvt.Minute) + #$27 + ' ' + LEvt.Player;
        if Length(LEvtLine) > LInnerW then
          LEvtLine := Copy(LEvtLine, 1, LInnerW);
        ACanvas.WriteAt(LX, LY, LEvtLine, LEvtStyle);
        Inc(LY);
      end;
      Inc(LY);
    end;
  end
  else
  begin
    ACanvas.WriteAt(LX, LY, 'No live matches', FDimStyle);
    Inc(LY, 2);
  end;
  // Recent finished results
  if LY < LMaxY then
  begin
    ACanvas.WriteAt(LX, LY, 'RECENT RESULTS',
      TTuiStyle.Create(Theme.TextDim, Theme.Surface, [taBold]));
    Inc(LY);
  end;
  var LShown := 0;
  for var LI := 0 to CMatchCount - 1 do
  begin
    if (LY >= LMaxY) or (LShown >= 6) then
      Break;
    var LM := FModel.GetMatch(LI);
    if LM.Status <> msFinished then
      Continue;
    var LHome := FModel.GetTeam(LM.HomeIdx);
    var LAway := FModel.GetTeam(LM.AwayIdx);
    var LLine := 'FT ' + LHome.Code + ' ' +
      FormatScore(LM.HomeScore, LM.AwayScore) + ' ' + LAway.Code;
    if Length(LLine) > LInnerW then
      LLine := Copy(LLine, 1, LInnerW);
    ACanvas.WriteAt(LX, LY, LLine, FDimStyle);
    Inc(LY);
    Inc(LShown);
  end;
end;

procedure TWorldCupDashboard.RenderGroupPanel(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  var LBorder: TTuiStyle;
  if Focused then
    LBorder := FBorderFocusedStyle
  else
    LBorder := FBorderStyle;
  ACanvas.FillRect(ARect, ' ', FTextStyle);
  var LTitle := CGroupPanelPrefix + Chr(Ord('A') + FSelGroup) + ' ';
  ACanvas.DrawBox(ARect, bsRounded, LTitle, LBorder);
  var LX := ARect.Left + 1;
  var LY := ARect.Top + 1;
  var LMaxY := ARect.Bottom - 1;
  var LInnerW := ARect.Width - 2;
  if LInnerW < 10 then
    Exit;
  // Column header row
  var LHdr := PadTeamName('Team', 12) + ' P  W  D  L GF GA Pt';
  if Length(LHdr) > LInnerW then
    LHdr := Copy(LHdr, 1, LInnerW);
  ACanvas.WriteAt(LX, LY, LHdr,
    TTuiStyle.Create(Theme.TextDim, Theme.Surface, [taBold]));
  Inc(LY);
  if LY < LMaxY then
  begin
    ACanvas.WriteAt(LX, LY, StringOfChar(#$2500, Min(LInnerW, 30)),
      TTuiStyle.Create(Theme.Border, Theme.Surface));
    Inc(LY);
  end;
  var LStandings := FModel.StandingsForGroup(FSelGroup);
  for var LIdx := 0 to High(LStandings) do
  begin
    if LY >= LMaxY then
      Break;
    var LS := LStandings[LIdx];
    var LTeam := FModel.GetTeam(LS.TeamIdx);
    var LQual := '';
    if LS.Qualified then
      LQual := CGlyphQual;
    var LName := PadTeamName(LTeam.Code + ' ' + LQual, 12);
    var LRow := LName +
      PadInt(LS.P, 2) + ' ' + PadInt(LS.W, 2) + ' ' +
      PadInt(LS.D, 2) + ' ' + PadInt(LS.L, 2) + ' ' +
      PadInt(LS.GF, 2) + ' ' + PadInt(LS.GA, 2) + ' ' +
      PadInt(LS.Pts, 2);
    if Length(LRow) > LInnerW then
      LRow := Copy(LRow, 1, LInnerW);
    var LRowStyle: TTuiStyle;
    if LS.Qualified then
      LRowStyle := FSuccessStyle
    else
      LRowStyle := FTextStyle;
    ACanvas.WriteAt(LX, LY, LRow, LRowStyle);
    Inc(LY);
  end;
  // Group matches below the standings table
  if LY < LMaxY - 1 then
  begin
    Inc(LY);
    ACanvas.WriteAt(LX, LY, 'MATCHES',
      TTuiStyle.Create(Theme.TextDim, Theme.Surface, [taBold]));
    Inc(LY);
  end;
  var LGroupMatches := FModel.MatchesForGroup(FSelGroup);
  for var LM in LGroupMatches do
  begin
    if LY >= LMaxY then
      Break;
    var LHome := FModel.GetTeam(LM.HomeIdx);
    var LAway := FModel.GetTeam(LM.AwayIdx);
    var LLine: string;
    case LM.Status of
      msFinished:
        LLine := LHome.Code + ' ' +
          FormatScore(LM.HomeScore, LM.AwayScore) + ' ' + LAway.Code + ' FT';
      msLive:
        LLine := CGlyphLive + ' ' + LHome.Code + ' ' +
          FormatScore(LM.HomeScore, LM.AwayScore) + ' ' +
          LAway.Code + ' ' + IntToStr(LM.Minute) + #$27;
    else
      LLine := LHome.Code + ' vs ' + LAway.Code + '  ' + LM.KickoffLabel;
    end;
    if Length(LLine) > LInnerW then
      LLine := Copy(LLine, 1, LInnerW);
    var LMatchStyle: TTuiStyle;
    if LM.Status = msLive then
      LMatchStyle := FLiveStyle
    else if LM.Status = msFinished then
      LMatchStyle := FDimStyle
    else
      LMatchStyle := FTextStyle;
    ACanvas.WriteAt(LX, LY, LLine, LMatchStyle);
    Inc(LY);
  end;
end;

procedure TWorldCupDashboard.RenderScorersPanel(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  var LBorder: TTuiStyle;
  if Focused then
    LBorder := FBorderFocusedStyle
  else
    LBorder := FBorderStyle;
  ACanvas.FillRect(ARect, ' ', FTextStyle);
  ACanvas.DrawBox(ARect, bsRounded, CScorersPanelTitle, LBorder);
  var LX := ARect.Left + 1;
  var LY := ARect.Top + 1;
  var LMaxY := ARect.Bottom - 1;
  var LInnerW := ARect.Width - 2;
  if LInnerW < 8 then
    Exit;
  // Header
  ACanvas.WriteAt(LX, LY,
    PadTeamName('#  Player', 20) + ' Club Gls',
    TTuiStyle.Create(Theme.TextDim, Theme.Surface, [taBold]));
  Inc(LY);
  var LScorers := FModel.TopScorers(12);
  for var LI := 0 to High(LScorers) do
  begin
    if LY >= LMaxY then
      Break;
    var LS := LScorers[LI];
    var LGoalBar := '';
    for var LG := 1 to Min(LS.Goals, 6) do
      LGoalBar := LGoalBar + CGlyphBall;
    var LLine := PadInt(LI + 1, 2) + ' ' +
      PadTeamName(LS.Player, 15) + ' ' +
      LS.TeamCode + ' ' + PadInt(LS.Goals, 2) + ' ' + LGoalBar;
    if Length(LLine) > LInnerW then
      LLine := Copy(LLine, 1, LInnerW);
    var LStyle: TTuiStyle;
    if LI = 0 then
      LStyle := TTuiStyle.Create(Theme.Warning, Theme.Surface, [taBold])
    else
      LStyle := FTextStyle;
    ACanvas.WriteAt(LX, LY, LLine, LStyle);
    Inc(LY);
  end;
  if Length(LScorers) = 0 then
    ACanvas.WriteAt(LX, LY, 'No goals yet', FDimStyle);
end;

procedure TWorldCupDashboard.RenderSchedulePanel(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  ACanvas.FillRect(ARect, ' ', FBgStyle);
  ACanvas.DrawBox(ARect, bsRounded, CSchedulePanelTitle,
    TTuiStyle.Create(Theme.Primary, Theme.Background));
  var LY := ARect.Top + 1;
  var LMaxY := ARect.Bottom - 1;
  if LY >= LMaxY then
    Exit;
  var LHalfW := (ARect.Width - 2) div 2;
  var LX0 := ARect.Left + 1;
  var LX1 := ARect.Left + 1 + LHalfW + 1;
  var LCol := 0;
  for var LI := 0 to CMatchCount - 1 do
  begin
    if LY >= LMaxY then
      Break;
    var LM := FModel.GetMatch(LI);
    var LHome := FModel.GetTeam(LM.HomeIdx);
    var LAway := FModel.GetTeam(LM.AwayIdx);
    var LLine: string;
    case LM.Status of
      msFinished:
        LLine := 'FT  ' + LHome.Code + ' ' +
          FormatScore(LM.HomeScore, LM.AwayScore) + ' ' + LAway.Code;
      msLive:
        LLine := CGlyphLive + '   ' + LHome.Code + ' ' +
          FormatScore(LM.HomeScore, LM.AwayScore) + ' ' +
          LAway.Code + ' ' + IntToStr(LM.Minute) + #$27;
    else
      LLine := LM.KickoffLabel + ' ' + LHome.Code + '-' + LAway.Code;
    end;
    var LCellW := LHalfW - 1;
    if Length(LLine) > LCellW then
      LLine := Copy(LLine, 1, LCellW);
    var LDrawX: Integer;
    if LCol = 0 then
      LDrawX := LX0
    else
      LDrawX := LX1;
    var LLineStyle: TTuiStyle;
    case LM.Status of
      msLive:     LLineStyle := FLiveStyle;
      msFinished: LLineStyle := FDimStyle;
    else
      LLineStyle := FTextStyle;
    end;
    ACanvas.WriteAt(LDrawX, LY, LLine, LLineStyle);
    Inc(LCol);
    if LCol >= 2 then
    begin
      LCol := 0;
      Inc(LY);
    end;
  end;
end;

procedure TWorldCupDashboard.RenderBracket(const ACanvas: TTuiCanvas;
  const ARect: TRect);
const
  CRoundLabels: array[0..3] of string = (
    'ROUND OF 16', 'QUARTER-FINALS', 'SEMI-FINALS', 'FINAL');
begin
  ACanvas.FillRect(ARect, ' ', FTextStyle);
  var LX := ARect.Left + 1;
  var LY := ARect.Top + 1;
  var LMaxY := ARect.Bottom - 1;
  var LColW := Max(14, (ARect.Width - 2) div 4);
  // Headers
  for var LRound := 0 to 3 do
  begin
    var LHX := ARect.Left + 1 + LRound * LColW;
    ACanvas.WriteAt(LHX, LY, Copy(CRoundLabels[LRound], 1, LColW - 1),
      TTuiStyle.Create(Theme.Primary, Theme.Background, [taBold]));
  end;
  Inc(LY);
  if LY < LMaxY then
  begin
    ACanvas.WriteAt(LX, LY, StringOfChar(#$2500, ARect.Width - 2),
      TTuiStyle.Create(Theme.Border, Theme.Background));
    Inc(LY);
  end;
  // Collect ties by round
  var LAllTies := FModel.BracketTies;
  var LR16: TArray<TBracketTie>;
  var LQF: TArray<TBracketTie>;
  var LSF: TArray<TBracketTie>;
  var LFinal: TBracketTie;
  var LHasFinal := False;
  for var LTie in LAllTies do
    case LTie.Round of
      0:
      begin
        SetLength(LR16, Length(LR16) + 1);
        LR16[High(LR16)] := LTie;
      end;
      1:
      begin
        SetLength(LQF, Length(LQF) + 1);
        LQF[High(LQF)] := LTie;
      end;
      2:
      begin
        SetLength(LSF, Length(LSF) + 1);
        LSF[High(LSF)] := LTie;
      end;
      3:
      begin
        LFinal := LTie;
        LHasFinal := True;
      end;
    end;
  // Render one row per R16 tie; align QF/SF/Final on appropriate rows
  for var LRowIdx := 0 to High(LR16) do
  begin
    if LY >= LMaxY then
      Break;
    // Column 0: R16 tie
    var LR16Line := TieLabel(LR16[LRowIdx]);
    if Length(LR16Line) > LColW - 1 then
      LR16Line := Copy(LR16Line, 1, LColW - 1);
    ACanvas.WriteAt(ARect.Left + 1, LY, LR16Line, FTextStyle);
    // Column 1: QF tie every 2 R16 rows
    if (LRowIdx mod 2 = 0) and (LRowIdx div 2 <= High(LQF)) then
    begin
      var LQFLine := TieLabel(LQF[LRowIdx div 2]);
      if Length(LQFLine) > LColW - 1 then
        LQFLine := Copy(LQFLine, 1, LColW - 1);
      ACanvas.WriteAt(ARect.Left + 1 + LColW, LY, LQFLine,
        TTuiStyle.Create(Theme.TextDim, Theme.Background));
    end;
    // Column 2: SF tie every 4 R16 rows
    if (LRowIdx mod 4 = 0) and (LRowIdx div 4 <= High(LSF)) then
    begin
      var LSFLine := TieLabel(LSF[LRowIdx div 4]);
      if Length(LSFLine) > LColW - 1 then
        LSFLine := Copy(LSFLine, 1, LColW - 1);
      ACanvas.WriteAt(ARect.Left + 1 + LColW * 2, LY, LSFLine,
        TTuiStyle.Create(Theme.TextDim, Theme.Background));
    end;
    // Column 3: Final on first row only
    if (LRowIdx = 0) and LHasFinal then
    begin
      var LFinalLine := TieLabel(LFinal);
      ACanvas.WriteAt(ARect.Left + 1 + LColW * 3, LY, LFinalLine,
        TTuiStyle.Create(Theme.Warning, Theme.Background, [taBold]));
    end;
    Inc(LY);
  end;
  // Navigation hint at bottom
  if ARect.Bottom - 2 > LY then
    ACanvas.WriteAt(LX, ARect.Bottom - 2,
      'Press B to return to Dashboard',
      TTuiStyle.Create(Theme.TextDim, Theme.Background));
end;

end.
