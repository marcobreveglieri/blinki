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
{   Unit:        Dashboard.Model.pas                             }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Dashboard demo — domain model: records and the TDashboardModel class.
///   No UI dependencies. Seed() populates static fake data that mirrors the
///   gonzo screenshot; Tick() advances the simulation every second.
/// </summary>
unit Dashboard.Model;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Generics.Collections;

type

{ TTopItem }

  /// <summary>
  ///   A single ranked item in the Top Words or Top Attributes list.
  /// </summary>
  TTopItem = record
    Caption: string;
    Count: Integer;
    class function Make(const ACaption: string; ACount: Integer): TTopItem; static;
  end;

{ TPatternItem }

  /// <summary>
  ///   A single log-pattern entry with its frequency percentage and message template.
  /// </summary>
  TPatternItem = record
    Percent: Double;
    Text: string;
    class function Make(APercent: Double; const AText: string): TPatternItem; static;
  end;

{ TLogEntry }

  /// <summary>
  ///   A single log line with time, severity level, host, service, and message.
  /// </summary>
  TLogEntry = record
    Time: string;
    Level: string;
    Host: string;
    Service: string;
    Message: string;
    class function Make(const ATime, ALevel, AHost, AService, AMessage: string): TLogEntry; static;
  end;

{ TSeverityCounts }

  /// <summary>
  ///   Accumulated counts of log entries per severity level.
  /// </summary>
  TSeverityCounts = record
    Fatal: Integer;
    Error: Integer;
    Warn: Integer;
    Info: Integer;
    Debug: Integer;
    Trace: Integer;
    function Total: Integer;
  end;

{ TDashboardModel }

  /// <summary>
  ///   Fake-data model for the Dashboard demo. Seed() loads the initial state
  ///   (matching the gonzo screenshot); Tick() advances the simulation by one step,
  ///   appending new log entries and updating counters.
  /// </summary>
  TDashboardModel = class
  strict private
    FTopWords: TList<TTopItem>;
    FTopAttributes: TList<TTopItem>;
    FPatterns: TList<TPatternItem>;
    FHistogram: TArray<Integer>;
    FSeverities: TSeverityCounts;
    FLogEntries: TList<TLogEntry>;
    FTotalLogs: Int64;
    FPatternCount: Integer;
    FTickSeed: Int64;
    function NextRand: Int64;
    procedure GenerateLogEntry(const ATime: string);
    procedure AddInitialLogs;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Populates the model with the static data visible in the gonzo screenshot.
    /// </summary>
    procedure Seed;
    /// <summary>
    ///   Advances the simulation by one tick: appends new log entries, rotates
    ///   the histogram, and updates severity and word counters.
    /// </summary>
    procedure Tick;
    property TopWords: TList<TTopItem> read FTopWords;
    property TopAttributes: TList<TTopItem> read FTopAttributes;
    property Patterns: TList<TPatternItem> read FPatterns;
    property Histogram: TArray<Integer> read FHistogram;
    property Severities: TSeverityCounts read FSeverities;
    property LogEntries: TList<TLogEntry> read FLogEntries;
    property TotalLogs: Int64 read FTotalLogs;
    property PatternCount: Integer read FPatternCount;
  end;

implementation

uses
  System.SysUtils;

{ TTopItem }

class function TTopItem.Make(const ACaption: string; ACount: Integer): TTopItem;
begin
  Result.Caption := ACaption;
  Result.Count := ACount;
end;

{ TPatternItem }

class function TPatternItem.Make(APercent: Double; const AText: string): TPatternItem;
begin
  Result.Percent := APercent;
  Result.Text := AText;
end;

{ TLogEntry }

class function TLogEntry.Make(const ATime, ALevel, AHost, AService, AMessage: string): TLogEntry;
begin
  Result.Time := ATime;
  Result.Level := ALevel;
  Result.Host := AHost;
  Result.Service := AService;
  Result.Message := AMessage;
end;

{ TSeverityCounts }

function TSeverityCounts.Total: Integer;
begin
  Result := Fatal + Error + Warn + Info + Debug + Trace;
end;

{ TDashboardModel }

constructor TDashboardModel.Create;
begin
  inherited Create;
  FTopWords := TList<TTopItem>.Create;
  FTopAttributes := TList<TTopItem>.Create;
  FPatterns := TList<TPatternItem>.Create;
  FLogEntries := TList<TLogEntry>.Create;
  FTickSeed := 42;
end;

destructor TDashboardModel.Destroy;
begin
  FLogEntries.Free;
  FPatterns.Free;
  FTopAttributes.Free;
  FTopWords.Free;
  inherited Destroy;
end;

function TDashboardModel.NextRand: Int64;
begin
  // 31-bit LCG — all intermediate values are Int64, no Cardinal overflow.
  FTickSeed := (FTickSeed * Int64(1664525) + Int64(1013904223)) and $7FFFFFFF;
  Result := FTickSeed;
end;

procedure TDashboardModel.Seed;
begin
  // Top Words (matching the gonzo screenshot)
  FTopWords.Clear;
  FTopWords.Add(TTopItem.Make('for', 17637));
  FTopWords.Add(TTopItem.Make('with', 13149));
  FTopWords.Add(TTopItem.Make('172.18.0.22:8080', 9883));
  FTopWords.Add(TTopItem.Make('172.18.0.27:8080', 9883));
  FTopWords.Add(TTopItem.Make('frontend', 9883));
  FTopWords.Add(TTopItem.Make('frontend-proxy:8080', 9883));
  FTopWords.Add(TTopItem.Make('http/1.1', 9883));
  FTopWords.Add(TTopItem.Make('via_upstream', 9847));
  FTopWords.Add(TTopItem.Make('python-requests/2.32.3', 9750));
  FTopWords.Add(TTopItem.Make('min-width', 9704));

  // Top Attributes (matching the gonzo screenshot)
  FTopAttributes.Clear;
  FTopAttributes.Add(TTopItem.Make('rr-web.event', 654));
  FTopAttributes.Add(TTopItem.Make('rr-web.offset', 654));
  FTopAttributes.Add(TTopItem.Make('otelSpanID', 410));
  FTopAttributes.Add(TTopItem.Make('otelTraceID', 410));
  FTopAttributes.Add(TTopItem.Make('context.total', 278));
  FTopAttributes.Add(TTopItem.Make('userId', 139));
  FTopAttributes.Add(TTopItem.Make('app.payment.amount', 83));
  FTopAttributes.Add(TTopItem.Make('request.amount.units.low', 83));
  FTopAttributes.Add(TTopItem.Make('request.creditCard.creditCardNumber', 83));
  FTopAttributes.Add(TTopItem.Make('span_id', 83));

  // Log Patterns (matching the gonzo screenshot)
  FPatterns.Clear;
  FPatterns.Add(TPatternItem.Make(22.6, '*** *** *** HTTP/1.1" *** - via_upstream ...'));
  FPatterns.Add(TPatternItem.Make(12.5, 'GetCartAsync called with userId={userId}'));
  FPatterns.Add(TPatternItem.Make(9.8,  'Convert conversion successful'));
  FPatterns.Add(TPatternItem.Make(6.0,  'Calculated quote'));
  FPatterns.Add(TPatternItem.Make(6.0,  'no baggage found in context'));
  FPatterns.Add(TPatternItem.Make(5.9,  'AddItemAsync called with userId={userId},...'));
  FPatterns.Add(TPatternItem.Make(3.0,  'Targeted ad request received for ***'));
  FPatterns.Add(TPatternItem.Make(2.0,  'Deleted *** index ***'));
  FPatternCount := 100;

  // Histogram (approximate bar heights matching the screenshot; max=38)
  SetLength(FHistogram, 16);
  FHistogram[0] := 5;
  FHistogram[1] := 8;
  FHistogram[2] := 12;
  FHistogram[3] := 7;
  FHistogram[4] := 10;
  FHistogram[5] := 9;
  FHistogram[6] := 14;
  FHistogram[7] := 38;
  FHistogram[8] := 0;
  FHistogram[9] := 6;
  FHistogram[10] := 4;
  FHistogram[11] := 0;
  FHistogram[12] := 0;
  FHistogram[13] := 0;
  FHistogram[14] := 0;
  FHistogram[15] := 0;

  // Severities start at zero (matching the screenshot)
  FSeverities := Default(TSeverityCounts);

  // Total log count (matching the screenshot)
  FTotalLogs := 131186;

  // Initial log entries (matching the gonzo screenshot rows)
  FLogEntries.Clear;
  AddInitialLogs;
end;

procedure TDashboardModel.AddInitialLogs;

  procedure Add(const ATime, ALevel, AHost, AService, AMessage: string);
  begin
    FLogEntries.Add(TLogEntry.Make(ATime, ALevel, AHost, AService, AMessage));
  end;

begin
  Add('12:22:08', 'INFO',  '08b51e83166c', 'cart',
      'GetCartAsync called with userId={userId}');
  Add('12:22:08', 'INFO',  '08b51e83166c', 'cart',
      'GetCartAsync called with userId={userId}');
  Add('12:22:08', 'INFO',  '08b51e83166c', 'cart',
      'AddItemAsync called with userId={userId}, productId={productId}, quantity={quantity}');
  Add('12:22:08', 'INFO',  '08b51e83166c', 'cart',
      'GetCartAsync called with userId={userId}');
  Add('12:22:08', 'INFO',  '08b51e83166c', 'cart',
      'GetCartAsync called with userId={userId}');
  Add('12:22:08', 'INFO',  '08b51e83166c', 'cart',
      'AddItemAsync called with userId={userId}, productId={productId}, quantity={quantity}');
  Add('12:22:08', 'INFO',  '08b51e83166c', 'cart',
      'GetCartAsync called with userId={userId}');
  Add('12:22:08', 'INFO',  '08b51e83166c', 'cart',
      'AddItemAsync called with userId={userId}, productId={productId}, quantity={quantity}');
  Add('12:22:08', 'INFO',  '08b51e83166c', 'cart',
      'GetCartAsync called with userId={userId}');
  Add('12:22:08', 'INFO',  '',              'recommendation',
      'Receive ListRecommendations for product ids:' +
      '[''HQTGWGPNH4'', ''OLJCESPC7Z'', ''L9ECAV7KIM'', ''LS4P...''');
  Add('12:22:08', 'INFO',  '',              'recommendation',
      'Receive ListRecommendations for product ids:' +
      '[''OLJCESPC7Z'', ''1YMWWN1N4O'', ''6E92ZMYYFZ'', ''9SIQ...''');
  Add('12:22:08', 'INFO',  '',              'recommendation',
      'Receive ListRecommendations for product ids:' +
      '[''L9ECAV7KIM'', ''2ZYFJ3GM2N'', ''LS4PSXUNUM'', ''66VC...''');
  Add('12:22:08', 'INFO',  'ac46c7f5cceb', 'kafka',
      '[LocalLog partition=__cluster_metadata-0, dir=/tmp/kafka-logs]' +
      ' Rolled new log segment at off...');
  Add('12:22:08', 'INFO',  'ac46c7f5cceb', 'kafka',
      '[ProducerStateManager partition=__cluster_metadata-0]' +
      ' Wrote producer snapshot at offset 1714...');
  Add('12:22:08', 'INFO',  'e81ca6c9d7b5', 'payment',
      'Charge request received.');
  Add('12:22:08', 'ERROR', 'e81ca6c9d7b5', 'payment',
      'Visa cache full: cannot add new item.');
  Add('12:22:08', 'INFO',  '',              'currency',
      'Convert conversion successful');
  Add('12:22:08', 'INFO',  '',              'currency',
      'Convert conversion successful');
  Add('12:22:13', 'INFO',  'ab25f780f642', 'ad',
      'no baggage found in context');
  Add('12:22:13', 'INFO',  'ab25f780f642', 'ad',
      'Targeted ad request received for [telescopes, books, accessories]');
  Add('12:22:13', 'INFO',  '20bdc678616d', 'quote',
      'Calculated quote');
  Add('12:22:13', 'INFO',  '20bdc678616d', 'quote',
      'Calculated quote');
end;

procedure TDashboardModel.GenerateLogEntry(const ATime: string);
begin
  var LR1 := NextRand;
  var LServiceIdx := LR1 mod 7;
  var LR2 := NextRand;
  var LMsgIdx := LR2 mod 3;
  var LService: string;
  var LHost: string;
  var LLevel: string;
  var LMsg: string;

  case LServiceIdx of
    0: begin
      // cart service
      LService := 'cart';
      LHost := '08b51e83166c';
      LLevel := 'INFO';
      case LMsgIdx of
        0: LMsg := 'GetCartAsync called with userId={userId}';
        1: LMsg := 'AddItemAsync called with userId={userId},' +
             ' productId={productId}, quantity={quantity}';
        else
          LMsg := 'GetCartAsync called with userId={userId}';
      end;
    end;
    1: begin
      // recommendation service
      LService := 'recommendation';
      LHost := '';
      LLevel := 'INFO';
      case LMsgIdx of
        0: LMsg := 'Receive ListRecommendations for product ids:[''HQTGWGPNH4'', ''OLJCESPC7Z'']';
        1: LMsg := 'Receive ListRecommendations for product ids:[''OLJCESPC7Z'', ''1YMWWN1N4O'']';
        else
          LMsg := 'Receive ListRecommendations for product ids:[''L9ECAV7KIM'', ''2ZYFJ3GM2N'']';
      end;
    end;
    2: begin
      // kafka service
      LService := 'kafka';
      LHost := 'ac46c7f5cceb';
      LLevel := 'INFO';
      case LMsgIdx of
        0: LMsg := '[LocalLog partition=__cluster_metadata-0] Rolled new log segment';
        1: LMsg := '[ProducerStateManager partition=__cluster_metadata-0] Wrote producer snapshot';
        else
          LMsg := '[LocalLog partition=__cluster_metadata-0] Rolled log segment at offset 2048';
      end;
    end;
    3: begin
      // payment service (occasionally ERROR)
      LService := 'payment';
      LHost := 'e81ca6c9d7b5';
      if LMsgIdx = 1 then
        LLevel := 'ERROR'
      else
        LLevel := 'INFO';
      case LMsgIdx of
        0: LMsg := 'Charge request received.';
        1: LMsg := 'Visa cache full: cannot add new item.';
        else
          LMsg := 'Payment processing completed.';
      end;
    end;
    4: begin
      // currency service
      LService := 'currency';
      LHost := '';
      LLevel := 'INFO';
      LMsg := 'Convert conversion successful';
    end;
    5: begin
      // ad service
      LService := 'ad';
      LHost := 'ab25f780f642';
      LLevel := 'INFO';
      case LMsgIdx of
        0: LMsg := 'no baggage found in context';
        1: LMsg := 'Targeted ad request received for [telescopes, books, accessories]';
        else
          LMsg := 'Targeted ad request received for [cameras, lenses, tripods]';
      end;
    end;
    else begin
      // quote service
      LService := 'quote';
      LHost := '20bdc678616d';
      LLevel := 'INFO';
      LMsg := 'Calculated quote';
    end;
  end;

  FLogEntries.Add(TLogEntry.Make(ATime, LLevel, LHost, LService, LMsg));

  // Track severity
  if LLevel = 'ERROR' then
    Inc(FSeverities.Error)
  else
    Inc(FSeverities.Info);

  Inc(FTotalLogs);
end;

procedure TDashboardModel.Tick;
begin
  var LNow := Now;
  var LTimeStr := FormatDateTime('hh:nn:ss', LNow);

  // Generate 1-4 new log entries per tick
  var LR := NextRand;
  var LNewCount := 1 + (LR mod 4);

  for var LI := 0 to LNewCount - 1 do
    GenerateLogEntry(LTimeStr);

  // Trim log list to a maximum of 500 entries
  while FLogEntries.Count > 500 do
    FLogEntries.Delete(0);

  // Rotate histogram: drop the leftmost bar and append the new entry count
  for var LJ := 0 to High(FHistogram) - 1 do
    FHistogram[LJ] := FHistogram[LJ + 1];
  FHistogram[High(FHistogram)] := LNewCount;

  // Slightly vary top word counts to simulate ongoing log processing
  for var LK := 0 to FTopWords.Count - 1 do
  begin
    var LItem := FTopWords[LK];
    var LDelta: Int64 := NextRand mod 8;
    LItem.Count := LItem.Count + Integer(LDelta);
    FTopWords[LK] := LItem;
  end;

  Inc(FPatternCount, 1);
end;

end.
