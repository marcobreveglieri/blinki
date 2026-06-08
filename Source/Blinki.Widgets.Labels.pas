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
{   Unit:        Blinki.Widgets.Labels.pas                       }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TTuiLabel: non-focusable static text widget.
///   Renders Text truncated to a single row inside ARect using Style.
///   First concrete widget of the Blinki library; inaugurates the Blinki.Widgets.* namespace.
/// </summary>
unit Blinki.Widgets.Labels;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Types,
  Blinki.Core.Canvas,
  Blinki.Core.Style,
  Blinki.Core.Widget;

type

{ TTuiLabel }

  /// <summary>
  ///   Single-row static text widget. Not focusable.
  ///   Assign Text and Style before the first Render; each assignment
  ///   automatically invalidates the widget (dirty flag).
  /// </summary>
  TTuiLabel = class(TTuiWidget)
  strict private
    FText: string;
    FStyle: TTuiStyle;
    procedure SetText(const AValue: string);
    procedure SetStyle(const AValue: TTuiStyle);
  protected
    /// <summary>
    ///   Writes FText on the first row of ARect, truncated to ARect.Width.
    /// </summary>
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
  public
    /// <summary>
    ///   Displayed text; assigning it automatically invalidates the widget.
    /// </summary>
    property Text:  string    read FText  write SetText;
    /// <summary>
    ///   Rendering style; assigning it automatically invalidates the widget.
    /// </summary>
    property Style: TTuiStyle read FStyle write SetStyle;
  end;

implementation

uses
  Blinki.Core.Event;

{ TTuiLabel }

procedure TTuiLabel.SetText(const AValue: string);
begin
  if FText = AValue then
    Exit;
  FText := AValue;
  Invalidate;
end;

procedure TTuiLabel.SetStyle(const AValue: TTuiStyle);
begin
  if FStyle = AValue then
    Exit;
  FStyle := AValue;
  Invalidate;
end;

procedure TTuiLabel.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  ACanvas.FillRect(ARect, ' ', FStyle);
  var LText := FText;
  if Length(LText) > ARect.Width then
    LText := Copy(LText, 1, ARect.Width);
  if LText <> '' then
    ACanvas.WriteAt(ARect.Left, ARect.Top, LText, FStyle);
end;

end.
