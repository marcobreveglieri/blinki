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
{   Unit:        ResTui.Http.pas                                 }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Asynchronous HTTP execution engine for the ResTui demo.
///   Fires a TResTuiRequest on a background thread via THTTPClient
///   and delivers the result safely to the TUI event loop through a
///   thread-safe state machine protected by a critical section.
/// </summary>
unit ResTui.Http;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SyncObjs,
  ResTui.Model;

type

  /// <summary>
  ///   Internal lifecycle state of the HTTP engine.
  /// </summary>
  TResTuiRequestState = (
    rsIdle,     // no request in progress
    rsInFlight, // request running on worker thread
    rsDone      // result ready; call TryTakeResult to consume
  );

  /// <summary>
  ///   Thread-safe asynchronous HTTP execution engine.
  ///   Call Send to start a request on a background thread; poll Busy and
  ///   TryTakeResult from the TUI OnTimer handler (loop thread) to retrieve
  ///   the result. Cancel discards any pending result (best-effort).
  /// </summary>
  TResTuiHttpEngine = class
  strict private
    FGeneration: Integer;
    FLastResponse: TResTuiResponse;
    FLock: TCriticalSection;
    FState: TResTuiRequestState;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Fires the request asynchronously on a background thread.
    ///   No-op if a request is already in flight.
    ///   Snapshots ARequest immediately, so the caller may modify it after Send returns.
    /// </summary>
    procedure Send(const ARequest: TResTuiRequest);
    /// <summary>
    ///   True while the background worker is executing.
    /// </summary>
    function Busy: Boolean;
    /// <summary>
    ///   Returns True and sets AResponse when a result is ready.
    ///   Resets the engine to rsIdle. Call only from the TUI loop thread.
    /// </summary>
    function TryTakeResult(out AResponse: TResTuiResponse): Boolean;
    /// <summary>
    ///   Discards any pending result. The background network call may still
    ///   complete but its result will be silently dropped.
    /// </summary>
    procedure Cancel;
  end;

implementation

uses
  System.Classes,
  System.Diagnostics,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.NetEncoding,
  System.StrUtils,
  System.SysUtils,
  System.Threading;

{ TResTuiHttpEngine }

constructor TResTuiHttpEngine.Create;
begin
  inherited;
  FState := rsIdle;
  FLock := TCriticalSection.Create;
end;

destructor TResTuiHttpEngine.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TResTuiHttpEngine.Busy: Boolean;
begin
  FLock.Enter;
  try
    Result := FState = rsInFlight;
  finally
    FLock.Leave;
  end;
end;

function TResTuiHttpEngine.TryTakeResult(out AResponse: TResTuiResponse): Boolean;
begin
  FLock.Enter;
  try
    Result := FState = rsDone;
    if Result then
    begin
      AResponse := FLastResponse;
      FState := rsIdle;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TResTuiHttpEngine.Cancel;
begin
  FLock.Enter;
  try
    Inc(FGeneration);
    if FState <> rsInFlight then
      FState := rsIdle;
  finally
    FLock.Leave;
  end;
end;

procedure TResTuiHttpEngine.Send(const ARequest: TResTuiRequest);
var
  LGen: Integer;
begin
  FLock.Enter;
  try
    if FState = rsInFlight then
      Exit;
    Inc(FGeneration);
    LGen := FGeneration;
    FState := rsInFlight;
  finally
    FLock.Leave;
  end;

  // Snapshot the request so the worker captures only immutable value types
  var LMethod := ARequest.Method;
  var LUrl := ARequest.Url;
  var LBodyKind := ARequest.BodyKind;
  var LBodyContent := ARequest.Body;
  var LAuth := ARequest.Auth;

  var LParamSnap: TArray<TResTuiKeyValue>;
  SetLength(LParamSnap, ARequest.Params.Count);
  for var PI := 0 to ARequest.Params.Count - 1 do
    LParamSnap[PI] := ARequest.Params[PI];

  var LHeaderSnap: TArray<TResTuiKeyValue>;
  SetLength(LHeaderSnap, ARequest.Headers.Count);
  for var HI := 0 to ARequest.Headers.Count - 1 do
    LHeaderSnap[HI] := ARequest.Headers[HI];

  TTask.Run(
    procedure
    begin
      var LWatch := TStopwatch.StartNew;
      var LResult: TResTuiResponse;
      try
        // Build final URL with enabled query params
        var LFinalUrl := LUrl;
        var LSep := IfThen(Pos('?', LUrl) > 0, '&', '?');
        for var I := 0 to Length(LParamSnap) - 1 do
        begin
          var LKV := LParamSnap[I];
          if not LKV.Enabled then
            Continue;
          LFinalUrl := LFinalUrl + LSep +
            TNetEncoding.URL.Encode(LKV.Key) + '=' +
            TNetEncoding.URL.Encode(LKV.Value);
          LSep := '&';
        end;

        // Create HTTP client and set custom headers
        var LClient := THTTPClient.Create;
        try
          LClient.CustomHeaders['User-Agent'] := 'ResTui/1.0';
          LClient.CustomHeaders['Accept'] := '*/*';

          // Authentication header
          case LAuth.Kind of
            akBearer:
              LClient.CustomHeaders['Authorization'] := 'Bearer ' + LAuth.Token;
            akBasic:
            begin
              var LCred := TNetEncoding.Base64.Encode(LAuth.Username + ':' + LAuth.Password);
              LClient.CustomHeaders['Authorization'] := 'Basic ' + LCred;
            end;
            akApiKey:
              if LAuth.HeaderName <> '' then
                LClient.CustomHeaders[LAuth.HeaderName] := LAuth.HeaderValue;
          end;

          // Content-Type for JSON body
          if LBodyKind = bkJson then
            LClient.CustomHeaders['Content-Type'] := 'application/json; charset=utf-8';

          // User-defined headers (override defaults if they conflict)
          for var I := 0 to Length(LHeaderSnap) - 1 do
          begin
            var LKV := LHeaderSnap[I];
            if LKV.Enabled and (LKV.Key <> '') then
              LClient.CustomHeaders[LKV.Key] := LKV.Value;
          end;

          // Body stream
          var LStream: TStringStream;
          if (LBodyKind <> bkNone) and (LBodyContent <> '') then
            LStream := TStringStream.Create(LBodyContent, TEncoding.UTF8)
          else
            LStream := nil;
          try
            // Dispatch by method name
            var LHttpResp: IHTTPResponse;
            var LUMethod := UpperCase(LMethod);
            if LUMethod = 'GET' then
              LHttpResp := LClient.Get(LFinalUrl)
            else if LUMethod = 'DELETE' then
              LHttpResp := LClient.Delete(LFinalUrl)
            else if LUMethod = 'HEAD' then
              LHttpResp := LClient.Head(LFinalUrl)
            else if LUMethod = 'POST' then
              LHttpResp := LClient.Post(LFinalUrl, LStream)
            else if LUMethod = 'PUT' then
              LHttpResp := LClient.Put(LFinalUrl, LStream)
            else if LUMethod = 'PATCH' then
              LHttpResp := LClient.Patch(LFinalUrl, LStream)
            else
              // OPTIONS, TRACE, and other custom methods: fall back to GET
              LHttpResp := LClient.Get(LFinalUrl);

            LWatch.Stop;

            // Convert response headers
            var LRawHdrs := LHttpResp.Headers;
            var LRespHdrs: TArray<TResTuiKeyValue>;
            SetLength(LRespHdrs, Length(LRawHdrs));
            for var I := 0 to Length(LRawHdrs) - 1 do
            begin
              LRespHdrs[I].Enabled := True;
              LRespHdrs[I].Key := LRawHdrs[I].Name;
              LRespHdrs[I].Value := LRawHdrs[I].Value;
            end;

            LResult := TResTuiResponse.MakeOk(
              LHttpResp.StatusCode,
              LHttpResp.StatusText,
              LHttpResp.ContentAsString(TEncoding.UTF8),
              LWatch.ElapsedMilliseconds,
              LRespHdrs);
          finally
            LStream.Free;
          end;
        finally
          LClient.Free;
        end;
      except
        on E: Exception do
        begin
          LWatch.Stop;
          LResult := TResTuiResponse.MakeError(E.Message);
          LResult.DurationMs := LWatch.ElapsedMilliseconds;
        end;
      end;

      // Post the result to the loop thread via the state machine
      FLock.Enter;
      try
        if FGeneration = LGen then
        begin
          FLastResponse := LResult;
          FState := rsDone;
        end;
      finally
        FLock.Leave;
      end;
    end
  );
end;

end.
