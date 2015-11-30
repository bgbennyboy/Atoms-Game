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

unit formMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Vcl.ExtCtrls, Vcl.Imaging.pngimage, System.UITypes,
  bass;

type
  T2dArray = array of array of integer;

  TfrmMain = class(TForm)
    lblCell0, lblCell1, lblCell2, lblCell3, lblCell4, lblCell5, lblCell6,
    lblCell7, lblCell8, lblCell9, lblCell10, lblCell11, lblCell12, lblCell13,
    lblCell14, lblCell15, lblCell16, lblCell17, lblCell18, lblCell19, lblCell20,
    lblCell21, lblCell22, lblCell23, lblCell24, lblCell25, lblCell26, lblCell27,
    lblCell28, lblCell29, lblCell30, lblCell31, lblCell32, lblCell33, lblCell34,
    lblCell35, lblCell36, lblCell37, lblCell38, lblCell39, lblCell40, lblCell41,
    lblCell42, lblCell43, lblCell44, lblCell45, lblCell46, lblCell47, lblCell48,
    lblDebug, lblPlayer1AtomCount, lblPlayer2AtomCount, lblPlayer, lblMusic,
    lblAbout: TLabel;
    panelAtoms, panelBottom: TPanel;
    imagePlayer1, imagePlayer2: TImage;
    procedure AtomClickHandler(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure labelUnderlineOnMouseEnter(Sender: TObject);
    procedure labelRemoveUnderlineOnMouseLeave(Sender: TObject);
    procedure lblMusicClick(Sender: TObject);
    procedure lblAboutClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
  private
    function IsCornerAtom(y, x: integer): boolean;
    function IsEdgeAtom(y, x:integer): boolean;
    function FindOverloadedAtoms: T2dArray;
    function CheckIfSomeoneWon: integer;
    procedure AddAtom(y, x: integer; ALabel: TLabel);
    procedure Explode(y, x: integer);
    procedure RedrawAtom(y, x: integer);
    procedure IncArrayAndRedraw(y, x: integer);
    procedure ChangeAtomAndRedraw(y, x, NewValue: integer);
    procedure ChangePlayer;
    procedure DisplayWinnerAndReset(WinningPlayer: integer);
    procedure PlayMusic(Restart: boolean = true);
    procedure StopMusic;
    procedure CountAtomsAndUpdateLabels;
    procedure AnimateGrid;
  public
  end;

  procedure LoopSyncProc(handle: HSYNC; channel, data: DWORD; user: Pointer); stdcall;

var
  frmMain: TfrmMain;
  AtomsArray: array [0..6, 0..6, 0..1] of integer;
  CurrentPlayer: integer = 0;
  CurrentTurn: integer = 0;
  CurrentColour: TColor;
  TotalPlayers: integer = 2;
  fAudioHandle: HSTREAM;
  Player1AtomCount, Player2AtomCount: integer;
  Muted: boolean = false;
  Busy: boolean = false;

const
  strAppVersion: string = '0.3';
  strAppTitle:   string = 'Atoms';
  strAppURL:     string = 'http://quickandeasysoftware.net';
  strAboutText:  string =  'Based on Atoms on the Amiga by Tom Kuhn - although many versions of this game exist, his excellent version is the one I first played back in 1993. The music is taken from his version.' + #13#13 +
                          'Rules:' + #13 +
                          'Players take turns to place atoms on the grid' + #13 +
                          'Different boxes on the grid can hold different amounts of atoms. When boxes have too many atoms placed in them they will explode. Players can only place atoms on empty boxes or boxes containing atoms of their own colour.' + #13#13 +
                          'Corner boxes can hold only one atom before exploding.' + #13 +
                          'Side boxes can hold only two atoms before exploding.' + #13 +
                          'Middle boxes can hold three atoms before exploding.';
implementation

{$R *.dfm}

{
  1 on corners
  2 on edges
  3 everywhere else

  Arrays are row major order in Delphi https://en.wikipedia.org/wiki/Row-major_order
  So really its [row,column] but we write it y,x not x,y due to how its stored in memory
}


procedure TfrmMain.AddAtom(y, x: integer; ALabel: TLabel);
var
  OverloadedAtoms: T2dArray;
  i, Winner: integer;
begin
  //Check that player is clicking on their atom or an empty cell
  if AtomsArray[y, x, 1] = 0 then //no atom in this cell
  else
  if AtomsArray[y, x, 1] <> CurrentPlayer then //clicking on atoms that arent yours!
  begin
    exit;
  end;

  //Stop other clicks while explosions are happening
  Busy := true;

  inc(CurrentTurn);

  //Change the colour to the player's colour
  ALabel.Transparent := false;
  ALabel.Color := CurrentColour;

  IncArrayAndRedraw(y, x);

  {$IFDEF DEBUG}
    lblDebug.Caption := 'Y: ' + inttostr(y) + #13 + 'X: ' + inttostr(x) + #13 + 'V: ' + inttostr( AtomsArray[y, x, 0] );
  {$ENDIF}

  //Check if in corner
  if IsCornerAtom(y, x) then
  begin
    if AtomsArray[y, x, 0] > 1 then //Check if already contains atom
      Explode(y, x);
  end
  else //Check if on edge
  if IsEdgeAtom(y, x) then
  begin
    if AtomsArray[y, x, 0] > 2 then
      Explode (y, x);
  end
  else //Must be a central atom
    if AtomsArray[y, x, 0] > 3 then
      Explode(y, x);

  //Update atom count labels
  CountAtomsAndUpdateLabels;

  //Check if anyone's won after the initial explosions
  if CurrentTurn > 2 then
  begin
    Winner := CheckIfSomeoneWon;
    if Winner > -1 then
    begin
      DisplayWinnerAndReset(Winner);
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

      CountAtomsAndUpdateLabels;
      //Check for a winner
      Winner := CheckIfSomeoneWon;
      if Winner <> -1 then
      begin
        DisplayWinnerAndReset(Winner);
        exit;
      end;

    end;
  end;

  //Change to the next player
  ChangePlayer;
  Busy := false;
end;

procedure TfrmMain.Explode(y, x: integer);
begin
  ChangeAtomAndRedraw(y, x, 0);

  //Corner atom should explode to the 2 surrounding edges
  if IsCornerAtom(y, x) then
  begin
    if (y = 0) and (x=0) then
    begin
      IncArrayAndRedraw(0,1);
      IncArrayAndRedraw(1,0);
    end
    else
    if (y = 0) and (x=6) then
    begin
      IncArrayAndRedraw(0,5);
      IncArrayAndRedraw(1,6);
    end
    else
    if (y = 6) and (x=0) then
    begin
      IncArrayAndRedraw(5,0);
      IncArrayAndRedraw(6,1);
    end
    else
    if (y = 6) and (x=6) then
    begin
      IncArrayAndRedraw(5,6);
      IncArrayAndRedraw(6,5);
    end
  end
  else
  //Edge atom should explode to the 3 adjacent squares - left, right and in front
  if IsEdgeAtom(y, x) then
  begin
    if y = 0 then
    begin
      IncArrayAndRedraw(y, x -1); //above
      IncArrayAndRedraw(y, x +1); //below
      IncArrayAndRedraw(y +1, x); //right
    end
    else
    if y = 6 then
    begin
      IncArrayAndRedraw(y, x -1); //above
      IncArrayAndRedraw(y, x +1); //below
      IncArrayAndRedraw(y -1, x); //left
    end
    else
    if x = 0 then
    begin
      IncArrayAndRedraw(y -1, x); //above
      IncArrayAndRedraw(y +1, x); //below
      IncArrayAndRedraw(y, x +1); //right
    end
    else
    if x = 6 then
    begin
      IncArrayAndRedraw(y -1, x); //above
      IncArrayAndRedraw(y +1, x); //below
      IncArrayAndRedraw(y, x -1); //left
    end;
  end
  else //Central atom should explode to the 4 surrounding squares
  begin
    IncArrayAndRedraw(y -1, x); //above
    IncArrayAndRedraw(y +1, x); //below
    IncArrayAndRedraw(y, x +1); //right
    IncArrayAndRedraw(y, x -1); //left
  end;
end;

procedure TfrmMain.RedrawAtom(y, x: integer);
var
  ALabel: TLabel;
  OriginalFontSize, i: integer;
begin
  ALabel := nil;

  if (y=0) and (x=0) then ALabel := lblCell0
  else
  if (y=0) and (x=1) then ALabel := lblCell1
  else
  if (y=0) and (x=2) then ALabel := lblCell2
  else
  if (y=0) and (x=3) then ALabel := lblCell3
  else
  if (y=0) and (x=4) then ALabel := lblCell4
  else
  if (y=0) and (x=5) then ALabel := lblCell5
  else
  if (y=0) and (x=6) then ALabel := lblCell6
  else
  if (y=1) and (x=0) then ALabel := lblCell7
  else
  if (y=1) and (x=1) then ALabel := lblCell8
  else
  if (y=1) and (x=2) then ALabel := lblCell9
  else
  if (y=1) and (x=3) then ALabel := lblCell10
  else
  if (y=1) and (x=4) then ALabel := lblCell11
  else
  if (y=1) and (x=5) then ALabel := lblCell12
  else
  if (y=1) and (x=6) then ALabel := lblCell13
  else
  if (y=2) and (x=0) then ALabel := lblCell14
  else
  if (y=2) and (x=1) then ALabel := lblCell15
  else
  if (y=2) and (x=2) then ALabel := lblCell16
  else
  if (y=2) and (x=3) then ALabel := lblCell17
  else
  if (y=2) and (x=4) then ALabel := lblCell18
  else
  if (y=2) and (x=5) then ALabel := lblCell19
  else
  if (y=2) and (x=6) then ALabel := lblCell20
  else
  if (y=3) and (x=0) then ALabel := lblCell21
  else
  if (y=3) and (x=1) then ALabel := lblCell22
  else
  if (y=3) and (x=2) then ALabel := lblCell23
  else
  if (y=3) and (x=3) then ALabel := lblCell24
  else
  if (y=3) and (x=4) then ALabel := lblCell25
  else
  if (y=3) and (x=5) then ALabel := lblCell26
  else
  if (y=3) and (x=6) then ALabel := lblCell27
  else
  if (y=4) and (x=0) then ALabel := lblCell28
  else
  if (y=4) and (x=1) then ALabel := lblCell29
  else
  if (y=4) and (x=2) then ALabel := lblCell30
  else
  if (y=4) and (x=3) then ALabel := lblCell31
  else
  if (y=4) and (x=4) then ALabel := lblCell32
  else
  if (y=4) and (x=5) then ALabel := lblCell33
  else
  if (y=4) and (x=6) then ALabel := lblCell34
  else
  if (y=5) and (x=0) then ALabel := lblCell35
  else
  if (y=5) and (x=1) then ALabel := lblCell36
  else
  if (y=5) and (x=2) then ALabel := lblCell37
  else
  if (y=5) and (x=3) then ALabel := lblCell38
  else
  if (y=5) and (x=4) then ALabel := lblCell39
  else
  if (y=5) and (x=5) then ALabel := lblCell40
  else
  if (y=5) and (x=6) then ALabel := lblCell41
  else
  if (y=6) and (x=0) then ALabel := lblCell42
  else
  if (y=6) and (x=1) then ALabel := lblCell43
  else
  if (y=6) and (x=2) then ALabel := lblCell44
  else
  if (y=6) and (x=3) then ALabel := lblCell45
  else
  if (y=6) and (x=4) then ALabel := lblCell46
  else
  if (y=6) and (x=5) then ALabel := lblCell47
  else
  if (y=6) and (x=6) then ALabel := lblCell48;


  //Animate it getting bigger
  //If atom has popped cell will now be empty
  if (AtomsArray[y, x, 0] = 0) and (CurrentPlayer <> 0) then
  begin
    OriginalFontSize := ALabel.Font.Size;
    for I := 1 to 10 do
    begin
      ALabel.Font.Size := ALabel.Font.Size -4;
      Application.ProcessMessages;
      Sleep(80);
    end;

    ALabel.Font.Size := OriginalFontSize;
  end;


  ALabel.Caption := inttostr( AtomsArray[y, x, 0] );
  ALabel.Transparent := false;

  if AtomsArray[y, x, 0] = 0 then //If its empty then clear its colour
    ALabel.Color := clBtnFace
  else
    ALabel.Color := CurrentColour;
end;

procedure TfrmMain.AnimateGrid;
begin
  AnimateWindow(panelAtoms.Handle , 1, AW_CENTER or AW_HIDE);
  AnimateWindow(panelAtoms.Handle , 800, AW_CENTER );
end;

procedure TfrmMain.AtomClickHandler(Sender: TObject);
begin
  //Dont allow other clicks while other explosions happening
  if Busy then exit;

  if Sender = lblCell0 then AddAtom(0, 0, TLabel(Sender))
  else
  if Sender = lblCell1 then AddAtom(0, 1, TLabel(Sender))
  else
  if Sender = lblCell2 then AddAtom(0, 2, TLabel(Sender))
  else
  if Sender = lblCell3 then AddAtom(0, 3, TLabel(Sender))
  else
  if Sender = lblCell4 then AddAtom(0, 4, TLabel(Sender))
  else
  if Sender = lblCell5 then AddAtom(0, 5, TLabel(Sender))
  else
  if Sender = lblCell6 then AddAtom(0, 6, TLabel(Sender))
  else
  if Sender = lblCell7 then AddAtom(1, 0, TLabel(Sender))
  else
  if Sender = lblCell8 then AddAtom(1, 1, TLabel(Sender))
  else
  if Sender = lblCell9 then AddAtom(1, 2, TLabel(Sender))
  else
  if Sender = lblCell10 then AddAtom(1, 3, TLabel(Sender))
  else
  if Sender = lblCell11 then AddAtom(1, 4, TLabel(Sender))
  else
  if Sender = lblCell12 then AddAtom(1, 5, TLabel(Sender))
  else
  if Sender = lblCell13 then AddAtom(1, 6, TLabel(Sender))
  else
  if Sender = lblCell14 then AddAtom(2, 0, TLabel(Sender))
  else
  if Sender = lblCell15 then AddAtom(2, 1, TLabel(Sender))
  else
  if Sender = lblCell16 then AddAtom(2, 2, TLabel(Sender))
  else
  if Sender = lblCell17 then AddAtom(2, 3, TLabel(Sender))
  else
  if Sender = lblCell18 then AddAtom(2, 4, TLabel(Sender))
  else
  if Sender = lblCell19 then AddAtom(2, 5, TLabel(Sender))
  else
  if Sender = lblCell20 then AddAtom(2, 6, TLabel(Sender))
  else
  if Sender = lblCell21 then AddAtom(3, 0, TLabel(Sender))
  else
  if Sender = lblCell22 then AddAtom(3, 1, TLabel(Sender))
  else
  if Sender = lblCell23 then AddAtom(3, 2, TLabel(Sender))
  else
  if Sender = lblCell24 then AddAtom(3, 3, TLabel(Sender))
  else
  if Sender = lblCell25 then AddAtom(3, 4, TLabel(Sender))
  else
  if Sender = lblCell26 then AddAtom(3, 5, TLabel(Sender))
  else
  if Sender = lblCell27 then AddAtom(3, 6, TLabel(Sender))
  else
  if Sender = lblCell28 then AddAtom(4, 0, TLabel(Sender))
  else
  if Sender = lblCell29 then AddAtom(4, 1, TLabel(Sender))
  else
  if Sender = lblCell30 then AddAtom(4, 2, TLabel(Sender))
  else
  if Sender = lblCell31 then AddAtom(4, 3, TLabel(Sender))
  else
  if Sender = lblCell32 then AddAtom(4, 4, TLabel(Sender))
  else
  if Sender = lblCell33 then AddAtom(4, 5, TLabel(Sender))
  else
  if Sender = lblCell34 then AddAtom(4, 6, TLabel(Sender))
  else
  if Sender = lblCell35 then AddAtom(5, 0, TLabel(Sender))
  else
  if Sender = lblCell36 then AddAtom(5, 1, TLabel(Sender))
  else
  if Sender = lblCell37 then AddAtom(5, 2, TLabel(Sender))
  else
  if Sender = lblCell38 then AddAtom(5, 3, TLabel(Sender))
  else
  if Sender = lblCell39 then AddAtom(5, 4, TLabel(Sender))
  else
  if Sender = lblCell40 then AddAtom(5, 5, TLabel(Sender))
  else
  if Sender = lblCell41 then AddAtom(5, 6, TLabel(Sender))
  else
  if Sender = lblCell42 then AddAtom(6, 0, TLabel(Sender))
  else
  if Sender = lblCell43 then AddAtom(6, 1, TLabel(Sender))
  else
  if Sender = lblCell44 then AddAtom(6, 2, TLabel(Sender))
  else
  if Sender = lblCell45 then AddAtom(6, 3, TLabel(Sender))
  else
  if Sender = lblCell46 then AddAtom(6, 4, TLabel(Sender))
  else
  if Sender = lblCell47 then AddAtom(6, 5, TLabel(Sender))
  else
  if Sender = lblCell48 then AddAtom(6, 6, TLabel(Sender));
end;

procedure TfrmMain.ChangePlayer;
begin
  inc( CurrentPlayer);
  if CurrentPlayer > TotalPlayers then
    CurrentPlayer := 1;

  lblPlayer.Caption := 'Player ' + inttostr(CurrentPlayer);

  case CurrentPlayer of
    1: CurrentColour := clSkyBlue;
    2: CurrentColour := clMoneyGreen;
  end;

  panelBottom.Color := CurrentColour;
end;

procedure TfrmMain.DisplayWinnerAndReset(WinningPlayer: integer);
var
  i, j: integer;
begin
  //Let the previous animations appear
  Application.ProcessMessages;

  StopMusic;
  MessageDlg('Player ' + inttostr(WinningPlayer) + ' wins in ' + inttostr(CurrentTurn) + ' turns!' ,mtInformation, [mbOk], 0);

  //Reset everything
  CurrentTurn := 0;
  CurrentPlayer := 0;
  Busy := false;

  for i := 0 to High(AtomsArray)  do
    for j := 0 to High(AtomsArray[i]) do
    begin
      AtomsArray[i, j, 0] := 0;
      AtomsArray[i, j, 1] := 0;
      RedrawAtom(i, j);
    end;

  CountAtomsAndUpdateLabels;
  ChangePlayer;
  if Muted = false then
    PlayMusic;

  AnimateGrid;
end;

procedure TfrmMain.IncArrayAndRedraw(y, x: integer);
begin
  inc( AtomsArray[y, x, 0] );
  AtomsArray[y, x, 1] := CurrentPlayer; //Update the extra dimension too - thats the current player
  RedrawAtom(y, x);
end;

procedure TfrmMain.ChangeAtomAndRedraw(y, x, NewValue: integer);
begin
  AtomsArray[y, x, 0] := NewValue;
  if NewValue = 0 then
    AtomsArray[y, x, 1] := 0 //Set it to 0 as it has no player owner now
  else
    AtomsArray[y, x, 1] := CurrentPlayer;

  RedrawAtom(y, x);
end;

function TfrmMain.IsCornerAtom(y, x: integer): boolean;
begin
  result := false;

  if ( (y = 0) and (x=0) ) or ( (y = 6) and (x=0) ) or
     ( (y = 0) and (x=6) ) or ( (y = 6) and (x=6) ) then
     result := true;
end;

function TfrmMain.IsEdgeAtom(y, x: integer): boolean;
begin
  result := false;

  if ((y = 0) and (IsCornerAtom(y, x) = false)) or
     ((y = 6) and (IsCornerAtom(y, x) = false)) or
     ((x = 0) and (IsCornerAtom(y, x) = false)) or
     ((x = 6) and (IsCornerAtom(y, x) = false)) then
     result := true;
end;

function TfrmMain.FindOverloadedAtoms: T2dArray;
var
  y, x: integer;
  Overloaded: boolean;
begin
  SetLength(result, 0, 0);

  for y := 0 to High(AtomsArray)  do
    for x := 0 to High(AtomsArray[y]) do
    begin
      Overloaded := false;

      if IsCornerAtom(y, x) then
      begin
        if AtomsArray[y, x, 0] > 1 then
          Overloaded := true;
      end
      else
      if IsEdgeAtom(y, x) then
      begin
        if AtomsArray[y, x, 0] > 2 then
          Overloaded := true;
      end
      else //Central atom
      begin
        if AtomsArray[y, x, 0] > 3 then
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

function TfrmMain.CheckIfSomeoneWon: integer;
var
  i, j: integer;
  Player1Dead, Player2Dead: boolean;
begin
  result := -1; //means no-one's won yet
  Player1Dead := True;
  Player2Dead := True;

  for i := 0 to High(AtomsArray)  do
    for j := 0 to High(AtomsArray[i]) do
    begin
      if AtomsArray[i, j, 1] = 1 then Player1Dead := false;
      if AtomsArray[i, j, 1] = 2 then Player2Dead := false;
    end;

  if Player1Dead then result := 2
  else
  if Player2Dead then result := 1;
end;

procedure TfrmMain.CountAtomsAndUpdateLabels;
var
  i, j: integer;
begin
  Player1AtomCount := 0;
  Player2AtomCount := 0;
  for i := 0 to High(AtomsArray)  do
    for j := 0 to High(AtomsArray[i]) do
    begin
      if AtomsArray[i, j, 1] = 1 then inc(Player1AtomCount, AtomsArray[i, j, 0]);
      if AtomsArray[i, j, 1] = 2 then inc(Player2AtomCount, AtomsArray[i, j, 0]);
    end;

   lblPlayer1AtomCount.Caption := inttostr( Player1AtomCount );
   lblPlayer2AtomCount.Caption := inttostr( Player2AtomCount );
end;


//******************************************Form Stuff*******************************************
procedure TfrmMain.FormActivate(Sender: TObject);
begin
  AnimateGrid;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  i, j: integer;
  ResStream: TResourceStream;
begin
  frmMain.Caption := strAppTitle + ' ' + strAppVersion;

	// check the correct BASS dll was loaded
	if (HIWORD(BASS_GetVersion) <> BASSVERSION) then
	begin
		MessageBox(0, PChar('An incorrect version of BASS.DLL was loaded'), nil, MB_ICONERROR);
		Halt;
	end;

	// Initialize audio - default device, 44100hz, stereo, 16 bits
	if not BASS_Init(-1, 44100, 0, Handle, nil) then
		MessageBox(0, PChar('Error initializing audio!'), nil, MB_ICONERROR);

  //Load audio from memory
  ResStream := TResourceStream.Create(hInstance, 'MusicMod', RT_RCDATA);
  try
    ResStream.Position := 0;
    fAudioHandle := BASS_MusicLoad(true, ResStream.Memory , 0, ResStream.Size, BASS_SAMPLE_LOOP or BASS_UNICODE, 0);
    if fAudioHandle = 0 then ShowMessage('Error playing mod music: ' + inttostr(BASS_ErrorGetCode));
  finally
    ResStream.Free;
  end;

  //fAudioHandle := BASS_MusicLoad(false, Pchar('mainmod.mod'), 0, 0, BASS_SAMPLE_LOOP or BASS_UNICODE , 0);
  //if fAudioHandle = 0 then ShowMessage('Error playing mod music: ' + inttostr(BASS_ErrorGetCode));

  //Setup the loop - when it gets to the end it calls LoopSyncProc
  BASS_ChannelSetSync(fAudioHandle, BASS_SYNC_END or BASS_SYNC_MIXTIME, 0, LoopSyncProc, nil);

  for i := 0 to High(AtomsArray)  do
    for j := 0 to High(AtomsArray[i]) do
    begin
      AtomsArray[i, j, 0] := 0;
      AtomsArray[i, j, 1] := 0; //last dimension 1 - holds player (owner of atoms in that square)
      RedrawAtom(i, j);
      //ShowMessage('multiArray['+IntToStr(i)+','+IntToStr(j)+'] = '+ IntToStr(AtomsArray[i,j]));
    end;

  ChangePlayer;
  PlayMusic;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  StopMusic;
  BASS_ChannelStop(fAudioHandle);
  BASS_StreamFree(fAudioHandle);
  BASS_Free;
end;

procedure TfrmMain.lblAboutClick(Sender: TObject);
begin
  MessageDlg(strAppTitle + ' ' + strAppVersion + #13 +
  'By Bennyboy' + #13 +
  strAppURL + #13#13 +
  strAboutText,
  mtInformation, [mbOk], 0);
end;

procedure TfrmMain.lblMusicClick(Sender: TObject);
begin
  if Muted = false then
  begin
    StopMusic;
    lblMusic.Caption := 'Music Off';
    Muted := true;
  end
  else
  begin
    PlayMusic(false);
    lblMusic.Caption := 'Music On';
    Muted := false;
  end;
end;

procedure TfrmMain.labelUnderlineOnMouseEnter(Sender: TObject);
begin
  TLabel(sender).Font.style:=[fsunderline];
end;

procedure TfrmMain.labelRemoveUnderlineOnMouseLeave(Sender: TObject);
begin
  TLabel(sender).Font.style := lblMusic.Font.style - [fsunderline];
end;
//***********************************************************************************************




//******************************************Music Stuff******************************************

procedure TfrmMain.PlayMusic(Restart: boolean = true);
begin
  //Set the volume back to full if we've previously stopped and faded it out
  BASS_ChannelSetAttribute(fAudioHandle, BASS_ATTRIB_VOL, 1);

  //if not BASS_ChannelSetPosition(fAudioHandle, MAKELONG(2, 0), BASS_POS_MUSIC_ORDER or BASS_MUSIC_POSRESET) then
	//	BASS_ChannelSetPosition(fAudioHandle, 0, BASS_POS_BYTE); // Seek failed, go to start of file instead

	if not BASS_ChannelPlay(fAudioHandle, Restart) then
		ShowMessage('Error playing mod music: ' + inttostr(BASS_ErrorGetCode));
end;

procedure TfrmMain.StopMusic;
begin
  BASS_ChannelSlideAttribute(fAudioHandle, BASS_ATTRIB_VOL, 0, 500);
  Sleep(500);

  if BASS_ChannelPause(fAudioHandle) = false then
    if BASS_ErrorGetCode = BASS_ERROR_ALREADY then //Already paused
      BASS_ChannelPlay(fAudioHandle, False)
end;

procedure LoopSyncProc(handle: HSYNC; channel, data: DWORD; user: Pointer); stdcall;
begin
	if not BASS_ChannelSetPosition(channel, MAKELONG(2, 0), BASS_POS_MUSIC_ORDER or BASS_MUSIC_POSRESET) then
		BASS_ChannelSetPosition(channel,0, BASS_POS_BYTE); // Seek failed, go to start of file instead
end;
//***********************************************************************************************



end.
