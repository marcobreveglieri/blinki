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
{   Unit:        Recorder.Sapi.pas                               }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   RecorderDemo -- SAPI 5 speech transcription engine using low-level COM
///   interfaces declared by hand from sapi.idl (Windows SDK v7.0A).
///   Events are polled via SetNotifyWin32Event + GetEvents: no threads,
///   no message pump -- fully compatible with the Blinki OnTimer loop.
///   NOTE: this unit calls CoInitializeEx / CoUninitialize, so the demo
///   does use COM (unlike the original "no COM" comment in Recorder.dpr).
///   Graceful degradation: if no speech recogniser is available, Active
///   stays False and LastError describes the failure.
/// </summary>
unit Recorder.Sapi;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.SysUtils,
  Winapi.Windows;

// ============================================================================
// Minimal SAPI 5 COM interface declarations (vtable order from sapi.idl)
// Only the subset needed for dictation + event polling is declared.
// Methods not called by this unit are still present to keep vtable offsets
// correct; their parameter types use Pointer where the exact type is unused.
// ============================================================================

type

  // Forward declarations
  ISpRecoContext  = interface;
  ISpRecoGrammar  = interface;
  ISpRecognizer   = interface;
  ISpRecoResult   = interface;

  // SPEVENT: structure returned by ISpEventSource.GetEvents.
  // The eEventId field carries the SPEVENTENUM value (38 = recognition,
  // 39 = hypothesis). When elParamType = 2 (SPET_LPARAM_IS_OBJECT), lParam
  // is an AddRef'd IUnknown pointer that the caller must release.
  TSPEVENT = record
    eEventId:             Word;
    elParamType:          Word;
    ulStreamNum:          LongWord;
    ullAudioStreamOffset: UInt64;
    wParam:               WPARAM;
    lParam:               LPARAM;
  end;

  // ISpNotifySource -- base notification-source interface.
  // IID: {5EFF4AEF-8487-11D2-961C-00C04F8EE628}
  ISpNotifySource = interface(IUnknown)
    ['{5EFF4AEF-8487-11D2-961C-00C04F8EE628}']
    function SetNotifySink(pNotifySink: IUnknown): HResult; stdcall;
    function SetNotifyWindowMessage(hWnd: HWND; Msg: UINT;
      wParam: WPARAM; lParam: LPARAM): HResult; stdcall;
    function SetNotifyCallbackFunction(pfnCallback: Pointer;
      wParam: WPARAM; lParam: LPARAM): HResult; stdcall;
    function SetNotifyCallbackInterface(pSpNotifyCallback: IUnknown;
      wParam: WPARAM; lParam: LPARAM): HResult; stdcall;
    function SetNotifyWin32Event: HResult; stdcall;
    function WaitForNotifyEvent(dwMilliseconds: DWORD): HResult; stdcall;
    function GetNotifyEventHandle: THandle; stdcall;
  end;

  // ISpEventSource -- adds event queue access on top of ISpNotifySource.
  // IID: {BE7A9CCE-5F9E-11D2-960F-00C04F8EE628}
  ISpEventSource = interface(ISpNotifySource)
    ['{BE7A9CCE-5F9E-11D2-960F-00C04F8EE628}']
    function SetInterest(ullEventInterest: UInt64;
      ullQueuedInterest: UInt64): HResult; stdcall;
    function GetEvents(ulCount: ULONG; pEventArray: Pointer;
      pulFetched: PULONG): HResult; stdcall;
    function GetInfo(pInfo: Pointer): HResult; stdcall;
  end;

  // ISpProperties -- base property bag; ISpRecognizer inherits from this.
  // IID: {5B4FB971-B115-4DE1-AD97-E482E3BF6EE4}
  ISpProperties = interface(IUnknown)
    ['{5B4FB971-B115-4DE1-AD97-E482E3BF6EE4}']
    function SetPropertyNum(pName: PWideChar; lValue: Integer): HResult; stdcall;
    function GetPropertyNum(pName: PWideChar;
      plValue: PInteger): HResult; stdcall;
    function SetPropertyString(pName: PWideChar;
      pValue: PWideChar): HResult; stdcall;
    function GetPropertyString(pName: PWideChar;
      ppCoMemValue: Pointer): HResult; stdcall;
  end;

  // ISpRecognizer -- in-process or shared recogniser.
  // IID: {C2B5F241-DAA0-4507-9E16-5A1EAA2B7A5C}
  ISpRecognizer = interface(ISpProperties)
    ['{C2B5F241-DAA0-4507-9E16-5A1EAA2B7A5C}']
    function SetRecognizer(pRecognizer: IUnknown): HResult; stdcall;
    function GetRecognizer(out ppRecognizer: IUnknown): HResult; stdcall;
    function SetInput(pUnkInput: IUnknown;
      fAllowFormatChanges: BOOL): HResult; stdcall;
    function GetInputObjectToken(out ppToken: IUnknown): HResult; stdcall;
    function GetInputStream(out ppStream: IUnknown): HResult; stdcall;
    function CreateRecoContext(
      out ppNewCtxt: ISpRecoContext): HResult; stdcall;
    function GetRecoProfile(out ppToken: IUnknown): HResult; stdcall;
    function SetRecoProfile(pToken: IUnknown): HResult; stdcall;
    function IsSharedInstance: HResult; stdcall;
    function GetRecoState(pState: PDWORD): HResult; stdcall;
    function SetRecoState(NewState: DWORD): HResult; stdcall;
    function GetStatus(pStatus: Pointer): HResult; stdcall;
    function GetFormat(WaveFormatType: DWORD; pFormatId: Pointer;
      ppCoMemWFEX: Pointer): HResult; stdcall;
    function IsUISupported(pszTypeOfUI: PWideChar; pvExtraData: Pointer;
      cbExtraData: ULONG; pfSupported: PBOOL): HResult; stdcall;
    function DisplayUI(hwndParent: HWND; pszTitle: PWideChar;
      pszTypeOfUI: PWideChar; pvExtraData: Pointer;
      cbExtraData: ULONG): HResult; stdcall;
    function EmulateRecognition(pPhrase: IUnknown): HResult; stdcall;
  end;

  // ISpRecoContext -- recognition context; source of events and grammar host.
  // Inherits ISpEventSource, so SetNotifyWin32Event / GetEvents are available.
  // IID: {F740A62F-7C15-489E-8234-940A33D9272D}
  ISpRecoContext = interface(ISpEventSource)
    ['{F740A62F-7C15-489E-8234-940A33D9272D}']
    function GetRecognizer(out ppRecognizer: ISpRecognizer): HResult; stdcall;
    function CreateGrammar(ullGrammarId: UInt64;
      out ppGrammar: ISpRecoGrammar): HResult; stdcall;
    function GetStatus(pStatus: Pointer): HResult; stdcall;
    function GetMaxAlternates(pcAlternates: PULONG): HResult; stdcall;
    function SetMaxAlternates(cAlternates: ULONG): HResult; stdcall;
    function SetAudioOptions(Options: DWORD; pAudioFormatId: Pointer;
      pWaveFormatEx: Pointer): HResult; stdcall;
    function GetAudioOptions(pOptions: PDWORD; pAudioFormatId: Pointer;
      ppCoMemWFEX: Pointer): HResult; stdcall;
    function DeserializeResult(pSerializedResult: Pointer;
      out ppResult: IUnknown): HResult; stdcall;
    function Bookmark(Options: DWORD; ullStreamPosition: UInt64;
      lparamEvent: LPARAM): HResult; stdcall;
    function SetAdaptationData(pAdaptationData: PWideChar;
      cch: ULONG): HResult; stdcall;
    function Pause(dwReserved: DWORD): HResult; stdcall;
    function Resume(dwReserved: DWORD): HResult; stdcall;
    function SetVoice(pVoice: IUnknown;
      fAllowFormatChanges: BOOL): HResult; stdcall;
    function GetVoice(out ppVoice: IUnknown): HResult; stdcall;
    function SetVoicePurgeEvent(
      ullEventInterest: UInt64): HResult; stdcall;
    function GetVoicePurgeEvent(
      pullEventInterest: PUInt64): HResult; stdcall;
    function SetContextState(eContextState: DWORD): HResult; stdcall;
    function GetContextState(
      peContextState: PDWORD): HResult; stdcall;
  end;

  // ISpGrammarBuilder -- base grammar-builder interface.
  // IID: {8137828F-591A-4A42-BE58-49EA7EBAAC68}
  ISpGrammarBuilder = interface(IUnknown)
    ['{8137828F-591A-4A42-BE58-49EA7EBAAC68}']
    function ResetGrammar(NewLanguage: Word): HResult; stdcall;
    function GetRule(pszRuleName: PWideChar; dwRuleId: DWORD;
      dwAttributes: DWORD; fCreateIfNotExist: BOOL;
      out phInitialState: Pointer): HResult; stdcall;
    function ClearRule(hState: Pointer): HResult; stdcall;
    function CreateNewState(hState: Pointer;
      out phState: Pointer): HResult; stdcall;
    function AddWordTransition(hFromState, hToState: Pointer;
      psz, pszSeparators: PWideChar; eWordType: DWORD;
      Weight: Single; pPropInfo: Pointer): HResult; stdcall;
    function AddRuleTransition(hFromState, hToState, hRule: Pointer;
      Weight: Single; pPropInfo: Pointer): HResult; stdcall;
    function AddResource(hRuleState: Pointer;
      pszResourceName, pszResourceValue: PWideChar): HResult; stdcall;
    function Commit(dwReserved: DWORD): HResult; stdcall;
  end;

  // ISpRecoGrammar -- grammar object: loads dictation, sets active state.
  // IID: {2177DB29-7F45-47D0-8554-067E91C80502}
  ISpRecoGrammar = interface(ISpGrammarBuilder)
    ['{2177DB29-7F45-47D0-8554-067E91C80502}']
    function GetGrammarId(pullGrammarId: PUInt64): HResult; stdcall;
    function GetRecoContext(
      out ppRecoCtxt: ISpRecoContext): HResult; stdcall;
    function LoadCmdFromFile(pszFileName: PWideChar;
      Options: DWORD): HResult; stdcall;
    function LoadCmdFromObject(const rcid: TGUID;
      pszGrammarName: PWideChar; Options: DWORD): HResult; stdcall;
    function LoadCmdFromResource(hModule: HMODULE;
      pszResourceName, pszResourceType: PWideChar;
      wLanguage: Word; Options: DWORD): HResult; stdcall;
    function LoadCmdFromMemory(pGrammar: Pointer;
      Options: DWORD): HResult; stdcall;
    function LoadCmdFromProprietaryGrammar(const rguidParam: TGUID;
      pszStringParam: PWideChar; pvDataParam: Pointer;
      cbDataSize: ULONG; Options: DWORD): HResult; stdcall;
    function SetRuleState(pszName: PWideChar; pReserved: Pointer;
      NewState: DWORD): HResult; stdcall;
    function SetRuleIdState(ulRuleId: ULONG;
      NewState: DWORD): HResult; stdcall;
    function LoadDictation(pszTopicName: PWideChar;
      Options: DWORD): HResult; stdcall;
    function UnloadDictation: HResult; stdcall;
    function SetDictationState(NewState: DWORD): HResult; stdcall;
    function SetWordSequenceData(pText: PWideChar; cchText: ULONG;
      pInfo: Pointer): HResult; stdcall;
    function SetTextSelection(pInfo: Pointer): HResult; stdcall;
    function IsPronounceable(pszWord: PWideChar;
      pWordPronounceable: PDWORD): HResult; stdcall;
    function SetGrammarState(
      eGrammarState: DWORD): HResult; stdcall;
    function SaveCmd(pStream: IUnknown;
      ppszCoMemErrorText: Pointer): HResult; stdcall;
    function GetGrammarState(
      peGrammarState: PDWORD): HResult; stdcall;
  end;

  // ISpPhrase -- base phrase interface; provides GetText.
  // IID: {1A5C0354-B621-4B5A-8791-D306ED379E53}
  ISpPhrase = interface(IUnknown)
    ['{1A5C0354-B621-4B5A-8791-D306ED379E53}']
    function GetPhrase(out ppCoMemPhrase: Pointer): HResult; stdcall;
    function GetSerializedPhrase(
      out ppCoMemPhrase: Pointer): HResult; stdcall;
    // ulStart = ulCount = $FFFFFFFF selects the whole phrase.
    // ppszCoMemText is CoTaskMemAlloc'd; caller must CoTaskMemFree it.
    function GetText(ulStart: ULONG; ulCount: ULONG;
      fUseTextReplacements: BOOL; out ppszCoMemText: PWideChar;
      pbDisplayAttributes: PByte): HResult; stdcall;
    function Discard(dwValueTypes: DWORD): HResult; stdcall;
  end;

  // ISpRecoResult -- recognition result; inherits GetText from ISpPhrase.
  // IID: {20B053BE-E235-43CD-9A2A-8D17A48B7842}
  ISpRecoResult = interface(ISpPhrase)
    ['{20B053BE-E235-43CD-9A2A-8D17A48B7842}']
    function GetResultTimes(pTimes: Pointer): HResult; stdcall;
    function GetAlternates(ulStartElement, cElements,
      ulRequestCount: ULONG; ppPhrases: Pointer;
      pcPhrasesReturned: PULONG): HResult; stdcall;
    function GetAudio(ulStartElement, cElements: ULONG;
      out ppStream: IUnknown): HResult; stdcall;
    function SpeakAudio(ulStartElement, cElements: ULONG;
      dwFlags: DWORD; pulStreamNumber: PULONG): HResult; stdcall;
    function Serialize(
      out ppCoMemSerializedResult: Pointer): HResult; stdcall;
    function ScaleAudio(pAudioFormatId: Pointer;
      pWaveFormatEx: Pointer): HResult; stdcall;
    function GetRecoContext(
      out ppRecoContext: ISpRecoContext): HResult; stdcall;
  end;

// ============================================================================
// TSpeechTranscriber -- public engine class
// ============================================================================

type

  /// <summary>
  ///   Non-blocking SAPI speech transcriber.  Call Start to open the default
  ///   microphone, Poll from App.OnTimer to drain recognition events, Stop to
  ///   shut down.  Active is False (with LastError set) when SAPI is
  ///   unavailable -- the caller should degrade gracefully in that case.
  /// </summary>
  TSpeechTranscriber = class(TObject)
  strict private
    FActive: Boolean;
    FAudioInput: IUnknown;
    FComInited: Boolean;
    FEventHandle: THandle;
    FGrammar: ISpRecoGrammar;
    FLastError: string;
    FOnHypothesis: TProc<string>;
    FOnStatus: TProc<string>;
    FOnText: TProc<string>;
    FRecoCtx: ISpRecoContext;
    FRecognizer: ISpRecognizer;
    procedure ReleaseInterfaces;
    procedure HandleRecognitionEvent(ALParam: LPARAM; AHypothesis: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Opens the default audio input, creates the in-process recogniser,
    ///   loads the dictation grammar, and starts recognition.
    ///   On failure Active stays False and LastError is set.
    /// </summary>
    procedure Start;
    /// <summary>
    ///   Stops recognition and releases all SAPI COM interfaces.
    /// </summary>
    procedure Stop;
    /// <summary>
    ///   Polls the SAPI event queue; fires OnText / OnHypothesis for each
    ///   pending result.  Call from App.OnTimer.  No-op when not Active.
    /// </summary>
    procedure Poll;
    /// <summary>
    ///   True while the recogniser is open and active.
    /// </summary>
    property Active: Boolean read FActive;
    /// <summary>
    ///   Human-readable description of the last Start failure (empty when OK).
    /// </summary>
    property LastError: string read FLastError;
    /// <summary>
    ///   Fired when a final recognised phrase is available (the text).
    /// </summary>
    property OnText: TProc<string> read FOnText write FOnText;
    /// <summary>
    ///   Fired for partial (hypothesis) recognition results; may be nil.
    /// </summary>
    property OnHypothesis: TProc<string>
      read FOnHypothesis write FOnHypothesis;
    /// <summary>
    ///   Fired for audio-state transitions: sound start/end and interference.
    ///   The parameter is a short status string.  Pass nil to suppress.
    /// </summary>
    property OnStatus: TProc<string>
      read FOnStatus write FOnStatus;
  end;

implementation

uses
  Winapi.ActiveX;

const
  // CLSID of the in-process speech recogniser (sapi.dll).
  CLSID_SpInprocRecognizer: TGUID =
    '{41B89B6B-9399-11D2-9623-00C04F8EE628}';

  // CLSID of the default multimedia audio input object.
  // Using an explicit SpMMAudioIn instance avoids ambiguous device binding
  // when SetInput(nil) picks up an unconfigured SAPI token on some systems.
  CLSID_SpMMAudioIn: TGUID =
    '{CF3D2E50-53F2-11D2-960C-00C04F8EE628}';

  // SPEVENTENUM values for recognition and hypothesis events.
  SPEI_HYPOTHESIS  = 39;
  SPEI_RECOGNITION = 38;
  // SPEVENTENUM values for audio-state detection (non-object events).
  SPEI_SOUND_START = 35;
  SPEI_SOUND_END = 36;
  SPEI_INTERFERENCE = 44;

  // SPRULESTATE: SPRS_INACTIVE = 0, SPRS_ACTIVE = 1.
  SPRS_INACTIVE = DWORD(0);
  SPRS_ACTIVE   = DWORD(1);

  // SPRECOSTATE: SPRST_INACTIVE = 0, SPRST_ACTIVE = 1.
  SPRST_INACTIVE = DWORD(0);
  SPRST_ACTIVE = DWORD(1);

  // SPLOADOPTIONS: SPLO_STATIC = 0.
  SPLO_STATIC = DWORD(0);

  // SPET_LPARAM_IS_OBJECT: the event lParam is an AddRef'd IUnknown ptr.
  SPET_LPARAM_IS_OBJECT = Word(2);

  // Whole-phrase selector for ISpPhrase.GetText.
  SP_GETWHOLEPHRASE = ULONG($FFFFFFFF);

  // SPFEI macro: converts SPEVENTENUM value to 64-bit interest mask bit.
  function SPFEI(AEvent: Integer): UInt64; inline;
  begin
    Result := UInt64(1) shl AEvent;
  end;

{ TSpeechTranscriber }

constructor TSpeechTranscriber.Create;
begin
  inherited Create;
  // Initialize COM for this thread (MTA: no message pump needed).
  var LRes := CoInitializeEx(nil, COINIT_MULTITHREADED);
  // S_FALSE means "already initialised with the same model" -- still OK.
  FComInited := Succeeded(LRes);
end;

destructor TSpeechTranscriber.Destroy;
begin
  if FActive then
    Stop;
  ReleaseInterfaces;
  if FComInited then
    CoUninitialize;
  inherited;
end;

procedure TSpeechTranscriber.ReleaseInterfaces;
begin
  FAudioInput := nil;
  FGrammar := nil;
  FRecoCtx := nil;
  FRecognizer := nil;
  FEventHandle := 0;
end;

procedure TSpeechTranscriber.Start;
begin
  if FActive then
    Exit;
  var LRes: HResult;
  FLastError := '';

  if not FComInited then
  begin
    FLastError := 'COM initialisation failed';
    Exit;
  end;

  // Create the in-process recogniser.
  LRes := CoCreateInstance(CLSID_SpInprocRecognizer, nil,
    CLSCTX_ALL, ISpRecognizer, FRecognizer);
  if not Succeeded(LRes) then
  begin
    FLastError := Format('SpInprocRecognizer not available (0x%.8X)', [LRes]);
    Exit;
  end;

  // Bind to the default audio input using an explicit SpMMAudioIn object,
  // which avoids ambiguous device binding when the SAPI audio-input token
  // is not configured in Control Panel (common on Windows 11).
  // Falls back to SetInput(nil) if SpMMAudioIn is unavailable.
  var LCreateInput := CoCreateInstance(CLSID_SpMMAudioIn, nil,
    CLSCTX_ALL, IUnknown, FAudioInput);
  if Succeeded(LCreateInput) then
    LRes := FRecognizer.SetInput(FAudioInput, True)
  else
    LRes := FRecognizer.SetInput(nil, True);
  if not Succeeded(LRes) then
  begin
    FLastError := Format('SetInput failed (0x%.8X)', [LRes]);
    ReleaseInterfaces;
    Exit;
  end;

  // Create a recognition context.
  LRes := FRecognizer.CreateRecoContext(FRecoCtx);
  if not Succeeded(LRes) then
  begin
    FLastError := Format('CreateRecoContext failed (0x%.8X)', [LRes]);
    ReleaseInterfaces;
    Exit;
  end;

  // Use Win32 event for polling (no message pump required).
  LRes := FRecoCtx.SetNotifyWin32Event;
  if not Succeeded(LRes) then
  begin
    FLastError := Format('SetNotifyWin32Event failed (0x%.8X)', [LRes]);
    ReleaseInterfaces;
    Exit;
  end;
  FEventHandle := FRecoCtx.GetNotifyEventHandle;

  // Subscribe to recognition, hypothesis, and audio-state events.
  var LInterest :=
    SPFEI(SPEI_RECOGNITION) or SPFEI(SPEI_HYPOTHESIS) or
    SPFEI(SPEI_SOUND_START) or SPFEI(SPEI_SOUND_END) or
    SPFEI(SPEI_INTERFERENCE);
  FRecoCtx.SetInterest(LInterest, LInterest);

  // Create and load the dictation grammar.
  LRes := FRecoCtx.CreateGrammar(0, FGrammar);
  if not Succeeded(LRes) then
  begin
    FLastError := Format('CreateGrammar failed (0x%.8X)', [LRes]);
    ReleaseInterfaces;
    Exit;
  end;

  LRes := FGrammar.LoadDictation(nil, SPLO_STATIC);
  if not Succeeded(LRes) then
  begin
    FLastError := Format(
      'LoadDictation failed -- speech language pack installed? (0x%.8X)',
      [LRes]);
    ReleaseInterfaces;
    Exit;
  end;

  // Activate the grammar.
  LRes := FGrammar.SetDictationState(SPRS_ACTIVE);
  if not Succeeded(LRes) then
  begin
    FLastError := Format('SetDictationState failed (0x%.8X)', [LRes]);
    ReleaseInterfaces;
    Exit;
  end;

  // Ensure the recogniser itself is active (defensive; the default should be
  // SPRST_ACTIVE, but some systems start in inactive state).
  FRecognizer.SetRecoState(SPRST_ACTIVE);

  FActive := True;
end;

procedure TSpeechTranscriber.Stop;
begin
  if not FActive then
    Exit;
  FActive := False;

  // Deactivate grammar and recogniser before releasing.
  if Assigned(FGrammar) then
    FGrammar.SetDictationState(SPRS_INACTIVE);
  if Assigned(FRecognizer) then
    FRecognizer.SetRecoState(SPRST_INACTIVE);

  ReleaseInterfaces;
end;

procedure TSpeechTranscriber.HandleRecognitionEvent(ALParam: LPARAM;
  AHypothesis: Boolean);
begin
  // "Adopt" the AddRef'd IUnknown pointer given by SAPI in lParam without
  // calling AddRef again.  When LUnk goes out of scope at the end of this
  // procedure, Delphi's managed finalisation calls Release once, which
  // correctly balances the reference count.
  var LUnk: IUnknown;
  Pointer(LUnk) := Pointer(ALParam);
  var LResult: ISpRecoResult;
  if LUnk.QueryInterface(ISpRecoResult, LResult) = S_OK then
  begin
    var LText: PWideChar := nil;
    if LResult.GetText(SP_GETWHOLEPHRASE, SP_GETWHOLEPHRASE,
        True, LText, nil) = S_OK then
    begin
      if LText <> nil then
      begin
        var LStr := string(LText);
        CoTaskMemFree(LText);
        if AHypothesis then
        begin
          if Assigned(FOnHypothesis) then
            FOnHypothesis(LStr);
        end
        else
        begin
          if Assigned(FOnText) then
            FOnText(LStr);
        end;
      end;
    end;
  end;
  // LUnk and LResult go out of scope here; Delphi calls Release on each.
end;

procedure TSpeechTranscriber.Poll;
begin
  if not FActive then
    Exit;

  // Poll until the Win32 event is no longer signalled (no more SAPI events).
  while WaitForSingleObject(FEventHandle, 0) = WAIT_OBJECT_0 do
  begin
    var LFetched: ULONG;
    repeat
      var LEvent: TSPEVENT;
      LFetched := 0;
      if FRecoCtx.GetEvents(1, @LEvent, @LFetched) <> S_OK then
        Break;
      if LFetched = 0 then
        Break;

      if LEvent.elParamType = SPET_LPARAM_IS_OBJECT then
      begin
        if LEvent.eEventId = SPEI_RECOGNITION then
          HandleRecognitionEvent(LEvent.lParam, False)
        else if LEvent.eEventId = SPEI_HYPOTHESIS then
          HandleRecognitionEvent(LEvent.lParam, True)
        else
        begin
          // Adopt and immediately release the object for event
          // types we don't handle, so SAPI's AddRef is balanced.
          var LSkip: IUnknown;
          Pointer(LSkip) := Pointer(LEvent.lParam);
        end;
      end
      else
      begin
        // Non-object events: audio-state transitions.  Forward to OnStatus
        // so the UI can confirm that SAPI is receiving microphone audio.
        if Assigned(FOnStatus) then
        begin
          if LEvent.eEventId = SPEI_SOUND_START then
            FOnStatus('[sound]')
          else if LEvent.eEventId = SPEI_SOUND_END then
            FOnStatus('[silence]')
          else if LEvent.eEventId = SPEI_INTERFERENCE then
            FOnStatus('[interference -- background noise?]');
        end;
      end;
    until LFetched = 0;
  end;
end;

end.
