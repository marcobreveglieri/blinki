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
{   Unit:        TeamChat.dpr                                    }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   TeamChatDemo -- Showcase demo for Blinki: Chat/IM client in Slack/Discord style.
///
///   Demonstrates:
///   - Composition of stock widgets (TTuiSelect, TTuiTextInput, TTuiBox, Stack, TTuiLabel)
///   - Custom widget TChatView: message history scroll with adaptive word-wrap,
///     animated "is typing..." indicator via DoTick, automatic follow-tail,
///     manual scroll support
///   - Simulated activity via OnTimer: bots writing, unread badges,
///     automatic reply to user messages, status bar notification
///   - Terminal resize handled automatically by the Stacks
///   - Hot dark / light theme toggle
///
///   Keys:
///     Tab / Shift-Tab  -- cycle focus among channel list, chat, message input
///     Up / Down        -- scroll history (chat focused)
///     PgUp / PgDn      -- scroll by page (chat focused)
///     Home             -- jump to beginning of history
///     End              -- jump to tail (activates follow-tail)
///     Enter            -- send the typed message (text input focused)
///     T                -- toggle Dark / Light theme
///     Q / Esc          -- quit
///
///   Widget tree:
///     LRoot (TTuiVStack)
///       LMainRow (TTuiHStack)                     Fill(1)
///         LChannelBox (TTuiBox "Channels")         Fixed(22)  bsRounded
///           LChannelSel (TTuiSelect)
///         LRightStack (TTuiVStack)                 Fill(1)
///           LChatBox (TTuiBox "# general")         Fill(1)    bsSingle
///             LChatView (TChatView)
///           LInputBox (TTuiBox "Message")          Fixed(3)   bsRounded
///             LMsgInput (TTuiTextInput)
///       LHintBar (TTuiLabel)                       Fixed(1)
/// </summary>
program TeamChat;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Blinki.Core.Ansi,
  Blinki.Core.Input,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Event,
  Blinki.Core.Geometry,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Box,
  Blinki.Widgets.Select,
  Blinki.Widgets.TextInput,
  Blinki.Layout.Stack,
  TeamChat.Model in 'TeamChat.Model.pas',
  TeamChat.Helpers in 'TeamChat.Helpers.pas',
  TeamChat.View in 'TeamChat.View.pas',
  TeamChat.Consts in 'TeamChat.Consts.pas';

// ============================================================================
// Main body
// ============================================================================

begin
  ReportMemoryLeaksOnShutdown := True;
  Randomize;
  var LDark := True;

  // ---- create channels and populate with initial messages ----
  var LChannels := TObjectList<TChatChannel>.Create(True);
  var LActiveIdx := 0;
  try

    LChannels.Add(TChatChannel.Create('# general', False));
    LChannels.Add(TChatChannel.Create('# random', False));
    LChannels.Add(TChatChannel.Create('# development', False));
    LChannels.Add(TChatChannel.Create('@ marco', True));
    LChannels.Add(TChatChannel.Create('@ laura', True));

    // seed #general
    with LChannels[0] do
    begin
      Messages.Add(TChatMsg.Make('alice', '10:28',
        'Good morning, everyone!', mkOther));
      Messages.Add(TChatMsg.Make('bob', '10:29',
        'Hi! Ready for the daily?', mkOther));
      Messages.Add(TChatMsg.Make('carlo', '10:30',
        'I''m here, five minutes', mkOther));
      Messages.Add(TChatMsg.Make('', '10:31',
        'you joined the channel', mkSystem));
      Messages.Add(TChatMsg.Make('alice', '10:32',
        'I pushed the feature branch last night, can someone take a look?',
        mkOther));
      Messages.Add(TChatMsg.Make('you', '10:33',
        'Sure, I''ll look at it after the daily', mkMe));
      Messages.Add(TChatMsg.Make('bob', '10:35',
        'Great, thanks! Meanwhile I opened the PR', mkOther));
    end;

    // seed #random
    with LChannels[1] do
    begin
      Messages.Add(TChatMsg.Make('bob', '10:15',
        'Did you hear a new place is opening near the office?', mkOther));
      Messages.Add(TChatMsg.Make('carlo', '10:16',
        'Just what we needed', mkOther));
      Messages.Add(TChatMsg.Make('alice', '10:17',
        'Not bad, shall we go this week?', mkOther));
    end;

    // seed #development
    with LChannels[2] do
    begin
      Messages.Add(TChatMsg.Make('carlo', '09:45',
        'Found a bug in the renderer, I''ll fix it this morning', mkOther));
      Messages.Add(TChatMsg.Make('alice', '09:47',
        'Oh right, it''s been on the TODO for a while', mkOther));
      Messages.Add(TChatMsg.Make('', '09:52',
        'commit: fix: corrected off-by-one in the layout solver', mkSystem));
      Messages.Add(TChatMsg.Make('carlo', '09:55',
        'Pushed, build green', mkOther));
      Messages.Add(TChatMsg.Make('you', '09:56',
        'Great work!', mkMe));
    end;

    // seed @marco
    with LChannels[3] do
    begin
      Messages.Add(TChatMsg.Make('marco', '10:00',
        'Hi! Did you look at the PR I opened yesterday?', mkOther));
      Messages.Add(TChatMsg.Make('you', '10:01',
        'Yes, I''ll review it today', mkMe));
      Messages.Add(TChatMsg.Make('marco', '10:02',
        'Thanks! Let me know if you need anything', mkOther));
    end;

    // seed @laura
    with LChannels[4] do
    begin
      Messages.Add(TChatMsg.Make('laura', '09:50',
        'Hi! Is the demo for tomorrow ready?', mkOther));
      Messages.Add(TChatMsg.Make('you', '09:51',
        'Almost, I''m finishing the last part', mkMe));
      Messages.Add(TChatMsg.Make('laura', '09:52',
        'Perfect, I''m counting on it!', mkOther));
    end;

    // ---- build widget tree ----
    var LApp := TTuiApp.Create;
    var LRoot := TTuiVStack.Create;
    try
      // main row
      var LMainRow := TTuiHStack.Create(LRoot);
      LMainRow.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      // left column: channel list
      var LChannelBox := TTuiBox.Create(LMainRow);
      LChannelBox.Title := ' Channels ';
      LChannelBox.BoxStyle := bsRounded;
      LChannelBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(22);

      var LChannelSel := TTuiSelect.Create(LChannelBox);

      // right column: chat + message input
      var LRightStack := TTuiVStack.Create(LMainRow);
      LRightStack.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      var LChatBox := TTuiBox.Create(LRightStack);
      LChatBox.Title := ' ' + LChannels[0].Display + ' ';
      LChatBox.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

      var LChatView := TChatView.Create(LChatBox);

      var LInputBox := TTuiBox.Create(LRightStack);
      LInputBox.Title := ' Message ';
      LInputBox.BoxStyle := bsRounded;
      LInputBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(3);

      var LMsgInput := TTuiTextInput.Create(LInputBox);
      LMsgInput.Placeholder := 'Type a message and press Enter...';
      LMsgInput.MaxLength := 240;

      // hint bar
      var LHintBar := TTuiLabel.Create(LRoot);
      LHintBar.Text := CHintText;
      LHintBar.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

      // ---- bot state initialization ----
      // declared before any closure so all anonymous methods can capture them
      var LBotState := 0;           // 0=idle, 1=writing
      var LBotAccumMs := 0;
      var LBotIntervalMs := 3000 + Random(4000);
      var LBotChanIdx := 0;
      var LBotAuthor := '';
      var LBotTypingMs := 0;
      var LReplyPending := False;
      var LReplyAccumMs := 0;
      var LReplyDelayMs := 0;
      var LReplyChanIdx := 0;
      var LReplyAuthor := '';
      var LReplyTyping := False;    // True when BeginTyping has already been called for the reply

      // ---- helper: update channel list in the Select ----
      var LRefreshChannels: TProc := procedure
      begin
        var LSaved := LChannelSel.OnChange;
        LChannelSel.OnChange := nil;
        try
          LChannelSel.Items.BeginUpdate;
          try
            LChannelSel.Items.Clear;
            for var LI := 0 to LChannels.Count - 1 do
            begin
              var LItem := LChannels[LI].Display;
              if LChannels[LI].Unread > 0 then
                LItem := LItem + '  *' + IntToStr(LChannels[LI].Unread);
              LChannelSel.Items.Add(LItem);
            end;
          finally
            LChannelSel.Items.EndUpdate;
          end;
          LChannelSel.ItemIndex := LActiveIdx;
        finally
          LChannelSel.OnChange := LSaved;
        end;
      end;

      // initial population
      LRefreshChannels();
      LChatView.SetChannel(LChannels[0]);

      // ---- channel switch ----
      LChannelSel.OnChange := procedure(AIdx: Integer)
      begin
        LActiveIdx := AIdx;
        LChannels[AIdx].Unread := 0;
        LChatView.EndTyping;
        LChatView.SetChannel(LChannels[AIdx]);
        LChatBox.Title := ' ' + LChannels[AIdx].Display + ' ';
        LHintBar.Text := CHintText;
        LRefreshChannels();
      end;

      // ---- send message ----
      LMsgInput.OnSubmit := procedure(AText: string)
      begin
        var LTrimmed := Trim(AText);
        if LTrimmed = '' then
          Exit;
        LChatView.AppendMessage(
          TChatMsg.Make('you', FormatDateTime('hh:nn', Now), LTrimmed, mkMe));
        LMsgInput.Text := '';
        // schedule auto-reply if not already in progress
        if not LReplyPending then
        begin
          LReplyPending := True;
          LReplyTyping := False;
          LReplyChanIdx := LActiveIdx;
          LReplyDelayMs := 1500 + Random(2000);
          LReplyAccumMs := 0;
          case LReplyChanIdx of
            0: LReplyAuthor := CBotAuthors0[Random(3)];
            1: LReplyAuthor := CBotAuthors1[Random(2)];
            2: LReplyAuthor := CBotAuthors2[Random(2)];
            3: LReplyAuthor := 'marco';
          else   LReplyAuthor := 'laura';
          end;
        end;
      end;

      // ---- timer: simulated activity ----
      LApp.OnTimer := procedure(AElapsedMs: Integer)
      begin
        var LTime := FormatDateTime('hh:nn', Now);

        // -- user reply --
        if LReplyPending then
        begin
          Inc(LReplyAccumMs, AElapsedMs);

          // start typing indicator at half the delay
          if (not LReplyTyping) and (LReplyAccumMs >= LReplyDelayMs div 2) then
          begin
            LReplyTyping := True;
            if LReplyChanIdx = LActiveIdx then
              LChatView.BeginTyping(LReplyAuthor);
          end;

          // post the message
          if LReplyAccumMs >= LReplyDelayMs then
          begin
            LReplyPending := False;
            LReplyTyping := False;
            var LBotMsg := TChatMsg.Make(LReplyAuthor, LTime,
              CDMReplies[Random(5)], mkOther);
            if LReplyChanIdx = LActiveIdx then
            begin
              LChatView.EndTyping;
              LChatView.AppendMessage(LBotMsg);
            end
            else
            begin
              LChannels[LReplyChanIdx].Messages.Add(LBotMsg);
              Inc(LChannels[LReplyChanIdx].Unread);
              LHintBar.Text := ' Reply in ' + LChannels[LReplyChanIdx].Display +
                '  |  Tab switch channel  |  Q quit';
              LRefreshChannels();
            end;
          end;
        end;

        // -- independent bot activity (channels 0,1,2) --
        case LBotState of
          0: // idle
          begin
            Inc(LBotAccumMs, AElapsedMs);
            if LBotAccumMs >= LBotIntervalMs then
            begin
              LBotAccumMs := 0;
              LBotIntervalMs := 2500 + Random(5000);
              LBotChanIdx := Random(3);
              case LBotChanIdx of
                0: LBotAuthor := CBotAuthors0[Random(3)];
                1: LBotAuthor := CBotAuthors1[Random(2)];
              else   LBotAuthor := CBotAuthors2[Random(2)];
              end;
              LBotTypingMs := 900 + Random(1200);
              LBotState := 1;
              if LBotChanIdx = LActiveIdx then
                LChatView.BeginTyping(LBotAuthor);
            end;
          end;

          1: // writing
          begin
            Inc(LBotAccumMs, AElapsedMs);
            if LBotAccumMs >= LBotTypingMs then
            begin
              LBotAccumMs := 0;
              LBotState := 0;
              var LMsg: string;
              case LBotChanIdx of
                0: LMsg := CBotMsgs0[Random(8)];
                1: LMsg := CBotMsgs1[Random(6)];
              else   LMsg := CBotMsgs2[Random(6)];
              end;
              var LBotMsg := TChatMsg.Make(LBotAuthor, LTime, LMsg, mkOther);
              if LBotChanIdx = LActiveIdx then
              begin
                LChatView.EndTyping;
                LChatView.AppendMessage(LBotMsg);
              end
              else
              begin
                LChannels[LBotChanIdx].Messages.Add(LBotMsg);
                Inc(LChannels[LBotChanIdx].Unread);
                LHintBar.Text := ' New in ' + LChannels[LBotChanIdx].Display +
                  '  |  Tab focus  |  Up/Down scroll  |  Enter sends  |  T theme  |  Q quit';
                LRefreshChannels();
              end;
            end;
          end;
        end;
      end;

      // ---- global key handling ----
      LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
      begin
        case AKey.Code of
          kcEscape:
            LApp.Quit;
          kcChar:
            case UpCase(AKey.Character) of
              'Q': LApp.Quit;
              'T':
              begin
                LDark := not LDark;
                if LDark then
                  LApp.Theme := TTuiTheme.Dark
                else
                  LApp.Theme := TTuiTheme.Light;
                LHintBar.Text := CHintText;
              end;
            end;
        end;
      end;

      // ---- start ----
      LApp.SetRoot(LRoot);
      LApp.Run;

    finally
      LApp.Free;
    end;
  finally
    LChannels.Free;
  end;
end.
