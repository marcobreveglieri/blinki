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
{   Unit:        Recorder.Consts.pas                             }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   RecorderDemo -- constants for the audio capture format and UI strings.
/// </summary>
unit Recorder.Consts;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

const

  // Audio capture format
  CBufferCount = 4;
  CBufferMs = 100;
  CBitsPerSample = 16;
  CChannels = 1;
  CDefaultWavFile = 'recording.wav';
  CSampleRate = 16000;

  // UI strings -- recording controls
  CHintIdle  = ' R start recording  T theme  Q quit';
  CHintRec   = ' R stop recording   T theme  Q quit';
  CHintSaved = ' Saved: ';
  CStatusIdle = 'Ready -- press R to start recording';
  CStatusRec  = #$25CF' REC';   // ● REC

  // UI strings -- transcription status
  CTranscriptIdle   = '(no transcription -- press R to start recording)';
  CTranscriptNoSapi = '(speech recognition unavailable: ';
  CTranscriptReady  = '(listening... speak now)';

implementation

end.
