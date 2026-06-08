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
{   Unit:        WorldCup.Model.pas                              }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   WorldCupDemo -- Domain types and in-memory simulation model.
///   No UI dependencies. All data is seeded and advanced deterministically.
///   32 teams in 8 groups (A-H), 48 group-stage matches, knockout bracket.
/// </summary>
unit WorldCup.Model;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Generics.Collections,
  Blinki.Core.Style;

const

  /// <summary>
  ///   Total number of teams in the tournament.
  /// </summary>
  CTeamCount = 32;

  /// <summary>
  ///   Total group-stage matches (8 groups x 6 matches each).
  /// </summary>
  CMatchCount = 48;

type

  /// <summary>
  ///   Lifecycle state of a group-stage match.
  /// </summary>
  TMatchStatus = (msScheduled, msLive, msFinished);

  /// <summary>
  ///   Type of an in-match event logged in the event feed.
  /// </summary>
  TEventKind = (ekGoal, ekYellow, ekRed);

  /// <summary>
  ///   Immutable snapshot of a national team.
  /// </summary>
  TTeam = record
    AccentColor: TTuiColor;
    Code: string;
    Name: string;
    /// <summary>
    ///   Creates a TTeam with the given 3-letter code, full name, and RGB accent.
    /// </summary>
    class function Make(const ACode, AName: string;
      AR, AG, AB: Byte): TTeam; static;
  end;

  /// <summary>
  ///   A single event (goal, card) that occurred during a match.
  /// </summary>
  TMatchEvent = record
    Kind: TEventKind;
    Minute: Integer;
    Player: string;
    TeamCode: string;
    /// <summary>
    ///   Creates a fully-initialized TMatchEvent value.
    /// </summary>
    class function Make(AMinute: Integer; AKind: TEventKind;
      const ATeamCode, APlayer: string): TMatchEvent; static;
  end;

  /// <summary>
  ///   Mutable snapshot of a single group-stage match.
  ///   Events are stored separately in TWorldCupModel.FMatchEvents.
  /// </summary>
  TMatch = record
    AwayIdx: Integer;
    AwayScore: Integer;
    GroupId: Char;
    HomeIdx: Integer;
    HomeScore: Integer;
    Id: Integer;
    KickoffLabel: string;
    Minute: Integer;
    Round: Integer;
    Status: TMatchStatus;
    /// <summary>
    ///   Creates a scheduled match with zero scores and no events.
    /// </summary>
    class function Make(AId: Integer; AGroupId: Char; ARound,
      AHomeIdx, AAwayIdx: Integer;
      const AKickoffLabel: string): TMatch; static;
  end;

  /// <summary>
  ///   Computed standings entry for one team in a group.
  /// </summary>
  TStanding = record
    D: Integer;
    GA: Integer;
    GD: Integer;
    GF: Integer;
    L: Integer;
    P: Integer;
    Pts: Integer;
    Qualified: Boolean;
    TeamIdx: Integer;
    W: Integer;
  end;

  /// <summary>
  ///   Aggregated goal tally for a player across all matches.
  /// </summary>
  TScorer = record
    Goals: Integer;
    Player: string;
    TeamCode: string;
    /// <summary>
    ///   Creates a TScorer with the given player, team code, and initial goal count.
    /// </summary>
    class function Make(const APlayer, ATeamCode: string;
      AGoals: Integer): TScorer; static;
  end;

  /// <summary>
  ///   One tie in the knockout bracket (R16, QF, SF, or Final).
  /// </summary>
  TBracketTie = record
    AwayCode: string;
    AwayScore: Integer;
    Decided: Boolean;
    HomeCode: string;
    HomeScore: Integer;
    Round: Integer;
    SlotIndex: Integer;
    /// <summary>
    ///   Creates an undecided bracket tie with zero scores.
    /// </summary>
    class function Make(ARound, ASlotIndex: Integer;
      const AHomeCode, AAwayCode: string): TBracketTie; static;
  end;

  /// <summary>
  ///   In-memory World Cup model. Populates 32 teams, 48 group matches, and a
  ///   15-tie knockout bracket via Seed. Tick advances live matches each timer step
  ///   using a deterministic FNV-1a hash — no Random calls.
  /// </summary>
  TWorldCupModel = class
  strict private
    FBracket: TArray<TBracketTie>;
    FMatchEvents: array[0..CMatchCount - 1] of TArray<TMatchEvent>;
    FMatches: TList<TMatch>;
    FPlayerNames: array[0..CTeamCount - 1, 0..3] of string;
    FTeams: TArray<TTeam>;
    FTickCount: Integer;
    procedure AddEvent(AMatchId: Integer; const AEvent: TMatchEvent);
    function EventHash(AMatchId, AMinute: Integer): Cardinal;
    procedure SeedBracket;
    procedure SeedEvents;
    procedure SeedMatches;
    procedure SeedPlayerNames;
    procedure SeedTeams;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Returns the team at the given index (0-based, 0..31).
    /// </summary>
    function GetTeam(AIdx: Integer): TTeam;
    /// <summary>
    ///   Returns the group letter for the given group index (0='A', 7='H').
    /// </summary>
    function GroupLetter(AGroupIdx: Integer): Char;
    /// <summary>
    ///   Returns the match with the given Id.
    /// </summary>
    function GetMatch(AId: Integer): TMatch;
    /// <summary>
    ///   Returns all events recorded for the given match Id.
    /// </summary>
    function Events(AMatchId: Integer): TArray<TMatchEvent>;
    /// <summary>
    ///   Returns all 6 matches for the given group index (0..7).
    /// </summary>
    function MatchesForGroup(AGroupIdx: Integer): TArray<TMatch>;
    /// <summary>
    ///   Returns the 4 standings entries for the group, sorted by
    ///   Pts DESC / GD DESC / GF DESC / TeamIdx ASC.
    /// </summary>
    function StandingsForGroup(AGroupIdx: Integer): TArray<TStanding>;
    /// <summary>
    ///   Returns all currently live matches.
    /// </summary>
    function LiveMatches: TArray<TMatch>;
    /// <summary>
    ///   Returns all 15 bracket ties (8 R16, 4 QF, 2 SF, 1 Final).
    /// </summary>
    function BracketTies: TArray<TBracketTie>;
    /// <summary>
    ///   Returns the top AMaxCount scorers sorted by goals descending.
    /// </summary>
    function TopScorers(AMaxCount: Integer): TArray<TScorer>;
    /// <summary>
    ///   Populates all teams, matches, events, player names, and bracket.
    /// </summary>
    procedure Seed;
    /// <summary>
    ///   Advances all live matches by one minute, generating events
    ///   deterministically and finishing matches that reach minute 90.
    /// </summary>
    procedure Tick;
  end;

implementation

uses
  System.Generics.Defaults,
  System.Math,
  System.SysUtils;

{ TTeam }

class function TTeam.Make(const ACode, AName: string;
  AR, AG, AB: Byte): TTeam;
begin
  Result.AccentColor := TTuiColor.RGB(AR, AG, AB);
  Result.Code := ACode;
  Result.Name := AName;
end;

{ TMatchEvent }

class function TMatchEvent.Make(AMinute: Integer; AKind: TEventKind;
  const ATeamCode, APlayer: string): TMatchEvent;
begin
  Result.Kind := AKind;
  Result.Minute := AMinute;
  Result.Player := APlayer;
  Result.TeamCode := ATeamCode;
end;

{ TMatch }

class function TMatch.Make(AId: Integer; AGroupId: Char; ARound,
  AHomeIdx, AAwayIdx: Integer; const AKickoffLabel: string): TMatch;
begin
  Result.AwayIdx := AAwayIdx;
  Result.GroupId := AGroupId;
  Result.HomeIdx := AHomeIdx;
  Result.Id := AId;
  Result.KickoffLabel := AKickoffLabel;
  Result.Round := ARound;
  Result.Status := msScheduled;
end;

{ TScorer }

class function TScorer.Make(const APlayer, ATeamCode: string;
  AGoals: Integer): TScorer;
begin
  Result.Goals := AGoals;
  Result.Player := APlayer;
  Result.TeamCode := ATeamCode;
end;

{ TBracketTie }

class function TBracketTie.Make(ARound, ASlotIndex: Integer;
  const AHomeCode, AAwayCode: string): TBracketTie;
begin
  Result.AwayCode := AAwayCode;
  Result.Decided := False;
  Result.HomeCode := AHomeCode;
  Result.Round := ARound;
  Result.SlotIndex := ASlotIndex;
end;

{ TWorldCupModel }

constructor TWorldCupModel.Create;
begin
  inherited Create;
  FMatches := TList<TMatch>.Create;
end;

destructor TWorldCupModel.Destroy;
begin
  FMatches.Free;
  inherited Destroy;
end;

procedure TWorldCupModel.AddEvent(AMatchId: Integer; const AEvent: TMatchEvent);
begin
  var LLen := Length(FMatchEvents[AMatchId]);
  SetLength(FMatchEvents[AMatchId], LLen + 1);
  FMatchEvents[AMatchId][LLen] := AEvent;
end;

function TWorldCupModel.EventHash(AMatchId, AMinute: Integer): Cardinal;
begin
  // FNV-1a 32-bit: hash ^= byte; hash *= prime (16777619 < $80000000, safe)
  Result := 2166136261;
  Result := Result xor Cardinal(AMatchId);
  Result := Cardinal(Int64(Result) * 16777619);
  Result := Result xor Cardinal(AMinute);
  Result := Cardinal(Int64(Result) * 16777619);
end;

function TWorldCupModel.GetTeam(AIdx: Integer): TTeam;
begin
  Result := FTeams[AIdx];
end;

function TWorldCupModel.GroupLetter(AGroupIdx: Integer): Char;
begin
  Result := Chr(Ord('A') + AGroupIdx);
end;

function TWorldCupModel.GetMatch(AId: Integer): TMatch;
begin
  Result := FMatches[AId];
end;

function TWorldCupModel.Events(AMatchId: Integer): TArray<TMatchEvent>;
begin
  Result := FMatchEvents[AMatchId];
end;

function TWorldCupModel.MatchesForGroup(AGroupIdx: Integer): TArray<TMatch>;
begin
  SetLength(Result, 6);
  for var LI := 0 to 5 do
    Result[LI] := FMatches[AGroupIdx * 6 + LI];
end;

function TWorldCupModel.LiveMatches: TArray<TMatch>;
begin
  var LList := TList<TMatch>.Create;
  try
    for var LI := 0 to FMatches.Count - 1 do
      if FMatches[LI].Status = msLive then
        LList.Add(FMatches[LI]);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TWorldCupModel.BracketTies: TArray<TBracketTie>;
begin
  Result := FBracket;
end;

function TWorldCupModel.StandingsForGroup(AGroupIdx: Integer): TArray<TStanding>;
begin
  var LBaseIdx := AGroupIdx * 4;
  SetLength(Result, 4);
  for var LI := 0 to 3 do
  begin
    Result[LI].D := 0;
    Result[LI].GA := 0;
    Result[LI].GD := 0;
    Result[LI].GF := 0;
    Result[LI].L := 0;
    Result[LI].P := 0;
    Result[LI].Pts := 0;
    Result[LI].Qualified := False;
    Result[LI].TeamIdx := LBaseIdx + LI;
    Result[LI].W := 0;
  end;
  var LFinished := 0;
  for var LMatchId := AGroupIdx * 6 to AGroupIdx * 6 + 5 do
  begin
    var LMatch := FMatches[LMatchId];
    if LMatch.Status <> msFinished then
      Continue;
    Inc(LFinished);
    var LHI := LMatch.HomeIdx - LBaseIdx;
    var LAI := LMatch.AwayIdx - LBaseIdx;
    Inc(Result[LHI].P);
    Inc(Result[LAI].P);
    Inc(Result[LHI].GF, LMatch.HomeScore);
    Inc(Result[LHI].GA, LMatch.AwayScore);
    Inc(Result[LAI].GF, LMatch.AwayScore);
    Inc(Result[LAI].GA, LMatch.HomeScore);
    if LMatch.HomeScore > LMatch.AwayScore then
    begin
      Inc(Result[LHI].W);
      Inc(Result[LAI].L);
      Inc(Result[LHI].Pts, 3);
    end
    else if LMatch.HomeScore = LMatch.AwayScore then
    begin
      Inc(Result[LHI].D);
      Inc(Result[LAI].D);
      Inc(Result[LHI].Pts);
      Inc(Result[LAI].Pts);
    end
    else
    begin
      Inc(Result[LHI].L);
      Inc(Result[LAI].W);
      Inc(Result[LAI].Pts, 3);
    end;
  end;
  for var LI := 0 to 3 do
    Result[LI].GD := Result[LI].GF - Result[LI].GA;
  // Sort: Pts DESC, GD DESC, GF DESC, TeamIdx ASC
  var LList := TList<TStanding>.Create;
  try
    for var LS in Result do
      LList.Add(LS);
    LList.Sort(TComparer<TStanding>.Construct(
      function(const A, B: TStanding): Integer
      begin
        if A.Pts <> B.Pts then
          Exit(B.Pts - A.Pts);
        if A.GD <> B.GD then
          Exit(B.GD - A.GD);
        if A.GF <> B.GF then
          Exit(B.GF - A.GF);
        Exit(A.TeamIdx - B.TeamIdx);
      end));
    for var LI := 0 to 3 do
      Result[LI] := LList[LI];
  finally
    LList.Free;
  end;
  // Mark top 2 qualified only when all group matches are decided
  if LFinished = 6 then
  begin
    Result[0].Qualified := True;
    Result[1].Qualified := True;
  end;
end;

function TWorldCupModel.TopScorers(AMaxCount: Integer): TArray<TScorer>;
begin
  var LMap := TDictionary<string, TScorer>.Create;
  try
    for var LMatchId := 0 to CMatchCount - 1 do
      for var LEvt in FMatchEvents[LMatchId] do
      begin
        if LEvt.Kind <> ekGoal then
          Continue;
        var LKey := LEvt.Player + '|' + LEvt.TeamCode;
        var LScorer: TScorer;
        if LMap.TryGetValue(LKey, LScorer) then
        begin
          Inc(LScorer.Goals);
          LMap[LKey] := LScorer;
        end
        else
          LMap.Add(LKey, TScorer.Make(LEvt.Player, LEvt.TeamCode, 1));
      end;
    var LList := TList<TScorer>.Create;
    try
      for var LEntry in LMap.Values do
        LList.Add(LEntry);
      LList.Sort(TComparer<TScorer>.Construct(
        function(const A, B: TScorer): Integer
        begin
          Exit(B.Goals - A.Goals);
        end));
      var LCount := Min(AMaxCount, LList.Count);
      SetLength(Result, LCount);
      for var LI := 0 to LCount - 1 do
        Result[LI] := LList[LI];
    finally
      LList.Free;
    end;
  finally
    LMap.Free;
  end;
end;

procedure TWorldCupModel.SeedTeams;
begin
  SetLength(FTeams, CTeamCount);
  // Group A
  FTeams[0] := TTeam.Make('BRA', 'Brazil',       0,  155, 64);
  FTeams[1] := TTeam.Make('SRB', 'Serbia',      196,  55, 46);
  FTeams[2] := TTeam.Make('SUI', 'Switzerland', 213,  43, 30);
  FTeams[3] := TTeam.Make('CMR', 'Cameroon',    180, 150, 20);
  // Group B
  FTeams[4] := TTeam.Make('ENG', 'England',       0,  36,125);
  FTeams[5] := TTeam.Make('NED', 'Netherlands', 255, 110,  0);
  FTeams[6] := TTeam.Make('USA', 'USA',          60,  59,110);
  FTeams[7] := TTeam.Make('IRN', 'Iran',          0, 114, 41);
  // Group C
  FTeams[8] := TTeam.Make('ARG', 'Argentina',   116, 172,223);
  FTeams[9] := TTeam.Make('MEX', 'Mexico',        0, 104, 71);
  FTeams[10] := TTeam.Make('POL', 'Poland',       220,  20, 60);
  FTeams[11] := TTeam.Make('KSA', 'Saudi Arabia',  0, 106, 56);
  // Group D
  FTeams[12] := TTeam.Make('FRA', 'France',        0,  35,149);
  FTeams[13] := TTeam.Make('DEN', 'Denmark',      198,  12, 48);
  FTeams[14] := TTeam.Make('TUN', 'Tunisia',      220,  30, 40);
  FTeams[15] := TTeam.Make('AUS', 'Australia',   255, 200, 50);
  // Group E
  FTeams[16] := TTeam.Make('ESP', 'Spain',        170,  21, 27);
  FTeams[17] := TTeam.Make('GER', 'Germany',      100, 100,100);
  FTeams[18] := TTeam.Make('JPN', 'Japan',        188,   0, 45);
  FTeams[19] := TTeam.Make('CRC', 'Costa Rica',    0,  56,147);
  // Group F
  FTeams[20] := TTeam.Make('BEL', 'Belgium',       0,   0,  0);
  FTeams[21] := TTeam.Make('CRO', 'Croatia',      220,  20, 60);
  FTeams[22] := TTeam.Make('MAR', 'Morocco',      195,  11, 44);
  FTeams[23] := TTeam.Make('CAN', 'Canada',       213,  43, 30);
  // Group G
  FTeams[24] := TTeam.Make('POR', 'Portugal',       0, 102, 51);
  FTeams[25] := TTeam.Make('URU', 'Uruguay',      107, 168,214);
  FTeams[26] := TTeam.Make('KOR', 'South Korea',    0,  71,160);
  FTeams[27] := TTeam.Make('GHA', 'Ghana',        210, 180, 20);
  // Group H
  FTeams[28] := TTeam.Make('ITA', 'Italy',          0, 146,200);
  FTeams[29] := TTeam.Make('CHI', 'Chile',         213,  43, 30);
  FTeams[30] := TTeam.Make('ECU', 'Ecuador',      255, 215,  0);
  FTeams[31] := TTeam.Make('QAT', 'Qatar',         128,   0, 32);
end;

procedure TWorldCupModel.SeedPlayerNames;
begin
  // Group A
  FPlayerNames[0,0] := 'Vinicius Jr'; FPlayerNames[0,1] := 'Neymar';
  FPlayerNames[0,2] := 'Casemiro';   FPlayerNames[0,3] := 'Martinelli';
  FPlayerNames[1,0] := 'Mitrovic';   FPlayerNames[1,1] := 'Tadic';
  FPlayerNames[1,2] := 'Kostic';     FPlayerNames[1,3] := 'Vlahovic';
  FPlayerNames[2,0] := 'Embolo';     FPlayerNames[2,1] := 'Shaqiri';
  FPlayerNames[2,2] := 'Seferovic';  FPlayerNames[2,3] := 'Xhaka';
  FPlayerNames[3,0] := 'Aboubakar';  FPlayerNames[3,1] := 'Choupo-M.';
  FPlayerNames[3,2] := 'Onana';      FPlayerNames[3,3] := 'Toko Ekambi';
  // Group B
  FPlayerNames[4,0] := 'Bellingham'; FPlayerNames[4,1] := 'Saka';
  FPlayerNames[4,2] := 'Kane';       FPlayerNames[4,3] := 'Sterling';
  FPlayerNames[5,0] := 'Depay';      FPlayerNames[5,1] := 'de Jong';
  FPlayerNames[5,2] := 'Blind';      FPlayerNames[5,3] := 'Bergwijn';
  FPlayerNames[6,0] := 'Pulisic';    FPlayerNames[6,1] := 'Weah';
  FPlayerNames[6,2] := 'Adams';      FPlayerNames[6,3] := 'Morris';
  FPlayerNames[7,0] := 'Taremi';     FPlayerNames[7,1] := 'Jahanbakhsh';
  FPlayerNames[7,2] := 'Rezaeian';   FPlayerNames[7,3] := 'Ansarifard';
  // Group C
  FPlayerNames[8,0] := 'Messi';        FPlayerNames[8,1] := 'Lautaro';
  FPlayerNames[8,2] := 'Di Maria';     FPlayerNames[8,3] := 'Mac Allister';
  FPlayerNames[9,0] := 'Lozano';       FPlayerNames[9,1] := 'Jimenez';
  FPlayerNames[9,2] := 'Herrera';      FPlayerNames[9,3] := 'Vega';
  FPlayerNames[10,0] := 'Lewandowski';  FPlayerNames[10,1] := 'Zielinski';
  FPlayerNames[10,2] := 'Szymanski';    FPlayerNames[10,3] := 'Swiderski';
  FPlayerNames[11,0] := 'Al-Dawsari';   FPlayerNames[11,1] := 'Saleh';
  FPlayerNames[11,2] := 'Al-Shahrani';  FPlayerNames[11,3] := 'Shehri';
  // Group D
  FPlayerNames[12,0] := 'Mbappe';      FPlayerNames[12,1] := 'Giroud';
  FPlayerNames[12,2] := 'Benzema';     FPlayerNames[12,3] := 'Griezmann';
  FPlayerNames[13,0] := 'Eriksen';     FPlayerNames[13,1] := 'Damsgaard';
  FPlayerNames[13,2] := 'Braithwaite'; FPlayerNames[13,3] := 'Dolberg';
  FPlayerNames[14,0] := 'Msakni';      FPlayerNames[14,1] := 'Khazri';
  FPlayerNames[14,2] := 'Drager';      FPlayerNames[14,3] := 'Ben Romdhane';
  FPlayerNames[15,0] := 'Leckie';      FPlayerNames[15,1] := 'Goodwin';
  FPlayerNames[15,2] := 'Irvine';      FPlayerNames[15,3] := 'Devlin';
  // Group E
  FPlayerNames[16,0] := 'Morata';       FPlayerNames[16,1] := 'Asensio';
  FPlayerNames[16,2] := 'Torres';       FPlayerNames[16,3] := 'Pedri';
  FPlayerNames[17,0] := 'Muller';       FPlayerNames[17,1] := 'Gnabry';
  FPlayerNames[17,2] := 'Werner';       FPlayerNames[17,3] := 'Havertz';
  FPlayerNames[18,0] := 'Minamino';     FPlayerNames[18,1] := 'Doan';
  FPlayerNames[18,2] := 'Asano';        FPlayerNames[18,3] := 'Ito';
  FPlayerNames[19,0] := 'Campbell';     FPlayerNames[19,1] := 'Calvo';
  FPlayerNames[19,2] := 'Borges';       FPlayerNames[19,3] := 'Acosta';
  // Group F
  FPlayerNames[20,0] := 'De Bruyne';  FPlayerNames[20,1] := 'Lukaku';
  FPlayerNames[20,2] := 'Hazard';     FPlayerNames[20,3] := 'Batshuayi';
  FPlayerNames[21,0] := 'Modric';     FPlayerNames[21,1] := 'Perisic';
  FPlayerNames[21,2] := 'Kovacic';    FPlayerNames[21,3] := 'Kramaric';
  FPlayerNames[22,0] := 'Ziyech';     FPlayerNames[22,1] := 'En-Nesyri';
  FPlayerNames[22,2] := 'Ounahi';     FPlayerNames[22,3] := 'Boufal';
  FPlayerNames[23,0] := 'Davies';     FPlayerNames[23,1] := 'David';
  FPlayerNames[23,2] := 'Buchanan';   FPlayerNames[23,3] := 'Hoilett';
  // Group G
  FPlayerNames[24,0] := 'Ronaldo';       FPlayerNames[24,1] := 'Joao Felix';
  FPlayerNames[24,2] := 'Leao';          FPlayerNames[24,3] := 'Bernardo';
  FPlayerNames[25,0] := 'Cavani';        FPlayerNames[25,1] := 'Valverde';
  FPlayerNames[25,2] := 'De Arrascaeta'; FPlayerNames[25,3] := 'Bentancur';
  FPlayerNames[26,0] := 'Son';           FPlayerNames[26,1] := 'Hwang H-C';
  FPlayerNames[26,2] := 'Kwon';          FPlayerNames[26,3] := 'Lee Jae-S.';
  FPlayerNames[27,0] := 'Ayew J.';       FPlayerNames[27,1] := 'Ayew A.';
  FPlayerNames[27,2] := 'Kudus';         FPlayerNames[27,3] := 'Bukari';
  // Group H
  FPlayerNames[28,0] := 'Insigne';   FPlayerNames[28,1] := 'Immobile';
  FPlayerNames[28,2] := 'Barella';   FPlayerNames[28,3] := 'Jorginho';
  FPlayerNames[29,0] := 'Alexis';    FPlayerNames[29,1] := 'Medel';
  FPlayerNames[29,2] := 'Vidal';     FPlayerNames[29,3] := 'Pulgar';
  FPlayerNames[30,0] := 'Valencia';  FPlayerNames[30,1] := 'Caicedo';
  FPlayerNames[30,2] := 'Estrada';   FPlayerNames[30,3] := 'Ibarra';
  FPlayerNames[31,0] := 'Afif';      FPlayerNames[31,1] := 'Almoez';
  FPlayerNames[31,2] := 'Hassan';    FPlayerNames[31,3] := 'Ali';
end;

procedure TWorldCupModel.SeedMatches;
  procedure AddMatch(AId: Integer; AGroupId: Char; ARound, AHome, AAway: Integer;
    const ALabel: string; AStatus: TMatchStatus; AHomeScore, AAwayScore,
    AMinute: Integer);
  begin
    var LM := TMatch.Make(AId, AGroupId, ARound, AHome, AAway, ALabel);
    LM.Status := AStatus;
    LM.HomeScore := AHomeScore;
    LM.AwayScore := AAwayScore;
    LM.Minute := AMinute;
    FMatches.Add(LM);
  end;
begin
  // Group A (teams 0-3: BRA SRB SUI CMR)
  // MD1: BRA-SRB, SUI-CMR
  AddMatch(0,  'A', 1, 0, 1, 'MD1', msFinished, 2, 0, 90);
  AddMatch(1,  'A', 1, 2, 3, 'MD1', msFinished, 1, 0, 90);
  // MD2: BRA-SUI (Live), SRB-CMR (Scheduled)
  AddMatch(2,  'A', 2, 0, 2, 'MD2', msLive,      1, 0, 52);
  AddMatch(3,  'A', 2, 1, 3, 'MD2', msScheduled, 0, 0,  0);
  // MD3
  AddMatch(4,  'A', 3, 0, 3, 'MD3', msScheduled, 0, 0,  0);
  AddMatch(5,  'A', 3, 1, 2, 'MD3', msScheduled, 0, 0,  0);

  // Group B (teams 4-7: ENG NED USA IRN)
  // MD1: ENG-IRN, NED-USA
  AddMatch(6,  'B', 1,  4,  7, 'MD1', msFinished, 3, 0, 90);
  AddMatch(7,  'B', 1,  5,  6, 'MD1', msFinished, 2, 1, 90);
  // MD2: ENG-NED (Live), USA-IRN (Finished)
  AddMatch(8,  'B', 2,  4,  5, 'MD2', msLive,     1, 1, 67);
  AddMatch(9,  'B', 2,  6,  7, 'MD2', msFinished, 1, 0, 90);
  // MD3
  AddMatch(10, 'B', 3,  4,  6, 'MD3', msScheduled, 0, 0, 0);
  AddMatch(11, 'B', 3,  7,  5, 'MD3', msScheduled, 0, 0, 0);

  // Group C (teams 8-11: ARG MEX POL KSA)
  AddMatch(12, 'C', 1,  8, 11, 'MD1', msFinished,  1, 2, 90);
  AddMatch(13, 'C', 1,  9, 10, 'MD1', msFinished,  0, 0, 90);
  AddMatch(14, 'C', 2,  8,  9, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(15, 'C', 2, 10, 11, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(16, 'C', 3,  8, 10, 'MD3', msScheduled, 0, 0,  0);
  AddMatch(17, 'C', 3,  9, 11, 'MD3', msScheduled, 0, 0,  0);

  // Group D (teams 12-15: FRA DEN TUN AUS)
  AddMatch(18, 'D', 1, 12, 15, 'MD1', msFinished,  4, 1, 90);
  AddMatch(19, 'D', 1, 13, 14, 'MD1', msFinished,  0, 0, 90);
  AddMatch(20, 'D', 2, 12, 13, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(21, 'D', 2, 15, 14, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(22, 'D', 3, 12, 14, 'MD3', msScheduled, 0, 0,  0);
  AddMatch(23, 'D', 3, 13, 15, 'MD3', msScheduled, 0, 0,  0);

  // Group E (teams 16-19: ESP GER JPN CRC)
  AddMatch(24, 'E', 1, 16, 19, 'MD1', msFinished,  7, 0, 90);
  AddMatch(25, 'E', 1, 17, 18, 'MD1', msFinished,  1, 2, 90);
  AddMatch(26, 'E', 2, 16, 17, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(27, 'E', 2, 18, 19, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(28, 'E', 3, 16, 18, 'MD3', msScheduled, 0, 0,  0);
  AddMatch(29, 'E', 3, 17, 19, 'MD3', msScheduled, 0, 0,  0);

  // Group F (teams 20-23: BEL CRO MAR CAN)
  AddMatch(30, 'F', 1, 20, 23, 'MD1', msFinished,  1, 0, 90);
  AddMatch(31, 'F', 1, 22, 21, 'MD1', msFinished,  0, 0, 90);
  AddMatch(32, 'F', 2, 20, 22, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(33, 'F', 2, 21, 23, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(34, 'F', 3, 20, 21, 'MD3', msScheduled, 0, 0,  0);
  AddMatch(35, 'F', 3, 22, 23, 'MD3', msScheduled, 0, 0,  0);

  // Group G (teams 24-27: POR URU KOR GHA)
  AddMatch(36, 'G', 1, 24, 27, 'MD1', msFinished,  3, 2, 90);
  AddMatch(37, 'G', 1, 25, 26, 'MD1', msFinished,  0, 0, 90);
  AddMatch(38, 'G', 2, 24, 25, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(39, 'G', 2, 26, 27, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(40, 'G', 3, 24, 26, 'MD3', msScheduled, 0, 0,  0);
  AddMatch(41, 'G', 3, 27, 25, 'MD3', msScheduled, 0, 0,  0);

  // Group H (teams 28-31: ITA CHI ECU QAT)
  AddMatch(42, 'H', 1, 28, 31, 'MD1', msFinished,  2, 0, 90);
  AddMatch(43, 'H', 1, 30, 29, 'MD1', msFinished,  2, 1, 90);
  AddMatch(44, 'H', 2, 28, 30, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(45, 'H', 2, 29, 31, 'MD2', msScheduled, 0, 0,  0);
  AddMatch(46, 'H', 3, 28, 29, 'MD3', msScheduled, 0, 0,  0);
  AddMatch(47, 'H', 3, 30, 31, 'MD3', msScheduled, 0, 0,  0);
end;

procedure TWorldCupModel.SeedEvents;
begin
  // Match 0: BRA 2-0 SRB
  AddEvent(0, TMatchEvent.Make(23, ekGoal, 'BRA', 'Vinicius Jr'));
  AddEvent(0, TMatchEvent.Make(67, ekGoal, 'BRA', 'Martinelli'));
  // Match 1: SUI 1-0 CMR
  AddEvent(1, TMatchEvent.Make(51, ekGoal, 'SUI', 'Embolo'));
  // Match 2: BRA 1-0 SUI (Live, min 52) -- pre-seeded goal
  AddEvent(2, TMatchEvent.Make(34, ekGoal, 'BRA', 'Neymar'));
  // Match 6: ENG 3-0 IRN
  AddEvent(6, TMatchEvent.Make(35, ekGoal, 'ENG', 'Bellingham'));
  AddEvent(6, TMatchEvent.Make(43, ekGoal, 'ENG', 'Saka'));
  AddEvent(6, TMatchEvent.Make(71, ekGoal, 'ENG', 'Sterling'));
  // Match 7: NED 2-1 USA
  AddEvent(7, TMatchEvent.Make(10, ekGoal, 'NED', 'Depay'));
  AddEvent(7, TMatchEvent.Make(38, ekGoal, 'USA', 'Weah'));
  AddEvent(7, TMatchEvent.Make(65, ekGoal, 'NED', 'de Jong'));
  // Match 8: ENG 1-1 NED (Live, min 67) -- pre-seeded goals
  AddEvent(8, TMatchEvent.Make(29, ekGoal, 'ENG', 'Bellingham'));
  AddEvent(8, TMatchEvent.Make(54, ekGoal, 'NED', 'Depay'));
  // Match 9: USA 1-0 IRN
  AddEvent(9, TMatchEvent.Make(38, ekGoal, 'USA', 'Pulisic'));
  // Match 12: ARG 1-2 KSA
  AddEvent(12, TMatchEvent.Make(10, ekGoal, 'ARG', 'Lautaro'));
  AddEvent(12, TMatchEvent.Make(48, ekGoal, 'KSA', 'Al-Dawsari'));
  AddEvent(12, TMatchEvent.Make(53, ekGoal, 'KSA', 'Saleh'));
  // Match 18: FRA 4-1 AUS
  AddEvent(18, TMatchEvent.Make( 9, ekGoal, 'AUS', 'Goodwin'));
  AddEvent(18, TMatchEvent.Make(27, ekGoal, 'FRA', 'Rabiot'));
  AddEvent(18, TMatchEvent.Make(32, ekGoal, 'FRA', 'Giroud'));
  AddEvent(18, TMatchEvent.Make(58, ekGoal, 'FRA', 'Benzema'));
  AddEvent(18, TMatchEvent.Make(71, ekGoal, 'FRA', 'Giroud'));
  // Match 24: ESP 7-0 CRC
  AddEvent(24, TMatchEvent.Make(11, ekGoal, 'ESP', 'Dani Olmo'));
  AddEvent(24, TMatchEvent.Make(21, ekGoal, 'ESP', 'Asensio'));
  AddEvent(24, TMatchEvent.Make(31, ekGoal, 'ESP', 'Torres'));
  AddEvent(24, TMatchEvent.Make(54, ekGoal, 'ESP', 'Torres'));
  AddEvent(24, TMatchEvent.Make(74, ekGoal, 'ESP', 'Asensio'));
  AddEvent(24, TMatchEvent.Make(75, ekGoal, 'ESP', 'Gavi'));
  AddEvent(24, TMatchEvent.Make(90, ekGoal, 'ESP', 'Soler'));
  // Match 25: GER 1-2 JPN
  AddEvent(25, TMatchEvent.Make(33, ekGoal, 'GER', 'Gundogan'));
  AddEvent(25, TMatchEvent.Make(75, ekGoal, 'JPN', 'Doan'));
  AddEvent(25, TMatchEvent.Make(83, ekGoal, 'JPN', 'Asano'));
  // Match 30: BEL 1-0 CAN
  AddEvent(30, TMatchEvent.Make(44, ekGoal, 'BEL', 'Batshuayi'));
  // Match 36: POR 3-2 GHA
  AddEvent(36, TMatchEvent.Make(65, ekGoal, 'POR', 'Ronaldo'));
  AddEvent(36, TMatchEvent.Make(73, ekGoal, 'GHA', 'Ayew J.'));
  AddEvent(36, TMatchEvent.Make(78, ekGoal, 'POR', 'Joao Felix'));
  AddEvent(36, TMatchEvent.Make(80, ekGoal, 'POR', 'Leao'));
  AddEvent(36, TMatchEvent.Make(89, ekGoal, 'GHA', 'Bukari'));
  // Match 42: ITA 2-0 QAT
  AddEvent(42, TMatchEvent.Make(25, ekGoal, 'ITA', 'Immobile'));
  AddEvent(42, TMatchEvent.Make(67, ekGoal, 'ITA', 'Barella'));
  // Match 43: ECU 2-1 CHI
  AddEvent(43, TMatchEvent.Make(16, ekGoal, 'ECU', 'Valencia'));
  AddEvent(43, TMatchEvent.Make(31, ekGoal, 'ECU', 'Valencia'));
  AddEvent(43, TMatchEvent.Make(74, ekGoal, 'CHI', 'Pulgar'));
end;

procedure TWorldCupModel.SeedBracket;
begin
  // 15 ties: 8 R16 + 4 QF + 2 SF + 1 Final
  SetLength(FBracket, 15);
  // Round of 16 (Round=0, slots 0-7) — projected from current group leaders
  FBracket[0] := TBracketTie.Make(0, 0, 'BRA', 'NED');
  FBracket[1] := TBracketTie.Make(0, 1, 'KSA', 'FRA');
  FBracket[2] := TBracketTie.Make(0, 2, 'ESP', 'BEL');
  FBracket[3] := TBracketTie.Make(0, 3, 'POR', 'ITA');
  FBracket[4] := TBracketTie.Make(0, 4, 'SUI', 'ENG');
  FBracket[5] := TBracketTie.Make(0, 5, 'ARG', 'DEN');
  FBracket[6] := TBracketTie.Make(0, 6, 'JPN', 'CRO');
  FBracket[7] := TBracketTie.Make(0, 7, 'URU', 'ECU');
  // Quarter-finals (Round=1, slots 0-3)
  FBracket[8] := TBracketTie.Make(1, 0, 'TBD', 'TBD');
  FBracket[9] := TBracketTie.Make(1, 1, 'TBD', 'TBD');
  FBracket[10] := TBracketTie.Make(1, 2, 'TBD', 'TBD');
  FBracket[11] := TBracketTie.Make(1, 3, 'TBD', 'TBD');
  // Semi-finals (Round=2, slots 0-1)
  FBracket[12] := TBracketTie.Make(2, 0, 'TBD', 'TBD');
  FBracket[13] := TBracketTie.Make(2, 1, 'TBD', 'TBD');
  // Final (Round=3, slot 0)
  FBracket[14] := TBracketTie.Make(3, 0, 'TBD', 'TBD');
end;

procedure TWorldCupModel.Seed;
begin
  FMatches.Clear;
  FTickCount := 0;
  for var LI := 0 to CMatchCount - 1 do
    FMatchEvents[LI] := nil;
  SeedTeams;
  SeedPlayerNames;
  SeedMatches;
  SeedEvents;
  SeedBracket;
end;

procedure TWorldCupModel.Tick;
begin
  Inc(FTickCount);
  for var LI := 0 to FMatches.Count - 1 do
  begin
    var LMatch := FMatches[LI];
    if LMatch.Status <> msLive then
      Continue;
    Inc(LMatch.Minute);
    // Deterministic event generation for this minute
    var LHash := EventHash(LMatch.Id, LMatch.Minute);
    if LHash mod 20 = 0 then  // ~5% goal probability per minute
    begin
      var LIsHome := (LHash shr 8) and 1 = 0;
      var LTeamIdx: Integer;
      if LIsHome then
        LTeamIdx := LMatch.HomeIdx
      else
        LTeamIdx := LMatch.AwayIdx;
      var LPlayer := FPlayerNames[LTeamIdx, (LHash shr 4) mod 4];
      var LTeamCode := FTeams[LTeamIdx].Code;
      if LIsHome then
        Inc(LMatch.HomeScore)
      else
        Inc(LMatch.AwayScore);
      AddEvent(LMatch.Id,
        TMatchEvent.Make(LMatch.Minute, ekGoal, LTeamCode, LPlayer));
    end
    else if LHash mod 30 = 5 then  // yellow card (lower frequency than goals)
    begin
      var LIsHome := (LHash shr 12) and 1 = 0;
      var LTeamIdx: Integer;
      if LIsHome then
        LTeamIdx := LMatch.HomeIdx
      else
        LTeamIdx := LMatch.AwayIdx;
      var LPlayer := FPlayerNames[LTeamIdx, (LHash shr 6) mod 4];
      var LTeamCode := FTeams[LTeamIdx].Code;
      AddEvent(LMatch.Id,
        TMatchEvent.Make(LMatch.Minute, ekYellow, LTeamCode, LPlayer));
    end;
    // Match ends at minute 90
    if LMatch.Minute >= 90 then
    begin
      LMatch.Status := msFinished;
      // Activate the next scheduled match
      for var LJ := 0 to FMatches.Count - 1 do
        if FMatches[LJ].Status = msScheduled then
        begin
          var LNext := FMatches[LJ];
          LNext.Status := msLive;
          FMatches[LJ] := LNext;
          Break;
        end;
    end;
    FMatches[LI] := LMatch;
  end;
end;

end.
