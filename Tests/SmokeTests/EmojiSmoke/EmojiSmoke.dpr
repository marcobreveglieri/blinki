/// <summary>
///   EmojiSmoke — Interactive smoke test for Blinki extended emoji support.
///
///   Visually verifies:
///   - EMOJI-01: astral-plane emoji (surrogate pairs) render as one 2-column
///               glyph with correct alignment (pipe markers must line up)
///   - EMOJI-02: VS16 sequences, flags (regional indicators), skin tones and
///               ZWJ families render without splitting; alignment respects
///               the detected TTuiUnicode.EmojiLevel (toggle with L)
///   - EMOJI-03: emoji in DrawBox titles stay centred and intact
///   - EMOJI-04: shortcode expansion via TTuiEmoji.Expand
///   - EMOJI-05: typing/pasting emoji in the input line arrives as whole
///               code points (surrogate reassembly); Backspace removes a
///               whole cluster; the diff renderer leaves no artifacts
///
///   Run in Windows Terminal (elFull) and in legacy conhost (elBasic) and
///   compare: layout must stay aligned in both.
/// </summary>
program EmojiSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Blinki.Core.Ansi,
  Blinki.Core.Canvas,
  Blinki.Core.Console,
  Blinki.Core.Emoji,
  Blinki.Core.Input,
  Blinki.Core.Render,
  Blinki.Core.Style,
  Blinki.Core.Unicode;

const
  SampleRows: array[0..4] of string = (
    'Simple:  |' + #$D83D#$DE00 + '|' + #$D83D#$DE80 + '|' + #$D83D#$DD25 +
      '|' + #$2B50 + '|',
    'VS16:    |' + #$2600#$FE0F + '|' + #$2764#$FE0F + '|' + #$2699#$FE0F +
      '|' + #$26A0#$FE0F + '|',
    'Flags:   |' + #$D83C#$DDEE#$D83C#$DDF9 + '|' + #$D83C#$DDE9#$D83C#$DDEA +
      '|' + #$D83C#$DDEB#$D83C#$DDF7 + '|',
    'Tones:   |' + #$D83D#$DC4D + '|' + #$D83D#$DC4D#$D83C#$DFFB +
      '|' + #$D83D#$DC4D#$D83C#$DFFD + '|' + #$D83D#$DC4D#$D83C#$DFFF + '|',
    'ZWJ:     |' + #$D83D#$DC68#$200D#$D83D#$DC69#$200D#$D83D#$DC67 +
      '|' + #$D83D#$DC69#$200D#$D83D#$DCBB + '|'
  );

  EmojiLevelNames: array[TTuiEmojiLevel] of string = ('None', 'Basic', 'Full');

var
  LBackend: ITuiConsoleBackend;
  LCanvas: TTuiCanvas;
  LKey: TTuiKeyEvent;
  LRunning: Boolean;
  LInput: string;
begin
  ReportMemoryLeaksOnShutdown := True;

  LBackend := TTuiConsoleBackendFactory.CreateBackend;
  try
    LBackend.Open;
    LBackend.Write(TTuiAnsi.AlternateBufferOn);
    LBackend.Write(TTuiAnsi.CursorHide);
    LBackend.Write(TTuiAnsi.SetTitle('Blinki — Emoji Smoke Test'));
    LCanvas := TTuiCanvas.Create(LBackend);
    try
      LInput := '';
      LRunning := True;

      while LRunning do
      begin
        if LBackend.TryReadKey(50, LKey) then
        begin
          case LKey.Code of
            kcEscape:
              LRunning := False;
            kcBackspace:
              if LInput <> '' then
              begin
                var LStart := TTuiUnicode.PrevGraphemeBoundary(LInput, Length(LInput) + 1);
                Delete(LInput, LStart, Length(LInput) - LStart + 1);
              end;
            kcChar, kcSpace:
              begin
                // L toggles the emoji level to compare alignment policies
                if (LKey.Code = kcChar) and (UpCase(LKey.Character) = 'L') then
                begin
                  if TTuiUnicode.EmojiLevel = elFull then
                    TTuiUnicode.EmojiLevel := elBasic
                  else
                    TTuiUnicode.EmojiLevel := elFull;
                end
                else if (LKey.Code = kcChar) and (UpCase(LKey.Character) = 'Q') then
                  LRunning := False
                else
                  LInput := LInput + LKey.CharText;
              end;
          end;
        end;

        if not LRunning then
          Break;

        LCanvas.HandleResize;
        LCanvas.Clear;

        // EMOJI-03: emoji in a box title
        var LBoxRect := TRect.Create(1, 1, LCanvas.Width - 1, 12);
        LCanvas.DrawBox(LBoxRect, bsRounded,
          TTuiEmoji.Expand(':rocket: Emoji :sparkles:'),
          TTuiStyle.Create(TTuiColors.BrightCyan, TTuiColor.Default));

        // EMOJI-01/02: alignment grid — all pipes of a row must line up,
        // and the text after each sample must start at the same column.
        for var LRow := 0 to High(SampleRows) do
        begin
          var LSample := SampleRows[LRow];
          LCanvas.WriteAt(3, 2 + LRow, LSample,
            TTuiStyle.Create(TTuiColors.White, TTuiColor.Default));
          LCanvas.WriteAt(3 + TTuiAnsi.VisibleLength(LSample) + 1, 2 + LRow,
            '<- width ' + IntToStr(TTuiAnsi.VisibleLength(LSample)),
            TTuiStyle.Create(TTuiColors.BrightBlack, TTuiColor.Default));
        end;

        // EMOJI-04: shortcode expansion
        LCanvas.WriteAt(3, 8,
          TTuiEmoji.Expand('Shortcodes: :check_mark_button: build :bug: fix ' +
            ':flag_it: locale :thumbs_up:'),
          TTuiStyle.Create(TTuiColors.BrightGreen, TTuiColor.Default));

        // Detected terminal capability
        LCanvas.WriteAt(3, 10,
          'EmojiLevel: ' + EmojiLevelNames[TTuiUnicode.EmojiLevel] +
          '   (press L to toggle)',
          TTuiStyle.Create(TTuiColors.BrightYellow, TTuiColor.Default));

        // EMOJI-05: type or paste emoji here
        if LCanvas.Height > 14 then
        begin
          LCanvas.WriteAt(1, 13, 'Type here (emoji ok, Backspace removes a cluster):',
            TTuiStyle.Create(TTuiColors.BrightBlack, TTuiColor.Default));
          var LPrompt := '> ' + LInput + '_';
          LCanvas.WriteAt(1, 14, TTuiAnsi.TruncateToWidth(LPrompt, LCanvas.Width - 2),
            TTuiStyle.Create(TTuiColors.White, TTuiColor.Default));
        end;

        if LCanvas.Height > 16 then
          LCanvas.WriteAt(1, LCanvas.Height - 1, 'Q/ESC to quit',
            TTuiStyle.Create(TTuiColors.BrightBlack, TTuiColor.Default));

        LCanvas.Flush;
      end;

    finally
      LCanvas.Free;
      LBackend.Write(TTuiAnsi.CursorShow);
      LBackend.Write(TTuiAnsi.AlternateBufferOff);
      LBackend.Write(TTuiAnsi.Reset);
      LBackend.Close;
    end;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, 'ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
