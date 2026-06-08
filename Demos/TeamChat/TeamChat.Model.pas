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
{   Unit:        TeamChat.Model.pas                              }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TeamChatDemo -- Domain types: TChatMsgKind, TChatMsg, TChatChannel.
/// </summary>
unit TeamChat.Model;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.Generics.Collections;

type

  TChatMsgKind = (mkOther, mkMe, mkSystem);

  /// <summary>
  ///   Record representing a single message in the history.
  /// </summary>
  TChatMsg = record
    Author: string;
    Time: string;
    Text: string;
    Kind: TChatMsgKind;
    class function Make(const AAuthor, ATime, AText: string;
      AKind: TChatMsgKind): TChatMsg; static;
  end;

  /// <summary>
  ///   Chat channel: holds the message list and the unread counter.
  /// </summary>
  TChatChannel = class
  public
    Display: string;          // e.g. "# general", "@ marco"
    IsDM: Boolean;
    Messages: TList<TChatMsg>;
    Unread: Integer;
    constructor Create(const ADisplay: string; AIsDM: Boolean);
    destructor Destroy; override;
  end;

implementation

{ TChatMsg }

class function TChatMsg.Make(const AAuthor, ATime, AText: string;
  AKind: TChatMsgKind): TChatMsg;
begin
  Result.Author := AAuthor;
  Result.Time := ATime;
  Result.Text := AText;
  Result.Kind := AKind;
end;

{ TChatChannel }

constructor TChatChannel.Create(const ADisplay: string; AIsDM: Boolean);
begin
  inherited Create;
  Display := ADisplay;
  IsDM := AIsDM;
  Messages := TList<TChatMsg>.Create;
end;

destructor TChatChannel.Destroy;
begin
  if Assigned(Messages) then
    Messages.Free;
  inherited Destroy;
end;

end.
