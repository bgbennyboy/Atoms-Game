program Atoms;



{$R *.dres}

uses
  Forms,
  formMain in 'formMain.pas' {frmMain},
  uAtoms in 'uAtoms.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
