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
{   Unit:        DataViewer.dpr                                  }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   DataViewer — Sample app SAMPLE-03: CSV data viewer.
///
///   Loads data.csv with country data (name, population, GDP, area) and displays
///   them in a navigable table with a bar chart updated in real-time.
///   Verifies: TTuiTable, TTuiBarChart, data loading, runtime sort.
///
///   Keys:
///     Tab              -- focus on the table
///     Up/Down          -- navigate rows (when the table is focused)
///     S                -- cycle the sort column (Country/Population/GDP/Area)
///     R                -- reverse the sort order (asc/desc)
///     T                -- toggle Dark / Light theme
///     Q                -- quit
///
///   Layout:
///     LRoot (TTuiVStack)
///       LHeader (TTuiLabel)                          Fixed(1)
///       LBody (TTuiHStack)                           Fill(1)
///         LTableBox (TTuiBox 'Countries')            Fill(2)
///           LTable (TTuiTable)
///         LChartBox (TTuiBox 'Top 10 by Column')    Fixed(36)
///           LChart (TTuiBarChart)
///       LFooter (TTuiLabel)                          Fixed(1)
/// </summary>
program DataViewer;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  System.Math,
  System.StrUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  Blinki.Core.Input,
  Blinki.Core.Widget,
  Blinki.Core.App,
  Blinki.Core.Geometry,
  Blinki.Core.Ansi,
  Blinki.Core.Style,
  Blinki.Core.Theme,
  Blinki.Widgets.Labels,
  Blinki.Widgets.Box,
  Blinki.Widgets.BarChart,
  Blinki.Widgets.Table,
  Blinki.Layout.Stack;

type
  TCountryRow = record
    Country: string;
    Population: Double;
    GDP: Double;
    Area: Double;
  end;

var
  LApp: TTuiApp;
  LFooter: TTuiLabel;
  LTable: TTuiTable;
  LChart: TTuiBarChart;
  LDark: Boolean;
  LData: TList<TCountryRow>;
  LSortCol: Integer;
  LSortAsc: Boolean;

procedure LoadCSV(const AFileName: string);
begin
  LData.Clear;
  if not FileExists(AFileName) then
    Exit;
  var LLines := TStringList.Create;
  try
    LLines.LoadFromFile(AFileName);
    // Skip header row (index 0)
    for var LI: Integer := 1 to LLines.Count - 1 do
    begin
      var LLine := Trim(LLines[LI]);
      if LLine = '' then Continue;
      var LParts := LLine.Split([',']);
      if Length(LParts) < 4 then Continue;
      var LEntry: TCountryRow;
      LEntry.Country := Trim(LParts[0]);
      LEntry.Population := StrToFloatDef(Trim(LParts[1]), 0);
      LEntry.GDP := StrToFloatDef(Trim(LParts[2]), 0);
      LEntry.Area := StrToFloatDef(Trim(LParts[3]), 0);
      LData.Add(LEntry);
    end;
  finally
    LLines.Free;
  end;
end;

procedure SortData;
begin
  LData.Sort(TComparer<TCountryRow>.Construct(
    function(const A, B: TCountryRow): Integer
    begin
      var LCmp: Integer;
      case LSortCol of
        0: LCmp := CompareStr(A.Country, B.Country);
        1:
          if A.Population > B.Population then
            LCmp := 1
          else if A.Population < B.Population then
            LCmp := -1
          else
            LCmp := 0;
        2:
          if A.GDP > B.GDP then
            LCmp := 1
          else if A.GDP < B.GDP then
            LCmp := -1
          else
            LCmp := 0;
      else
        if A.Area > B.Area then
          LCmp := 1
        else if A.Area < B.Area then
          LCmp := -1
        else
          LCmp := 0;
      end;
      if LSortAsc then
        Result := LCmp
      else
        Result := -LCmp;
    end));
end;

procedure RefreshTable;
begin
  LTable.ClearRows;
  for var LI: Integer := 0 to LData.Count - 1 do
  begin
    var LRow: TArray<string> := TArray<string>.Create(
      LData[LI].Country,
      Format('%d', [Round(LData[LI].Population)]),
      Format('%d', [Round(LData[LI].GDP)]),
      Format('%d', [Round(LData[LI].Area)]));
    LTable.AddRow(LRow);
  end;
end;

procedure RefreshChart;
begin
  var LCount: Integer := Min(10, LData.Count);
  var LMax: Double := 1.0;
  for var LI: Integer := 0 to LCount - 1 do
  begin
    var LVal: Double;
    case LSortCol of
      0: LVal := LData[LI].Population;
      1: LVal := LData[LI].Population;
      2: LVal := LData[LI].GDP;
    else LVal := LData[LI].Area;
    end;
    if LVal > LMax then
      LMax := LVal;
  end;
  LChart.Clear;
  for var LI: Integer := 0 to LCount - 1 do
  begin
    var LVal: Double;
    case LSortCol of
      0: LVal := LData[LI].Population;
      1: LVal := LData[LI].Population;
      2: LVal := LData[LI].GDP;
    else LVal := LData[LI].Area;
    end;
    var LColor: TTuiColor := TTuiColor.RGB(
      Round(64 * (1 - LVal/LMax)),
      Round(150 + 100 * (LVal/LMax)),
      Round(200 * (1 - LVal/LMax)));
    LChart.AddBar(Copy(LData[LI].Country, 1, 6), LVal, LColor);
  end;
end;

const
  CSortCols: array[0..3] of string = ('Country', 'Population', 'GDP', 'Area');

begin
  ReportMemoryLeaksOnShutdown := True;
  LDark := True;
  LSortCol := 1;
  LSortAsc := False;

  LData := TList<TCountryRow>.Create;
  try
    // Look for data.csv in the current dir, then in the exe dir
    if FileExists('data.csv') then
      LoadCSV('data.csv')
    else
      LoadCSV(ExtractFilePath(ParamStr(0)) + 'data.csv');
    SortData;

    LApp := TTuiApp.Create;
    try
      var LRoot: TTuiVStack := TTuiVStack.Create;
      try
        var LHeader: TTuiLabel := TTuiLabel.Create(LRoot);
        LHeader.Text := ' Blinki Data Viewer -- World Countries | S=sort col  R=reverse  T=theme  Q=quit';
        LHeader.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

        var LBody: TTuiHStack := TTuiHStack.Create(LRoot);
        LBody.LayoutConstraint := TTuiLayoutConstraint.Fill(1);

        // ---- Table column ----
        var LTableBox: TTuiBox := TTuiBox.Create(LBody);
        LTableBox.Title := ' Countries ';
        LTableBox.BoxStyle := bsRounded;
        LTableBox.LayoutConstraint := TTuiLayoutConstraint.Fill(2);

        LTable := TTuiTable.Create(LTableBox);
        LTable.ShowHeader := True;
        LTable.ShowBorder := False;
        LTable.AddColumn('Country', 16, taLeft);
        LTable.AddColumn('Pop (M)', 8, taRight);
        LTable.AddColumn('GDP ($B)', 9, taRight);
        LTable.AddColumn('Area (K)', 9, taRight);

        // ---- Chart column ----
        var LChartBox: TTuiBox := TTuiBox.Create(LBody);
        LChartBox.Title := ' Top 10 ';
        LChartBox.BoxStyle := bsRounded;
        LChartBox.LayoutConstraint := TTuiLayoutConstraint.Fixed(36);

        LChart := TTuiBarChart.Create(LChartBox);
        LChart.Title := '';
        LChart.ShowYAxis := True;
        LChart.ShowLabels := True;

        LFooter := TTuiLabel.Create(LRoot);
        LFooter.LayoutConstraint := TTuiLayoutConstraint.Fixed(1);

        RefreshTable;
        RefreshChart;

        LFooter.Text := Format(' Sort: %s %s | %d countries loaded',
          [CSortCols[LSortCol], IfThen(LSortAsc, '[asc]', '[desc]'), LData.Count]);

        // ---- App setup: da qui LApp possiede LRoot ----
        LApp.SetRoot(LRoot);
      except
        LRoot.Free;
        raise;
      end;

      LApp.OnKeyPress := procedure(const AKey: TTuiKeyEvent)
        begin
          if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'Q') then
            LApp.Quit
          else if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'T') then
          begin
            LDark := not LDark;
            if LDark then
              LApp.Theme := TTuiTheme.Dark
            else
              LApp.Theme := TTuiTheme.Light;
          end
          else if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'S') then
          begin
            LSortCol := (LSortCol + 1) mod 4;
            SortData;
            RefreshTable;
            RefreshChart;
            LFooter.Text := Format(' Sort: %s %s | %d countries loaded',
              [CSortCols[LSortCol], IfThen(LSortAsc, '[asc]', '[desc]'), LData.Count]);
          end
          else if (AKey.Code = kcChar) and (UpCase(AKey.Character) = 'R') then
          begin
            LSortAsc := not LSortAsc;
            SortData;
            RefreshTable;
            RefreshChart;
            LFooter.Text := Format(' Sort: %s %s | %d countries loaded',
              [CSortCols[LSortCol], IfThen(LSortAsc, '[asc]', '[desc]'), LData.Count]);
          end;
        end;

      LApp.Run;
    finally
      LApp.Free;
    end;
  finally
    LData.Free;
  end;
end.
