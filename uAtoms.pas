{
******************************************************
  Atoms Game
  By Bennyboy
  Http://quickandeasysoftware.net
******************************************************
}
{
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
}

{
  Atom rules:
  1 on corners
  2 on edges
  3 everywhere else

  Arrays are row major order in Delphi https://en.wikipedia.org/wiki/Row-major_order
  So really its [row,column] but we write it y,x not x,y due to how its stored in memory
}

unit uAtoms;

interface

uses
  Classes, Contnrs, SysUtils, System.UITypes, Generics.Collections;

type
  EAtomsError = class (exception);
  T2dArray = array of array of integer;
  TPlayerChangedEvent = procedure(PlayerNum: integer; PlayerColour: TColor) of object;
  TBoardChangedEvent = procedure(y, x, value: integer; Colour: TColor) of object;
  TGameWonEvent = procedure(PlayerName: string) of object;
  TGameBusyEvent = procedure(Busy: boolean) of object;

  TAtomsPlayer = class
  public
    Colour: TColor;
    AtomCount: integer;
    Dead: boolean;
  end;

  TAtomsGame = class
  private
    FPlayerChanged: TPlayerChangedEvent;
    FBoardChanged: TBoardChangedEvent;
    FGameWon: TGameWonEvent;
    FBusy: TGameBusyEvent;
    FPlayers: TObjectList<TAtomsPlayer>;//Will free owned objects automatically
    FAtomsArray: array [0..6, 0..6, 0..1] of integer; //3rd dimension is the player number for that square
    FCurrentPlayer, FTurnNum: integer;
    FBoardWidth, FBoardHeight: integer;
    function IsCornerAtom(y, x: integer): boolean;
    function IsEdgeAtom(y, x: integer): boolean;
    function CheckIfSomeoneWon: integer;
    function FindOverloadedAtoms: T2dArray;
    procedure Explode(y, x: integer);
    procedure ChangePlayer;
    procedure CheckForDeaths;
    procedure IncAtom(y, x: integer);
    procedure ChangeAtom(y, x, NewValue: integer);
    procedure UpdateAtomCounts;
    procedure ResetGame;
  public
    constructor Create(NumPlayers: integer);
    destructor Destroy; override;
    procedure AddAtom(y, x: integer);
    procedure StartGame;
    property PlayerChanged: TPlayerChangedEvent read FPlayerChanged write FPlayerChanged;
    property BoardChanged: TBoardChangedEvent read FBoardChanged write FBoardChanged;
    property GameWon: TGameWonEvent read FGameWon write FGameWon;
    property GameBusy: TGameBusyEvent read FBusy write FBusy;
    property BoardWidth: integer read FBoardWidth;
    property BoardHeight: integer read FBoardHeight;
    property TurnNum: integer read FTurnNum;
  const
    FMaxPlayers: integer = 4;
    FColours: array [0..3] of TColor = ($231DFF, $FF8E2F, $4FFF1D, $1DCEFF);
  end;

implementation

constructor TAtomsGame.Create(NumPlayers: integer);
var
  i: integer;
  NewPlayer: TAtomsPlayer;
begin
  if NumPlayers <1 then
    raise EAtomsError.Create('Must be 1 or more players!');

  if NumPlayers > FMaxPlayers then
    raise EAtomsError.Create('Max players is currently limited to ' + IntToStr(fMaxPlayers));

  FPlayers := TObjectList<TAtomsPlayer>.Create;
  for I := 0 to NumPlayers -1 do
  begin
    NewPlayer := TAtomsPlayer.Create;
    NewPlayer.Colour := FColours[i];
    FPlayers.Add(NewPlayer);
  end;

  FCurrentPlayer := 1;
  FBoardWidth := 7;
  FBoardHeight := 7;
end;

destructor TAtomsGame.Destroy;
begin
  if FPlayers <> nil then
  begin
    FPlayers.Free;
    FPlayers:=nil;
  end;
  inherited;
end;

procedure TAtomsGame.AddAtom(y, x: integer);
var
  OverloadedAtoms: T2dArray;
  i, Winner: integer;
begin
  //Check that player is clicking on their atom or an empty cell
  if FAtomsArray[y, x, 1] = 0 then //no atom in this cell
  else
  if FAtomsArray[y, x, 1] <> FCurrentPlayer then //clicking on atoms that arent yours!
  begin
    exit;
  end;

  //Stop other clicks while explosions are happening
  if Assigned(FBusy) then
    FBusy(True);


  inc(FTurnNum);

  IncAtom(y, x);

  //Update the board to change colour
  FBoardChanged(y, x,  FAtomsArray[y, x, 0], FPlayers[FCurrentPlayer -1].Colour);


  //Check if in corner
  if IsCornerAtom(y, x) then
  begin
    if FAtomsArray[y, x, 0] > 1 then //Check if already contains atom
      Explode(y, x);
  end
  else //Check if on edge
  if IsEdgeAtom(y, x) then
  begin
    if FAtomsArray[y, x, 0] > 2 then
      Explode (y, x);
  end
  else //Must be a central atom
    if FAtomsArray[y, x, 0] > 3 then
      Explode(y, x);

  //Update atom counts
  UpdateAtomCounts;

  //Check for deaths only once everyones had 1 turn or more
  if FTurnNum > FPlayers.Count then
    CheckForDeaths;

  //Check if anyone's won after the initial explosions
  if FTurnNum > FPlayers.Count then
  begin
    Winner := CheckIfSomeoneWon;
    if Winner > -1 then
    begin
      if Assigned(FGameWon ) then
	      FGameWon( inttostr(Winner) );

      exit;
    end;
  end;

  //Now check for overloaded atoms and explode any that are overloaded
  //Keep looping checking and exploding until there's no more overloaded atoms
  while true do
  begin
    OverloadedAtoms := FindOverloadedAtoms;
    if length(OverloadedAtoms) = 0 then
      break;

    //sleep(200); //Give us time to see it exploding
    for I := 0 to length(OverloadedAtoms) -1 do
    begin
      Explode(OverloadedAtoms[i,0], OverloadedAtoms[i, 1] );

      UpdateAtomCounts;
      CheckForDeaths;
      //Check for a winner
      Winner := CheckIfSomeoneWon;
      if Winner <> -1 then
      begin
        if Assigned(FGameWon ) then
	        FGameWon( inttostr(Winner) );

        exit;
      end;

    end;
  end;

  //Change to the next player
  ChangePlayer;
  if Assigned(FBusy) then
    FBusy(False);

end;

procedure TAtomsGame.ChangePlayer;
var
  NumAlivePlayers, NextPlayer: integer;
  Player: TAtomsPlayer;
begin
  //First work out how many alive players there are
  NumAlivePlayers := 0;
  for Player in FPlayers do
    if Player.Dead = false then
      inc(NumAlivePlayers);

  if NumAlivePlayers < 2 then
    exit; //Only 1 player left! TODO raise error here


  //Loop until we've got the next player thats alive
  NextPlayer := FCurrentPlayer + 1 ; //List is 0 indexed so will be 1 more than CurrentPlayer
  while True do
  begin
    if NextPlayer > FPlayers.Count then //Currently at the end of the list so loop around again
      NextPlayer := 1;

    if FPlayers[NextPlayer -1].Dead = false then
    begin
      FCurrentPlayer := NextPlayer;
      break;
    end
    else
      inc(NextPlayer);
  end;

  if Assigned(FPlayerChanged) then
    FPlayerChanged(FCurrentPlayer, FPlayers[FCurrentPlayer -1].Colour);
end;

procedure TAtomsGame.CheckForDeaths;
var
  Player: TAtomsPlayer;
begin
  for Player in FPlayers do
    if Player.AtomCount = 0 then
      Player.Dead := true;
end;

function TAtomsGame.CheckIfSomeoneWon: integer;
var
  Player: TAtomsPlayer;
  AlivePlayers, AlivePlayer: integer;
begin
  result := -1;
  AlivePlayer := -1;
  AlivePlayers := 0;

  for Player in FPlayers do
    if Player.Dead = false then
    begin
      inc(AlivePlayers);
      AlivePlayer :=  FPlayers.IndexOf(Player); //TODO Silly - should just rewrite loop to be a normal for loop
    end;

  if AlivePlayers = 1 then
    result := AlivePlayer +1;
end;

procedure TAtomsGame.Explode(y, x: integer);
begin
  ChangeAtom(y, x, 0);

  //Corner atom should explode to the 2 surrounding edges
  if IsCornerAtom(y, x) then
  begin
    if (y = 0) and (x=0) then
    begin
      IncAtom(0,1);
      IncAtom(1,0);
    end
    else
    if (y = 0) and (x=6) then
    begin
      IncAtom(0,5);
      IncAtom(1,6);
    end
    else
    if (y = 6) and (x=0) then
    begin
      IncAtom(5,0);
      IncAtom(6,1);
    end
    else
    if (y = 6) and (x=6) then
    begin
      IncAtom(5,6);
      IncAtom(6,5);
    end
  end
  else
  //Edge atom should explode to the 3 adjacent squares - left, right and in front
  if IsEdgeAtom(y, x) then
  begin
    if y = 0 then
    begin
      IncAtom(y, x -1); //above
      IncAtom(y, x +1); //below
      IncAtom(y +1, x); //right
    end
    else
    if y = 6 then
    begin
      IncAtom(y, x -1); //above
      IncAtom(y, x +1); //below
      IncAtom(y -1, x); //left
    end
    else
    if x = 0 then
    begin
      IncAtom(y -1, x); //above
      IncAtom(y +1, x); //below
      IncAtom(y, x +1); //right
    end
    else
    if x = 6 then
    begin
      IncAtom(y -1, x); //above
      IncAtom(y +1, x); //below
      IncAtom(y, x -1); //left
    end;
  end
  else //Central atom should explode to the 4 surrounding squares
  begin
    IncAtom(y -1, x); //above
    IncAtom(y +1, x); //below
    IncAtom(y, x +1); //right
    IncAtom(y, x -1); //left
  end;
end;

function TAtomsGame.FindOverloadedAtoms: T2dArray;
var
  y, x: integer;
  Overloaded: boolean;
begin
  SetLength(result, 0, 0);

  for y := 0 to High(FAtomsArray)  do
    for x := 0 to High(FAtomsArray[y]) do
    begin
      Overloaded := false;

      if IsCornerAtom(y, x) then
      begin
        if FAtomsArray[y, x, 0] > 1 then
          Overloaded := true;
      end
      else
      if IsEdgeAtom(y, x) then
      begin
        if FAtomsArray[y, x, 0] > 2 then
          Overloaded := true;
      end
      else //Central atom
      begin
        if FAtomsArray[y, x, 0] > 3 then
          Overloaded := true;
      end;

      if Overloaded then
      begin
        SetLength(Result, length(result) + 1, 2); //First dimension the index, second holds the y and x
        Result[high(result), 0] := y;
        Result[high(result), 1] := x;
      end;
    end;
end;

procedure TAtomsGame.IncAtom(y, x: integer);
begin
  inc( FAtomsArray[y, x, 0] );
  FAtomsArray[y, x, 1] := FCurrentPlayer; //Update the extra dimension too - thats the current player

  if (Assigned(FBoardChanged)) then
	  FBoardChanged(y, x,  FAtomsArray[y, x, 0], FPlayers[FCurrentPlayer -1].Colour);
end;

procedure TAtomsGame.ChangeAtom(y, x, NewValue: integer);
begin
  FAtomsArray[y, x, 0] := NewValue;
  if NewValue = 0 then
    FAtomsArray[y, x, 1] := 0 //Set it to 0 as it has no player owner now
  else
    FAtomsArray[y, x, 1] := FCurrentPlayer;

  if (Assigned(FBoardChanged)) then
	  FBoardChanged(y, x,  FAtomsArray[y, x, 0], FPlayers[FCurrentPlayer -1].Colour);
end;

function TAtomsGame.IsCornerAtom(y, x: integer): boolean;
begin
  result := false;

  if ( (y = 0) and (x=0) ) or ( (y = 6) and (x=0) ) or
     ( (y = 0) and (x=6) ) or ( (y = 6) and (x=6) ) then
     result := true;
end;

function TAtomsGame.IsEdgeAtom(y, x: integer): boolean;
begin
  result := false;

  if ((y = 0) and (IsCornerAtom(y, x) = false)) or
     ((y = 6) and (IsCornerAtom(y, x) = false)) or
     ((x = 0) and (IsCornerAtom(y, x) = false)) or
     ((x = 6) and (IsCornerAtom(y, x) = false)) then
     result := true;
end;

procedure TAtomsGame.ResetGame;
var
  i, j: integer;
begin
  FTurnNum := 0;
  FCurrentPlayer := 1;
    if Assigned(FBusy) then
    FBusy(False);

  for i := 0 to High(FAtomsArray)  do
    for j := 0 to High(FAtomsArray[i]) do
    begin
      FAtomsArray[i, j, 0] := 0;
      FAtomsArray[i, j, 1] := 0;
    end;

  UpdateAtomCounts;
end;

procedure TAtomsGame.StartGame;
begin
  //Fire the player changed event to give the form the current player num and colour
  if Assigned(FPlayerChanged) then
    FPlayerChanged(FCurrentPlayer, FPlayers[FCurrentPlayer -1].Colour);
end;

procedure TAtomsGame.UpdateAtomCounts;
var
  i, j, PlayerNum: Integer;
  Player: TAtomsPlayer;
begin
  //First set all atom counts to 0
  for Player in FPlayers do
    Player.AtomCount := 0;

  for i := 0 to High(FAtomsArray)  do
    for j := 0 to High(FAtomsArray[i]) do
    begin
      PlayerNum := FAtomsArray[i, j, 1];
      if PlayerNum > 0 then
        inc(FPlayers[PlayerNum -1].AtomCount, FAtomsArray[i, j, 0]);
    end;
end;

end.
