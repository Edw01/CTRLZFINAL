program visor_mp25;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // LCL widgetset
  Forms,
  tachartlazaruspkg,
  LazSerialPort,
  u_visor_mp25;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TFormularioVisorMP25, FormularioVisorMP25);
  Application.Run;
end.
