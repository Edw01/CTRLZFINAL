program servidor_tcp_aire;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,
  SysUtils,
  ssockets,
  sqldb,
  sqlite3conn,
  sqlite3dyn;

type
  { TServidorRecepcionAire }
  TServidorRecepcionAire = class(TObject)
  private
    FServidorSocket: TInetServer;
    FConexionSQLite: TSQLite3Connection;
    FTransaccionSQL: TSQLTransaction;
    FRutaBaseDatos: string;
    FPuertoEscucha: Word;
    FContadorRegistros: Integer;

    procedure InicializarBaseDeDatos;
    procedure GuardarLecturaEnSQLite(const ValorMP25: Integer; const FechaActual, HoraActual: string);
    procedure ProcesarLineaRecibida(const LineaCruda: string);
    procedure AlConectarCliente(Sender: TObject; FlujoCliente: TSocketStream);
  public
    constructor Create(const PuertoTCP: Word; const RutaArchivoDB: string);
    destructor Destroy; override;
    procedure IniciarEscucha;
  end;

{ TServidorRecepcionAire }

constructor TServidorRecepcionAire.Create(const PuertoTCP: Word; const RutaArchivoDB: string);
begin
  inherited Create;
  FPuertoEscucha := PuertoTCP;
  FRutaBaseDatos := RutaArchivoDB;
  FContadorRegistros := 0;

  InicializarBaseDeDatos;

  FServidorSocket := TInetServer.Create('127.0.0.1', FPuertoEscucha);
  FServidorSocket.ReuseAddress := True;
  FServidorSocket.OnConnect := @AlConectarCliente;
end;

destructor TServidorRecepcionAire.Destroy;
begin
  if Assigned(FServidorSocket) then
  begin
    FServidorSocket.Free;
  end;

  if Assigned(FConexionSQLite) then
  begin
    if FConexionSQLite.Connected then
    begin
      FConexionSQLite.Close;
    end;
    FConexionSQLite.Free;
  end;

  if Assigned(FTransaccionSQL) then
  begin
    FTransaccionSQL.Free;
  end;

  inherited Destroy;
end;

procedure TServidorRecepcionAire.InicializarBaseDeDatos;
var
  RutaLibreriaDLL: string;
  ConsultaVerificacion: TSQLQuery;
begin
  // Cargar el motor SQLite
  RutaLibreriaDLL := ExtractFilePath(ParamStr(0)) + 'sqlite3.dll';
  if FileExists(RutaLibreriaDLL) then
  begin
    SQLiteDefaultLibrary := RutaLibreriaDLL;
  end;

  // Verificar que la base de datos haya sido creada previamente en HeidiSQL
  if not FileExists(FRutaBaseDatos) then
  begin
    raise Exception.Create(
      'No se encontro la base de datos "' + FRutaBaseDatos + '". ' +
      'Debe crearla previamente en HeidiSQL segun lo solicitado en el punto 11 de la pauta.'
    );
  end;

  // Abrir la conexion con la base de datos existente
  FConexionSQLite := TSQLite3Connection.Create(nil);
  FTransaccionSQL := TSQLTransaction.Create(nil);

  FConexionSQLite.Transaction := FTransaccionSQL;
  FConexionSQLite.DatabaseName := FRutaBaseDatos;
  FConexionSQLite.Open;

  // Verificar que la tabla "Aire" haya sido creada en HeidiSQL
  ConsultaVerificacion := TSQLQuery.Create(nil);
  try
    ConsultaVerificacion.DataBase := FConexionSQLite;
    ConsultaVerificacion.Transaction := FTransaccionSQL;
    ConsultaVerificacion.SQL.Text :=
      'SELECT count(*) FROM sqlite_master WHERE type="table" AND name="Aire";';
    ConsultaVerificacion.Open;
    if (ConsultaVerificacion.EOF) or (ConsultaVerificacion.Fields[0].AsInteger = 0) then
    begin
      raise Exception.Create(
        'La tabla "Aire" no existe en la base de datos "' + FRutaBaseDatos + '". ' +
        'Debe crearla previamente en HeidiSQL ejecutando el script crear_tabla_aire.sql.'
      );
    end;
  finally
    ConsultaVerificacion.Free;
  end;
end;

procedure TServidorRecepcionAire.GuardarLecturaEnSQLite(
  const ValorMP25: Integer;
  const FechaActual, HoraActual: string
);
var
  ConsultaInsercion: TSQLQuery;
begin
  ConsultaInsercion := TSQLQuery.Create(nil);
  try
    ConsultaInsercion.DataBase := FConexionSQLite;
    ConsultaInsercion.Transaction := FTransaccionSQL;
    ConsultaInsercion.SQL.Text :=
      'INSERT INTO Aire (MP25, Fecha, Hora) VALUES (:ParametroMP25, :ParametroFecha, :ParametroHora);';

    ConsultaInsercion.Params.ParamByName('ParametroMP25').AsInteger := ValorMP25;
    ConsultaInsercion.Params.ParamByName('ParametroFecha').AsString := FechaActual;
    ConsultaInsercion.Params.ParamByName('ParametroHora').AsString := HoraActual;

    ConsultaInsercion.ExecSQL;
    FTransaccionSQL.Commit;
  finally
    ConsultaInsercion.Free;
  end;
end;

procedure TServidorRecepcionAire.ProcesarLineaRecibida(const LineaCruda: string);
var
  TextoLimpio: string;
  ValorMP25: Integer;
  InstanteActual: TDateTime;
  FechaFormateada: string;
  HoraFormateada: string;
  PosicionSeparador: Integer;
begin
  TextoLimpio := Trim(LineaCruda);
  if TextoLimpio = '' then
  begin
    Exit;
  end;

  PosicionSeparador := Pos('=', TextoLimpio);
  if PosicionSeparador > 0 then
  begin
    TextoLimpio := Trim(Copy(TextoLimpio, PosicionSeparador + 1, Length(TextoLimpio)));
  end;

  if not TryStrToInt(TextoLimpio, ValorMP25) then
  begin
    WriteLn('[AVISO] Dato recibido no es un entero valido: "', LineaCruda, '"');
    Exit;
  end;

  InstanteActual := Now;
  FechaFormateada := FormatDateTime('yyyy-mm-dd', InstanteActual);
  HoraFormateada := FormatDateTime('hh:nn:ss', InstanteActual);

  try
    GuardarLecturaEnSQLite(ValorMP25, FechaFormateada, HoraFormateada);
    Inc(FContadorRegistros);

    WriteLn(
      Format(
        '[#%0.3d] Recibido -> MP25: %3d [ug/m3] | Fecha: %s | Hora: %s | Guardado en SQLite (Tabla Aire)',
        [FContadorRegistros, ValorMP25, FechaFormateada, HoraFormateada]
      )
    );
  except
    on ErrorSQL: Exception do
    begin
      WriteLn('[ERROR SQLITE] No se pudo insertar en Tabla Aire: ', ErrorSQL.Message);
    end;
  end;
end;

procedure TServidorRecepcionAire.AlConectarCliente(Sender: TObject; FlujoCliente: TSocketStream);
var
  BufferLectura: array[0..1023] of Char;
  BytesLeidos: Integer;
  TextoAcumulado: string;
  IndiceSalto: Integer;
  LineaIndividual: string;
begin
  TextoAcumulado := '';
  try
    repeat
      BytesLeidos := FlujoCliente.Read(BufferLectura[0], SizeOf(BufferLectura));
      if BytesLeidos > 0 then
      begin
        SetString(LineaIndividual, PChar(@BufferLectura[0]), BytesLeidos);
        TextoAcumulado := TextoAcumulado + LineaIndividual;

        IndiceSalto := Pos(#10, TextoAcumulado);
        while IndiceSalto > 0 do
        begin
          LineaIndividual := Copy(TextoAcumulado, 1, IndiceSalto - 1);
          Delete(TextoAcumulado, 1, IndiceSalto);
          ProcesarLineaRecibida(LineaIndividual);
          IndiceSalto := Pos(#10, TextoAcumulado);
        end;
      end;
    until BytesLeidos <= 0;

    if Trim(TextoAcumulado) <> '' then
    begin
      ProcesarLineaRecibida(TextoAcumulado);
    end;
  finally
    FlujoCliente.Free;
  end;
end;

procedure TServidorRecepcionAire.IniciarEscucha;
begin
  WriteLn('================================================================================');
  WriteLn('  SERVIDOR TCP/IP LAZARUS PASCAL (MODO CONSOLA)');
  WriteLn('================================================================================');
  WriteLn('  Direccion IP   : 127.0.0.1');
  WriteLn('  Puerto TCP     : ', FPuertoEscucha);
  WriteLn('  Base de Datos  : ', FRutaBaseDatos);
  WriteLn('  Tabla SQLite   : Aire (id, MP25, Fecha, Hora)');
  WriteLn('--------------------------------------------------------------------------------');
  WriteLn('  Esperando datos de MP2.5 desde la interfaz grafica (Presione Ctrl+C para salir)');
  WriteLn('================================================================================');

  FServidorSocket.Bind;
  FServidorSocket.Listen;
  FServidorSocket.StartAccepting;
end;

var
  ServidorAire: TServidorRecepcionAire;
  RutaBaseDatosPorDefecto: string;
  PuertoConfigurado: Word;

{$R *.res}

begin
  PuertoConfigurado := 5000;

  RutaBaseDatosPorDefecto := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\db\aire.db');
  if not DirectoryExists(ExtractFileDir(RutaBaseDatosPorDefecto)) then
  begin
    RutaBaseDatosPorDefecto := ExtractFilePath(ParamStr(0)) + 'aire.db';
  end;

  try
    ServidorAire := TServidorRecepcionAire.Create(PuertoConfigurado, RutaBaseDatosPorDefecto);
    try
      ServidorAire.IniciarEscucha;
    finally
      ServidorAire.Free;
    end;
  except
    on ErrorGeneral: Exception do
    begin
      WriteLn('[ERROR CRITICO] ', ErrorGeneral.Message);
      ExitCode := 1;
    end;
  end;
end.

