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
{   Unit:        Scaffold.Consts.pas                             }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Compile-time constants for the ScaffoldDemo project:
///   Unicode icons, spinner timing, UI string literals, and task/message text.
/// </summary>
unit Scaffold.Consts;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

const

  // ---------------------------------------------------------------
  // Unicode icons
  // ---------------------------------------------------------------

  /// <summary>
  ///   Check mark — success / confirmed (U+2714).
  /// </summary>
  CIconOk = #$2714;

  /// <summary>
  ///   Cross — error / failure (U+2716).
  /// </summary>
  CIconErr = #$2716;

  /// <summary>
  ///   Warning sign — caution (U+26A0).
  /// </summary>
  CIconWarn = #$26A0;

  /// <summary>
  ///   Information symbol (U+2139).
  /// </summary>
  CIconInfo = #$2139;

  /// <summary>
  ///   Arrow pointer — active selection cursor (U+276F).
  /// </summary>
  CIconPointer = #$276F;

  /// <summary>
  ///   Clockwise arrow — retry / refresh (U+21BB).
  /// </summary>
  CIconRetry = #$21BB;

  /// <summary>
  ///   Black diamond — neutral step prompt (U+25C6).
  /// </summary>
  CIconPrompt = #$25C6;

  /// <summary>
  ///   Dingbat arrow — next steps (U+279C).
  /// </summary>
  CIconArrow = #$279C;

  // ---------------------------------------------------------------
  // Radio / checkbox bullet characters
  // ---------------------------------------------------------------

  /// <summary>
  ///   Filled circle bullet — selected option (U+25C9).
  /// </summary>
  CRadioOn = #$25C9;

  /// <summary>
  ///   Open circle bullet — unselected option (U+25EF).
  /// </summary>
  CRadioOff = #$25EF;

  // ---------------------------------------------------------------
  // Spinner timing (frame sequence is CTuiSpinnerDotsFrames in
  // Blinki.Widgets.Spinner)
  // ---------------------------------------------------------------

  CSpinnerFrameMs = 80;

  // ---------------------------------------------------------------
  // App identity
  // ---------------------------------------------------------------

  CAppName = 'create-blinki-app';
  CAppVersion = 'v0.1.0';

  // ---------------------------------------------------------------
  // Prompt labels (short labels shown next to the icon)
  // ---------------------------------------------------------------

  CPromptName = 'Nome progetto';
  CPromptTemplate = 'Template';
  CPromptFeatures = 'Funzionalit' + #$00E0;  // Funzionalità

  // ---------------------------------------------------------------
  // Default values and placeholder text
  // ---------------------------------------------------------------

  CDefaultName = 'my-blinki-app';
  CNamePlaceholder = 'es. my-blinki-app';

  // ---------------------------------------------------------------
  // Template option labels (for the inline select prompt)
  // ---------------------------------------------------------------

  CTemplateDashboard = 'Dashboard  ' + #$2014 + '  pannello con widget e grafici';
  CTemplateForm = 'Form  ' + #$2014 + '  modulo di inserimento dati';
  CTemplateEmpty = 'Vuoto  ' + #$2014 + '  progetto minimale';

  // ---------------------------------------------------------------
  // Feature option labels (for the inline multi-select prompt)
  // ---------------------------------------------------------------

  CFeatureDark = 'Tema scuro';
  CFeatureExamples = 'Esempi';
  CFeatureGit = 'Git';

  // ---------------------------------------------------------------
  // CLI phase — task labels
  // ---------------------------------------------------------------

  CTaskFolders = 'Creazione struttura cartelle';
  CTaskTemplate = 'Generazione file dal template';
  CTaskDownload = 'Download dipendenze (blinki@0.1.0)';
  CTaskGit = 'Inizializzazione repository git';
  CTaskCompile = 'Compilazione di prova';

  // ---------------------------------------------------------------
  // CLI phase — messages
  // ---------------------------------------------------------------

  CMsgThemeApplied = 'Tema Dark applicato';
  CMsgDelphiWarn = 'Versione Delphi non rilevata: uso la più recente';
  CMsgSuccess = 'Progetto creato con successo!';
  CMsgCancelled = 'Operazione annullata.';
  CMsgNetworkError = 'timeout di rete simulato';
  CMsgRetryDownload = 'Nuovo tentativo download';
  CMsgPressAnyKey = 'Premi un tasto per uscire' + #$2026;  // …

  CMsgNextStepsTitle = 'Passi successivi';
  CMsgNextStep2 = 'Apri %s.dproj in RAD Studio';
  CMsgNextStep3 = 'F9 per compilare ed eseguire';

implementation

end.
