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
{   Unit:        Recorder.dpr                                    }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   RecorderDemo -- proof-of-concept demo for microphone capture and
///   on-device speech transcription inside a Blinki TUI.
///
///   Features:
///     - Custom VU meter (TAudioMeterView) with peak-hold.
///     - ASCII microphone illustration (TMicView) with reactive sound arcs.
///     - Non-blocking PCM capture (TAudioCapture) via waveIn -- saves WAV.
///     - Sparkline waveform (TTuiSparkline).
///     - SAPI 5 dictation transcription (TSpeechTranscriber) polled from
///       OnTimer via Win32 event -- no threads, no message pump.
///       NOTE: COM is used by the SAPI layer (CoInitializeEx/CoUninitialize).
///       Graceful degradation: recording works even without a speech
///       language pack (the Transcription box shows an informative hint).
///
///   Keys:
///     R         -- toggle recording start / stop
///     T         -- toggle Dark / Light theme
///     Q / Esc   -- quit (stops any active recording first)
///
///   Widget tree:
///     LRoot (TTuiVStack)
///       LRecBox  (TTuiBox "Recorder")      Fixed(7)  bsRounded
///         LRecStack (TTuiVStack)
///           LStatusLabel (TTuiLabel)        Fixed(1)
///           LTimerLabel  (TTuiLabel)        Fixed(1)
///           LMeterRow    (TTuiHStack)       Fill(1)
///             LMic         (TMicView)       Fixed(12)
///             LMeter       (TAudioMeterView) Fill(1)
///       LWaveBox (TTuiBox "Waveform")       Fill(1)   bsSingle
///         LSpark (TTuiSparkline)
///       LTransBox (TTuiBox "Transcription") Fill(2)   bsSingle
///         LTranscript (TTranscriptView)
///       LHintBar (TTuiLabel)                Fixed(1)
/// </summary>
program Recorder;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Blinki.Core.Ansi,
  Blinki.Core.App,
  Blinki.Core.Event,
  Blinki.Core.Geometry,
  Blinki.Core.Input,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  Blinki.Layout.Stack,
  Blinki.Widgets.Box,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Sparkline,
  Recorder.Capture in 'Recorder.Capture.pas',
  Recorder.Consts in 'Recorder.Consts.pas',
  Recorder.Helpers in 'Recorder.Helpers.pas',
  Recorder.Sapi in 'Recorder.Sapi.pas',
  Recorder.View in 'Recorder.View.pas';

// ============================================================================
// Main body
// ============================================================================

begin
  ReportMemoryLeaksOnShutdown := True;
  var LDark := True;
  var LCapture    := TAudioCapture.Create;
  var LTranscriber := TSpeechTranscriber.Create;
  try
    var LApp  := TTuiApp.Create;
    var LRoot := TTuiVStack.Create;
    try

      // ---- Recorder box (Fixed 7: 2 border + 1 status + 1 timer + 3 HStack) ----
      var LRecBox := TTuiBox.Create(LRoot);
      LRecBox.Title := ' Recorder ';
      LRecBox.BoxStyle := bsRounded;
      LRecBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(7);

      var LRecStack := TTuiVStack.Create(LRecBox);

      var LStatusLabel := TTuiLabel.Create(LRecStack);
      LStatusLabel.Text := CStatusIdle;
      LStatusLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      var LTimerLabel := TTuiLabel.Create(LRecStack);
      LTimerLabel.Text := FormatElapsed(0);
      LTimerLabel.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      // HStack: mic illustration (Fixed 12) + VU meter (Fill 1)
      var LMeterRow := TTuiHStack.Create(LRecStack);

      var LMic := TMicView.Create(LMeterRow);
      LMic.LayoutConstraint := TTuiLayoutConstraint.Fixed(12);

      var LMeter := TAudioMeterView.Create(LMeterRow);
      // LMeter uses default Fill(1)

      // ---- Waveform box ----
      var LWaveBox := TTuiBox.Create(LRoot);
      LWaveBox.Title := ' Waveform ';
      LWaveBox.BoxStyle := bsSingle;
      LWaveBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      var LSpark := TTuiSparkline.Create(LWaveBox);
      LSpark.AutoScale := False;
      LSpark.MinValue := 0.0;
      LSpark.MaxValue := 1.0;
      LSpark.MaxPoints := 120;

      // ---- Transcription box ----
      var LTransBox := TTuiBox.Create(LRoot);
      LTransBox.Title := ' Transcription ';
      LTransBox.BoxStyle := bsSingle;
      LTransBox.LayoutConstraint := TTuiLayoutConstraint.Fill(2);

      var LTranscript := TTranscriptView.Create(LTransBox);

      // ---- Hint bar ----
      var LHintBar := TTuiLabel.Create(LRoot);
      LHintBar.Text := CHintIdle;
      LHintBar.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      // ---- Wire recording-complete hook ----
      LCapture.OnRecordingComplete := procedure(AWavPath: string)
      begin
        LStatusLabel.Text := CStatusIdle;
        LTimerLabel.Text  := FormatElapsed(0);
        LMeter.Level := 0;
        LMic.Active  := False;
        LMic.Level   := 0;
        LHintBar.Text := CHintSaved + AWavPath + '  |  R new recording  Q quit';
      end;

      // ---- Wire transcription hooks ----
      LTranscriber.OnText := procedure(AText: string)
      begin
        LTranscript.SetHypothesis('');
        LTranscript.AppendText(AText);
      end;
      LTranscriber.OnHypothesis := procedure(AText: string)
      begin
        LTranscript.SetHypothesis(AText);
      end;
      LTranscriber.OnStatus := procedure(AStatus: string)
      begin
        // Show audio-state transitions (sound start/end, interference) as a
        // transient hypothesis line -- dim italic, not persisted in the log.
        LTranscript.SetHypothesis(AStatus);
      end;

      // ---- Timer: poll audio and SAPI engines, update UI ----
      LApp.OnTimer := procedure(AElapsedMs: Integer)
      begin
        LCapture.Poll;
        LTranscriber.Poll;
        if LCapture.Recording then
        begin
          LMeter.Level := LCapture.Level;
          LMic.Level   := LCapture.Level;
          LSpark.AddPoint(LCapture.Level);
          LTimerLabel.Text := FormatElapsed(LCapture.ElapsedMs);
        end;
      end;

      // ---- Global key handling ----
      LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        case AKey.Code of
          kcEscape:
          begin
            if LCapture.Recording then
              LCapture.Stop;
            if LTranscriber.Active then
              LTranscriber.Stop;
            LApp.Quit;
          end;
          kcChar:
            case UpCase(AKey.Character) of
              'Q':
              begin
                if LCapture.Recording then
                  LCapture.Stop;
                if LTranscriber.Active then
                  LTranscriber.Stop;
                LApp.Quit;
              end;
              'R':
              begin
                if LCapture.Recording then
                begin
                  LCapture.Stop;
                  if LTranscriber.Active then
                    LTranscriber.Stop;
                end
                else
                begin
                  LSpark.Clear;
                  LTranscript.SetHypothesis('');
                  LCapture.Start(CDefaultWavFile);
                  if LCapture.Recording then
                  begin
                    LStatusLabel.Text := CStatusRec;
                    LTimerLabel.Text  := FormatElapsed(0);
                    LMic.Active := True;
                    // Start SAPI in parallel; degrade silently on failure.
                    LTranscriber.Start;
                    if LTranscriber.Active then
                      LTranscript.AppendText(CTranscriptReady)
                    else
                      LTranscript.AppendText(
                        CTranscriptNoSapi + LTranscriber.LastError + ')');
                    LHintBar.Text := CHintRec;
                  end
                  else
                    LHintBar.Text := ' Error: ' + LCapture.LastError;
                end;
              end;
              'T':
              begin
                LDark := not LDark;
                if LDark then
                  LApp.Theme := TTuiTheme.Dark
                else
                  LApp.Theme := TTuiTheme.Light;
              end;
            end;
        end;
      end;

      // ---- Set initial transcription hint ----
      LTranscript.AppendText(CTranscriptIdle);

      // ---- Start ----
      LApp.SetRoot(LRoot);
      LApp.Run;

    finally
      LApp.Free;
    end;
  finally
    LTranscriber.Free;
    LCapture.Free;
  end;
end.
