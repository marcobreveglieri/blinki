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
{   Unit:        Scaffold.Model.pas                              }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   Domain model for the ScaffoldDemo project.
///   Defines the project template enum, optional features, and the
///   TScaffoldConfig data class that carries the user's choices from
///   the interactive wizard (Phase 1) to the install runner (Phase 2).
/// </summary>
unit Scaffold.Model;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

type

{ TScaffoldTemplate }

  /// <summary>
  ///   Available project templates for the new Blinki project.
  /// </summary>
  TScaffoldTemplate = (
    /// <summary>
    ///   Dashboard layout with charts and status widgets.
    /// </summary>
    stDashboard,
    /// <summary>
    ///   Data-entry form with inputs and buttons.
    /// </summary>
    stForm,
    /// <summary>
    ///   Minimal empty project with only the app entry point.
    /// </summary>
    stEmpty
  );

{ TScaffoldFeature }

  /// <summary>
  ///   Optional features that can be added to the new project.
  /// </summary>
  TScaffoldFeature = (
    /// <summary>
    ///   Apply TTuiTheme.Dark as the default theme.
    /// </summary>
    sfDarkTheme,
    /// <summary>
    ///   Include smoke-test and sample-app examples.
    /// </summary>
    sfExamples,
    /// <summary>
    ///   Initialise a git repository in the project folder.
    /// </summary>
    sfGit
  );

{ TScaffoldFeatures }

  /// <summary>
  ///   Set of optional features selected by the user.
  /// </summary>
  TScaffoldFeatures = set of TScaffoldFeature;

{ TScaffoldConfig }

  /// <summary>
  ///   Plain data object that carries the wizard choices.
  ///   Populated by TScaffoldForm.ApplyTo in Phase 1 and read by
  ///   TCliConsole in Phase 2.
  /// </summary>
  TScaffoldConfig = class
  strict private
    FConfirmed: Boolean;
    FFeatures: TScaffoldFeatures;
    FProjectName: string;
    FTemplate: TScaffoldTemplate;
  public
    /// <summary>
    ///   Creates a config with sensible defaults: project name
    ///   'my-blinki-app', Dashboard template, all features enabled.
    /// </summary>
    constructor Create;
    /// <summary>
    ///   Returns a short human-readable name for the selected template.
    /// </summary>
    function DescribeTemplate: string;
    /// <summary>
    ///   Returns a comma-separated list of the selected feature names,
    ///   or 'nessuna' when the feature set is empty.
    /// </summary>
    function DescribeFeatures: string;
    /// <summary>
    ///   True when the user confirmed the form; False when they cancelled.
    /// </summary>
    property Confirmed: Boolean read FConfirmed write FConfirmed;
    /// <summary>
    ///   Set of optional features the user selected.
    /// </summary>
    property Features: TScaffoldFeatures read FFeatures write FFeatures;
    /// <summary>
    ///   Name of the new project (used as the folder name and .dpr prefix).
    /// </summary>
    property ProjectName: string read FProjectName write FProjectName;
    /// <summary>
    ///   The selected project template.
    /// </summary>
    property Template: TScaffoldTemplate read FTemplate write FTemplate;
  end;

implementation

{ TScaffoldConfig }

constructor TScaffoldConfig.Create;
begin
  inherited Create;
  FProjectName := 'my-blinki-app';
  FTemplate := stDashboard;
  FFeatures := [sfDarkTheme, sfExamples, sfGit];
end;

function TScaffoldConfig.DescribeTemplate: string;
begin
  case FTemplate of
    stDashboard: Result := 'Dashboard';
    stForm:      Result := 'Form';
    stEmpty:     Result := 'Vuoto';
  end;
end;

function TScaffoldConfig.DescribeFeatures: string;
begin
  var LParts := '';
  if sfDarkTheme in FFeatures then
    LParts := LParts + 'Tema scuro';
  if sfExamples in FFeatures then
  begin
    if LParts <> '' then
      LParts := LParts + ', ';
    LParts := LParts + 'Esempi';
  end;
  if sfGit in FFeatures then
  begin
    if LParts <> '' then
      LParts := LParts + ', ';
    LParts := LParts + 'Git';
  end;
  if LParts = '' then
    Result := 'nessuna'
  else
    Result := LParts;
end;

end.
