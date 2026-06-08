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
{   Unit:        Blinki.Widgets.Box.pas                          }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Widget decorator TTuiBox: draws a border with an optional title around a single child
///   widget, reserving the inner rectangle for it.
/// </summary>
unit Blinki.Widgets.Box;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Ansi,
  Blinki.Core.Canvas,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Core.Widget;

type

{ TTuiBox }

  /// <summary>
  ///   Single-child decorator: draws a border and an optional title, assigning the child
  ///   the inner rectangle (Inflate -1,-1). Accepts at most one child; a second call to
  ///   AddChild raises ETuiWidgetError.
  ///   The border style is updated automatically when the theme changes.
  /// </summary>
  TTuiBox = class(TTuiWidget)
  strict private
    FTitle: string;
    FBoxStyle: TTuiBoxStyle;
    FBorderStyle: TTuiStyle;
    FStyleOverride: Boolean;
    procedure SetTitle(const AValue: string);
    procedure SetBoxStyle(AValue: TTuiBoxStyle);
    procedure SetBorderStyle(const AValue: TTuiStyle);
  protected
    procedure DoRender(const ACanvas: TTuiCanvas; const ARect: TRect); override;
    procedure DoApplyTheme(const ATheme: TTuiTheme); override;
  public
    /// <summary>
    ///   Creates the box. If AParent is specified, registers itself as a child.
    ///   Initial style is derived from TTuiTheme.Default.
    /// </summary>
    constructor Create(AParent: TTuiWidget = nil);
    /// <summary>
    ///   Override: raises ETuiWidgetError if a child is already present.
    /// </summary>
    procedure AddChild(AChild: TTuiWidget); override;
    /// <summary>
    ///   Title text centered on the top border line. Empty string means no title.
    /// </summary>
    property Title: string read FTitle write SetTitle;
    /// <summary>
    ///   Border drawing style (Single/Double/Rounded/Heavy). Default: bsSingle.
    /// </summary>
    property BoxStyle: TTuiBoxStyle read FBoxStyle write SetBoxStyle;
    /// <summary>
    ///   ANSI style for the border and title.
    ///   Once explicitly assigned, the theme no longer overrides it.
    /// </summary>
    property BorderStyle: TTuiStyle read FBorderStyle write SetBorderStyle;
  end;

implementation

uses
  System.Generics.Collections,
  Blinki.Core.Event;

{ TTuiBox }

constructor TTuiBox.Create(AParent: TTuiWidget);
begin
  inherited Create(AParent);
  FBorderStyle := TTuiStyle.Create(Theme.Border, Theme.Surface);
  FBoxStyle := bsSingle;
end;

procedure TTuiBox.DoApplyTheme(const ATheme: TTuiTheme);
begin
  if not FStyleOverride then
    FBorderStyle := TTuiStyle.Create(ATheme.Border, ATheme.Surface);
end;

procedure TTuiBox.AddChild(AChild: TTuiWidget);
begin
  if ChildCount >= 1 then
    raise ETuiWidgetError.Create('TTuiBox.AddChild: the box accepts a maximum of one child');
  inherited AddChild(AChild);
end;

procedure TTuiBox.SetTitle(const AValue: string);
begin
  if FTitle = AValue then
    Exit;
  FTitle := AValue;
  Invalidate;
end;

procedure TTuiBox.SetBoxStyle(AValue: TTuiBoxStyle);
begin
  if FBoxStyle = AValue then
    Exit;
  FBoxStyle := AValue;
  Invalidate;
end;

procedure TTuiBox.SetBorderStyle(const AValue: TTuiStyle);
begin
  if FBorderStyle = AValue then
    Exit;
  FBorderStyle := AValue;
  FStyleOverride := True;
  Invalidate;
end;

procedure TTuiBox.DoRender(const ACanvas: TTuiCanvas; const ARect: TRect);
begin
  if ARect.IsEmpty then
    Exit;
  ACanvas.DrawBox(ARect, FBoxStyle, FTitle, FBorderStyle);
  if ChildCount = 1 then
  begin
    var LInner := ARect;
    LInner.Inflate(-1, -1);
    if not LInner.IsEmpty then
      Children[0].Render(ACanvas, LInner);
  end;
end;

end.
