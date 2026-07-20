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
{   Unit:        Scaffold.Helpers.pas                            }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Sequential CLI console writer for the ScaffoldDemo project.
///   TCliConsole wraps an ITuiConsoleBackend and provides high-level
///   methods for styled line output, animated spinner tasks, inline
///   interactive prompts (text, single-select, multi-select), and
///   the install-log script (banner, next-steps box).
///   Intended for use after TTuiApp.Run exits (i.e. outside the
///   alternate buffer), so output persists in the terminal scrollback.
/// </summary>
unit Scaffold.Helpers;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Blinki.Core.Console,
  Blinki.Core.Event,
  Blinki.Core.Input,
  Blinki.Core.Style,
  Scaffold.Model;

type

{ TCliConsole }

  /// <summary>
  ///   Wraps an ITuiConsoleBackend and writes styled CLI output without
  ///   entering the alternate buffer. Provides info/ok/warn/error lines,
  ///   animated spinner tasks (inline cursor overwrite via CR + EL),
  ///   error-with-recovery tasks, interactive inline prompts for text
  ///   input and option selection, a project banner, and a next-steps
  ///   box. Spinner frame pacing uses ITuiConsoleBackend.TryReadEvent
  ///   so pressing any key skips ahead.
  /// </summary>
  TCliConsole = class
  strict private
    FAborted: Boolean;
    FBackend: ITuiConsoleBackend;
    FSpinnerIndex: Integer;
    /// <summary>
    ///   Emits a single collapsed-prompt summary line after a prompt is
    ///   confirmed: green check mark, dim label, middle dot, and value.
    /// </summary>
    procedure CollapsePrompt(const ALabel, AValue: string);
    /// <summary>
    ///   Renders one option row for PromptMultiSelect in place.
    ///   Starts with CR + ClearLineToEnd; ends with CRLF.
    ///   The active row shows the pointer and a filled/empty bullet;
    ///   inactive rows show only the bullet.
    /// </summary>
    procedure DrawMultiSelectRow(AIndex, ASelected: Integer;
      const AText: string; AIsChecked: Boolean);
    /// <summary>
    ///   Renders one option row for PromptSelect in place.
    ///   Starts with CR + ClearLineToEnd; ends with CRLF.
    ///   The active row is highlighted; others are dimmed.
    /// </summary>
    procedure DrawSelectRow(AIndex, ASelected: Integer; const AText: string);
    procedure DoWrite(const AText: string);
    procedure DoWriteLn(const AText: string);
    procedure DoWriteStyled(const AText: string; const AStyle: TTuiStyle);
    procedure DoWriteStyledLn(const AText: string; const AStyle: TTuiStyle);
    procedure DoPause(AMs: Integer);
    procedure DrawSpinnerFrame(const ALabel: string);
    procedure FinishSpinner(const AIcon, ALabel: string; const AStyle: TTuiStyle);
    /// <summary>
    ///   Blocks until a key-press event arrives.
    ///   Polls TryReadEvent(50 ms) in a loop, discarding non-key events.
    /// </summary>
    function ReadKey: TTuiKeyEvent;
    function StyleDim: TTuiStyle;
    function StyleError: TTuiStyle;
    function StyleInfo: TTuiStyle;
    /// <summary>
    ///   Cyan + bold style used for active prompt icons and the selection
    ///   pointer.
    /// </summary>
    function StylePromptActive: TTuiStyle;
    function StyleSuccess: TTuiStyle;
    function StyleTitle: TTuiStyle;
    function StyleWarning: TTuiStyle;
  public
    /// <summary>
    ///   Creates the writer. ABackend must already be Open; the caller
    ///   retains ownership of the backend and must call Close after use.
    /// </summary>
    constructor Create(const ABackend: ITuiConsoleBackend);
    /// <summary>
    ///   Returns True when the most recent prompt was dismissed with Escape.
    ///   Reset to False at the start of each new prompt call.
    /// </summary>
    function Aborted: Boolean;
    /// <summary>
    ///   Writes a blank line.
    /// </summary>
    procedure Blank;
    /// <summary>
    ///   Writes a plain unstyled text line.
    /// </summary>
    procedure Line(const AText: string);
    /// <summary>
    ///   Writes a horizontal rule (dim, 60 chars wide).
    /// </summary>
    procedure Rule;
    /// <summary>
    ///   Writes an info line: blue ℹ icon + text.
    /// </summary>
    procedure Info(const AText: string);
    /// <summary>
    ///   Writes a success line: green ✔ icon + text.
    /// </summary>
    procedure Ok(const AText: string);
    /// <summary>
    ///   Writes a warning line: yellow ⚠ icon + text.
    /// </summary>
    procedure Warn(const AText: string);
    /// <summary>
    ///   Writes an error line: red ✖ icon + text.
    /// </summary>
    procedure Err(const AText: string);
    /// <summary>
    ///   Writes a neutral note line: dim ◆ icon + text.
    /// </summary>
    procedure Note(const AText: string);
    /// <summary>
    ///   Shows a multi-select checklist prompt navigable with the arrow
    ///   keys. Space toggles the item under the cursor; Enter confirms.
    ///   The option block is redrawn in place on each navigation step.
    ///   On confirmation the block collapses to a single summary line.
    ///   Returns a Boolean array parallel to AOptions indicating which
    ///   items are selected. Sets Aborted = True if Escape is pressed.
    /// </summary>
    function PromptMultiSelect(const ALabel: string;
      const AOptions: array of string;
      const ADefaults: array of Boolean): TArray<Boolean>;
    /// <summary>
    ///   Shows a single-select prompt navigable with the arrow keys.
    ///   Enter confirms; the option block collapses to a summary line.
    ///   Returns the 0-based index of the confirmed choice.
    ///   Sets Aborted = True if Escape is pressed.
    /// </summary>
    function PromptSelect(const ALabel: string;
      const AOptions: array of string; ADefault: Integer): Integer;
    /// <summary>
    ///   Shows an editable text input prompt. Backspace deletes, Enter
    ///   confirms. An empty value falls back to ADefault. On confirmation
    ///   the two-line prompt collapses to a single summary line.
    ///   Sets Aborted = True if Escape is pressed.
    /// </summary>
    function PromptText(const ALabel, ADefault, APlaceholder: string): string;
    /// <summary>
    ///   Simulates a task with a spinning Braille indicator.
    ///   After ADurationMs elapses (or a key is pressed), overwrites
    ///   the spinner line with a green ✔ check mark.
    /// </summary>
    procedure RunTask(const ALabel: string; ADurationMs: Integer);
    /// <summary>
    ///   Simulates a task that fails after ADurationMs ms and then
    ///   recovers. Sequence: spin → red ✖ + error detail → retry spin
    ///   → green ✔. Demonstrates error + recovery in the install log.
    /// </summary>
    procedure RunTaskWithRecovery(const ALabel, AErrorMsg, ARetryLabel: string;
      ADurationMs, AErrorPauseMs, ARetryMs: Integer);
    /// <summary>
    ///   Writes the create-blinki-app banner with name and version.
    /// </summary>
    procedure Banner;
    /// <summary>
    ///   Writes a bordered next-steps box with the first commands to
    ///   run after a successful scaffold.
    /// </summary>
    procedure NextSteps(const AConfig: TScaffoldConfig);
    /// <summary>
    ///   Writes a dim prompt line and blocks until any key is pressed.
    ///   Used as the final "press a key to exit" gate.
    /// </summary>
    procedure WaitForKey(const APrompt: string);
  end;

implementation

uses
  System.SysUtils,
  Blinki.Core.Ansi,
  Blinki.Widgets.Spinner,
  Scaffold.Consts;

{ TCliConsole — private style builders }

function TCliConsole.StyleDim: TTuiStyle;
begin
  Result := TTuiStyle.Create(TTuiColors.BrightBlack, TTuiColor.Default);
end;

function TCliConsole.StyleError: TTuiStyle;
begin
  Result := TTuiStyle.Create(TTuiColors.Red, TTuiColor.Default, [taBold]);
end;

function TCliConsole.StyleInfo: TTuiStyle;
begin
  Result := TTuiStyle.Create(TTuiColors.Cyan, TTuiColor.Default);
end;

function TCliConsole.StylePromptActive: TTuiStyle;
begin
  Result := TTuiStyle.Create(TTuiColors.Cyan, TTuiColor.Default, [taBold]);
end;

function TCliConsole.StyleSuccess: TTuiStyle;
begin
  Result := TTuiStyle.Create(TTuiColors.Green, TTuiColor.Default, [taBold]);
end;

function TCliConsole.StyleTitle: TTuiStyle;
begin
  Result := TTuiStyle.Create(TTuiColors.BrightWhite, TTuiColor.Default, [taBold]);
end;

function TCliConsole.StyleWarning: TTuiStyle;
begin
  Result := TTuiStyle.Create(TTuiColors.Yellow, TTuiColor.Default);
end;

{ TCliConsole — private helpers }

procedure TCliConsole.CollapsePrompt(const ALabel, AValue: string);
begin
  FBackend.Write(
    TTuiAnsi.ApplyStyle(StyleSuccess) + CIconOk + '  ' + TTuiAnsi.Reset +
    TTuiAnsi.ApplyStyle(StyleDim) + ALabel + '  ' + #$00B7 + '  ' + TTuiAnsi.Reset +
    AValue + #13#10
  );
end;

procedure TCliConsole.DrawMultiSelectRow(AIndex, ASelected: Integer;
  const AText: string; AIsChecked: Boolean);
begin
  FBackend.Write(#13 + TTuiAnsi.ClearLineToEnd);
  if AIndex = ASelected then
  begin
    if AIsChecked then
      FBackend.Write(
        TTuiAnsi.ApplyStyle(StylePromptActive) + '  ' + CIconPointer + ' ' +
        TTuiAnsi.Reset +
        TTuiAnsi.ApplyStyle(StyleSuccess) + CRadioOn + ' ' + TTuiAnsi.Reset +
        TTuiAnsi.ApplyStyle(StyleTitle) + AText + TTuiAnsi.Reset + #13#10
      )
    else
      FBackend.Write(
        TTuiAnsi.ApplyStyle(StylePromptActive) + '  ' + CIconPointer + ' ' +
        TTuiAnsi.Reset +
        TTuiAnsi.ApplyStyle(StyleDim) + CRadioOff + ' ' + AText +
        TTuiAnsi.Reset + #13#10
      );
  end
  else
  begin
    if AIsChecked then
      FBackend.Write(
        TTuiAnsi.ApplyStyle(StyleSuccess) + '    ' + CRadioOn + ' ' +
        TTuiAnsi.Reset + AText + #13#10
      )
    else
      FBackend.Write(
        TTuiAnsi.ApplyStyle(StyleDim) + '    ' + CRadioOff + ' ' + AText +
        TTuiAnsi.Reset + #13#10
      );
  end;
end;

procedure TCliConsole.DrawSelectRow(AIndex, ASelected: Integer;
  const AText: string);
begin
  FBackend.Write(#13 + TTuiAnsi.ClearLineToEnd);
  if AIndex = ASelected then
    FBackend.Write(
      TTuiAnsi.ApplyStyle(StylePromptActive) + '  ' + CIconPointer + ' ' +
      CRadioOn + ' ' + TTuiAnsi.Reset +
      TTuiAnsi.ApplyStyle(StyleTitle) + AText + TTuiAnsi.Reset + #13#10
    )
  else
    FBackend.Write(
      TTuiAnsi.ApplyStyle(StyleDim) + '    ' + CRadioOff + ' ' + AText +
      TTuiAnsi.Reset + #13#10
    );
end;

{ TCliConsole — private I/O helpers }

procedure TCliConsole.DoWrite(const AText: string);
begin
  FBackend.Write(AText);
end;

procedure TCliConsole.DoWriteLn(const AText: string);
begin
  FBackend.Write(AText + #13#10);
end;

procedure TCliConsole.DoWriteStyled(const AText: string; const AStyle: TTuiStyle);
begin
  FBackend.Write(TTuiAnsi.ApplyStyle(AStyle) + AText + TTuiAnsi.Reset);
end;

procedure TCliConsole.DoWriteStyledLn(const AText: string; const AStyle: TTuiStyle);
begin
  FBackend.Write(TTuiAnsi.ApplyStyle(AStyle) + AText + TTuiAnsi.Reset + #13#10);
end;

procedure TCliConsole.DoPause(AMs: Integer);
begin
  var LEvent: TTuiEvent;
  FBackend.TryReadEvent(AMs, LEvent);
end;

procedure TCliConsole.DrawSpinnerFrame(const ALabel: string);
begin
  FBackend.Write(
    #13 + TTuiAnsi.ClearLineToEnd +
    TTuiAnsi.ApplyStyle(StyleInfo) +
    CTuiSpinnerDotsFrames[FSpinnerIndex] +
    TTuiAnsi.Reset +
    '  ' + ALabel
  );
end;

procedure TCliConsole.FinishSpinner(const AIcon, ALabel: string;
  const AStyle: TTuiStyle);
begin
  FBackend.Write(
    #13 + TTuiAnsi.ClearLineToEnd +
    TTuiAnsi.ApplyStyle(AStyle) + AIcon + TTuiAnsi.Reset +
    '  ' + ALabel + #13#10
  );
end;

function TCliConsole.ReadKey: TTuiKeyEvent;
begin
  var LEvent: TTuiEvent;
  repeat
  until FBackend.TryReadEvent(50, LEvent) and (LEvent.Kind = ekKey);
  Result := LEvent.Key;
end;

{ TCliConsole }

constructor TCliConsole.Create(const ABackend: ITuiConsoleBackend);
begin
  inherited Create;
  FBackend := ABackend;
end;

function TCliConsole.Aborted: Boolean;
begin
  Result := FAborted;
end;

procedure TCliConsole.Blank;
begin
  DoWriteLn('');
end;

procedure TCliConsole.Line(const AText: string);
begin
  DoWriteLn(AText);
end;

procedure TCliConsole.Rule;
begin
  var LLine := '';
  for var LI := 1 to 60 do
    LLine := LLine + #$2500;
  DoWriteStyledLn(LLine, StyleDim);
end;

procedure TCliConsole.Info(const AText: string);
begin
  DoWriteStyled(CIconInfo + '  ', StyleInfo);
  DoWriteLn(AText);
end;

procedure TCliConsole.Ok(const AText: string);
begin
  DoWriteStyled(CIconOk + '  ', StyleSuccess);
  DoWriteLn(AText);
end;

procedure TCliConsole.Warn(const AText: string);
begin
  DoWriteStyled(CIconWarn + '  ', StyleWarning);
  DoWriteLn(AText);
end;

procedure TCliConsole.Err(const AText: string);
begin
  DoWriteStyled(CIconErr + '  ', StyleError);
  DoWriteLn(AText);
end;

procedure TCliConsole.Note(const AText: string);
begin
  DoWriteStyled(CIconPrompt + '  ', StyleDim);
  DoWriteLn(AText);
end;

function TCliConsole.PromptMultiSelect(const ALabel: string;
  const AOptions: array of string;
  const ADefaults: array of Boolean): TArray<Boolean>;
begin
  var LCount := Length(AOptions);
  if LCount = 0 then
    Exit;
  var LIndex := 0;
  FAborted := False;
  SetLength(Result, LCount);
  for var LI := 0 to LCount - 1 do
  begin
    if LI < Length(ADefaults) then
      Result[LI] := ADefaults[LI]
    else
      Result[LI] := False;
  end;
  // Header line
  FBackend.Write(
    TTuiAnsi.ApplyStyle(StylePromptActive) + CIconPrompt + '  ' + TTuiAnsi.Reset +
    TTuiAnsi.ApplyStyle(StyleTitle) + ALabel + TTuiAnsi.Reset + #13#10
  );
  // Hint line (static; included in collapse row count)
  FBackend.Write(
    TTuiAnsi.ApplyStyle(StyleDim) +
    '  Spazio: seleziona  ' + #$00B7 + '  ' + #$2191 + #$2193 + ': naviga  ' +
    #$00B7 + '  Invio: conferma' +
    TTuiAnsi.Reset + #13#10
  );
  // Initial option rows
  for var LI := 0 to LCount - 1 do
    DrawMultiSelectRow(LI, LIndex, AOptions[LI], Result[LI]);
  // Navigation / toggle loop
  while True do
  begin
    var LKey := ReadKey;
    if LKey.Code = kcEnter then
      Break
    else if LKey.Code = kcEscape then
    begin
      FAborted := True;
      Break;
    end
    else if LKey.Code = kcUp then
      LIndex := (LIndex - 1 + LCount) mod LCount
    else if LKey.Code = kcDown then
      LIndex := (LIndex + 1) mod LCount
    else if LKey.Code = kcSpace then
      Result[LIndex] := not Result[LIndex]
    else
      Continue;
    // Redraw only the option rows (not header/hint)
    FBackend.Write(TTuiAnsi.CursorUp(LCount));
    for var LI := 0 to LCount - 1 do
      DrawMultiSelectRow(LI, LIndex, AOptions[LI], Result[LI]);
  end;
  // Collapse: header + hint + LCount option rows = LCount + 2 lines
  FBackend.Write(
    TTuiAnsi.CursorUp(LCount + 2) + #13 + TTuiAnsi.ClearScreenAfterCursor
  );
  if FAborted then
    Exit;
  // Build selected-items label
  var LSelected := '';
  for var LI := 0 to LCount - 1 do
  begin
    if Result[LI] then
    begin
      if LSelected <> '' then
        LSelected := LSelected + ', ';
      LSelected := LSelected + AOptions[LI];
    end;
  end;
  if LSelected = '' then
    LSelected := 'nessuna';
  CollapsePrompt(ALabel, LSelected);
end;

function TCliConsole.PromptSelect(const ALabel: string;
  const AOptions: array of string; ADefault: Integer): Integer;
begin
  var LCount := Length(AOptions);
  if LCount = 0 then
    Exit(ADefault);
  var LIndex := ADefault;
  FAborted := False;
  // Header line
  FBackend.Write(
    TTuiAnsi.ApplyStyle(StylePromptActive) + CIconPrompt + '  ' + TTuiAnsi.Reset +
    TTuiAnsi.ApplyStyle(StyleTitle) + ALabel + TTuiAnsi.Reset + #13#10
  );
  // Initial option rows
  for var LI := 0 to LCount - 1 do
    DrawSelectRow(LI, LIndex, AOptions[LI]);
  // Navigation loop
  while True do
  begin
    var LKey := ReadKey;
    if LKey.Code = kcEnter then
      Break
    else if LKey.Code = kcEscape then
    begin
      FAborted := True;
      Break;
    end
    else if LKey.Code = kcUp then
      LIndex := (LIndex - 1 + LCount) mod LCount
    else if LKey.Code = kcDown then
      LIndex := (LIndex + 1) mod LCount
    else
      Continue;
    // Redraw option rows
    FBackend.Write(TTuiAnsi.CursorUp(LCount));
    for var LI := 0 to LCount - 1 do
      DrawSelectRow(LI, LIndex, AOptions[LI]);
  end;
  // Collapse: header + LCount option rows = LCount + 1 lines
  FBackend.Write(
    TTuiAnsi.CursorUp(LCount + 1) + #13 + TTuiAnsi.ClearScreenAfterCursor
  );
  if FAborted then
  begin
    Result := ADefault;
    Exit;
  end;
  Result := LIndex;
  CollapsePrompt(ALabel, AOptions[LIndex]);
end;

function TCliConsole.PromptText(const ALabel, ADefault,
  APlaceholder: string): string;
begin
  var LText := '';
  FAborted := False;
  // Header line
  FBackend.Write(
    TTuiAnsi.ApplyStyle(StylePromptActive) + CIconPrompt + '  ' + TTuiAnsi.Reset +
    TTuiAnsi.ApplyStyle(StyleTitle) + ALabel + TTuiAnsi.Reset + #13#10
  );
  // Input line — no newline; cursor stays at end of text
  FBackend.Write('  ');
  FBackend.Write(TTuiAnsi.ApplyStyle(StyleDim) + APlaceholder + TTuiAnsi.Reset);
  // Edit loop
  while True do
  begin
    var LKey := ReadKey;
    if LKey.Code = kcEnter then
      Break
    else if LKey.Code = kcEscape then
    begin
      FAborted := True;
      Break;
    end
    else if LKey.Code = kcBackspace then
    begin
      if Length(LText) > 0 then
        Delete(LText, Length(LText), 1);
    end
    else if LKey.IsPrintable then
      LText := LText + LKey.CharText
    else
      Continue;
    // Redraw input line in place
    FBackend.Write(#13 + TTuiAnsi.ClearLineToEnd + '  ');
    if LText = '' then
      FBackend.Write(TTuiAnsi.ApplyStyle(StyleDim) + APlaceholder + TTuiAnsi.Reset)
    else
      FBackend.Write(LText);
  end;
  // Collapse both lines (input + header)
  FBackend.Write(
    #13 + TTuiAnsi.ClearLineToEnd +
    TTuiAnsi.CursorUp(1) + #13 + TTuiAnsi.ClearScreenAfterCursor
  );
  if FAborted then
  begin
    Result := ADefault;
    Exit;
  end;
  if LText = '' then
    Result := ADefault
  else
    Result := LText;
  CollapsePrompt(ALabel, Result);
end;

procedure TCliConsole.RunTask(const ALabel: string; ADurationMs: Integer);
begin
  var LElapsed := 0;
  var LEvent: TTuiEvent;
  FSpinnerIndex := 0;
  // Write the initial blank spinner line (no newline) so CR can overwrite it.
  DoWrite('  ' + ALabel);
  while LElapsed < ADurationMs do
  begin
    DrawSpinnerFrame(ALabel);
    if FBackend.TryReadEvent(CSpinnerFrameMs, LEvent) then
      Break;
    Inc(LElapsed, CSpinnerFrameMs);
    FSpinnerIndex := (FSpinnerIndex + 1) mod Length(CTuiSpinnerDotsFrames);
  end;
  FinishSpinner(CIconOk, ALabel, StyleSuccess);
end;

procedure TCliConsole.RunTaskWithRecovery(const ALabel, AErrorMsg,
  ARetryLabel: string; ADurationMs, AErrorPauseMs, ARetryMs: Integer);
begin
  var LElapsed := 0;
  var LEvent: TTuiEvent;
  // --- Phase A: first attempt (ends in failure) ---
  FSpinnerIndex := 0;
  DoWrite('  ' + ALabel);
  while LElapsed < ADurationMs do
  begin
    DrawSpinnerFrame(ALabel);
    if FBackend.TryReadEvent(CSpinnerFrameMs, LEvent) then
      Break;
    Inc(LElapsed, CSpinnerFrameMs);
    FSpinnerIndex := (FSpinnerIndex + 1) mod Length(CTuiSpinnerDotsFrames);
  end;
  FinishSpinner(CIconErr, ALabel, StyleError);
  // Error detail indented below the failed task line.
  DoWriteStyledLn(
    '  ' + #$21B3 + ' ' + AErrorMsg,
    StyleDim
  );
  // Brief pause so the user can read the error before the retry starts.
  DoPause(AErrorPauseMs);

  // --- Phase B: retry (ends in success) ---
  LElapsed := 0;
  FSpinnerIndex := 0;
  DoWrite('  ' + ARetryLabel);
  while LElapsed < ARetryMs do
  begin
    DrawSpinnerFrame(CIconRetry + ' ' + ARetryLabel);
    if FBackend.TryReadEvent(CSpinnerFrameMs, LEvent) then
      Break;
    Inc(LElapsed, CSpinnerFrameMs);
    FSpinnerIndex := (FSpinnerIndex + 1) mod Length(CTuiSpinnerDotsFrames);
  end;
  FinishSpinner(CIconOk, ARetryLabel, StyleSuccess);
end;

procedure TCliConsole.Banner;
begin
  DoWriteLn('');
  FBackend.Write(
    TTuiAnsi.ApplyStyle(StyleTitle) +
    '  ' + CIconPrompt + '  ' + CAppName +
    TTuiAnsi.Reset +
    TTuiAnsi.ApplyStyle(StyleDim) +
    '  ' + CAppVersion +
    TTuiAnsi.Reset + #13#10
  );
  DoWriteLn('');
end;

procedure TCliConsole.NextSteps(const AConfig: TScaffoldConfig);
const
  CW = 56; // inner content width (between the two vertical border chars)
begin
  // Build reusable pieces.
  var LHRule := '';
  for var LI := 1 to CW do
    LHRule := LHRule + #$2500;
  var LBlank := StringOfChar(' ', CW);

  // Title bar: ┌─ title ──...──┐
  var LTitleText := ' ' + CMsgNextStepsTitle + ' ';
  var LTopFill := '';
  for var LI := 1 to CW - 1 - Length(LTitleText) do
    LTopFill := LTopFill + #$2500;

  DoWriteLn('');
  DoWriteStyledLn(
    ' ' + #$250C + #$2500 + LTitleText + LTopFill + #$2510,
    StyleTitle
  );
  DoWriteStyledLn(' ' + #$2502 + LBlank + #$2502, StyleDim);

  // Three next-step lines.
  var LStepTexts: array[0..2] of string;
  LStepTexts[0] := '  ' + CIconArrow + '  cd ' + AConfig.ProjectName;
  LStepTexts[1] := '  ' + CIconArrow + '  ' + Format(CMsgNextStep2, [AConfig.ProjectName]);
  LStepTexts[2] := '  ' + CIconArrow + '  ' + CMsgNextStep3;

  for var LI := 0 to 2 do
  begin
    var LContent := LStepTexts[LI];
    if Length(LContent) < CW then
      LContent := LContent + StringOfChar(' ', CW - Length(LContent));
    FBackend.Write(
      TTuiAnsi.ApplyStyle(StyleDim) + ' ' + #$2502 + TTuiAnsi.Reset +
      TTuiAnsi.ApplyStyle(StyleSuccess) + LContent + TTuiAnsi.Reset +
      TTuiAnsi.ApplyStyle(StyleDim) + #$2502 + TTuiAnsi.Reset + #13#10
    );
  end;

  DoWriteStyledLn(' ' + #$2502 + LBlank + #$2502, StyleDim);
  DoWriteStyledLn(' ' + #$2514 + LHRule + #$2518, StyleDim);
  DoWriteLn('');
end;

procedure TCliConsole.WaitForKey(const APrompt: string);
begin
  Blank;
  FBackend.Write(
    TTuiAnsi.ApplyStyle(StyleDim) + CIconPrompt + '  ' + APrompt +
    TTuiAnsi.Reset
  );
  ReadKey;
  FBackend.Write(#13#10);
end;

end.
