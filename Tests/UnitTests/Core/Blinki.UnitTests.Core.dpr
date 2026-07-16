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
{   Unit:        BlinkiUnitTests.dpr                             }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   DUnitX console test runner for the Blinki library. Executes every
///   registered test fixture and sets the process exit code to a non-zero
///   value when any test fails, so the run can gate a CI/MSBuild pipeline.
/// </summary>
program Blinki.UnitTests.Core;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  Blinki.UnitTests.Core.Ansi in 'Blinki.UnitTests.Core.Ansi.pas',
  Blinki.UnitTests.Core.Emoji in 'Blinki.UnitTests.Core.Emoji.pas',
  Blinki.UnitTests.Core.Geometry in 'Blinki.UnitTests.Core.Geometry.pas',
  Blinki.UnitTests.Core.Render in 'Blinki.UnitTests.Core.Render.pas',
  Blinki.UnitTests.Core.Unicode in 'Blinki.UnitTests.Core.Unicode.pas';

begin
  try
    var LRunner: ITestRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.FailsOnNoAsserts := False;

    var LLogger: ITestLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);

    var LResults: IRunResults := LRunner.Execute;
    if not LResults.AllPassed then
      System.ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
  {$IFNDEF CI}
  Readln;
  {$ENDIF}
end.
