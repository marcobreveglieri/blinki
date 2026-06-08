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
{   Unit:        ResTui.Consts.pas                               }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Shared constants for the ResTui demo: palette colours, panel titles,
///   HTTP method list, and footer hint strings.
/// </summary>
unit ResTui.Consts;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Blinki.Core.Style;

const

  // ---- Application header ----
  CAppTitle = '* ResTui *';

  // ---- Panel / box titles ----
  CPanelRequests = ' Requests ';
  CPanelParams   = ' Params ';
  CPanelHeaders  = ' Headers ';
  CPanelBody     = ' Body ';
  CPanelAuth     = ' Auth ';
  CPanelResponse = ' Response ';

  // ---- HTTP methods (ordered for display) ----
  CHttpMethods: array[0..6] of string = (
    'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'
  );

  // ---- Footer hint lines ----
  CFooterMain   = 'F1 Help  F2 Save  F5/Ctrl+Enter Send  F7 New  F8 Delete  Tab Focus  F10/Ctrl+Q Quit';
  CFooterLoading = 'Esc Cancel request  F10 Quit';

  // ---- Method badge colours (RGB) ----
  CColorMethodGet:    TTuiColor = (Kind: ckRGB; R: 0;   G: 180; B: 216);  // cyan
  CColorMethodPost:   TTuiColor = (Kind: ckRGB; R: 72;  G: 199; B: 142);  // green
  CColorMethodPut:    TTuiColor = (Kind: ckRGB; R: 255; G: 159; B: 64);   // orange
  CColorMethodPatch:  TTuiColor = (Kind: ckRGB; R: 72;  G: 145; B: 220);  // blue
  CColorMethodDelete: TTuiColor = (Kind: ckRGB; R: 240; G: 80;  B: 80);   // red
  CColorMethodHead:   TTuiColor = (Kind: ckRGB; R: 140; G: 140; B: 140);  // grey
  CColorMethodOther:  TTuiColor = (Kind: ckRGB; R: 160; G: 100; B: 220);  // purple

  // ---- Status code colours (RGB) ----
  CColorStatus2xx: TTuiColor = (Kind: ckRGB; R: 72;  G: 199; B: 142);  // green
  CColorStatus3xx: TTuiColor = (Kind: ckRGB; R: 0;   G: 180; B: 216);  // cyan
  CColorStatus4xx: TTuiColor = (Kind: ckRGB; R: 255; G: 159; B: 64);   // orange
  CColorStatus5xx: TTuiColor = (Kind: ckRGB; R: 240; G: 80;  B: 80);   // red
  CColorStatusErr: TTuiColor = (Kind: ckRGB; R: 240; G: 80;  B: 80);   // red

  // ---- Border colours ----
  CColorBorderNormal: TTuiColor = (Kind: ckRGB; R: 80;  G: 80;  B: 100);
  CColorBorderFocus:  TTuiColor = (Kind: ckRGB; R: 100; G: 160; B: 240);

  // ---- Miscellaneous ----
  CRequestListWidth = 36;  // fixed column width of the sidebar
  CMethodBoxWidth   = 11;  // fixed column width of the method selector box

implementation

end.
