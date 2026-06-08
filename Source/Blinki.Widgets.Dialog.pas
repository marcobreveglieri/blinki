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
{   Unit:        Blinki.Widgets.Dialog.pas                       }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Modal dialog overlay system for the Blinki library.
///   Provides TTuiDialog (floating centered box with lightweight button bar),
///   TTuiDialogText (word-wrapped text content), TTuiInputDialog (with text
///   input field) and TTuiProgressDialog (with animated progress bar).
///   The factory record TTuiDialogs creates pre-configured instances for the
///   most common patterns: confirmation, error, info, input, and progress.
///   Dialogs are intended to be pushed onto the TTuiApp modal stack via
///   PushModal and removed from the OnClose callback via PopModal.
/// </summary>
unit Blinki.Widgets.Dialog;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Event,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget,
  Blinki.Widgets.ProgressBar,
  Blinki.Widgets.TextInput;

type

{ TTuiDialogResult }

  /// <summary>
  ///   Result returned when a dialog is dismissed.
  /// </summary>
  TTuiDialogResult = (
    /// <summary>
    ///   No result yet (dialog still open or no buttons).
    /// </summary>
    drNone,
    /// <summary>
    ///   User confirmed with OK.
    /// </summary>
    drOK,
    /// <summary>
    ///   User cancelled.
    /// </summary>
    drCancel,
    /// <summary>
    ///   User chose Yes.
    /// </summary>
    drYes,
    /// <summary>
    ///   User chose No.
    /// </summary>
    drNo
  );

{ TTuiDialogButtons }

  /// <summary>
  ///   Set of buttons to display in the dialog button bar.
  /// </summary>
  TTuiDialogButtons = (
    /// <summary>
    ///   Single OK button.
    /// </summary>
    dbOK,
    /// <summary>
    ///   OK and Cancel buttons.
    /// </summary>
    dbOKCancel,
    /// <summary>
    ///   Yes and No buttons.
    /// </summary>
    dbYesNo,
    /// <summary>
    ///   Yes, No and Cancel buttons.
    /// </summary>
    dbYesNoCancel,
    /// <summary>
    ///   Single Cancel button (useful for cancellable progress dialogs).
    /// </summary>
    dbCancel,
    /// <summary>
    ///   No buttons (content only).
    /// </summary>
    dbNone
  );

{ TTuiDialogCloseEvent }

  /// <summary>
  ///   Callback invoked when the dialog is dismissed via CloseWith.
  ///   The caller is responsible for calling App.PopModal inside this handler.
  /// </summary>
  TTuiDialogCloseEvent =
    reference to procedure(ASender: TObject; AResult: TTuiDialogResult);

{ TTuiDialogCaptions }

  /// <summary>
  ///   Button captions for a TTuiDialog. Assign to TTuiDialog.DefaultCaptions
  ///   once at application startup to localise all dialogs, or set
  ///   TTuiDialog.Captions on a single instance for a per-dialog override.
  /// </summary>
  TTuiDialogCaptions = record
    Cancel: string;
    No: string;
    OK: string;
    Yes: string;
    /// <summary>
    ///   Returns the built-in English captions (OK / Cancel / Yes / No).
    /// </summary>
    class function Default: TTuiDialogCaptions; static;
  end;

{ TTuiDialogBorderRole }

  /// <summary>
  ///   Semantic role for the dialog border. Determines which theme colour is used
  ///   for the border in RebuildStyles. Ignored when BorderStyle has been set
  ///   directly (which sets the FBorderStyleOverride flag).
  /// </summary>
  TTuiDialogBorderRole = (
    /// <summary>
    ///   Primary colour (default).
    /// </summary>
    dbrPrimary,
    /// <summary>
    ///   Error colour (Theme.Error).
    /// </summary>
    dbrError,
    /// <summary>
    ///   Info colour (alias for Primary, Theme.Primary).
    /// </summary>
    dbrInfo,
    /// <summary>
    ///   Success colour (Theme.Success).
    /// </summary>
    dbrSuccess,
    /// <summary>
    ///   Warning colour (Theme.Warning).
    /// </summary>
    dbrWarning
  );

{ TTuiDialogText }

  /// <summary>
  ///   Non-focusable widget that renders a block of text with word-wrapping.
  ///   Intended for use as the content child of a TTuiDialog.
  ///   Wrapped lines are cached and only recomputed when the text or the
  ///   available width changes, so DoRender is O(visible rows) per frame.
  /// </summary>
  TTuiDialogText = class(TTuiWidget)
  strict private
    FCacheWidth: Integer;
    FStyle: TTuiStyle;
    FStyleOverride: Boolean;
    FText: string;
    FWrappedLines: TArray<string>;
    procedure SetText(const AValue: string);
    procedure SetStyle(const AValue: TTuiStyle);
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the widget. Style is derived from the theme until overridden.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Text to display. Supports word-wrapping within the assigned rect.
    /// </summary>
    property Text: string read FText write SetText;
    /// <summary>
    ///   Text rendering style. Once assigned, theme changes no longer override it.
    /// </summary>
    property Style: TTuiStyle read FStyle write SetStyle;
  end;

{ TTuiDialog }

  /// <summary>
  ///   Floating centered dialog box. Renders as a rounded-border overlay above
  ///   the root widget tree when pushed onto the TTuiApp modal stack.
  ///   Supports a title, one optional content child widget, an optional 1-pixel
  ///   shadow, and a lightweight button bar (buttons are drawn directly, not
  ///   as child TTuiButton widgets, so the modal focus ring stays clean).
  ///   Keyboard: ESC cancels; Enter confirms the focused button; Left/Right
  ///   navigate buttons. Mouse: click on a button confirms it.
  ///   Override OnClose to react to the result and call App.PopModal there.
  /// </summary>
  TTuiDialog = class(TTuiWidget)
  strict private
    FBorderRole: TTuiDialogBorderRole;
    FBorderStyle: TTuiStyle;
    FBorderStyleOverride: Boolean;
    FButtonFocusedStyle: TTuiStyle;
    FButtonIndex: Integer;
    FButtonNormalStyle: TTuiStyle;
    FButtonRects: TArray<TRect>;
    FButtons: TTuiDialogButtons;
    FDialogHeight: Integer;
    FDialogWidth: Integer;
    FOnClose: TTuiDialogCloseEvent;
    FResult: TTuiDialogResult;
    FShadow: Boolean;
    FSurfaceStyle: TTuiStyle;
    FTitle: string;
    class var
      FDefaultCaptions: TTuiDialogCaptions;
    class constructor Create;
    procedure SetBorderRole(AValue: TTuiDialogBorderRole);
    procedure SetBorderStyle(const AValue: TTuiStyle);
    procedure SetButtons(AValue: TTuiDialogButtons);
    procedure SetDialogHeight(AValue: Integer);
    procedure SetDialogWidth(AValue: Integer);
    procedure SetShadow(AValue: Boolean);
    procedure SetTitle(const AValue: string);
    procedure RebuildStyles;
    function GetButtonCaptions: TArray<string>;
    function ButtonResultForIndex(AIndex: Integer): TTuiDialogResult;
    function EscapeResult: TTuiDialogResult;
    function CalcEffectiveWidth: Integer;
    function CalcEffectiveHeight: Integer;
    procedure RenderButtonBar(const ACanvas: TTuiCanvas; const ARect: TRect);
  protected
    /// <summary>
    ///   Marks the dialog as focusable so it receives keyboard events.
    ///   Subclasses with interactive children may choose not to call inherited.
    /// </summary>
    procedure DoInit; override;
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    function DoHandleEvent(const AEvent: TTuiEvent): Boolean; override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
    /// <summary>
    ///   Sets FResult and invokes OnClose. Does not call App.PopModal —
    ///   that is the responsibility of the OnClose handler.
    /// </summary>
    procedure CloseWith(AResult: TTuiDialogResult); virtual;
  public
    /// <summary>
    ///   Per-instance button captions. Initialised from DefaultCaptions when
    ///   the dialog is created; override individual fields to customise a single
    ///   dialog without changing the global default.
    ///   Note: this is a public field (not a property) so that record-field
    ///   writes such as `LDlg.Captions.Cancel := '...'` compile correctly.
    /// </summary>
    Captions: TTuiDialogCaptions;
    /// <summary>
    ///   Creates the dialog. No child is set; shadow is enabled; Buttons = dbOKCancel.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Enforces the single-child constraint (raises ETuiWidgetError on a second call).
    /// </summary>
    procedure AddChild(AChild: TTuiWidget); override;
    /// <summary>
    ///   Title displayed on the top border. Enclose with spaces for visual padding.
    /// </summary>
    property Title: string read FTitle write SetTitle;
    /// <summary>
    ///   Buttons to show in the button bar.
    /// </summary>
    property Buttons: TTuiDialogButtons read FButtons write SetButtons;
    /// <summary>
    ///   Application-wide default captions used to initialise every new dialog.
    ///   Set this once at startup to localise all dialogs in one step.
    ///   Defaults to English (OK / Cancel / Yes / No).
    /// </summary>
    class property DefaultCaptions: TTuiDialogCaptions
      read FDefaultCaptions write FDefaultCaptions;
    /// <summary>
    ///   Explicit dialog width in characters. 0 = auto-compute.
    /// </summary>
    property DialogWidth: Integer read FDialogWidth write SetDialogWidth;
    /// <summary>
    ///   Explicit dialog height in rows. 0 = auto-compute.
    /// </summary>
    property DialogHeight: Integer read FDialogHeight write SetDialogHeight;
    /// <summary>
    ///   When True, a 1-cell shadow is drawn to the right and below. Default: True.
    /// </summary>
    property Shadow: Boolean read FShadow write SetShadow;
    /// <summary>
    ///   Semantic border role. Controls which theme colour is used for the border
    ///   in RebuildStyles (Primary, Error, Info, Success, or Warning).
    ///   Has no effect when BorderStyle has been assigned directly.
    ///   Default: dbrPrimary.
    /// </summary>
    property BorderRole: TTuiDialogBorderRole read FBorderRole write SetBorderRole;
    /// <summary>
    ///   Border style. Once assigned, theme changes no longer override it.
    /// </summary>
    property BorderStyle: TTuiStyle read FBorderStyle write SetBorderStyle;
    /// <summary>
    ///   Invoked when the dialog is dismissed (by any button or ESC).
    ///   Call App.PopModal inside this handler to remove the dialog.
    /// </summary>
    property OnClose: TTuiDialogCloseEvent read FOnClose write FOnClose;
    /// <summary>
    ///   The last result set by CloseWith. drNone while the dialog is open.
    /// </summary>
    property DialogResult: TTuiDialogResult read FResult;
  end;

{ TTuiInputDialog }

  /// <summary>
  ///   Dialog variant that embeds a single-line TTuiTextInput.
  ///   Press Enter in the text field to confirm (drOK), ESC to cancel (drCancel).
  ///   The dialog itself is not focusable; only the text input is.
  /// </summary>
  TTuiInputDialog = class(TTuiDialog)
  strict private
    FInput: TTuiTextInput;
    function GetValue: string;
    procedure SetValue(const AValue: string);
    function GetPlaceholder: string;
    procedure SetPlaceholder(const AValue: string);
  protected
    procedure DoInit; override;
  public
    /// <summary>
    ///   Creates the input dialog. A TTuiTextInput is added automatically as the
    ///   content child. OnSubmit of the input is wired to confirm with drOK.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Current text value of the embedded text input.
    /// </summary>
    property Value: string read GetValue write SetValue;
    /// <summary>
    ///   Placeholder text shown when the input is empty.
    /// </summary>
    property Placeholder: string read GetPlaceholder write SetPlaceholder;
  end;

{ TTuiProgressDialog }

  /// <summary>
  ///   Dialog variant that embeds a TTuiProgressBar.
  ///   Typical usage: push the dialog, advance Progress from OnTimer, pop on completion.
  ///   ESC or the Cancel button fires OnCancel before the regular OnClose.
  /// </summary>
  TTuiProgressDialog = class(TTuiDialog)
  strict private
    FBar: TTuiProgressBar;
    FOnCancel: TProc;
    function GetProgress: Single;
    procedure SetProgress(AValue: Single);
  protected
    procedure CloseWith(AResult: TTuiDialogResult); override;
  public
    /// <summary>
    ///   Creates the progress dialog with dbCancel buttons and an embedded TTuiProgressBar.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Progress value in the range 0.0..1.0; updates the embedded progress bar.
    /// </summary>
    property Progress: Single read GetProgress write SetProgress;
    /// <summary>
    ///   Signals that the operation completed successfully (equivalent to drOK).
    ///   Call this from an OnTimer handler when the progress reaches 100%.
    /// </summary>
    procedure Complete;
    /// <summary>
    ///   Invoked before OnClose when the user cancels (ESC or the Cancel button).
    /// </summary>
    property OnCancel: TProc read FOnCancel write FOnCancel;
  end;

{ TTuiDialogs }

  /// <summary>
  ///   Factory record with static helpers that create pre-configured dialogs.
  ///   Each factory method returns an owning reference — pass to PushModal with
  ///   AOwnsModal = True (the default) so the App disposes the widget.
  /// </summary>
  TTuiDialogs = record
    /// <summary>
    ///   Creates a confirmation dialog with a word-wrapped message.
    /// </summary>
    class function Confirm(const ATitle, AMessage: string;
      AButtons: TTuiDialogButtons = dbOKCancel): TTuiDialog; static;
    /// <summary>
    ///   Creates an error dialog (border uses Theme.Error color) with an OK button.
    /// </summary>
    class function Error(const ATitle, AMessage: string): TTuiDialog; static;
    /// <summary>
    ///   Creates an informational dialog (border uses Theme.Primary color) with an OK button.
    /// </summary>
    class function Info(const ATitle, AMessage: string): TTuiDialog; static;
    /// <summary>
    ///   Creates an input dialog with a placeholder and a pre-filled default value.
    /// </summary>
    class function Input(const ATitle, APrompt,
      ADefault: string): TTuiInputDialog; static;
    /// <summary>
    ///   Creates a progress dialog with a Cancel button.
    /// </summary>
    class function Progress(const ATitle: string): TTuiProgressDialog; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.Math,
  Blinki.Core.Ansi,
  Blinki.Core.Geometry,
  Blinki.Core.Input;

{ ---- Module-level helpers ---- }

const
  CMinDialogWidth    = 20;
  CMinDialogHeight   = 4;
  CDefaultDialogWidth  = 50;
  CDefaultDialogHeight = 9;

// Returns the words-wrapped lines of AText fitting in AWidth columns.
function WordWrapLines(const AText: string; AWidth: Integer): TArray<string>;
begin
  Result := [];
  if AWidth <= 0 then
    Exit;
  var LWords := AText.Split([' '], TStringSplitOptions.None);
  var LLine := '';
  for var LWord in LWords do
  begin
    var LWordLen := TTuiAnsi.VisibleLength(LWord);
    var LLineLen := TTuiAnsi.VisibleLength(LLine);
    if LLine = '' then
      LLine := LWord
    else if LLineLen + 1 + LWordLen <= AWidth then
      LLine := LLine + ' ' + LWord
    else
    begin
      Result := Result + [LLine];
      LLine := LWord;
    end;
  end;
  if LLine <> '' then
    Result := Result + [LLine];
end;

{ TTuiDialogCaptions }

class function TTuiDialogCaptions.Default: TTuiDialogCaptions;
begin
  Result.Cancel := 'Cancel';
  Result.No := 'No';
  Result.OK := 'OK';
  Result.Yes := 'Yes';
end;

{ TTuiDialogText }

constructor TTuiDialogText.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FCacheWidth := -1;
  FStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
end;

procedure TTuiDialogText.DoApplyTheme(const ATheme: TTuiTheme);
begin
  if not FStyleOverride then
    FStyle := TTuiStyle.Create(ATheme.Text, ATheme.Surface);
end;

procedure TTuiDialogText.SetText(const AValue: string);
begin
  if FText = AValue then
    Exit;
  FText := AValue;
  FCacheWidth := -1; // invalidate wrapped-line cache
  Invalidate;
end;

procedure TTuiDialogText.SetStyle(const AValue: TTuiStyle);
begin
  if FStyle = AValue then
    Exit;
  FStyle := AValue;
  FStyleOverride := True;
  Invalidate;
end;

procedure TTuiDialogText.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  ACanvas.FillRect(ARect, ' ', FStyle);
  // Rebuild the wrapped-line cache only when the text or available width changes.
  if ARect.Width <> FCacheWidth then
  begin
    FWrappedLines := TTuiAnsi.WrapText(FText, ARect.Width);
    FCacheWidth := ARect.Width;
  end;
  for var LY := 0 to Min(High(FWrappedLines), ARect.Height - 1) do
    ACanvas.WriteAt(ARect.Left, ARect.Top + LY, FWrappedLines[LY], FStyle);
end;

{ TTuiDialog }

class constructor TTuiDialog.Create;
begin
  FDefaultCaptions := TTuiDialogCaptions.Default;
end;

constructor TTuiDialog.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FBorderRole := dbrPrimary;
  FButtons := dbOKCancel;
  FResult := drNone;
  FShadow := True;
  Captions := FDefaultCaptions;
  RebuildStyles;
end;

procedure TTuiDialog.RebuildStyles;
begin
  if not FBorderStyleOverride then
  begin
    var LBorderFg: TTuiColor;
    case FBorderRole of
      dbrError:   LBorderFg := Theme.Error;
      dbrInfo:    LBorderFg := Theme.Primary;
      dbrSuccess: LBorderFg := Theme.Success;
      dbrWarning: LBorderFg := Theme.Warning;
    else           LBorderFg := Theme.Primary; // dbrPrimary
    end;
    FBorderStyle := TTuiStyle.Create(LBorderFg, Theme.Surface);
  end;
  FSurfaceStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  FButtonNormalStyle := TTuiStyle.Create(Theme.Text, Theme.Surface);
  FButtonFocusedStyle := TTuiStyle.Create(Theme.Background, Theme.Primary);
end;

procedure TTuiDialog.SetBorderRole(AValue: TTuiDialogBorderRole);
begin
  if FBorderRole = AValue then
    Exit;
  FBorderRole := AValue;
  RebuildStyles;
  Invalidate;
end;

procedure TTuiDialog.DoInit;
begin
  SetFocusable(True);
end;

procedure TTuiDialog.DoApplyTheme(const ATheme: TTuiTheme);
begin
  RebuildStyles;
end;

procedure TTuiDialog.AddChild(AChild: TTuiWidget);
begin
  if ChildCount >= 1 then
    raise ETuiWidgetError.Create(
      'TTuiDialog.AddChild: the dialog accepts a maximum of one content child');
  inherited AddChild(AChild);
end;

procedure TTuiDialog.SetTitle(const AValue: string);
begin
  if FTitle = AValue then
    Exit;
  FTitle := AValue;
  Invalidate;
end;

procedure TTuiDialog.SetButtons(AValue: TTuiDialogButtons);
begin
  if FButtons = AValue then
    Exit;
  FButtons := AValue;
  FButtonIndex := 0;
  Invalidate;
end;

procedure TTuiDialog.SetDialogWidth(AValue: Integer);
begin
  if FDialogWidth = AValue then
    Exit;
  FDialogWidth := AValue;
  Invalidate;
end;

procedure TTuiDialog.SetDialogHeight(AValue: Integer);
begin
  if FDialogHeight = AValue then
    Exit;
  FDialogHeight := AValue;
  Invalidate;
end;

procedure TTuiDialog.SetShadow(AValue: Boolean);
begin
  if FShadow = AValue then
    Exit;
  FShadow := AValue;
  Invalidate;
end;

procedure TTuiDialog.SetBorderStyle(const AValue: TTuiStyle);
begin
  if FBorderStyle = AValue then
    Exit;
  FBorderStyle := AValue;
  FBorderStyleOverride := True;
  Invalidate;
end;

function TTuiDialog.GetButtonCaptions: TArray<string>;
begin
  case FButtons of
    dbOK:
      Result := [Captions.OK];
    dbOKCancel:
      Result := [Captions.OK, Captions.Cancel];
    dbYesNo:
      Result := [Captions.Yes, Captions.No];
    dbYesNoCancel:
      Result := [Captions.Yes, Captions.No, Captions.Cancel];
    dbCancel:
      Result := [Captions.Cancel];
  else
    Result := [];
  end;
end;

function TTuiDialog.ButtonResultForIndex(AIndex: Integer): TTuiDialogResult;
begin
  case FButtons of
    dbOK:
      Result := drOK;
    dbOKCancel:
    begin
      if AIndex = 0 then
        Result := drOK
      else
        Result := drCancel;
    end;
    dbYesNo:
    begin
      if AIndex = 0 then
        Result := drYes
      else
        Result := drNo;
    end;
    dbYesNoCancel:
    begin
      if AIndex = 0 then
        Result := drYes
      else if AIndex = 1 then
        Result := drNo
      else
        Result := drCancel;
    end;
    dbCancel:
      Result := drCancel;
  else
    Result := drNone;
  end;
end;

function TTuiDialog.EscapeResult: TTuiDialogResult;
begin
  Result := drCancel;
end;

function TTuiDialog.CalcEffectiveWidth: Integer;
begin
  if FDialogWidth > 0 then
    Result := FDialogWidth
  else
  begin
    // Auto-width: enough to fit the button bar with lateral padding.
    var LCaptions := GetButtonCaptions;
    var LBtnWidth := 0;
    for var S in LCaptions do
      Inc(LBtnWidth, TTuiAnsi.VisibleLength(S) + 4); // "[ X ]"
    if Length(LCaptions) > 1 then
      Inc(LBtnWidth, (Length(LCaptions) - 1) * 2);
    Result := Max(LBtnWidth + 6, CDefaultDialogWidth);
  end;
end;

function TTuiDialog.CalcEffectiveHeight: Integer;
begin
  if FDialogHeight > 0 then
    Result := FDialogHeight
  else
    Result := CDefaultDialogHeight;
end;

procedure TTuiDialog.RenderButtonBar(const ACanvas: TTuiCanvas;
  const ARect: TRect);
begin
  var LCaptions := GetButtonCaptions;
  var LCount := Length(LCaptions);
  SetLength(FButtonRects, LCount);
  if LCount = 0 then
    Exit;

  // Compute total rendered width of all buttons and gaps.
  var LTotalWidth := 0;
  for var LI := 0 to LCount - 1 do
    Inc(LTotalWidth, TTuiAnsi.VisibleLength(LCaptions[LI]) + 4); // "[ X ]"
  if LCount > 1 then
    Inc(LTotalWidth, (LCount - 1) * 2); // 2-char gaps between buttons

  // Centre the group horizontally within ARect.
  var LCurX := ARect.Left + Max((ARect.Width - LTotalWidth) div 2, 0);
  var LY := ARect.Top;

  for var LI := 0 to LCount - 1 do
  begin
    var LCaption := '[ ' + LCaptions[LI] + ' ]';
    var LStyle: TTuiStyle;
    if Focused and (LI = FButtonIndex) then
      LStyle := FButtonFocusedStyle
    else
      LStyle := FButtonNormalStyle;
    ACanvas.WriteAt(LCurX, LY, LCaption, LStyle);
    FButtonRects[LI] := TRect.Create(LCurX, LY,
      LCurX + TTuiAnsi.VisibleLength(LCaption), LY + 1);
    Inc(LCurX, TTuiAnsi.VisibleLength(LCaption) + 2);
  end;
end;

procedure TTuiDialog.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;

  // Check that the available space can fit the minimum dialog size before clamping.
  var LAvailW := ARect.Width - 2;
  var LAvailH := ARect.Height - 2;
  if (LAvailW < CMinDialogWidth) or (LAvailH < CMinDialogHeight) then
    Exit; // cannot render in the space available
  var LW := Max(Min(CalcEffectiveWidth, LAvailW), CMinDialogWidth);
  var LH := Max(Min(CalcEffectiveHeight, LAvailH), CMinDialogHeight);

  // Centre the dialog.
  var LDlgX := ARect.Left + (ARect.Width - LW) div 2;
  var LDlgY := ARect.Top + (ARect.Height - LH) div 2;
  var LDlgRect := TRect.Create(LDlgX, LDlgY, LDlgX + LW, LDlgY + LH);

  // Shadow: one column right and one row below (clamped by canvas internally).
  if FShadow then
  begin
    var LShadowStyle := TTuiStyle.Create(Theme.Background, Theme.Border);
    // Right strip (skip top-right corner to avoid overhang artifact).
    ACanvas.FillRect(
      TRect.Create(LDlgX + LW, LDlgY + 1, LDlgX + LW + 1, LDlgY + LH),
      ' ', LShadowStyle);
    // Bottom strip.
    ACanvas.FillRect(
      TRect.Create(LDlgX + 1, LDlgY + LH, LDlgX + LW + 1, LDlgY + LH + 1),
      ' ', LShadowStyle);
  end;

  // Fill the dialog area and draw the rounded border with title.
  ACanvas.FillRect(LDlgRect, ' ', FSurfaceStyle);
  ACanvas.DrawBox(LDlgRect, bsRounded, FTitle, FBorderStyle);

  // Compute the inner rectangle (inside the border).
  var LInner := LDlgRect;
  LInner.Inflate(-1, -1);
  if LInner.IsEmpty then
    Exit;

  // Split the inner area: button bar at the bottom, content above.
  var LButtonBar: TRect;
  var LContent: TRect;
  if LInner.Height >= 2 then
  begin
    LButtonBar := TRect.Create(
      LInner.Left, LInner.Bottom - 1, LInner.Right, LInner.Bottom);
    LContent := TRect.Create(
      LInner.Left, LInner.Top, LInner.Right, LInner.Bottom - 1);
  end
  else
  begin
    LButtonBar := LInner;
    LContent := TRect.Create(LInner.Left, LInner.Top, LInner.Right, LInner.Top);
  end;

  // Render content child if one is present.
  if (ChildCount = 1) and (not LContent.IsEmpty) then
    Children[0].Render(ACanvas, LContent);

  // Render the button bar.
  ACanvas.FillRect(LButtonBar, ' ', FSurfaceStyle);
  RenderButtonBar(ACanvas, LButtonBar);
end;

function TTuiDialog.DoHandleEvent(const AEvent: TTuiEvent): Boolean;
begin
  Result := False;
  case AEvent.Kind of
    ekKey:
    begin
      case AEvent.Key.Code of
        kcEscape:
        begin
          CloseWith(EscapeResult);
          Result := True;
        end;
        kcEnter:
        begin
          var LCaptions := GetButtonCaptions;
          if Length(LCaptions) > 0 then
            CloseWith(ButtonResultForIndex(FButtonIndex));
          Result := True;
        end;
        kcLeft:
        begin
          var LCount := Length(GetButtonCaptions);
          if LCount > 1 then
          begin
            FButtonIndex := (FButtonIndex - 1 + LCount) mod LCount;
            Invalidate;
            Result := True;
          end;
        end;
        kcRight:
        begin
          var LCount := Length(GetButtonCaptions);
          if LCount > 1 then
          begin
            FButtonIndex := (FButtonIndex + 1) mod LCount;
            Invalidate;
            Result := True;
          end;
        end;
      end;
    end;
    ekMouse:
    begin
      if AEvent.Mouse.Kind = mekDown then
      begin
        var LPt := TPoint.Create(AEvent.Mouse.X, AEvent.Mouse.Y);
        for var LI := 0 to High(FButtonRects) do
        begin
          if FButtonRects[LI].Contains(LPt) then
          begin
            CloseWith(ButtonResultForIndex(LI));
            Result := True;
            Break;
          end;
        end;
      end;
    end;
  end;
end;

procedure TTuiDialog.CloseWith(AResult: TTuiDialogResult);
begin
  FResult := AResult;
  if Assigned(FOnClose) then
  begin
    // Keep a local reference so the closure stays alive even if the dialog is
    // freed inside the callback (e.g. via AApp.PopModal with AOwnsModal=True).
    var LOnClose := FOnClose;
    LOnClose(Self, AResult);
  end;
end;

{ TTuiInputDialog }

constructor TTuiInputDialog.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  // Create the text input and add it as the dialog's content child.
  FInput := TTuiTextInput.Create(Self);
  FInput.LayoutConstraint := TTuiLayoutConstraint.Fill(1);
  // Pressing Enter in the text input confirms the dialog.
  FInput.OnSubmit :=
    procedure(AText: string)
    begin
      CloseWith(drOK);
    end;
end;

procedure TTuiInputDialog.DoInit;
begin
  // The embedded text input is focusable; the dialog itself is not, so the
  // user types directly into the field without needing to Tab to it first.
  // ESC typed in the input is not consumed there and bubbles up to this dialog.
  // Do NOT call inherited (which would make the dialog itself focusable).
end;

function TTuiInputDialog.GetValue: string;
begin
  Result := FInput.Text;
end;

procedure TTuiInputDialog.SetValue(const AValue: string);
begin
  FInput.Text := AValue;
end;

function TTuiInputDialog.GetPlaceholder: string;
begin
  Result := FInput.Placeholder;
end;

procedure TTuiInputDialog.SetPlaceholder(const AValue: string);
begin
  FInput.Placeholder := AValue;
end;

{ TTuiProgressDialog }

constructor TTuiProgressDialog.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  Buttons := dbCancel;
  // Create the progress bar and add it as the dialog's content child.
  FBar := TTuiProgressBar.Create(Self);
  FBar.LayoutConstraint := TTuiLayoutConstraint.Fill(1);
  FBar.ShowPercentage := True;
end;

function TTuiProgressDialog.GetProgress: Single;
begin
  Result := FBar.Value;
end;

procedure TTuiProgressDialog.SetProgress(AValue: Single);
begin
  FBar.Value := AValue;
end;

procedure TTuiProgressDialog.CloseWith(AResult: TTuiDialogResult);
begin
  if (AResult = drCancel) and Assigned(FOnCancel) then
    FOnCancel;
  inherited CloseWith(AResult);
end;

procedure TTuiProgressDialog.Complete;
begin
  CloseWith(drOK);
end;

{ TTuiDialogs }

class function TTuiDialogs.Confirm(const ATitle, AMessage: string;
  AButtons: TTuiDialogButtons): TTuiDialog;
begin
  var LText := TTuiDialogText.Create;
  LText.Text := AMessage;
  Result := TTuiDialog.Create;
  Result.Title := ATitle;
  Result.Buttons := AButtons;
  Result.AddChild(LText);
end;

class function TTuiDialogs.Error(const ATitle, AMessage: string): TTuiDialog;
begin
  Result := Confirm(ATitle, AMessage, dbOK);
  // Use the semantic role so the border colour is derived from the active theme.
  Result.BorderRole := dbrError;
end;

class function TTuiDialogs.Info(const ATitle, AMessage: string): TTuiDialog;
begin
  Result := Confirm(ATitle, AMessage, dbOK);
end;

class function TTuiDialogs.Input(const ATitle, APrompt,
  ADefault: string): TTuiInputDialog;
begin
  Result := TTuiInputDialog.Create;
  Result.Title := ATitle;
  Result.Placeholder := APrompt;
  Result.Value := ADefault;
end;

class function TTuiDialogs.Progress(const ATitle: string): TTuiProgressDialog;
begin
  Result := TTuiProgressDialog.Create;
  Result.Title := ATitle;
end;

end.
