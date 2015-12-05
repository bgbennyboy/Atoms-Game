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
  bass, uAtoms;

type
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
    function ComponentTagToCoords(ComponentTag: integer; var y, x: integer): boolean;
    function CoordsToComponentTag(y, x: integer; var ComponentTag: integer): boolean;
    procedure RedrawAtom(y, x, value: integer; Colour: TColor);
    procedure PlayMusic(Restart: boolean = true);
    procedure StopMusic;
    procedure AnimateGrid;
    procedure StartNewGame;
    procedure ResetBoard;
    procedure OnPlayerChanged(PlayerNum: integer; PlayerColour: TColor);
    procedure OnBoardChanged(y, x, value: integer; Colour: TColor);
    procedure OnGameWon(PlayerName: string);
    procedure OnGameBusy(Busy: boolean);
  public
  end;

  procedure LoopSyncProc(handle: HSYNC; channel, data: DWORD; user: Pointer); stdcall;

var
  frmMain: TfrmMain;
  fAtomsGame: TAtomsGame;
  fAudioHandle: HSTREAM;
  Muted: boolean = false;
  FBusy: boolean = false;

const
  strAppVersion: string = '0.5';
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

procedure TfrmMain.AtomClickHandler(Sender: TObject);
var
  y, x: Integer;
begin
  //Dont allow other clicks while other explosions happening
  if FBusy then exit;

  //showmessage( (sender as TLabel).Name );
  if ComponentTagToCoords((sender as TLabel).Tag, y, x) then
     fAtomsGame.AddAtom(y, x)
  else
    ShowMessage('Couldnt match component to co-ordinates!');
end;

function TfrmMain.ComponentTagToCoords(ComponentTag: integer; var y, x: integer): boolean;
var
  i, j, CurrAtom: integer;
begin
  result := false;
  if ComponentTag < 0 then exit;

  CurrAtom := -1;
  for i := 0 to fAtomsGame.BoardHeight -1 do
    for j := 0 to fAtomsGame.BoardWidth -1 do
    begin
      inc(CurrAtom);
      if CurrAtom = ComponentTag then
      begin
        y := i;
        x := j;
        Result := true;
        exit;
      end;
    end;

end;

function TfrmMain.CoordsToComponentTag(y, x: integer; var ComponentTag: integer): boolean;
var
  i, j, CurrAtom: integer;
begin
  result := false;
  if (y < 0) or (x <0) then exit;

  CurrAtom := -1;
  for i := 0 to fAtomsGame.BoardHeight -1 do
    for j := 0 to fAtomsGame.BoardWidth -1 do
    begin
      inc(CurrAtom);
      if (i = y) and (j = x) then
      begin
        ComponentTag := CurrAtom;
        Result := true;
        Break;
      end;
    end;
end;

procedure TfrmMain.RedrawAtom(y, x, value: integer; Colour: TColor);
var
  ALabel: TLabel;
  OriginalFontSize, i, Tag: integer;
begin
  if CoordsToComponentTag(y, x, Tag) then
  begin
    ALabel := FindComponent( 'lblCell' + inttostr(Tag)) as TLabel;
    if Assigned(Alabel) then
    else
    begin
      ShowMessage('Couldnt map component to label');
      exit;
    end;
  end
  else
  begin
    ShowMessage('Couldnt get tag from coords');
    exit;
  end;


  //Animate it getting bigger.
  if (Value = 0) and (fAtomsGame.TurnNum > 1) then // If atom has popped cell will now be empty
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


  ALabel.Caption := inttostr( value );
  ALabel.Transparent := false;


  if value = 0 then //If its empty then clear its colour
    ALabel.Color := clBtnFace
  else
    ALabel.Color := Colour;
end;

procedure TfrmMain.ResetBoard;
var
  i, j: integer;
begin
  for i := 0 to fAtomsGame.BoardHeight -1 do
    for j := 0 to fAtomsGame.BoardWidth -1 do
      RedrawAtom(i, j, 0, clBtnFace);
end;

procedure TfrmMain.AnimateGrid;
begin
  AnimateWindow(panelAtoms.Handle , 1, AW_CENTER or AW_HIDE);
  AnimateWindow(panelAtoms.Handle , 800, AW_CENTER );
end;

procedure TfrmMain.StartNewGame;
begin
  fAtomsGame.Free;

  try
    fAtomsGame := TAtomsGame.Create(4);
    fAtomsGame.PlayerChanged := OnPlayerChanged;
    fAtomsGame.BoardChanged := OnBoardChanged;
    fAtomsGame.GameWon := OnGameWon;
    FBusy := false;
    fAtomsGame.GameBusy := OnGameBusy;
    ResetBoard;
    fAtomsGame.StartGame;
  except on E: EAtomsError do
  begin
    ShowMessage(E.Message);
    exit;
  end;
  end;

  if Muted = false then
    PlayMusic;
end;



//******************************************Form Stuff*******************************************
procedure TfrmMain.FormActivate(Sender: TObject);
begin
  AnimateGrid;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
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

  //Setup the loop - when it gets to the end it calls LoopSyncProc
  BASS_ChannelSetSync(fAudioHandle, BASS_SYNC_END or BASS_SYNC_MIXTIME, 0, LoopSyncProc, nil);

  StartNewGame;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  StopMusic;
  BASS_ChannelStop(fAudioHandle);
  BASS_StreamFree(fAudioHandle);
  BASS_Free;
  fAtomsGame.Free;
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







//**************************************Event Handling Stuff**************************************
 procedure TfrmMain.OnBoardChanged(y, x, value: integer; Colour: TColor);
begin
  RedrawAtom(y, x, value, Colour);
end;

procedure TfrmMain.OnGameBusy(Busy: boolean);
begin
  FBusy := Busy;
end;

procedure TfrmMain.OnGameWon(PlayerName: string);
begin
  //Let the previous animations appear first
  Application.ProcessMessages;

  StopMusic;
  MessageDlg('Player ' + PlayerName + ' wins in ' + inttostr(fAtomsGame.TurnNum ) + ' turns!' ,mtInformation, [mbOk], 0);

  StartNewGame;
end;

procedure TfrmMain.OnPlayerChanged(PlayerNum: integer; PlayerColour: TColor);
begin
  lblPlayer.Caption := 'Player ' + inttostr(PlayerNum);
  panelBottom.Color := PlayerColour;
end;
//***********************************************************************************************

end.
