program visor_mp25;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  tachartlazaruspkg,
  LazSerialPort,
  u_visor_mp25;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='Visor MP 2.5 um';
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TFormularioVisorMP25, FormularioVisorMP25);
  Application.Run;
end.

