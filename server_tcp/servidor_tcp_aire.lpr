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
  ConsultaCreacion: TSQLQuery;
  DirectorioDB: string;
  RutaLibreriaDLL: string;
begin
  RutaLibreriaDLL := ExtractFilePath(ParamStr(0)) + 'sqlite3.dll';
  if FileExists(RutaLibreriaDLL) then
  begin
    SQLiteDefaultLibrary := RutaLibreriaDLL;
  end;

  DirectorioDB := ExtractFileDir(FRutaBaseDatos);
  if (DirectorioDB <> '') and (not DirectoryExists(DirectorioDB)) then
  begin
    ForceDirectories(DirectorioDB);
  end;

  FConexionSQLite := TSQLite3Connection.Create(nil);
  FTransaccionSQL := TSQLTransaction.Create(nil);

  FConexionSQLite.Transaction := FTransaccionSQL;
  FConexionSQLite.DatabaseName := FRutaBaseDatos;
  FConexionSQLite.Open;

  ConsultaCreacion := TSQLQuery.Create(nil);
  try
    ConsultaCreacion.DataBase := FConexionSQLite;
    ConsultaCreacion.Transaction := FTransaccionSQL;
    ConsultaCreacion.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS Aire (' +
      '  id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      '  MP25 INTEGER NOT NULL, ' +
      '  Fecha TEXT NOT NULL, ' +
      '  Hora TEXT NOT NULL' +
      ');';
    ConsultaCreacion.ExecSQL;
    FTransaccionSQL.Commit;
  finally
    ConsultaCreacion.Free;
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
  WriteLn('  SERVIDOR TCP/IP LAZARUS PASCAL (MODO CONSOLA) - PROYECTO #3 INFO1128');
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

