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
{   Unit:        Tetris.dpr                                      }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TetrisDemo -- Showcase demo for Blinki: classic Tetris game.
///
///   Demonstrates:
///   - Real-time game loop driven by DoTick (gravity, piece descent)
///   - Custom focusable widget TTetrisBoardView: handles all game input
///   - Per-cell coloured rendering with FillRect (2 columns per mino)
///   - Ghost piece, Next/Hold preview panels, Score/Level/Lines stats
///   - Full Tetris gameplay: 7-bag randomizer, SRS rotation with wall kick,
///     soft/hard drop, hold, line clear, levels, game over + restart
///
///   Keys:
///     Left / Right   -- move piece
///     Up / Z / X     -- rotate CW / CCW
///     Down           -- soft drop
///     Space          -- hard drop
///     Enter / C      -- hold piece
///     P / Esc        -- pause / resume
///     R              -- restart
///     Q / Esc        -- quit (when not paused, Esc quits; when paused, Esc unpauses)
///
///   Widget tree:
///     LRoot (TTuiVStack)
///       LMainRow (TTuiHStack)                            Fill(1)
///         LLeftMargin (TTuiVStack, empty)                Fill(1)
///         LCenterCol (TTuiVStack)                        Fixed(38)
///           LTitleView (TTetrisTitleView)                Fixed(7)
///           LTopSpacer (TTuiHStack, empty)               Fill(1)
///           LGameRow (TTuiHStack)                          Fixed(23)
///             LBoardBox (TTetrisBox, no title)             Fixed(22)
///               LBoardView (TTetrisBoardView)
///             LSideStack (TTuiVStack)                      Fixed(16)
///               LNextBox (TTetrisBox " Next ")             Fixed(6)
///                 LNextView (TTetrisPreviewView pkNext)
///               LHoldBox (TTetrisBox " Hold ")             Fixed(6)
///                 LHoldView (TTetrisPreviewView pkHold)
///               LStatsBox (TTetrisBox " Stats ")           Fill(1)
///                 LStatsView (TTetrisStatsView)
///           LBottomSpacer (TTuiHStack, empty)            Fill(1)
///         LRightMargin (TTuiVStack, empty)               Fill(1)
///       LHintBar (TTuiLabel)                            Fixed(1)
/// </summary>
program Tetris;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Blinki.Core.Ansi,
  Blinki.Core.App,
  Blinki.Core.Input,
  Blinki.Core.Widget,
  Blinki.Core.Geometry,
  Blinki.Core.Theme,
  Blinki.Widgets.Box,
  Blinki.Widgets.Labels,
  Blinki.Layout.Stack,
  Tetris.Consts in 'Tetris.Consts.pas',
  Tetris.Helpers in 'Tetris.Helpers.pas',
  Tetris.Model in 'Tetris.Model.pas',
  Tetris.View in 'Tetris.View.pas',
  Tetris.Audio in 'Tetris.Audio.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  Randomize;
  var LGame := TTetrisGame.Create;
  try
    {$IFDEF MSWINDOWS}
    var LAudio := TTetrisAudio.Create(ExtractFilePath(ParamStr(0)) + 'Sounds\');
    LGame.OnEvent := LAudio.HandleGameEvent;
    {$ENDIF}
    var LApp := TTuiApp.Create;
    var LRoot := TTuiVStack.Create;
    try
      // main row: left margin + center column + right margin
      var LMainRow := TTuiHStack.Create(LRoot);
      LMainRow.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      // left margin -- empty spacer that absorbs the leftover width
      var LLeftMargin := TTuiVStack.Create(LMainRow);
      LLeftMargin.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      // center column: fixed 38 wide (22 board + 16 side panel)
      var LCenterCol := TTuiVStack.Create(LMainRow);
      LCenterCol.LayoutConstraint := TTuiLayoutConstraint.Fixed(38);

      // title view: fixed 7 high -- animated ASCII art rainbow "TETRIS" header
      var LTitleView := TTetrisTitleView.Create(LCenterCol);
      LTitleView.LayoutConstraint := TTuiLayoutConstraint.Fixed(7);

      // top spacer -- empty, absorbs leftover height above the game
      var LTopSpacer := TTuiHStack.Create(LCenterCol);
      LTopSpacer.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      // game row: fixed 23 high (CBoardRows + 2 border lines)
      var LGameRow := TTuiHStack.Create(LCenterCol);
      LGameRow.LayoutConstraint := TTuiLayoutConstraint.Fixed(23);

      // board box: fixed 22 wide = CBoardCols * CCellWidth + 2 border
      var LBoardBox := TTetrisBox.Create(LGameRow);
      LBoardBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(22);

      var LBoardView := TTetrisBoardView.Create(LBoardBox);

      // side panel: fixed 16 wide
      var LSideStack := TTuiVStack.Create(LGameRow);
      LSideStack.LayoutConstraint := TTuiLayoutConstraint.Fixed(16);

      var LNextBox := TTetrisBox.Create(LSideStack);
      LNextBox.Title := ' Next ';
      LNextBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(6);

      var LNextView := TTetrisPreviewView.Create(pkNext, LNextBox);

      var LHoldBox := TTetrisBox.Create(LSideStack);
      LHoldBox.Title := ' Hold ';
      LHoldBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(6);

      var LHoldView := TTetrisPreviewView.Create(pkHold, LHoldBox);

      var LStatsBox := TTetrisBox.Create(LSideStack);
      LStatsBox.Title := ' Stats ';
      LStatsBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      var LStatsView := TTetrisStatsView.Create(LStatsBox);

      // bottom spacer -- empty, absorbs leftover height below the game
      var LBottomSpacer := TTuiHStack.Create(LCenterCol);
      LBottomSpacer.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      // right margin -- empty spacer that absorbs the leftover width
      var LRightMargin := TTuiVStack.Create(LMainRow);
      LRightMargin.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      // hint bar
      var LHintBar := TTuiLabel.Create(LRoot);
      LHintBar.Text := CHintText;
      LHintBar.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      // wire game to all views
      LBoardView.SetGame(LGame);
      LNextView.SetGame(LGame);
      LHoldView.SetGame(LGame);
      LStatsView.SetGame(LGame);

      // start a new game
      LGame.NewGame;

      // global key handler: only quit (game keys are handled by the focused board widget)
      LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        case AKey.Code of
          kcEscape:
            if LGame.State <> gsPaused then
              LApp.Quit;
          kcChar:
            if UpCase(AKey.Character) = 'Q' then
              LApp.Quit;
        end;
      end;

      LApp.SetRoot(LRoot);
      LApp.Run;

    finally
      {$IFDEF MSWINDOWS}
      LAudio.Free;
      {$ENDIF}
      LApp.Free;
    end;
  finally
    LGame.Free;
  end;
end.
