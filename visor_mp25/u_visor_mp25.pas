unit u_visor_mp25;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Forms,
  Controls,
  Graphics,
  Dialogs,
  Buttons,
  ExtCtrls,
  Types,
  Math,
  ssockets,
  LazSerial,
  TAGraph,
  TASeries,
  TATypes,
  TAChartUtils,
  TACustomSeries,
  TACustomSource,
  TATextElements,
  TALegend;

const
  CANTIDAD_MUESTRAS_VISOR = 30;
  TOTAL_IMAGENES_FONDO    = 6;
  DIRECCION_IP_SERVIDOR   = '127.0.0.1';
  PUERTO_TCP_SERVIDOR     = 5000;

type
  { TFormularioVisorMP25 }
  TFormularioVisorMP25 = class(TForm)
    VisorGraficoMP25: TChart;
    SerieLineaMP25: TLineSeries;
    BotonCapturarPantalla: TBitBtn;
    BotonAlternarGrilla: TBitBtn;
    BotonCambiarFondo: TBitBtn;
    PuertoSerialMP25: TLazSerial;
    TemporizadorSimulacion: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BotonCapturarPantallaClick(Sender: TObject);
    procedure BotonAlternarGrillaClick(Sender: TObject);
    procedure BotonCambiarFondoClick(Sender: TObject);
    procedure VisorGraficoMP25BeforeDrawBackWall(
      ASender: TChart;
      ACanvas: TCanvas;
      const ARect: TRect;
      var ADoDefaultDrawing: Boolean
    );
    procedure PuertoSerialMP25RxData(Sender: TObject);
    procedure TemporizadorSimulacionTimer(Sender: TObject);
  private
    FIndiceFondoActual: Integer;
    FEstadoGrillaActiva: Boolean;
    FRutaCarpetaImagenes: string;
    FImagenFondoActual: TPicture;
    FValoresMuestras: array[0..CANTIDAD_MUESTRAS_VISOR - 1] of Double;
    FCantidadMuestrasRecibidas: Integer;
    FBufferRecepcionSerial: string;

    function ResolverRutaCarpetaImagenes: string;
    procedure ConfigurarPropiedadesGrafico;
    procedure ConfigurarBotonesConIconosYHints;
    procedure CargarIconoEnBoton(BotonDestino: TBitBtn; const RutaArchivoIcono: string);
    procedure ConfigurarPuertoSerialLazSerial;
    procedure CargarImagenDeFondo(const NumeroImagen: Integer);
    procedure ActualizarIconoBotonGrilla;
    procedure InicializarMuestrasPorDefecto;
    procedure RegistrarNuevaMuestraMP25(const ValorMP25: Integer);
    procedure RedibujarSerieEnVisor;
    procedure EnviarMuestraAlServidorTCP(const ValorMP25: Integer);
    function GenerarMuestraNormal80_5: Integer;
    procedure GuardarCapturaFormularioCompleto(const RutaDestino: string);
  public

  end;

var
  FormularioVisorMP25: TFormularioVisorMP25;

implementation

{$R *.lfm}

{ TFormularioVisorMP25 }

procedure TFormularioVisorMP25.FormCreate(Sender: TObject);
begin
  Randomize;

  Caption := 'By Alberto Caro';
  Color := clBtnFace;
  ShowHint := True;

  FImagenFondoActual := TPicture.Create;
  FRutaCarpetaImagenes := ResolverRutaCarpetaImagenes;

  // Comenzamos con img6.png (bosque) tal como aparece en la primera figura del PDF
  FIndiceFondoActual := 6;
  FEstadoGrillaActiva := False;
  FCantidadMuestrasRecibidas := 0;
  FBufferRecepcionSerial := '';

  ConfigurarPropiedadesGrafico;
  ConfigurarBotonesConIconosYHints;
  CargarImagenDeFondo(FIndiceFondoActual);
  InicializarMuestrasPorDefecto;
  ConfigurarPuertoSerialLazSerial;
end;

procedure TFormularioVisorMP25.FormDestroy(Sender: TObject);
begin
  if Assigned(PuertoSerialMP25) and PuertoSerialMP25.Active then
  begin
    try
      PuertoSerialMP25.Close;
    except
      // Ignorar errores al cerrar el puerto durante la destruccion del formulario
    end;
  end;

  if Assigned(FImagenFondoActual) then
  begin
    FImagenFondoActual.Free;
  end;
end;

function TFormularioVisorMP25.ResolverRutaCarpetaImagenes: string;
var
  DirectorioEjecutable: string;
  RutaCandidataLocal: string;
  RutaCandidataPadre: string;
begin
  DirectorioEjecutable := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));

  RutaCandidataLocal := DirectorioEjecutable + 'images' + PathDelim;
  if DirectoryExists(RutaCandidataLocal) then
  begin
    Result := RutaCandidataLocal;
    Exit;
  end;

  RutaCandidataPadre := ExpandFileName(DirectorioEjecutable + '..' + PathDelim + 'images' + PathDelim);
  if DirectoryExists(RutaCandidataPadre) then
  begin
    Result := IncludeTrailingPathDelimiter(RutaCandidataPadre);
    Exit;
  end;

  Result := IncludeTrailingPathDelimiter(ExpandFileName('images'));
end;

procedure TFormularioVisorMP25.ConfigurarPropiedadesGrafico;
begin
  // 1. Titulo Principal (Top)
  VisorGraficoMP25.Title.Text.Clear;
  VisorGraficoMP25.Title.Text.Add('Material Particulado 2.5 um');
  VisorGraficoMP25.Title.Visible := True;
  VisorGraficoMP25.Title.Font.Name := 'Segoe UI';
  VisorGraficoMP25.Title.Font.Size := 11;
  VisorGraficoMP25.Title.Font.Style := [fsBold];
  VisorGraficoMP25.Title.Font.Color := clBlack;

  // 2. SubTitulo (Bottom / Foot)
  VisorGraficoMP25.Foot.Text.Clear;
  VisorGraficoMP25.Foot.Text.Add('Sampling MP 2.5um');
  VisorGraficoMP25.Foot.Visible := True;
  VisorGraficoMP25.Foot.Font.Name := 'Segoe UI';
  VisorGraficoMP25.Foot.Font.Size := 9;
  VisorGraficoMP25.Foot.Font.Style := [fsBold];
  VisorGraficoMP25.Foot.Font.Color := clBlack;

  // 3. Configuracion de Legend
  VisorGraficoMP25.Legend.Visible := True;
  VisorGraficoMP25.Legend.Alignment := laTopRight;
  VisorGraficoMP25.Legend.UseSidebar := True;
  VisorGraficoMP25.Legend.Frame.Visible := True;
  VisorGraficoMP25.Legend.Frame.Color := clBlack;
  VisorGraficoMP25.Legend.BackgroundBrush.Color := clWhite;
  VisorGraficoMP25.Legend.BackgroundBrush.Style := bsSolid;

  // 4. Configuracion del Marco del Visor (Frame)
  VisorGraficoMP25.Frame.Visible := True;
  VisorGraficoMP25.Frame.Color := clBlack;
  VisorGraficoMP25.Frame.Style := psSolid;
  VisorGraficoMP25.BackColor := clBtnFace;

  // 5. Eje Izquierdo (Y): [ug/m3], rango 0 a 230 con marcas cada 50 (0, 50, 100, 150, 200)
  VisorGraficoMP25.LeftAxis.Title.Caption := '[ug/m3]';
  VisorGraficoMP25.LeftAxis.Title.Visible := True;
  VisorGraficoMP25.LeftAxis.Title.LabelFont.Name := 'Segoe UI';
  VisorGraficoMP25.LeftAxis.Title.LabelFont.Size := 10;
  VisorGraficoMP25.LeftAxis.Title.LabelFont.Style := [fsBold];
  VisorGraficoMP25.LeftAxis.Title.LabelFont.Orientation := 900;

  VisorGraficoMP25.LeftAxis.Range.Min := -25;
  VisorGraficoMP25.LeftAxis.Range.Max := 235;
  VisorGraficoMP25.LeftAxis.Range.UseMin := True;
  VisorGraficoMP25.LeftAxis.Range.UseMax := True;
  VisorGraficoMP25.LeftAxis.Marks.Range.Min := 0;
  VisorGraficoMP25.LeftAxis.Marks.Range.Max := 200;
  VisorGraficoMP25.LeftAxis.Marks.Range.UseMin := True;
  VisorGraficoMP25.LeftAxis.Marks.Range.UseMax := True;
  VisorGraficoMP25.LeftAxis.Intervals.MinLength := 20;
  VisorGraficoMP25.LeftAxis.Intervals.MaxLength := 45;
  VisorGraficoMP25.LeftAxis.Intervals.NiceSteps := '0.5';
  VisorGraficoMP25.LeftAxis.Intervals.Options := [aipUseMinLength, aipUseMaxLength, aipUseNiceSteps];

  VisorGraficoMP25.LeftAxis.Grid.Visible := FEstadoGrillaActiva;
  VisorGraficoMP25.LeftAxis.Grid.Color := clBlack;
  VisorGraficoMP25.LeftAxis.Grid.Style := psDot;

  // 6. Eje Inferior (X): muestras 0 a 29 de 1 en 1
  VisorGraficoMP25.BottomAxis.Range.Min := 0;
  VisorGraficoMP25.BottomAxis.Range.Max := CANTIDAD_MUESTRAS_VISOR - 1;
  VisorGraficoMP25.BottomAxis.Range.UseMin := True;
  VisorGraficoMP25.BottomAxis.Range.UseMax := True;
  VisorGraficoMP25.BottomAxis.Intervals.MinLength := 10;
  VisorGraficoMP25.BottomAxis.Intervals.MaxLength := 30;
  VisorGraficoMP25.BottomAxis.Intervals.NiceSteps := '1';
  VisorGraficoMP25.BottomAxis.Intervals.Options := [aipUseMinLength, aipUseMaxLength, aipUseNiceSteps, aipInteger];

  VisorGraficoMP25.BottomAxis.Grid.Visible := FEstadoGrillaActiva;
  VisorGraficoMP25.BottomAxis.Grid.Color := clBlack;
  VisorGraficoMP25.BottomAxis.Grid.Style := psDot;

  // 7. Configuracion de la Serie TLineSeries (LinePen, Marks, Frame, LabelBrush, Style, Pointer, SeriesColor)
  SerieLineaMP25.AxisIndexX := 1;
  SerieLineaMP25.AxisIndexY := 0;
  SerieLineaMP25.Title := 'MP 10 um';
  SerieLineaMP25.ShowInLegend := True;
  SerieLineaMP25.SeriesColor := clRed;

  // Propiedad LinePen
  SerieLineaMP25.LinePen.Color := clRed;
  SerieLineaMP25.LinePen.Width := 1;
  SerieLineaMP25.LinePen.Style := psSolid;
  SerieLineaMP25.ShowLines := True;

  // Propiedad Pointer (cuadrados azules con borde amarillo como en las figuras del PDF)
  SerieLineaMP25.ShowPoints := True;
  SerieLineaMP25.Pointer.Visible := True;
  SerieLineaMP25.Pointer.Style := psRectangle;
  SerieLineaMP25.Pointer.HorizSize := 4;
  SerieLineaMP25.Pointer.VertSize := 4;
  SerieLineaMP25.Pointer.Brush.Color := clBlue;
  SerieLineaMP25.Pointer.Brush.Style := bsSolid;
  SerieLineaMP25.Pointer.Pen.Color := clYellow;
  SerieLineaMP25.Pointer.Pen.Width := 1;
  SerieLineaMP25.Pointer.OverrideColor := [];

  // Propiedades de Marks (Style, Frame, LabelBrush, LinkPen, Distance)
  SerieLineaMP25.Marks.Visible := True;
  SerieLineaMP25.Marks.Style := smsValue;
  SerieLineaMP25.Marks.Format := '%0:.0f';
  SerieLineaMP25.Marks.Distance := 10;
  SerieLineaMP25.Marks.Clipped := True;
  SerieLineaMP25.Marks.Frame.Visible := True;
  SerieLineaMP25.Marks.Frame.Color := clBlack;
  SerieLineaMP25.Marks.Frame.Style := psSolid;
  SerieLineaMP25.Marks.LabelBrush.Color := clWhite;
  SerieLineaMP25.Marks.LabelBrush.Style := bsSolid;
  SerieLineaMP25.Marks.LabelFont.Name := 'Segoe UI';
  SerieLineaMP25.Marks.LabelFont.Size := 8;
  SerieLineaMP25.Marks.LabelFont.Color := clBlack;
  SerieLineaMP25.Marks.LinkPen.Color := clWhite;
  SerieLineaMP25.Marks.LinkPen.Visible := True;
  SerieLineaMP25.MarkPositions := lmpPositive;
end;

procedure TFormularioVisorMP25.CargarIconoEnBoton(BotonDestino: TBitBtn; const RutaArchivoIcono: string);
var
  ImagenIcono: TPicture;
begin
  if not FileExists(RutaArchivoIcono) then
  begin
    Exit;
  end;

  ImagenIcono := TPicture.Create;
  try
    ImagenIcono.LoadFromFile(RutaArchivoIcono);
    BotonDestino.Glyph.Assign(ImagenIcono.Graphic);
  finally
    ImagenIcono.Free;
  end;
end;

procedure TFormularioVisorMP25.ConfigurarBotonesConIconosYHints;
var
  RutaIconoCamara: string;
  RutaIconoPaleta: string;
begin
  // Activacion de Hint en cada boton (Observacion #9 del PDF)
  BotonCapturarPantalla.Caption := 'Save';
  BotonCapturarPantalla.Hint := 'Capturar imagen del visor en captura.png';
  BotonCapturarPantalla.ShowHint := True;

  BotonAlternarGrilla.Caption := 'On/off';
  BotonAlternarGrilla.Hint := 'Activar / Desactivar la grilla del visor';
  BotonAlternarGrilla.ShowHint := True;

  BotonCambiarFondo.Caption := 'Click';
  BotonCambiarFondo.Hint := 'Cambiar la figura de fondo (background) del visor';
  BotonCambiarFondo.ShowHint := True;

  VisorGraficoMP25.Hint := 'Visor de Material Particulado MP 2.5 um';
  VisorGraficoMP25.ShowHint := True;

  // Cargar icono de camara fotografica (camara.png)
  RutaIconoCamara := FRutaCarpetaImagenes + 'camara.png';
  CargarIconoEnBoton(BotonCapturarPantalla, RutaIconoCamara);

  // Cargar icono de paleta (pale.png)
  RutaIconoPaleta := FRutaCarpetaImagenes + 'pale.png';
  CargarIconoEnBoton(BotonCambiarFondo, RutaIconoPaleta);

  // Cargar icono de grilla (f02.bmp)
  ActualizarIconoBotonGrilla;
end;

procedure TFormularioVisorMP25.ActualizarIconoBotonGrilla;
var
  RutaIconoGrilla: string;
begin
  RutaIconoGrilla := FRutaCarpetaImagenes + 'f02.bmp';
  CargarIconoEnBoton(BotonAlternarGrilla, RutaIconoGrilla);
end;

procedure TFormularioVisorMP25.CargarImagenDeFondo(const NumeroImagen: Integer);
var
  NombreArchivoFondo: string;
  RutaCompletaFondo: string;
begin
  NombreArchivoFondo := Format('img%d.png', [NumeroImagen]);
  RutaCompletaFondo := FRutaCarpetaImagenes + NombreArchivoFondo;

  if FileExists(RutaCompletaFondo) then
  begin
    FImagenFondoActual.LoadFromFile(RutaCompletaFondo);
    VisorGraficoMP25.Invalidate;
  end;
end;

procedure TFormularioVisorMP25.ConfigurarPuertoSerialLazSerial;
begin
  // Observaciones #3 y #4: LazSerial a 9.600 Bps, 8N1
  PuertoSerialMP25.BaudRate := br__9600;
  PuertoSerialMP25.DataBits := db8bits;
  PuertoSerialMP25.Parity := pNone;
  PuertoSerialMP25.StopBits := sbOne;
  PuertoSerialMP25.FlowControl := fcNone;
  PuertoSerialMP25.RcvLineCRLF := True;

  if (ParamCount >= 1) and (Copy(ParamStr(1), 1, 2) <> '--') then
  begin
    PuertoSerialMP25.Device := ParamStr(1);
  end
  else
  begin
    PuertoSerialMP25.Device := 'COM2';
  end;

  try
    PuertoSerialMP25.Open;
  except
    // Si COM2 no existe, intentar con COM1
    try
      PuertoSerialMP25.Device := 'COM1';
      PuertoSerialMP25.Open;
    except
      // Si el puerto serial esta ocupado por el script de Python o no hay par virtual,
      // el TemporizadorSimulacion mantiene el sampling de 1 segundo con Normal(80,5)
    end;
  end;

  // Sampling de 1 segundo (1000 ms)
  TemporizadorSimulacion.Interval := 1000;
  TemporizadorSimulacion.Enabled := True;
end;

function TFormularioVisorMP25.GenerarMuestraNormal80_5: Integer;
var
  ValorNormal: Double;
begin
  // Observacion #5: Distribución Normal(80, 5)
  ValorNormal := RandG(80.0, 5.0);
  Result := EnsureRange(Round(ValorNormal), 0, 200);
end;

procedure TFormularioVisorMP25.InicializarMuestrasPorDefecto;
var
  IndiceMuestra: Integer;
begin
  FCantidadMuestrasRecibidas := CANTIDAD_MUESTRAS_VISOR;
  for IndiceMuestra := 0 to CANTIDAD_MUESTRAS_VISOR - 1 do
  begin
    FValoresMuestras[IndiceMuestra] := GenerarMuestraNormal80_5;
  end;

  RedibujarSerieEnVisor;
end;

procedure TFormularioVisorMP25.RegistrarNuevaMuestraMP25(const ValorMP25: Integer);
var
  IndiceDesplazamiento: Integer;
begin
  if FCantidadMuestrasRecibidas < CANTIDAD_MUESTRAS_VISOR then
  begin
    FValoresMuestras[FCantidadMuestrasRecibidas] := ValorMP25;
    Inc(FCantidadMuestrasRecibidas);
  end
  else
  begin
    for IndiceDesplazamiento := 0 to CANTIDAD_MUESTRAS_VISOR - 2 do
    begin
      FValoresMuestras[IndiceDesplazamiento] := FValoresMuestras[IndiceDesplazamiento + 1];
    end;
    FValoresMuestras[CANTIDAD_MUESTRAS_VISOR - 1] := ValorMP25;
  end;

  RedibujarSerieEnVisor;
  EnviarMuestraAlServidorTCP(ValorMP25);
end;

procedure TFormularioVisorMP25.RedibujarSerieEnVisor;
var
  IndicePunto: Integer;
begin
  SerieLineaMP25.BeginUpdate;
  try
    SerieLineaMP25.Clear;
    for IndicePunto := 0 to FCantidadMuestrasRecibidas - 1 do
    begin
      SerieLineaMP25.AddXY(IndicePunto, FValoresMuestras[IndicePunto]);
    end;
  finally
    SerieLineaMP25.EndUpdate;
  end;
end;

procedure TFormularioVisorMP25.EnviarMuestraAlServidorTCP(const ValorMP25: Integer);
var
  SocketClienteTCP: TInetSocket;
  MensajeEnvio: string;
begin
  // Observacion #12: Enviar el MP25 recibido a un Server TCP/IP Lazarus Pascal mode consola
  MensajeEnvio := IntToStr(ValorMP25) + LineEnding;
  try
    SocketClienteTCP := TInetSocket.Create(DIRECCION_IP_SERVIDOR, PUERTO_TCP_SERVIDOR, 250);
    try
      SocketClienteTCP.WriteBuffer(MensajeEnvio[1], Length(MensajeEnvio));
    finally
      SocketClienteTCP.Free;
    end;
  except
    // Si el servidor consola aun no se ha iniciado, continuar sin bloquear la interfaz grafica
  end;
end;

procedure TFormularioVisorMP25.PuertoSerialMP25RxData(Sender: TObject);
var
  DatosRecibidos: string;
  TextoLimpio: string;
  ValorMP25Leido: Integer;
begin
  DatosRecibidos := PuertoSerialMP25.ReadData;
  TextoLimpio := Trim(DatosRecibidos);

  if TryStrToInt(TextoLimpio, ValorMP25Leido) then
  begin
    // Si llegan datos reales por LazSerial desde el script de Python,
    // desactivamos el generador interno para graficar unicamente el puerto serial
    TemporizadorSimulacion.Enabled := False;
    RegistrarNuevaMuestraMP25(ValorMP25Leido);
  end;
end;

procedure TFormularioVisorMP25.TemporizadorSimulacionTimer(Sender: TObject);
var
  MuestraSimulada: Integer;
begin
  MuestraSimulada := GenerarMuestraNormal80_5;
  RegistrarNuevaMuestraMP25(MuestraSimulada);
end;

procedure TFormularioVisorMP25.VisorGraficoMP25BeforeDrawBackWall(
  ASender: TChart;
  ACanvas: TCanvas;
  const ARect: TRect;
  var ADoDefaultDrawing: Boolean
);
begin
  if Assigned(FImagenFondoActual) and Assigned(FImagenFondoActual.Graphic) and (not FImagenFondoActual.Graphic.Empty) then
  begin
    ACanvas.StretchDraw(ARect, FImagenFondoActual.Graphic);
    ACanvas.Brush.Style := bsClear;
    ACanvas.Pen.Color := clBlack;
    ACanvas.Pen.Style := psSolid;
    ACanvas.Rectangle(ARect);
    ACanvas.Brush.Style := bsSolid;
    ADoDefaultDrawing := False;
  end;
end;

procedure TFormularioVisorMP25.GuardarCapturaFormularioCompleto(const RutaDestino: string);
begin
  CargarImagenDeFondo(FIndiceFondoActual);
  VisorGraficoMP25.SaveToFile(TPortableNetworkGraphic, RutaDestino);
end;

procedure TFormularioVisorMP25.BotonCapturarPantallaClick(Sender: TObject);
var
  DirectorioEjecutable: string;
  RutaArchivoCapturaLocal: string;
  RutaArchivoCapturaRaiz: string;
begin
  // Observacion #6: Boton "Camara Fotografica" -> realiza una captura -> captura.png
  DirectorioEjecutable := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  RutaArchivoCapturaLocal := DirectorioEjecutable + 'captura.png';
  GuardarCapturaFormularioCompleto(RutaArchivoCapturaLocal);

  RutaArchivoCapturaRaiz := ExpandFileName(DirectorioEjecutable + '..' + PathDelim + 'captura.png');
  if DirectoryExists(ExtractFilePath(RutaArchivoCapturaRaiz) + 'images') then
  begin
    GuardarCapturaFormularioCompleto(RutaArchivoCapturaRaiz);
  end;
end;

procedure TFormularioVisorMP25.BotonAlternarGrillaClick(Sender: TObject);
begin
  // Observacion #7: Boton "On/Off" -> Activa/Desactiva la Grilla del visor
  FEstadoGrillaActiva := not FEstadoGrillaActiva;
  VisorGraficoMP25.LeftAxis.Grid.Visible := FEstadoGrillaActiva;
  VisorGraficoMP25.BottomAxis.Grid.Visible := FEstadoGrillaActiva;
  VisorGraficoMP25.Invalidate;
end;

procedure TFormularioVisorMP25.BotonCambiarFondoClick(Sender: TObject);
begin
  // Observacion #8: Boton de "Click" -> Cambia la figura de fondo (background) del visor
  Inc(FIndiceFondoActual);
  if FIndiceFondoActual > TOTAL_IMAGENES_FONDO then
  begin
    FIndiceFondoActual := 1;
  end;

  CargarImagenDeFondo(FIndiceFondoActual);
end;

end.
