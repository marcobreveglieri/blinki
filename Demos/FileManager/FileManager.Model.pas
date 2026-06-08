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
{   Unit:        FileManager.Model.pas                        }
{   Version:     0.1.0                                           }
{   Repository:  https://github.com/marcobreveglieri/blinki      }
{                                                                }
{   Copyright (c) 2026 Marco Breveglieri                         }
{                                                                }
{   Released under the MIT License - see LICENSE file            }
{                                                                }
{****************************************************************}

/// <summary>
///   FileManagerDemo — in-memory virtual file system.
///   No real files are touched; all operations work on the TVfsNode tree.
/// </summary>
unit FileManager.Model;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.Generics.Collections;

type

  TVfsKind = (vkFolder, vkFile);

  /// <summary>
  ///   Node in the virtual file system tree. Owns its children.
  ///   The Parent pointer is non-owning (not ref-counted).
  /// </summary>
  TVfsNode = class
  strict private
    FChildren: TObjectList<TVfsNode>;
    FKind: TVfsKind;
    FModified: TDateTime;
    FName: string;
    FParent: TVfsNode;
    FSize: Int64;
    function GetChildCount: Integer;
  public
    /// <summary>
    ///   Creates a node and registers it with AParent (if assigned).
    /// </summary>
    constructor Create(const AName: string; AKind: TVfsKind; ASize: Int64;
      AModified: TDateTime; AParent: TVfsNode = nil);
    destructor Destroy; override;
    /// <summary>
    ///   Sorts children: folders first, then alphabetically by name.
    /// </summary>
    procedure SortChildren;
    /// <summary>
    ///   Returns the full path with trailing slash for folders.
    /// </summary>
    function FullPath: string;
    /// <summary>
    ///   Returns the child index with the given name (-1 if not found).
    /// </summary>
    function IndexOfName(const AName: string): Integer;
    property Children: TObjectList<TVfsNode> read FChildren;
    property ChildCount: Integer read GetChildCount;
    property Kind: TVfsKind read FKind write FKind;
    property Modified: TDateTime read FModified write FModified;
    property Name: string read FName write FName;
    property Parent: TVfsNode read FParent;
    property Size: Int64 read FSize write FSize;
  end;

  /// <summary>
  ///   Owning root of the virtual file system.
  ///   Operations validate inputs and return False + AError on failure.
  /// </summary>
  TVirtualFileSystem = class
  strict private
    FRoot: TVfsNode;
    function DeepCopy(ASource, ADestParent: TVfsNode): TVfsNode;
    function IsAncestorOf(APossibleAncestor, ANode: TVfsNode): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Creates a new folder inside AParent. Returns nil on failure.
    /// </summary>
    function CreateFolder(AParent: TVfsNode; const AName: string;
      out AError: string): TVfsNode;
    /// <summary>
    ///   Renames ANode to ANewName. Returns False on failure.
    /// </summary>
    function Rename(ANode: TVfsNode; const ANewName: string;
      out AError: string): Boolean;
    /// <summary>
    ///   Deletes ANode (and all its descendants). Returns False on failure.
    /// </summary>
    function Delete(ANode: TVfsNode; out AError: string): Boolean;
    /// <summary>
    ///   Copies ANode into ADestFolder. Returns the new node, or nil on failure.
    /// </summary>
    function Copy(ANode: TVfsNode; ADestFolder: TVfsNode;
      out AError: string): TVfsNode;
    /// <summary>
    ///   Moves ANode into ADestFolder. Returns False on failure.
    /// </summary>
    function Move(ANode: TVfsNode; ADestFolder: TVfsNode;
      out AError: string): Boolean;
    property Root: TVfsNode read FRoot;
  end;

implementation

uses
  System.Generics.Defaults,
  System.SysUtils;

{ TVfsNode }

constructor TVfsNode.Create(const AName: string; AKind: TVfsKind; ASize: Int64;
  AModified: TDateTime; AParent: TVfsNode);
begin
  inherited Create;
  FName := AName;
  FKind := AKind;
  FSize := ASize;
  FModified := AModified;
  FParent := AParent;
  FChildren := TObjectList<TVfsNode>.Create(True);
  if Assigned(AParent) then
    AParent.FChildren.Add(Self);
end;

destructor TVfsNode.Destroy;
begin
  FreeAndNil(FChildren);
  inherited;
end;

function TVfsNode.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

procedure TVfsNode.SortChildren;
begin
  FChildren.Sort(TComparer<TVfsNode>.Construct(
    function(const A, B: TVfsNode): Integer
    begin
      if A.FKind <> B.FKind then
      begin
        if A.FKind = vkFolder then
          Result := -1
        else
          Result := 1;
        Exit;
      end;
      Result := CompareText(A.FName, B.FName);
    end));
end;

function TVfsNode.FullPath: string;
begin
  if not Assigned(FParent) then
  begin
    Result := '/';
    Exit;
  end;
  Result := FParent.FullPath;
  if Result <> '/' then
    Result := Result + '/';
  Result := Result + FName;
  if FKind = vkFolder then
    Result := Result + '/';
end;

function TVfsNode.IndexOfName(const AName: string): Integer;
begin
  for var LI := 0 to FChildren.Count - 1 do
    if SameText(FChildren[LI].FName, AName) then
      Exit(LI);
  Result := -1;
end;

{ TVirtualFileSystem }

constructor TVirtualFileSystem.Create;
begin
  inherited Create;
  FRoot := TVfsNode.Create('/', vkFolder, 0, Now, nil);
end;

destructor TVirtualFileSystem.Destroy;
begin
  FreeAndNil(FRoot);
  inherited;
end;

function TVirtualFileSystem.IsAncestorOf(APossibleAncestor, ANode: TVfsNode): Boolean;
begin
  var LCurrent := ANode;
  while Assigned(LCurrent) do
  begin
    if LCurrent = APossibleAncestor then
      Exit(True);
    LCurrent := LCurrent.Parent;
  end;
  Result := False;
end;

function TVirtualFileSystem.DeepCopy(ASource, ADestParent: TVfsNode): TVfsNode;
begin
  Result := TVfsNode.Create(ASource.Name, ASource.Kind, ASource.Size,
    ASource.Modified, ADestParent);
  if ASource.Kind = vkFolder then
    for var LI := 0 to ASource.Children.Count - 1 do
      DeepCopy(ASource.Children[LI], Result);
end;

function TVirtualFileSystem.CreateFolder(AParent: TVfsNode; const AName: string;
  out AError: string): TVfsNode;
begin
  Result := nil;
  if AName.Trim = '' then
  begin
    AError := 'Il nome della cartella non può essere vuoto';
    Exit;
  end;
  if AParent.IndexOfName(AName) >= 0 then
  begin
    AError := 'Esiste già un elemento con il nome "' + AName + '"';
    Exit;
  end;
  Result := TVfsNode.Create(AName, vkFolder, 0, Now, AParent);
  AParent.SortChildren;
  AError := '';
end;

function TVirtualFileSystem.Rename(ANode: TVfsNode; const ANewName: string;
  out AError: string): Boolean;
begin
  Result := False;
  if ANewName.Trim = '' then
  begin
    AError := 'Il nome non può essere vuoto';
    Exit;
  end;
  if SameText(ANode.Name, ANewName) then
  begin
    AError := '';
    Result := True;
    Exit;
  end;
  if Assigned(ANode.Parent) and (ANode.Parent.IndexOfName(ANewName) >= 0) then
  begin
    AError := 'Esiste già un elemento con il nome "' + ANewName + '"';
    Exit;
  end;
  ANode.Name := ANewName;
  if Assigned(ANode.Parent) then
    ANode.Parent.SortChildren;
  AError := '';
  Result := True;
end;

function TVirtualFileSystem.Delete(ANode: TVfsNode; out AError: string): Boolean;
begin
  Result := False;
  if not Assigned(ANode.Parent) then
  begin
    AError := 'Impossibile eliminare la cartella radice';
    Exit;
  end;
  // TObjectList with OwnsObjects=True frees the node when removed
  ANode.Parent.Children.Remove(ANode);
  AError := '';
  Result := True;
end;

function TVirtualFileSystem.Copy(ANode: TVfsNode; ADestFolder: TVfsNode;
  out AError: string): TVfsNode;
begin
  Result := nil;
  if ADestFolder = ANode.Parent then
  begin
    AError := 'L''elemento si trova già in questa cartella';
    Exit;
  end;
  if IsAncestorOf(ANode, ADestFolder) then
  begin
    AError := 'Impossibile copiare una cartella al suo interno';
    Exit;
  end;
  if ADestFolder.IndexOfName(ANode.Name) >= 0 then
  begin
    AError := 'Nella cartella di destinazione esiste già "' + ANode.Name + '"';
    Exit;
  end;
  Result := DeepCopy(ANode, ADestFolder);
  ADestFolder.SortChildren;
  AError := '';
end;

function TVirtualFileSystem.Move(ANode: TVfsNode; ADestFolder: TVfsNode;
  out AError: string): Boolean;
begin
  Result := False;
  if IsAncestorOf(ANode, ADestFolder) then
  begin
    AError := 'Impossibile spostare una cartella al suo interno';
    Exit;
  end;
  if ADestFolder.IndexOfName(ANode.Name) >= 0 then
  begin
    AError := 'Nella cartella di destinazione esiste già "' + ANode.Name + '"';
    Exit;
  end;
  // Copy to destination, then delete the original (avoids direct FParent mutation).
  var LNewNode := Copy(ANode, ADestFolder, AError);
  if not Assigned(LNewNode) then
    Exit;
  ANode.Parent.Children.Remove(ANode); // frees ANode (OwnsObjects=True)
  AError := '';
  Result := True;
end;

end.
