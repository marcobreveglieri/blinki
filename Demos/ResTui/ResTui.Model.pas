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
{   Unit:        ResTui.Model.pas                                }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Domain model for the ResTui demo: key-value pairs, HTTP request,
///   response, authentication, and collection types.
///   No UI dependencies — only System.* units.
/// </summary>
unit ResTui.Model;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections;

type

  /// <summary>
  ///   A key-value pair with an enabled/disabled toggle.
  ///   Used for query parameters and HTTP headers.
  /// </summary>
  TResTuiKeyValue = record
    Enabled: Boolean;
    Key: string;
    Value: string;
    /// <summary>
    ///   Creates a new key-value pair. Enabled defaults to True.
    /// </summary>
    class function Make(const AKey, AValue: string;
      AEnabled: Boolean = True): TResTuiKeyValue; static;
  end;

  /// <summary>
  ///   Authentication strategy.
  /// </summary>
  TResTuiAuthKind = (
    akNone,     // no authentication
    akBearer,   // Authorization: Bearer <token>
    akBasic,    // Authorization: Basic base64(user:pass)
    akApiKey    // custom header <name>: <value>
  );

  /// <summary>
  ///   Authentication configuration for a request.
  ///   Only the fields relevant to the selected Kind need to be filled.
  /// </summary>
  TResTuiAuth = record
    Kind: TResTuiAuthKind;
    // bearer token
    Token: string;
    // basic auth
    Username: string;
    Password: string;
    // API key header
    HeaderName: string;
    HeaderValue: string;
  end;

  /// <summary>
  ///   Body content type.
  /// </summary>
  TResTuiBodyKind = (
    bkNone,  // no body
    bkRaw,   // plain text (no content-type forced)
    bkJson   // application/json
  );

  /// <summary>
  ///   A single REST request definition held inside a collection.
  ///   Owns its Params and Headers lists.
  /// </summary>
  TResTuiRequest = class
  strict private
    FAuth: TResTuiAuth;
    FBody: string;
    FBodyKind: TResTuiBodyKind;
    FHeaders: TList<TResTuiKeyValue>;
    FMethod: string;
    FName: string;
    FParams: TList<TResTuiKeyValue>;
    FUrl: string;
  public
    /// <summary>
    ///   Creates the request with default method GET and empty lists.
    /// </summary>
    constructor Create;
    destructor Destroy; override;
    property Auth: TResTuiAuth read FAuth write FAuth;
    property Body: string read FBody write FBody;
    property BodyKind: TResTuiBodyKind read FBodyKind write FBodyKind;
    property Headers: TList<TResTuiKeyValue> read FHeaders;
    property Method: string read FMethod write FMethod;
    property Name: string read FName write FName;
    property Params: TList<TResTuiKeyValue> read FParams;
    property Url: string read FUrl write FUrl;
  end;

  /// <summary>
  ///   The result of executing a request, including status, body, headers and timing.
  ///   HasError is True when a network-level error occurred (not an HTTP error status).
  /// </summary>
  TResTuiResponse = record
    StatusCode: Integer;
    StatusText: string;
    Body: string;
    ErrorMessage: string;
    DurationMs: Int64;
    Headers: TArray<TResTuiKeyValue>;
    HasError: Boolean;
    /// <summary>
    ///   Builds a successful response record.
    /// </summary>
    class function MakeOk(AStatus: Integer; const AStatusText, ABody: string;
      ADuration: Int64; const AHeaders: TArray<TResTuiKeyValue>): TResTuiResponse; static;
    /// <summary>
    ///   Builds a network-error response record.
    /// </summary>
    class function MakeError(const AMessage: string): TResTuiResponse; static;
  end;

  /// <summary>
  ///   A named collection of requests, optionally linked to a file on disk.
  ///   Owns all TResTuiRequest instances.
  /// </summary>
  TResTuiCollection = class
  strict private
    FFilePath: string;
    FName: string;
    FRequests: TObjectList<TResTuiRequest>;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Populates the collection with sample requests against public test APIs.
    /// </summary>
    procedure Seed;
    property FilePath: string read FFilePath write FFilePath;
    property Name: string read FName write FName;
    property Requests: TObjectList<TResTuiRequest> read FRequests;
  end;

implementation

uses
  System.SysUtils;

{ TResTuiKeyValue }

class function TResTuiKeyValue.Make(const AKey, AValue: string;
  AEnabled: Boolean): TResTuiKeyValue;
begin
  Result.Enabled := AEnabled;
  Result.Key := AKey;
  Result.Value := AValue;
end;

{ TResTuiRequest }

constructor TResTuiRequest.Create;
begin
  inherited;
  FMethod := 'GET';
  FBodyKind := bkNone;
  FAuth.Kind := akNone;
  FHeaders := TList<TResTuiKeyValue>.Create;
  FParams := TList<TResTuiKeyValue>.Create;
end;

destructor TResTuiRequest.Destroy;
begin
  FHeaders.Free;
  FParams.Free;
  inherited;
end;

{ TResTuiResponse }

class function TResTuiResponse.MakeOk(AStatus: Integer; const AStatusText,
  ABody: string; ADuration: Int64;
  const AHeaders: TArray<TResTuiKeyValue>): TResTuiResponse;
begin
  Result.StatusCode := AStatus;
  Result.StatusText := AStatusText;
  Result.Body := ABody;
  Result.DurationMs := ADuration;
  Result.Headers := AHeaders;
  Result.HasError := False;
end;

class function TResTuiResponse.MakeError(const AMessage: string): TResTuiResponse;
begin
  Result.HasError := True;
  Result.ErrorMessage := AMessage;
end;

{ TResTuiCollection }

constructor TResTuiCollection.Create;
begin
  inherited;
  FName := 'New Collection';
  FRequests := TObjectList<TResTuiRequest>.Create(True);
end;

destructor TResTuiCollection.Destroy;
begin
  FRequests.Free;
  inherited;
end;

procedure TResTuiCollection.Seed;
var
  LReq: TResTuiRequest;
begin
  FName := 'Sample Collection';

  // 1. GET a list of todos
  LReq := TResTuiRequest.Create;
  LReq.Name := 'Get todos';
  LReq.Method := 'GET';
  LReq.Url := 'https://jsonplaceholder.typicode.com/todos';
  LReq.Params.Add(TResTuiKeyValue.Make('_limit', '5'));
  FRequests.Add(LReq);

  // 2. GET a single todo
  LReq := TResTuiRequest.Create;
  LReq.Name := 'Get todo by id';
  LReq.Method := 'GET';
  LReq.Url := 'https://jsonplaceholder.typicode.com/todos/1';
  FRequests.Add(LReq);

  // 3. POST a new post
  LReq := TResTuiRequest.Create;
  LReq.Name := 'Create post';
  LReq.Method := 'POST';
  LReq.Url := 'https://jsonplaceholder.typicode.com/posts';
  LReq.BodyKind := bkJson;
  LReq.Body := '{'#13#10'  "title": "Hello ResTui",'#13#10'  "body": "A TUI REST client for Delphi",'#13#10'  "userId": 1'#13#10'}';
  FRequests.Add(LReq);

  // 4. GET with Bearer auth example (httpbin reflects the request)
  LReq := TResTuiRequest.Create;
  LReq.Name := 'Bearer auth (httpbin)';
  LReq.Method := 'GET';
  LReq.Url := 'https://httpbin.org/bearer';
  var LAuth := Default(TResTuiAuth);
  LAuth.Kind := akBearer;
  LAuth.Token := 'my-secret-token';
  LReq.Auth := LAuth;
  FRequests.Add(LReq);

  // 5. GET with query params (httpbin)
  LReq := TResTuiRequest.Create;
  LReq.Name := 'Echo params (httpbin)';
  LReq.Method := 'GET';
  LReq.Url := 'https://httpbin.org/get';
  LReq.Params.Add(TResTuiKeyValue.Make('foo', 'bar'));
  LReq.Params.Add(TResTuiKeyValue.Make('version', '1'));
  FRequests.Add(LReq);

  // 6. DELETE example
  LReq := TResTuiRequest.Create;
  LReq.Name := 'Delete post';
  LReq.Method := 'DELETE';
  LReq.Url := 'https://jsonplaceholder.typicode.com/posts/1';
  FRequests.Add(LReq);
end;

end.
