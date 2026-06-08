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
{   Unit:        ResTui.Storage.pas                              }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   JSON persistence for the ResTui demo: loading and saving
///   TResTuiCollection from/to a .json file on disk.
/// </summary>
unit ResTui.Storage;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  ResTui.Model;

/// <summary>
///   Loads a collection from a JSON file.
///   Raises an exception if the file cannot be read or the JSON is malformed.
/// </summary>
function LoadCollection(const APath: string): TResTuiCollection;

/// <summary>
///   Serialises a collection to a JSON file, creating or overwriting it.
/// </summary>
procedure SaveCollection(const ACollection: TResTuiCollection; const APath: string);

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.SysUtils;

{ Helper functions }

function ReadStr(const AObj: TJSONObject; const AKey: string): string;
begin
  var LVal := AObj.GetValue(AKey);
  if Assigned(LVal) then
    Result := LVal.Value
  else
    Result := '';
end;

function ReadBool(const AObj: TJSONObject; const AKey: string;
  ADefault: Boolean = True): Boolean;
begin
  var LVal := AObj.GetValue(AKey);
  if LVal is TJSONBool then
    Result := (LVal as TJSONBool).AsBoolean
  else
    Result := ADefault;
end;

function StrToAuthKind(const AStr: string): TResTuiAuthKind;
begin
  if AStr = 'bearer' then
    Result := akBearer
  else if AStr = 'basic' then
    Result := akBasic
  else if AStr = 'apikey' then
    Result := akApiKey
  else
    Result := akNone;
end;

function AuthKindToStr(AKind: TResTuiAuthKind): string;
begin
  case AKind of
    akBearer: Result := 'bearer';
    akBasic:  Result := 'basic';
    akApiKey: Result := 'apikey';
  else
    Result := 'none';
  end;
end;

function StrToBodyKind(const AStr: string): TResTuiBodyKind;
begin
  if AStr = 'raw' then
    Result := bkRaw
  else if AStr = 'json' then
    Result := bkJson
  else
    Result := bkNone;
end;

function BodyKindToStr(AKind: TResTuiBodyKind): string;
begin
  case AKind of
    bkRaw:  Result := 'raw';
    bkJson: Result := 'json';
  else
    Result := 'none';
  end;
end;

procedure ParseKeyValueArray(const AArr: TJSONArray;
  ATarget: TList<TResTuiKeyValue>);
begin
  if not Assigned(AArr) then
    Exit;
  for var I := 0 to AArr.Count - 1 do
  begin
    var LItem := AArr.Items[I];
    if not (LItem is TJSONObject) then
      Continue;
    var LObj := LItem as TJSONObject;
    var LKV: TResTuiKeyValue;
    LKV.Enabled := ReadBool(LObj, 'enabled');
    LKV.Key := ReadStr(LObj, 'key');
    LKV.Value := ReadStr(LObj, 'value');
    ATarget.Add(LKV);
  end;
end;

function BuildKeyValueArray(
  ASource: TList<TResTuiKeyValue>): TJSONArray;
begin
  Result := TJSONArray.Create;
  for var I := 0 to ASource.Count - 1 do
  begin
    var LKV := ASource[I];
    var LObj := TJSONObject.Create;
    LObj.AddPair('enabled', TJSONBool.Create(LKV.Enabled));
    LObj.AddPair('key', LKV.Key);
    LObj.AddPair('value', LKV.Value);
    Result.AddElement(LObj);
  end;
end;

{ LoadCollection }

function LoadCollection(const APath: string): TResTuiCollection;
begin
  var LJson := TFile.ReadAllText(APath, TEncoding.UTF8);
  var LRoot := TJSONObject.ParseJSONValue(LJson);
  if not (LRoot is TJSONObject) then
    raise Exception.Create('Invalid collection file: expected a JSON object at root level');
  var LRootObj := LRoot as TJSONObject;
  try
    Result := TResTuiCollection.Create;
    try
      Result.FilePath := APath;
      Result.Name := ReadStr(LRootObj, 'name');
      if Result.Name = '' then
        Result.Name := TPath.GetFileNameWithoutExtension(APath);

      var LRequestsArr := LRootObj.GetValue('requests') as TJSONArray;
      if not Assigned(LRequestsArr) then
        Exit;

      for var I := 0 to LRequestsArr.Count - 1 do
      begin
        var LItem := LRequestsArr.Items[I];
        if not (LItem is TJSONObject) then
          Continue;
        var LReqObj := LItem as TJSONObject;
        var LReq := TResTuiRequest.Create;
        try
          LReq.Name := ReadStr(LReqObj, 'name');
          LReq.Method := ReadStr(LReqObj, 'method');
          if LReq.Method = '' then
            LReq.Method := 'GET';
          LReq.Url := ReadStr(LReqObj, 'url');

          ParseKeyValueArray(LReqObj.GetValue('params') as TJSONArray, LReq.Params);
          ParseKeyValueArray(LReqObj.GetValue('headers') as TJSONArray, LReq.Headers);

          var LAuthObj := LReqObj.GetValue('auth') as TJSONObject;
          if Assigned(LAuthObj) then
          begin
            var LAuth: TResTuiAuth;
            LAuth.Kind := StrToAuthKind(ReadStr(LAuthObj, 'kind'));
            LAuth.Token := ReadStr(LAuthObj, 'token');
            LAuth.Username := ReadStr(LAuthObj, 'username');
            LAuth.Password := ReadStr(LAuthObj, 'password');
            LAuth.HeaderName := ReadStr(LAuthObj, 'headerName');
            LAuth.HeaderValue := ReadStr(LAuthObj, 'headerValue');
            LReq.Auth := LAuth;
          end;

          var LBodyObj := LReqObj.GetValue('body') as TJSONObject;
          if Assigned(LBodyObj) then
          begin
            LReq.BodyKind := StrToBodyKind(ReadStr(LBodyObj, 'kind'));
            LReq.Body := ReadStr(LBodyObj, 'content');
          end;

          Result.Requests.Add(LReq);
        except
          LReq.Free;
          raise;
        end;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LRoot.Free;
  end;
end;

{ SaveCollection }

procedure SaveCollection(const ACollection: TResTuiCollection; const APath: string);
begin
  var LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('name', ACollection.Name);
    var LRequestsArr := TJSONArray.Create;
    LRoot.AddPair('requests', LRequestsArr);
    for var I := 0 to ACollection.Requests.Count - 1 do
    begin
      var LReq := ACollection.Requests[I];
      var LReqObj := TJSONObject.Create;

      LReqObj.AddPair('name', LReq.Name);
      LReqObj.AddPair('method', LReq.Method);
      LReqObj.AddPair('url', LReq.Url);
      LReqObj.AddPair('params', BuildKeyValueArray(LReq.Params));
      LReqObj.AddPair('headers', BuildKeyValueArray(LReq.Headers));

      var LAuth := LReq.Auth;
      var LAuthObj := TJSONObject.Create;
      LAuthObj.AddPair('kind', AuthKindToStr(LAuth.Kind));
      LAuthObj.AddPair('token', LAuth.Token);
      LAuthObj.AddPair('username', LAuth.Username);
      LAuthObj.AddPair('password', LAuth.Password);
      LAuthObj.AddPair('headerName', LAuth.HeaderName);
      LAuthObj.AddPair('headerValue', LAuth.HeaderValue);
      LReqObj.AddPair('auth', LAuthObj);

      var LBodyObj := TJSONObject.Create;
      LBodyObj.AddPair('kind', BodyKindToStr(LReq.BodyKind));
      LBodyObj.AddPair('content', LReq.Body);
      LReqObj.AddPair('body', LBodyObj);

      LRequestsArr.AddElement(LReqObj);
    end;

    var LJson := LRoot.Format(2);
    TFile.WriteAllText(APath, LJson, TEncoding.UTF8);
  finally
    LRoot.Free;
  end;
end;

end.
