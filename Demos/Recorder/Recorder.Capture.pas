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
{   Unit:        Recorder.Capture.pas                            }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   RecorderDemo -- non-blocking microphone capture engine using the Windows
///   waveIn API (winmm). Buffers are polled from the Blinki OnTimer handler
///   (no threads, no COM). PCM audio is written to a WAV file in real time.
///
///   Usage:
///     LCapture := TAudioCapture.Create;
///     LCapture.OnRecordingComplete := procedure(AWavPath: string) begin ... end;
///     LCapture.Start('recording.wav');       // from a key handler
///     // in App.OnTimer: LCapture.Poll;
///     LCapture.Stop;                         // from a key handler
///     LCapture.Free;
/// </summary>
unit Recorder.Capture;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Classes,
  System.SysUtils,
  Winapi.MMSystem,
  Recorder.Consts;

type

  /// <summary>
  ///   Raised when a fatal audio operation fails during Start.
  /// </summary>
  EAudioCapture = class(Exception);

  /// <summary>
  ///   Non-blocking microphone recorder using waveIn with CALLBACK_NULL polling.
  ///   Call Poll from the application OnTimer to process completed buffers.
  ///   Start opens the device and begins recording; Stop flushes, patches the
  ///   WAV header, and fires OnRecordingComplete.
  /// </summary>
  TAudioCapture = class(TObject)
  strict private
    FBuffers: array[0..CBufferCount - 1] of Pointer;
    FDataBytes: Cardinal;
    FElapsedMs: Integer;
    FHeaders: array[0..CBufferCount - 1] of TWaveHdr;
    FLastError: string;
    FLevel: Double;
    FOnLevel: TProc<Double>;
    FOnRecordingComplete: TProc<string>;
    FRecording: Boolean;
    FStream: TFileStream;
    FWaveIn: HWAVEIN;
    FWavPath: string;
    procedure AllocBuffers;
    procedure FreeBuffers;
    procedure PrepareAndQueue(AIndex: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Polls completed waveIn buffers, computes the peak level, appends PCM
    ///   data to the WAV stream, and requeues each buffer. Call this from the
    ///   application OnTimer handler (every ~50 ms is more than sufficient).
    ///   Does nothing when not recording.
    /// </summary>
    procedure Poll;
    /// <summary>
    ///   Opens the default microphone and starts recording to AWavPath.
    ///   On failure (no microphone, access denied, etc.) Recording stays False
    ///   and LastError contains a description.
    /// </summary>
    procedure Start(const AWavPath: string);
    /// <summary>
    ///   Stops the capture, drains remaining buffers, patches the WAV header
    ///   sizes, closes the file, and fires OnRecordingComplete.
    /// </summary>
    procedure Stop;
    /// <summary>
    ///   Elapsed recording time in milliseconds, derived from bytes written.
    /// </summary>
    property ElapsedMs: Integer read FElapsedMs;
    /// <summary>
    ///   Human-readable description of the last Start failure (empty when OK).
    /// </summary>
    property LastError: string read FLastError;
    /// <summary>
    ///   Normalised peak amplitude [0.0, 1.0] of the last processed buffer.
    /// </summary>
    property Level: Double read FLevel;
    /// <summary>
    ///   Fired after each buffer is processed with the current Level value.
    /// </summary>
    property OnLevel: TProc<Double> read FOnLevel write FOnLevel;
    /// <summary>
    ///   Fired by Stop when the WAV file has been written and closed.
    ///   The parameter is the full path that was passed to Start.
    /// </summary>
    property OnRecordingComplete: TProc<string>
      read FOnRecordingComplete write FOnRecordingComplete;
    /// <summary>
    ///   True while the device is open and capturing audio.
    /// </summary>
    property Recording: Boolean read FRecording;
  end;

implementation

uses
  Recorder.Helpers;

const

  // Bytes per buffer: 16000 Hz * 1 ch * 2 bytes * 100 ms / 1000 = 3200 bytes
  CBufferBytes = CSampleRate * CChannels * (CBitsPerSample div 8) * CBufferMs div 1000;

{ TAudioCapture }

constructor TAudioCapture.Create;
begin
  inherited Create;
end;

destructor TAudioCapture.Destroy;
begin
  if FRecording then
    Stop;
  inherited;
end;

procedure TAudioCapture.AllocBuffers;
begin
  for var LI := 0 to CBufferCount - 1 do
    GetMem(FBuffers[LI], CBufferBytes);
end;

procedure TAudioCapture.FreeBuffers;
begin
  for var LI := 0 to CBufferCount - 1 do
    if Assigned(FBuffers[LI]) then
    begin
      FreeMem(FBuffers[LI]);
      FBuffers[LI] := nil;
    end;
end;

procedure TAudioCapture.PrepareAndQueue(AIndex: Integer);
begin
  FillChar(FHeaders[AIndex], SizeOf(TWaveHdr), 0);
  FHeaders[AIndex].lpData := FBuffers[AIndex];
  FHeaders[AIndex].dwBufferLength := CBufferBytes;
  waveInPrepareHeader(FWaveIn, @FHeaders[AIndex], SizeOf(TWaveHdr));
  waveInAddBuffer(FWaveIn, @FHeaders[AIndex], SizeOf(TWaveHdr));
end;

procedure TAudioCapture.Start(const AWavPath: string);
begin
  if FRecording then
    Exit;
  FLastError := '';
  FLevel := 0;
  FElapsedMs := 0;
  FDataBytes := 0;
  FWavPath := AWavPath;

  var LFmt: TWaveFormatEx;
  FillChar(LFmt, SizeOf(LFmt), 0);
  LFmt.wFormatTag := WAVE_FORMAT_PCM;
  LFmt.nChannels := CChannels;
  LFmt.nSamplesPerSec := CSampleRate;
  LFmt.wBitsPerSample := CBitsPerSample;
  LFmt.nBlockAlign := LFmt.nChannels * LFmt.wBitsPerSample div 8;
  LFmt.nAvgBytesPerSec := LFmt.nSamplesPerSec * LFmt.nBlockAlign;
  LFmt.cbSize := 0;

  // CALLBACK_NULL (0): driver marks WHDR_DONE without any callback;
  // we poll the flag in Poll.
  var LRes := waveInOpen(@FWaveIn, WAVE_MAPPER, @LFmt, 0, 0, 0);
  if LRes <> MMSYSERR_NOERROR then
  begin
    FLastError := Format('Microphone not available (waveInOpen error %d)', [LRes]);
    Exit;
  end;

  try
    AllocBuffers;
    FStream := TFileStream.Create(AWavPath, fmCreate);
    WriteWavHeaderPlaceholder(FStream, CSampleRate, CChannels, CBitsPerSample);
    for var LI := 0 to CBufferCount - 1 do
      PrepareAndQueue(LI);
    waveInStart(FWaveIn);
    FRecording := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FreeAndNil(FStream);
      FreeBuffers;
      waveInClose(FWaveIn);
      FWaveIn := 0;
    end;
  end;
end;

procedure TAudioCapture.Poll;
begin
  if not FRecording then
    Exit;
  for var LI := 0 to CBufferCount - 1 do
  begin
    if (FHeaders[LI].dwFlags and WHDR_DONE) = 0 then
      Continue;
    var LBytes := FHeaders[LI].dwBytesRecorded;
    if LBytes > 0 then
    begin
      FLevel := PeakOfPcm16(FBuffers[LI]^, LBytes);
      FStream.WriteBuffer(FBuffers[LI]^, LBytes);
      Inc(FDataBytes, LBytes);
      FElapsedMs := Integer(FDataBytes) * 1000
        div (CSampleRate * CChannels * (CBitsPerSample div 8));
      if Assigned(FOnLevel) then
        FOnLevel(FLevel);
    end;
    waveInUnprepareHeader(FWaveIn, @FHeaders[LI], SizeOf(TWaveHdr));
    PrepareAndQueue(LI);
  end;
end;

procedure TAudioCapture.Stop;
begin
  if not FRecording then
    Exit;
  FRecording := False;
  waveInStop(FWaveIn);
  waveInReset(FWaveIn);
  // After waveInReset all queued buffers are returned with WHDR_DONE;
  // drain data and unprepare every header.
  for var LI := 0 to CBufferCount - 1 do
  begin
    if (FHeaders[LI].dwFlags and WHDR_DONE) <> 0 then
    begin
      var LBytes := FHeaders[LI].dwBytesRecorded;
      if LBytes > 0 then
      begin
        FStream.WriteBuffer(FBuffers[LI]^, LBytes);
        Inc(FDataBytes, LBytes);
      end;
    end;
    if (FHeaders[LI].dwFlags and WHDR_PREPARED) <> 0 then
      waveInUnprepareHeader(FWaveIn, @FHeaders[LI], SizeOf(TWaveHdr));
  end;
  waveInClose(FWaveIn);
  FWaveIn := 0;
  PatchWavSizes(FStream, FDataBytes);
  FreeAndNil(FStream);
  FreeBuffers;
  FLevel := 0;
  if Assigned(FOnRecordingComplete) then
    FOnRecordingComplete(FWavPath);
end;

end.
