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
{   Unit:        ResTui.dpr                                      }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   ResTui — a terminal REST client demo for the Blinki library.
///   Entry point: loads the request collection, wires all callbacks,
///   and runs the TUI event loop.
///
///   Widget tree (built by TResTuiView):
///     TTuiVStack (root)
///       Header row            Fixed(1)
///       Body : TTuiHStack     Fill
///         RequestList         Fixed(26) — sidebar
///         Right : TTuiVStack  Fill
///           URL row           Fixed(3)  — method + URL
///           Mid : TTuiHStack  Fill      — tabs | response
///       Footer row            Fixed(1)
///
///   Keys:
///     F1         — help overlay
///     F2         — save collection to file
///     F5         — send the current request (async)
///     F7         — add a new request
///     F8         — delete the current request
///     F10 / Esc  — quit
///     Tab        — cycle focus forward
///     Shift+Tab  — cycle focus backward
/// </summary>
program ResTui;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Blinki.Core.App,
  Blinki.Core.Input,
  Blinki.Core.Theme,
  Blinki.Widgets.Dialog,
  ResTui.Consts  in 'ResTui.Consts.pas',
  ResTui.Helpers in 'ResTui.Helpers.pas',
  ResTui.Http    in 'ResTui.Http.pas',
  ResTui.Model   in 'ResTui.Model.pas',
  ResTui.Overlays in 'ResTui.Overlays.pas',
  ResTui.Storage in 'ResTui.Storage.pas',
  ResTui.View    in 'ResTui.View.pas',
  ResTui.AuthPanel     in 'ResTui.AuthPanel.pas',
  ResTui.BodyPanel     in 'ResTui.BodyPanel.pas',
  ResTui.KeyValueEditor in 'ResTui.KeyValueEditor.pas',
  ResTui.RequestList   in 'ResTui.RequestList.pas',
  ResTui.ResponseView  in 'ResTui.ResponseView.pas';

{ Helper: open an input dialog (key=value editor) and call AOnOk with the text. }
procedure ShowInputDialog(const AApp: TTuiApp; const ATitle, APrompt,
  ADefault: string; const AOnOk: TProc<string>);
begin
  var LDlg := TTuiDialogs.Input(ATitle, APrompt, ADefault);
  LDlg.OnClose :=
    procedure(ASender: TObject; AResult: TTuiDialogResult)
    begin
      var LValue := (ASender as TTuiInputDialog).Value;
      AApp.PopModal;
      if AResult = drOK then
        AOnOk(LValue);
    end;
  AApp.PushModal(LDlg);
end;

begin
  ReportMemoryLeaksOnShutdown := True;

  // Load collection: from command-line arg or seed a default
  var LCollection: TResTuiCollection;
  var LFilePath := ParamStr(1);
  if (LFilePath <> '') and FileExists(LFilePath) then
  begin
    try
      LCollection := LoadCollection(LFilePath);
    except
      on E: Exception do
      begin
        WriteLn('Error loading collection: ', E.Message);
        LCollection := TResTuiCollection.Create;
        LCollection.Seed;
        LFilePath := 'collection.json';
      end;
    end;
  end
  else
  begin
    LCollection := TResTuiCollection.Create;
    LCollection.Seed;
    if LFilePath = '' then
      LFilePath := 'collection.json';
  end;

  var LEngine := TResTuiHttpEngine.Create;
  var LApp := TTuiApp.Create;
  try
    LApp.Theme := TTuiTheme.Dark;

    var LView := TResTuiView.Create(LCollection);

    // Load first request if the collection is non-empty
    if LCollection.Requests.Count > 0 then
    begin
      LView.RequestList.ActiveIndex := 0;
      LView.LoadRequest(LCollection.Requests[0]);
    end;

    // ---- OnTimer: poll async HTTP result and drive the spinner ----
    LApp.OnTimer :=
      procedure(AElapsedMs: Integer)
      begin
        var LResponse: TResTuiResponse;
        if LEngine.TryTakeResult(LResponse) then
        begin
          LView.ShowResponse(LResponse);
          LView.Footer.Text := CFooterMain;
        end
        else if LEngine.Busy then
        begin
          LView.SetLoading(True);
          LView.Footer.Text := CFooterLoading;
        end;
      end;

    // ---- OnKeyPress: global shortcuts (F-keys only, never printable chars) ----
    LApp.OnKeyPress :=
      procedure(const AKey: TTuiKeyEvent)
      begin
        case AKey.Code of
          kcF1:
          begin
            // Help overlay
            var LHelp := TResTuiHelpView.Create(nil);
            LHelp.OnClose :=
              procedure
              begin
                LApp.PopModal;
              end;
            LApp.PushModal(LHelp);
          end;

          kcF2:
          begin
            // Save collection to file
            LView.CollectIntoCurrentRequest;
            try
              LCollection.FilePath := LFilePath;
              SaveCollection(LCollection, LFilePath);
            except
              on E: Exception do
              begin
                // Show a brief error via the footer (non-modal)
                LView.Footer.Text := 'Save error: ' + E.Message;
              end;
            end;
          end;

          kcF5:
          begin
            // Send the current request asynchronously
            if LEngine.Busy then
              Exit;
            LView.CollectIntoCurrentRequest;
            var LReq := LView.CurrentRequest;
            if not Assigned(LReq) then
              Exit;
            if LReq.Url = '' then
              Exit;
            LEngine.Send(LReq);
            LView.SetLoading(True);
            LView.Footer.Text := CFooterLoading;
          end;

          kcF7:
          begin
            // New request
            ShowInputDialog(LApp, 'New Request', 'Request name', 'New Request',
              procedure(AName: string)
              begin
                if AName = '' then
                  Exit;
                var LReq := TResTuiRequest.Create;
                LReq.Name := AName;
                LCollection.Requests.Add(LReq);
                LView.RequestList.Invalidate;
                LView.RequestList.ActiveIndex := LCollection.Requests.Count - 1;
                LView.LoadRequest(LReq);
              end);
          end;

          kcF8:
          begin
            // Delete current request
            var LIdx := LView.RequestList.ActiveIndex;
            if (LIdx < 0) or (LIdx >= LCollection.Requests.Count) then
              Exit;
            LCollection.Requests.Delete(LIdx);
            if LCollection.Requests.Count > 0 then
            begin
              var LNewIdx := LIdx;
              if LNewIdx >= LCollection.Requests.Count then
                LNewIdx := LCollection.Requests.Count - 1;
              LView.RequestList.ActiveIndex := LNewIdx;
              LView.LoadRequest(LCollection.Requests[LNewIdx]);
            end
            else
            begin
              LView.RequestList.ActiveIndex := -1;
              LView.ResponseView.ShowIdle;
            end;
            LView.RequestList.Invalidate;
          end;

          kcF10, kcEscape:
            LApp.Quit;
        end;
      end;

    // ---- RequestList.OnSelect: save current, load next ----
    LView.RequestList.OnSelect :=
      procedure(AIndex: Integer)
      begin
        LView.CollectIntoCurrentRequest;
        if (AIndex >= 0) and (AIndex < LCollection.Requests.Count) then
          LView.LoadRequest(LCollection.Requests[AIndex]);
      end;

    // ---- ParamsEditor callbacks ----
    LView.ParamsEditor.OnAddRequest :=
      procedure
      begin
        ShowInputDialog(LApp, 'Add Param', 'key=value', '',
          procedure(AText: string)
          begin
            var LEq := Pos('=', AText);
            var LKV: TResTuiKeyValue;
            LKV.Enabled := True;
            if LEq > 0 then
            begin
              LKV.Key := Trim(Copy(AText, 1, LEq - 1));
              LKV.Value := Trim(Copy(AText, LEq + 1, MaxInt));
            end
            else
            begin
              LKV.Key := Trim(AText);
              LKV.Value := '';
            end;
            LView.DummyParams.Add(LKV);
            LView.ParamsEditor.Refresh;
          end);
      end;

    LView.ParamsEditor.OnEditRequest :=
      procedure(AIndex: Integer)
      begin
        if (AIndex < 0) or (AIndex >= LView.DummyParams.Count) then
          Exit;
        var LKV := LView.DummyParams[AIndex];
        ShowInputDialog(LApp, 'Edit Param', 'key=value',
          LKV.Key + '=' + LKV.Value,
          procedure(AText: string)
          begin
            var LIdx2 := AIndex;
            if (LIdx2 < 0) or (LIdx2 >= LView.DummyParams.Count) then
              Exit;
            var LEq := Pos('=', AText);
            var LKV2: TResTuiKeyValue;
            LKV2.Enabled := LView.DummyParams[LIdx2].Enabled;
            if LEq > 0 then
            begin
              LKV2.Key := Trim(Copy(AText, 1, LEq - 1));
              LKV2.Value := Trim(Copy(AText, LEq + 1, MaxInt));
            end
            else
            begin
              LKV2.Key := Trim(AText);
              LKV2.Value := '';
            end;
            LView.DummyParams[LIdx2] := LKV2;
            LView.ParamsEditor.Refresh;
          end);
      end;

    LView.ParamsEditor.OnDeleteRequest :=
      procedure(AIndex: Integer)
      begin
        if (AIndex >= 0) and (AIndex < LView.DummyParams.Count) then
        begin
          LView.DummyParams.Delete(AIndex);
          LView.ParamsEditor.Refresh;
        end;
      end;

    LView.ParamsEditor.OnToggleRequest :=
      procedure(AIndex: Integer)
      begin
        if (AIndex >= 0) and (AIndex < LView.DummyParams.Count) then
        begin
          var LKV := LView.DummyParams[AIndex];
          LKV.Enabled := not LKV.Enabled;
          LView.DummyParams[AIndex] := LKV;
          LView.ParamsEditor.Refresh;
        end;
      end;

    // ---- HeadersEditor callbacks ----
    LView.HeadersEditor.OnAddRequest :=
      procedure
      begin
        ShowInputDialog(LApp, 'Add Header', 'Name=Value', '',
          procedure(AText: string)
          begin
            var LEq := Pos('=', AText);
            var LKV: TResTuiKeyValue;
            LKV.Enabled := True;
            if LEq > 0 then
            begin
              LKV.Key := Trim(Copy(AText, 1, LEq - 1));
              LKV.Value := Trim(Copy(AText, LEq + 1, MaxInt));
            end
            else
            begin
              LKV.Key := Trim(AText);
              LKV.Value := '';
            end;
            LView.DummyHeaders.Add(LKV);
            LView.HeadersEditor.Refresh;
          end);
      end;

    LView.HeadersEditor.OnEditRequest :=
      procedure(AIndex: Integer)
      begin
        if (AIndex < 0) or (AIndex >= LView.DummyHeaders.Count) then
          Exit;
        var LKV := LView.DummyHeaders[AIndex];
        ShowInputDialog(LApp, 'Edit Header', 'Name=Value',
          LKV.Key + '=' + LKV.Value,
          procedure(AText: string)
          begin
            var LIdx2 := AIndex;
            if (LIdx2 < 0) or (LIdx2 >= LView.DummyHeaders.Count) then
              Exit;
            var LEq := Pos('=', AText);
            var LKV2: TResTuiKeyValue;
            LKV2.Enabled := LView.DummyHeaders[LIdx2].Enabled;
            if LEq > 0 then
            begin
              LKV2.Key := Trim(Copy(AText, 1, LEq - 1));
              LKV2.Value := Trim(Copy(AText, LEq + 1, MaxInt));
            end
            else
            begin
              LKV2.Key := Trim(AText);
              LKV2.Value := '';
            end;
            LView.DummyHeaders[LIdx2] := LKV2;
            LView.HeadersEditor.Refresh;
          end);
      end;

    LView.HeadersEditor.OnDeleteRequest :=
      procedure(AIndex: Integer)
      begin
        if (AIndex >= 0) and (AIndex < LView.DummyHeaders.Count) then
        begin
          LView.DummyHeaders.Delete(AIndex);
          LView.HeadersEditor.Refresh;
        end;
      end;

    LView.HeadersEditor.OnToggleRequest :=
      procedure(AIndex: Integer)
      begin
        if (AIndex >= 0) and (AIndex < LView.DummyHeaders.Count) then
        begin
          var LKV := LView.DummyHeaders[AIndex];
          LKV.Enabled := not LKV.Enabled;
          LView.DummyHeaders[AIndex] := LKV;
          LView.HeadersEditor.Refresh;
        end;
      end;

    LApp.SetRoot(LView);
    LApp.Run;
  finally
    LApp.Free;
    LEngine.Free;
    LCollection.Free;
  end;
end.
