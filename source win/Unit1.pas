unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdGlobal,
  IdException, idExceptioncore, Vcl.Imaging.jpeg, Vcl.ExtCtrls, IdStack,
  Vcl.Mask, FileCtrl, IdUDPBase, IdUDPClient, Vcl.Samples.Spin;

type
  TForm1 = class(TForm)
    IdTCPClient1: TIdTCPClient;
    Button1: TButton;
    OpenDialog1: TOpenDialog;
    Button2: TButton;
    ProgressBar1: TProgressBar;
    Edit1: TEdit;
    Edit2: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Button3: TButton;
    GroupBox1: TGroupBox;
    Button4: TButton;
    Image1: TImage;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    Label4: TLabel;
    IdUDPClient1: TIdUDPClient;
    CheckBox1: TCheckBox;
    GroupBox2: TGroupBox;
    RadioButton3: TRadioButton;
    RadioButton4: TRadioButton;
    Label5: TLabel;
    Label6: TLabel;
    SpinEdit1: TSpinEdit;
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Edit1KeyPress(Sender: TObject; var Key: Char);
    procedure Edit2KeyPress(Sender: TObject; var Key: Char);
    procedure Button4Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure Image1Click(Sender: TObject);
    procedure UpdateProgress(APosition: Integer);
    procedure settings_unlock;
    procedure settings_lock;
    procedure tcp_connection;
    procedure udp_connection;
    procedure tcp_switch;
    procedure udp_switch;
    procedure tcp_can_switch;
    procedure udp_can_switch;
    procedure tcp_rs485_switch;
    procedure udp_rs485_switch;
    procedure tcp_update;
    procedure udp_update;
    procedure tcp_can_connection;
    procedure tcp_rs485_connection;
    procedure udp_can_connection;
    procedure udp_rs485_connection;
    procedure CheckBox1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.settings_unlock;
begin
  Edit1.Enabled := true;
  Edit2.Enabled := true;
  RadioButton1.Enabled := true;
  RadioButton2.Enabled := true;
  Label1.Enabled := true;
  Label2.Enabled := true;
  Label4.Enabled := true;
  Label3.Caption := '';
  Button3.Enabled := false;
  Button2.Enabled := false;
  Button1.Enabled := false;
  CheckBox1.Enabled := true;
  Button4.Caption := 'Подключиться';
  Button4.Tag := 0;
  if CheckBox1.Checked = true then
  begin
    Label5.Enabled := true;
    RadioButton3.Enabled := true;
    Label6.Enabled := true;
    // RadioButton4.Enabled := true;
    SpinEdit1.Enabled := true;
  end;
end;

procedure TForm1.settings_lock;
begin
  Edit1.Enabled := false;
  Edit2.Enabled := false;
  RadioButton1.Enabled := false;
  RadioButton2.Enabled := false;
  Label1.Enabled := false;
  Label2.Enabled := false;
  Label4.Enabled := false;
  Button3.Enabled := true;
  CheckBox1.Enabled := false;
  Label5.Enabled := false;
  Label6.Enabled := false;
  RadioButton3.Enabled := false;
  // RadioButton4.Enabled := false;
  SpinEdit1.Enabled := false;

  Button4.Caption := 'Отключиться';
  Button4.Tag := 1;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  if RadioButton1.Checked then
    tcp_update
  else if RadioButton2.Checked then
    udp_update;
end;

procedure TForm1.tcp_update;
const
  chunk_size = 512;
  marker = $DD;
var
  FileStream: TFileStream;
  Buffer: array [0 .. chunk_size] of Byte;
  BytesRead: Integer;
  IdBytes: TIdBytes;
  a, progress_step: real;
  Ack: Byte;
begin
  a := 0;
  if MessageDlg('Память рабочей программы будет очищена! Продолжить?',
    mtWarning, [mbYes, mbNo], 0) = mrYes then
  begin
    IdTCPClient1.IOHandler.ReadTimeout := 5000;
    IdTCPClient1.IOHandler.Write($DC);
    try
      Ack := IdTCPClient1.IOHandler.ReadByte;
      if Ack <> $DA then
      begin
        MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
      end
      else
        MessageDlg('Память рабочей программы очищена!', mtInformation,
          [mbOk], 0);
    except
      on E: Eidreadtimeout do
      begin
        MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
        settings_unlock;
        IdTCPClient1.Disconnect;
        IdTCPClient1.IOHandler := nil;
      end;
    end;

    FileStream := TFileStream.Create(OpenDialog1.FileName,
      fmOpenRead or fmShareDenyWrite);
    progress_step := (100 * chunk_size) / FileStream.Size;

    repeat
      BytesRead := FileStream.Read(Buffer, chunk_size);
      if BytesRead > 0 then
      begin
        SetLength(IdBytes, BytesRead + 1);
        IdBytes[0] := marker;
        Move(Buffer[0], IdBytes[1], BytesRead);
        IdTCPClient1.IOHandler.Write(IdBytes);
        a := a + progress_step;
        UpdateProgress(round(a));
        try
          Ack := IdTCPClient1.IOHandler.ReadByte;
        except
          on E: Eidreadtimeout do
          begin
            MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
            settings_unlock;
            IdTCPClient1.Disconnect;
            IdTCPClient1.IOHandler := nil;
            break;
          end;
        end;
      end;

    until BytesRead = 0;

    MessageDlg('ПО успешно загружено!', mtInformation, [mbOk], 0);
    ProgressBar1.Position := 0;
    FileStream.Free;
  end
  else
end;

procedure TForm1.udp_update;
const
  chunk_size = 512;
  marker = $DD;
var
  FileStream: TFileStream;
  Buffer: array [0 .. chunk_size] of Byte;
  BytesRead, Size: Integer;
  IdBytes, Ack: TIdBytes;
  a, progress_step: real;
begin
  a := 0;
  if MessageDlg('Память рабочей программы будет очищена! Продолжить?',
    mtWarning, [mbYes, mbNo], 0) = mrYes then
  begin
    IdUDPClient1.ReceiveTimeout := 5000;
    SetLength(Ack, 1);
    Ack[0] := $DC;
    IdUDPClient1.SendBuffer(Ack);
    Size := IdUDPClient1.ReceiveBuffer(Ack, 5000);
    if Size = 0 then
    begin
      MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
      settings_unlock;
      IdUDPClient1.Disconnect;
    end
    else
    begin
      if Ack[0] <> $DA then
      begin
        MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
      end
      else
        MessageDlg('Память рабочей программы очищена!', mtInformation,
          [mbOk], 0);
    end;

    FileStream := TFileStream.Create(OpenDialog1.FileName,
      fmOpenRead or fmShareDenyWrite);
    progress_step := (100 * chunk_size) / FileStream.Size;

    repeat
      BytesRead := FileStream.Read(Buffer, chunk_size);
      if BytesRead > 0 then
      begin
        SetLength(IdBytes, BytesRead + 1);
        IdBytes[0] := marker;
        Move(Buffer[0], IdBytes[1], BytesRead);
        IdUDPClient1.SendBuffer(IdBytes);
        a := a + progress_step;
        UpdateProgress(round(a));
        sleep(5);
        Size := IdUDPClient1.ReceiveBuffer(Ack, 2000);
        if Size = 0 then
        begin
          MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
          break;
        end;
      end;
    until BytesRead = 0;
    MessageDlg('ПО успешно загружено!', mtInformation, [mbOk], 0);
    ProgressBar1.Position := 0;
    FileStream.Free;
  end
  else
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  SearchRec: TSearchRec;
begin
  if OpenDialog1.Execute then
    if FileExists(OpenDialog1.FileName) then
    begin
      FindFirst(OpenDialog1.FileName, faAnyFile, SearchRec);
      if SearchRec.Size < 917504 then
      begin
        Label3.Caption := MinimizeName(OpenDialog1.FileName, Label3.Canvas,
          Label3.Width);
        Button1.Enabled := true;
      end
      else
      begin
        MessageDlg('Файл: ' + OpenDialog1.FileName + ' слишком большой!' + #13 +
          'Размер файла не должен превышать 896 КБ', mtError, [mbOk], 0);
        Label3.Caption := '';
        Button1.Enabled := false;
      end;
    end
    else
    begin
      MessageDlg('Файл: ' + OpenDialog1.FileName + ' не существует!', mtError,
        [mbOk], 0);
      Label3.Caption := '';
      Button1.Enabled := false;
    end;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  if CheckBox1.Checked = true then
  begin
    if RadioButton1.Checked = true then
    begin
      if RadioButton3.Checked = true then
        tcp_can_switch
      else if RadioButton4.Checked = true then
        tcp_rs485_switch;
    end
    else if RadioButton2.Checked = true then
    begin
      if RadioButton3.Checked = true then
        udp_can_switch
      else if RadioButton4.Checked = true then
        udp_rs485_switch;
    end;
  end
  else
  begin
    if RadioButton1.Checked = true then
      tcp_switch
    else if RadioButton2.Checked = true then
      udp_switch;
  end;
end;

procedure TForm1.tcp_switch;
var
  Ack: Byte;
begin
  if Button3.Tag = 0 then
  begin
    if MessageDlg('Вы точно хотите переключить режим работы?' + #13 +
      '(если рабочее ПО не поддерживает текущую версию загрузчика, то вход в режим обновления ПО станет невозможным)',
      mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      IdTCPClient1.IOHandler.ReadTimeout := 2000;
      IdTCPClient1.IOHandler.Write($DF);

      begin
        try
          Ack := IdTCPClient1.IOHandler.ReadByte;
          if Ack <> $DA then
          begin
            MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
            settings_unlock;
            IdTCPClient1.Disconnect;
            IdTCPClient1.IOHandler := nil;
          end
          else
          begin
            Button3.Tag := 1;
            Button3.Caption := 'Перейти в режим обновления ПО';
            MessageDlg
              ('Переход в рабочий режим выполнен. Требуется повторное подключение!',
              mtInformation, [mbOk], 0);
            settings_unlock;
            IdTCPClient1.Disconnect;
            IdTCPClient1.IOHandler := nil;
          end;
        except
          on E: Eidreadtimeout do
          begin
            MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
            settings_unlock;
            IdTCPClient1.Disconnect;
            IdTCPClient1.IOHandler := nil;
          end;
        end;
      end;
    end
    else
  end
  else
  begin
    if MessageDlg('Вы точно хотите переключить режим работы?', mtWarning,
      [mbYes, mbNo], 0) = mrYes then
    begin
      IdTCPClient1.IOHandler.ReadTimeout := 2000;
      IdTCPClient1.IOHandler.Write($DF);
      try
        Ack := IdTCPClient1.IOHandler.ReadByte;
        if Ack <> $DA then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end
        else
        begin
          Button3.Tag := 0;
          Button3.Caption := 'Перейти в рабочий режим';
          MessageDlg
            ('Переход в режим обновления ПО выполнен. Требуется повторное подключение!',
            mtInformation, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end;
      except
        on E: Eidreadtimeout do
        begin
          MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end;
      end;
    end
    else
  end;
end;

procedure TForm1.tcp_can_switch;
var
  Ack: Byte;
  Buffer: array [0 .. 1] of Byte;
  IdBytes: TIdBytes;
begin
  if Button3.Tag = 0 then
  begin
    if MessageDlg('Вы точно хотите переключить режим работы платы по адресу ' +
      inttostr(SpinEdit1.Value) + '?' + #13 +
      '(если рабочее ПО не поддерживает текущую версию загрузчика, то вход в режим обновления ПО станет невозможным)',
      mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      IdTCPClient1.IOHandler.ReadTimeout := 2000;
      SetLength(IdBytes, 2);
      Buffer[0] := $CF;
      Buffer[1] := SpinEdit1.Value;
      Move(Buffer[0], IdBytes[0], 2);
      IdTCPClient1.IOHandler.Write(IdBytes);
      begin
        try
          Ack := IdTCPClient1.IOHandler.ReadByte;
          if Ack <> $DA then
          begin
            MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
            settings_unlock;
            IdTCPClient1.Disconnect;
            IdTCPClient1.IOHandler := nil;
          end
          else
          begin
            Button3.Tag := 1;
            Button3.Caption := 'Перейти в режим обновления ПО';
            MessageDlg('Переход по адресу ' + inttostr(SpinEdit1.Value) +
              ' в рабочий режим выполнен. Требуется повторное подключение!',
              mtInformation, [mbOk], 0);
            settings_unlock;
            IdTCPClient1.Disconnect;
            IdTCPClient1.IOHandler := nil;
          end;
        except
          on E: Eidreadtimeout do
          begin
            MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
            settings_unlock;
            IdTCPClient1.Disconnect;
            IdTCPClient1.IOHandler := nil;
          end;
        end;
      end;
    end
    else
  end
  else
  begin
    if MessageDlg('Вы точно хотите переключить режим работы платы по адресу ' +
      inttostr(SpinEdit1.Value) + '?', mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      IdTCPClient1.IOHandler.ReadTimeout := 2000;
      SetLength(IdBytes, 2);
      Buffer[0] := $CF;
      Buffer[1] := SpinEdit1.Value;
      Move(Buffer[0], IdBytes[0], 2);
      IdTCPClient1.IOHandler.Write(IdBytes);
      try
        Ack := IdTCPClient1.IOHandler.ReadByte;
        if Ack <> $DA then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end
        else
        begin
          Button3.Tag := 0;
          Button3.Caption := 'Перейти в рабочий режим';
          MessageDlg('Переход платы по адресу ' + inttostr(SpinEdit1.Value) +
            ' в режим обновления ПО выполнен. Требуется повторное подключение!',
            mtInformation, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end;
      except
        on E: Eidreadtimeout do
        begin
          MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end;
      end;
    end
    else
  end;
end;

procedure TForm1.tcp_rs485_switch;
var
  Ack: Byte;
  Buffer: array [0 .. 1] of Byte;
  IdBytes: TIdBytes;
begin
  if Button3.Tag = 0 then
  begin
    if MessageDlg('Вы точно хотите переключить режим работы?' + #13 +
      '(если рабочее ПО не поддерживает текущую версию загрузчика, то вход в режим обновления ПО станет невозможным)',
      mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      IdTCPClient1.IOHandler.ReadTimeout := 2000;

      SetLength(IdBytes, 2);
      Buffer[0] := $EF;
      Buffer[1] := SpinEdit1.Value;
      Move(Buffer[0], IdBytes[0], 2);
      IdTCPClient1.IOHandler.Write(IdBytes);
      begin
        try
          Ack := IdTCPClient1.IOHandler.ReadByte;
          if Ack <> $DA then
          begin
            MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
            settings_unlock;
            IdTCPClient1.Disconnect;
            IdTCPClient1.IOHandler := nil;
          end
          else
          begin
            Button3.Tag := 1;
            Button3.Caption := 'Перейти в режим обновления ПО';
            MessageDlg('Переход платы по адресу ' + inttostr(SpinEdit1.Value) +
              ' в рабочий режим выполнен. Требуется повторное подключение!',
              mtInformation, [mbOk], 0);
            settings_unlock;
            IdTCPClient1.Disconnect;
            IdTCPClient1.IOHandler := nil;
          end;
        except
          on E: Eidreadtimeout do
          begin
            MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
            settings_unlock;
            IdTCPClient1.Disconnect;
            IdTCPClient1.IOHandler := nil;
          end;
        end;
      end;
    end
    else
  end
  else
  begin
    if MessageDlg('Вы точно хотите переключить режим работы?', mtWarning,
      [mbYes, mbNo], 0) = mrYes then
    begin
      IdTCPClient1.IOHandler.ReadTimeout := 2000;
      SetLength(IdBytes, 2);
      Buffer[0] := $EF;
      Buffer[1] := SpinEdit1.Value;
      Move(Buffer[0], IdBytes[0], 2);
      IdTCPClient1.IOHandler.Write(IdBytes);;

      try
        Ack := IdTCPClient1.IOHandler.ReadByte;
        if Ack <> $DA then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end
        else
        begin
          Button3.Tag := 0;
          Button3.Caption := 'Перейти в рабочий режим';
          MessageDlg('Переход платы по адресу ' + inttostr(SpinEdit1.Value) +
            ' в режим обновления ПО выполнен. Требуется повторное подключение!',
            mtInformation, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end;
      except
        on E: Eidreadtimeout do
        begin
          MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end;
      end;
    end
    else
  end;
end;

procedure TForm1.udp_switch;
var
  Ack: TIdBytes;
  Size: Integer;
begin
  if Button3.Tag = 0 then
  begin
    if MessageDlg('Вы точно хотите переключить режим работы?' + #13 +
      '(если рабочее ПО не поддерживает текущую версию загрузчика, то вход в режим обновления ПО станет невозможным)',
      mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      IdUDPClient1.ReceiveTimeout := 2000;
      SetLength(Ack, 1);
      Ack[0] := $DF;
      IdUDPClient1.SendBuffer(Ack);
      Size := IdUDPClient1.ReceiveBuffer(Ack, 2000);
      if Size = 0 then
      begin
        MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
        settings_unlock;
        IdUDPClient1.Disconnect;
      end
      else
      begin
        if Ack[0] <> $DA then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end
        else
        begin
          Button3.Tag := 1;
          Button3.Caption := 'Перейти в режим обновления ПО';
          MessageDlg
            ('Переход в рабочий режим выполнен. Требуется повторное подключение!',
            mtInformation, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end;
      end;
    end
    else
  end
  else
  begin
    if MessageDlg('Вы точно хотите переключить режим работы?', mtWarning,
      [mbYes, mbNo], 0) = mrYes then
    begin
      IdUDPClient1.ReceiveTimeout := 2000;
      SetLength(Ack, 1);
      Ack[0] := $DF;
      IdUDPClient1.SendBuffer(Ack);
      Size := IdUDPClient1.ReceiveBuffer(Ack, 2000);
      if Size = 0 then
      begin
        MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
        settings_unlock;
        IdUDPClient1.Disconnect;
      end
      else
      begin
        if Ack[0] <> $DA then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end
        else
        begin
          Button3.Tag := 0;
          Button3.Caption := 'Перейти в рабочий режим';
          MessageDlg
            ('Переход в режим обновления ПО выполнен. Требуется повторное подключение!',
            mtInformation, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end;
      end;
    end
    else
  end;
end;

procedure TForm1.udp_can_switch;
var
  Ack: TIdBytes;
  Size: Integer;
begin
  if Button3.Tag = 0 then
  begin
    if MessageDlg('Вы точно хотите переключить режим работы?' + #13 +
      '(если рабочее ПО не поддерживает текущую версию загрузчика, то вход в режим обновления ПО станет невозможным)',
      mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      IdUDPClient1.ReceiveTimeout := 2000;
      SetLength(Ack, 1);
      Ack[0] := $CF;
      Ack[1] := SpinEdit1.Value;
      IdUDPClient1.SendBuffer(Ack);
      Size := IdUDPClient1.ReceiveBuffer(Ack, 2000);
      if Size = 0 then
      begin
        MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
        settings_unlock;
        IdUDPClient1.Disconnect;
      end
      else
      begin
        if Ack[0] <> $DA then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end
        else
        begin
          Button3.Tag := 1;
          Button3.Caption := 'Перейти в режим обновления ПО';
          MessageDlg('Переход платы по адресу ' + inttostr(SpinEdit1.Value) +
            ' в рабочий режим выполнен. Требуется повторное подключение!',
            mtInformation, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end;
      end;
    end
    else
  end
  else
  begin
    if MessageDlg('Вы точно хотите переключить режим работы?', mtWarning,
      [mbYes, mbNo], 0) = mrYes then
    begin
      IdUDPClient1.ReceiveTimeout := 2000;
      SetLength(Ack, 1);
      Ack[0] := $CF;
      Ack[1] := SpinEdit1.Value;
      IdUDPClient1.SendBuffer(Ack);
      Size := IdUDPClient1.ReceiveBuffer(Ack, 2000);
      if Size = 0 then
      begin
        MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
        settings_unlock;
        IdUDPClient1.Disconnect;
      end
      else
      begin
        if Ack[0] <> $DA then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end
        else
        begin
          Button3.Tag := 0;
          Button3.Caption := 'Перейти в рабочий режим';
          MessageDlg('Переход платы по адресу ' + inttostr(SpinEdit1.Value) +
            ' в режим обновления ПО выполнен. Требуется повторное подключение!',
            mtInformation, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end;
      end;
    end
    else
  end;
end;

procedure TForm1.udp_rs485_switch;
var
  Ack: TIdBytes;
  Size: Integer;
begin
  if Button3.Tag = 0 then
  begin
    if MessageDlg('Вы точно хотите переключить режим работы?' + #13 +
      '(если рабочее ПО не поддерживает текущую версию загрузчика, то вход в режим обновления ПО станет невозможным)',
      mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      IdUDPClient1.ReceiveTimeout := 2000;
      SetLength(Ack, 1);
      Ack[0] := $EF;
      Ack[1] := SpinEdit1.Value;
      IdUDPClient1.SendBuffer(Ack);
      Size := IdUDPClient1.ReceiveBuffer(Ack, 2000);
      if Size = 0 then
      begin
        MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
        settings_unlock;
        IdUDPClient1.Disconnect;
      end
      else
      begin
        if Ack[0] <> $DA then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end
        else
        begin
          Button3.Tag := 1;
          Button3.Caption := 'Перейти в режим обновления ПО';
          MessageDlg
            ('Переход в рабочий режим выполнен. Требуется повторное подключение!',
            mtInformation, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end;
      end;
    end
    else
  end
  else
  begin
    if MessageDlg('Вы точно хотите переключить режим работы?', mtWarning,
      [mbYes, mbNo], 0) = mrYes then
    begin
      IdUDPClient1.ReceiveTimeout := 2000;
      SetLength(Ack, 1);
      Ack[0] := $EF;
      Ack[1] := SpinEdit1.Value;
      IdUDPClient1.SendBuffer(Ack);
      Size := IdUDPClient1.ReceiveBuffer(Ack, 2000);
      if Size = 0 then
      begin
        MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
        settings_unlock;
        IdUDPClient1.Disconnect;
      end
      else
      begin
        if Ack[0] <> $DA then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end
        else
        begin
          Button3.Tag := 0;
          Button3.Caption := 'Перейти в рабочий режим';
          MessageDlg
            ('Переход в режим обновления ПО выполнен. Требуется повторное подключение!',
            mtInformation, [mbOk], 0);
          settings_unlock;
          IdUDPClient1.Disconnect;
        end;
      end;
    end
    else
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  if Button4.Tag = 0 then
  begin
    if CheckBox1.Checked = true then
    begin
      if RadioButton1.Checked = true then
      begin
        if RadioButton3.Checked = true then
          tcp_can_connection
        else if RadioButton4.Checked = true then
          tcp_rs485_connection;
      end
      else if RadioButton2.Checked = true then
      begin
        if RadioButton3.Checked = true then
          udp_can_connection
        else if RadioButton4.Checked = true then
          udp_rs485_connection;
      end;
    end
    else
    begin
      if RadioButton1.Checked = true then
        tcp_connection
      else if RadioButton2.Checked = true then
        udp_connection;
    end;
  end
  else if Button4.Tag = 1 then
  begin
    settings_unlock;
    IdTCPClient1.Disconnect;
    IdTCPClient1.IOHandler := nil;
    IdUDPClient1.Disconnect;
  end;
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
  if CheckBox1.Checked = true then
  begin
    GroupBox2.Enabled := true;
    RadioButton3.Enabled := true;
    // RadioButton4.Enabled := true;
    SpinEdit1.Enabled := true;
    Label5.Enabled := true;
    Label6.Enabled := true;
  end
  else
  begin
    GroupBox2.Enabled := false;
    RadioButton3.Enabled := false;
    // RadioButton4.Enabled := false;
    SpinEdit1.Enabled := false;
    Label5.Enabled := false;
    Label6.Enabled := false;
  end;
end;

procedure TForm1.tcp_connection;
var
  Ack: Byte;
begin
  if (IdTCPClient1.Connected = false) and (Edit1.Text <> '') and
    (Edit2.Text <> '') then
  begin
    settings_lock;
    IdTCPClient1.Host := Edit1.Text;
    IdTCPClient1.Port := strtoint(Edit2.Text);
    try
      IdTCPClient1.Connect;
      sleep(100);
      IdTCPClient1.IOHandler.ReadTimeout := 2000;
      IdTCPClient1.IOHandler.Write($DE);
      try
        Ack := IdTCPClient1.IOHandler.ReadByte;
        if Ack = $D0 then
        begin
          Button3.Tag := 0;
          Button3.Caption := 'Перейти в рабочий режим';
          Button2.Enabled := true;
          Button1.Enabled := false;
        end
        else if Ack = $D1 then
        begin
          Button3.Tag := 1;
          Button3.Caption := 'Перейти в режим обновления ПО';
          Button2.Enabled := false;
          Button1.Enabled := false;
        end
        else if (Ack <> $D0) or (Ack <> $D1) then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end;

      except
        on E: Eidreadtimeout do
        begin
          MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end;
      end;
    except
      on E: EIdConnectTimeout do
      begin
        MessageDlg('Не удалось установить соединение!', mtError, [mbOk], 0);
        settings_unlock;
        IdTCPClient1.Disconnect;
        IdTCPClient1.IOHandler := nil;
      end;
      on E: EIdSocketError do
      begin
        MessageDlg
          ('Ошибка соединения! Проверьте правильность настроек и повторите попытку!',
          mtError, [mbOk], 0);
        settings_unlock;
        IdTCPClient1.Disconnect;
        IdTCPClient1.IOHandler := nil;
      end;
    end;
  end
  else
  begin
    settings_unlock;
    IdTCPClient1.Disconnect;
    IdTCPClient1.IOHandler := nil;
  end;
end;

procedure TForm1.tcp_can_connection;
var
  Ack: Byte;
  Buffer: array [0 .. 1] of Byte;
  IdBytes: TIdBytes;
begin
  tcp_connection;
  if Button3.Tag = 1 then
  begin
    if MessageDlg
      ('Работа в режиме шлюза tcp -> can доступна только в режиме обновления ПО. Перейти в этот режим?',
      mtWarning, [mbYes, mbNo], 0) = mrYes then
      tcp_switch
    else
    begin
      settings_unlock;
      IdTCPClient1.Disconnect;
      IdTCPClient1.IOHandler := nil;
    end;
  end
  else
  begin
    SetLength(IdBytes, 2);
    Buffer[0] := $CE;
    Buffer[1] := SpinEdit1.Value;
    Move(Buffer[0], IdBytes[0], 2);
    IdTCPClient1.IOHandler.Write(IdBytes);
    try
      Ack := IdTCPClient1.IOHandler.ReadByte;
      if Ack = $D0 then
      begin
        Button3.Tag := 0;
        Button3.Caption := 'Перейти в рабочий режим';
        Button2.Enabled := true;
        Button1.Enabled := false;
      end
      else if Ack = $D1 then
      begin
        Button3.Tag := 1;
        Button3.Caption := 'Перейти в режим обновления ПО';
        Button2.Enabled := false;
        Button1.Enabled := false;
      end
      else if (Ack <> $D0) or (Ack <> $D1) then
      begin
        MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
        settings_unlock;
        IdTCPClient1.Disconnect;
        IdTCPClient1.IOHandler := nil;
      end;

    except
      on E: Eidreadtimeout do
      begin
        MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
        settings_unlock;
        IdTCPClient1.Disconnect;
        IdTCPClient1.IOHandler := nil;
      end;
    end;

  end;

  // begin
  // settings_unlock;
  // IdTCPClient1.Disconnect;
  // IdTCPClient1.IOHandler := nil;
  // end;

end;

procedure TForm1.tcp_rs485_connection;
var
  Ack: Byte;
  Buffer: array [0 .. 1] of Byte;
  IdBytes: TIdBytes;
begin
  if (IdTCPClient1.Connected = false) and (Edit1.Text <> '') and
    (Edit2.Text <> '') then
  begin
    settings_lock;
    IdTCPClient1.Host := Edit1.Text;
    IdTCPClient1.Port := strtoint(Edit2.Text);
    try
      IdTCPClient1.Connect;
      sleep(100);
      IdTCPClient1.IOHandler.ReadTimeout := 2000;

      SetLength(IdBytes, 2);
      Buffer[0] := $EE;
      Buffer[1] := SpinEdit1.Value;
      Move(Buffer[0], IdBytes[0], 2);
      IdTCPClient1.IOHandler.Write(IdBytes);
      try
        Ack := IdTCPClient1.IOHandler.ReadByte;
        if Ack = $D0 then
        begin
          Button3.Tag := 0;
          Button3.Caption := 'Перейти в рабочий режим';
          Button2.Enabled := true;
          Button1.Enabled := false;
        end
        else if Ack = $D1 then
        begin
          Button3.Tag := 1;
          Button3.Caption := 'Перейти в режим обновления ПО';
          Button2.Enabled := false;
          Button1.Enabled := false;
        end
        else if (Ack <> $D0) or (Ack <> $D1) then
        begin
          MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end;

      except
        on E: Eidreadtimeout do
        begin
          MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
          settings_unlock;
          IdTCPClient1.Disconnect;
          IdTCPClient1.IOHandler := nil;
        end;
      end;
    except
      on E: EIdConnectTimeout do
      begin
        MessageDlg('Не удалось установить соединение!', mtError, [mbOk], 0);
        settings_unlock;
        IdTCPClient1.Disconnect;
        IdTCPClient1.IOHandler := nil;
      end;
      on E: EIdSocketError do
      begin
        MessageDlg
          ('Ошибка соединения! Проверьте правильность настроек и повторите попытку!',
          mtError, [mbOk], 0);
        settings_unlock;
        IdTCPClient1.Disconnect;
        IdTCPClient1.IOHandler := nil;
      end;
    end;
  end
  else
  begin
    settings_unlock;
    IdTCPClient1.Disconnect;
    IdTCPClient1.IOHandler := nil;
  end;
end;

procedure TForm1.udp_connection;
var
  Ack: TIdBytes;
  Size: Integer;
begin
  if (IdUDPClient1.Connected = false) and (Edit1.Text <> '') and
    (Edit2.Text <> '') then
  begin
    settings_lock;
    IdUDPClient1.Host := Edit1.Text;
    IdUDPClient1.Port := strtoint(Edit2.Text);

    IdUDPClient1.Connect;
    IdUDPClient1.ReceiveTimeout := 2000;
    SetLength(Ack, 1);
    Ack[0] := $DE;
    IdUDPClient1.SendBuffer(Ack);
    Size := IdUDPClient1.ReceiveBuffer(Ack, 2000);
    if Size = 0 then
    begin
      MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
      settings_unlock;
      IdUDPClient1.Disconnect;
    end
    else
    begin
      if Ack[0] = $D0 then
      begin
        Button3.Tag := 0;
        Button3.Caption := 'Перейти в рабочий режим';
        Button2.Enabled := true;
        Button1.Enabled := false;
      end
      else if Ack[0] = $D1 then
      begin
        Button3.Tag := 1;
        Button3.Caption := 'Перейти в режим обновления ПО';
        Button2.Enabled := false;
        Button1.Enabled := false;
      end
      else if (Ack[0] <> $D0) or (Ack[0] <> $D1) then
      begin
        MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
        settings_unlock;
        IdUDPClient1.Disconnect;
      end;
    end;
  end
  else
  begin
    settings_unlock;
    IdUDPClient1.Disconnect;
  end;
end;

procedure TForm1.udp_can_connection;
var
  Ack: TIdBytes;
  Size: Integer;
begin
  if (IdUDPClient1.Connected = false) and (Edit1.Text <> '') and
    (Edit2.Text <> '') then
  begin
    settings_lock;
    IdUDPClient1.Host := Edit1.Text;
    IdUDPClient1.Port := strtoint(Edit2.Text);

    IdUDPClient1.Connect;
    IdUDPClient1.ReceiveTimeout := 2000;
    SetLength(Ack, 1);
    Ack[0] := $CE;
    Ack[1] := SpinEdit1.Value;
    IdUDPClient1.SendBuffer(Ack);
    Size := IdUDPClient1.ReceiveBuffer(Ack, 2000);
    if Size = 0 then
    begin
      MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
      settings_unlock;
      IdUDPClient1.Disconnect;
    end
    else
    begin
      if Ack[0] = $D0 then
      begin
        Button3.Tag := 0;
        Button3.Caption := 'Перейти в рабочий режим';
        Button2.Enabled := true;
        Button1.Enabled := false;
      end
      else if Ack[0] = $D1 then
      begin
        Button3.Tag := 1;
        Button3.Caption := 'Перейти в режим обновления ПО';
        Button2.Enabled := false;
        Button1.Enabled := false;
      end
      else if (Ack[0] <> $D0) or (Ack[0] <> $D1) then
      begin
        MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
        settings_unlock;
        IdUDPClient1.Disconnect;
      end;
    end;
  end
  else
  begin
    settings_unlock;
    IdUDPClient1.Disconnect;
  end;
end;

procedure TForm1.udp_rs485_connection;
var
  Ack: TIdBytes;
  Size: Integer;
begin
  if (IdUDPClient1.Connected = false) and (Edit1.Text <> '') and
    (Edit2.Text <> '') then
  begin
    settings_lock;
    IdUDPClient1.Host := Edit1.Text;
    IdUDPClient1.Port := strtoint(Edit2.Text);

    IdUDPClient1.Connect;
    IdUDPClient1.ReceiveTimeout := 2000;
    SetLength(Ack, 1);
    Ack[0] := $EE;
    Ack[1] := SpinEdit1.Value;
    IdUDPClient1.SendBuffer(Ack);
    Size := IdUDPClient1.ReceiveBuffer(Ack, 2000);
    if Size = 0 then
    begin
      MessageDlg('Посылка команды не подтверждена!', mtError, [mbOk], 0);
      settings_unlock;
      IdUDPClient1.Disconnect;
    end
    else
    begin
      if Ack[0] = $D0 then
      begin
        Button3.Tag := 0;
        Button3.Caption := 'Перейти в рабочий режим';
        Button2.Enabled := true;
        Button1.Enabled := false;
      end
      else if Ack[0] = $D1 then
      begin
        Button3.Tag := 1;
        Button3.Caption := 'Перейти в режим обновления ПО';
        Button2.Enabled := false;
        Button1.Enabled := false;
      end
      else if (Ack[0] <> $D0) or (Ack[0] <> $D1) then
      begin
        MessageDlg('Неправильный ответ подтверждения!', mtError, [mbOk], 0);
        settings_unlock;
        IdUDPClient1.Disconnect;
      end;
    end;
  end
  else
  begin
    settings_unlock;
    IdUDPClient1.Disconnect;
  end;
end;

procedure TForm1.Edit1KeyPress(Sender: TObject; var Key: Char);
begin
  if not(Key in ['0' .. '9', '.', #8]) then
    Key := #0;
end;

procedure TForm1.Edit2KeyPress(Sender: TObject; var Key: Char);
begin
  if not(Key in ['0' .. '9', #8]) then
    Key := #0;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  IdUDPClient1.Disconnect;
  IdTCPClient1.Disconnect;
  IdTCPClient1.IOHandler := nil;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  IdUDPClient1.Disconnect;
  IdTCPClient1.Disconnect;
  IdTCPClient1.IOHandler := nil;
end;

procedure TForm1.Image1Click(Sender: TObject);
begin
  MessageDlg('Ethernet bootloader v.0.2.8 Lassard 2026', mtInformation,
    [mbOk], 0);
end;

procedure TForm1.UpdateProgress(APosition: Integer);
begin
  TThread.Queue(nil,
    procedure
    begin
      ProgressBar1.Position := APosition;
    end);
end;

end.
