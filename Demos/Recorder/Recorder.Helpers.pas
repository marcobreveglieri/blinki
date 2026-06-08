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
{   Unit:        Recorder.Helpers.pas                            }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   RecorderDemo -- WAV header helpers, elapsed-time formatting, and PCM peak
///   calculation used by the audio capture engine.
/// </summary>
unit Recorder.Helpers;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Classes;

type

  /// <summary>
  ///   44-byte RIFF/WAVE header written at the beginning of every recorded file.
  ///   The FileSize and DataSize fields are placeholders; call PatchWavSizes
  ///   once recording is complete.
  /// </summary>
  TWavHeader = packed record
    RiffId:       array[0..3] of AnsiChar;  // "RIFF"
    FileSize:     Cardinal;                  // total byte size - 8; patched on stop
    WaveId:       array[0..3] of AnsiChar;  // "WAVE"
    FmtId:        array[0..3] of AnsiChar;  // "fmt "
    FmtSize:      Cardinal;                  // 16 for PCM
    AudioFormat:  Word;                      // 1 = PCM
    NumChannels:  Word;
    SampleRate:   Cardinal;
    ByteRate:     Cardinal;                  // SampleRate * NumChannels * BitsPerSample div 8
    BlockAlign:   Word;                      // NumChannels * BitsPerSample div 8
    BitsPerSample: Word;
    DataId:       array[0..3] of AnsiChar;  // "data"
    DataSize:     Cardinal;                  // PCM payload in bytes; patched on stop
  end;

/// <summary>
///   Writes a TWavHeader placeholder (FileSize = DataSize = 0) to AStream.
///   The stream position advances by SizeOf(TWavHeader) = 44 bytes.
/// </summary>
procedure WriteWavHeaderPlaceholder(AStream: TStream;
  ASampleRate, AChannels, ABitsPerSample: Integer);

/// <summary>
///   Seeks to the FileSize and DataSize fields and writes the correct values.
///   Must be called after all PCM data has been written to the stream.
/// </summary>
procedure PatchWavSizes(AStream: TStream; ADataBytes: Cardinal);

/// <summary>
///   Returns a "mm:ss" string for a duration given in milliseconds.
/// </summary>
function FormatElapsed(AMs: Integer): string;

/// <summary>
///   Scans AByteLen bytes of 16-bit signed PCM samples at ABuf and returns the
///   normalised peak amplitude in [0.0, 1.0].
/// </summary>
function PeakOfPcm16(const ABuf; AByteLen: Integer): Double;

/// <summary>
///   Splits AText into wrapped lines of at most AMaxWidth characters using
///   greedy word-wrap.  Returns at least one element even for empty input.
/// </summary>
function WrapWords(const AText: string; AMaxWidth: Integer): TArray<string>;

implementation

uses
  Blinki.Core.Ansi,
  System.SysUtils;

function WrapWords(const AText: string; AMaxWidth: Integer): TArray<string>;
begin
  // Delegate to the canonical framework implementation.
  Result := TTuiAnsi.WrapText(AText, AMaxWidth);
end;

procedure WriteWavHeaderPlaceholder(AStream: TStream;
  ASampleRate, AChannels, ABitsPerSample: Integer);
begin
  var LHdr: TWavHeader;
  LHdr.RiffId := 'RIFF';
  LHdr.FileSize := 0;
  LHdr.WaveId := 'WAVE';
  LHdr.FmtId := 'fmt ';
  LHdr.FmtSize := 16;
  LHdr.AudioFormat := 1;
  LHdr.NumChannels := AChannels;
  LHdr.SampleRate := ASampleRate;
  LHdr.BitsPerSample := ABitsPerSample;
  LHdr.BlockAlign := AChannels * ABitsPerSample div 8;
  LHdr.ByteRate := ASampleRate * LHdr.BlockAlign;
  LHdr.DataId := 'data';
  LHdr.DataSize := 0;
  AStream.WriteBuffer(LHdr, SizeOf(LHdr));
end;

procedure PatchWavSizes(AStream: TStream; ADataBytes: Cardinal);
begin
  // RIFF payload = 4 (WAVE) + 8+16 (fmt chunk) + 8 (data header) + data
  var LFileSize := 36 + ADataBytes;
  AStream.Position := 4;
  AStream.WriteBuffer(LFileSize, SizeOf(LFileSize));
  AStream.Position := 40;
  AStream.WriteBuffer(ADataBytes, SizeOf(ADataBytes));
end;

function FormatElapsed(AMs: Integer): string;
begin
  var LTotalSec := AMs div 1000;
  Result := Format('%02d:%02d', [LTotalSec div 60, LTotalSec mod 60]);
end;

function PeakOfPcm16(const ABuf; AByteLen: Integer): Double;
begin
  var LSamples := PSmallInt(@ABuf);
  var LCount := AByteLen div 2;
  var LPeak := 0;
  for var LI := 0 to LCount - 1 do
  begin
    var LAbsVal := Abs(Integer(LSamples^));
    if LAbsVal > LPeak then
      LPeak := LAbsVal;
    Inc(LSamples);
  end;
  if LCount = 0 then
    Result := 0.0
  else
    Result := LPeak / 32768.0;
end;

end.
