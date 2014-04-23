unit SerialNum;  {Delphi 函數程式集 , 程式開發 2003.10.09整理 }

interface
uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  DB, DBTables, Grids, IniFiles, ShellApi, Winsock, ComObj, NB30;

//====================================
function GetIdeDiskSerialNumber: string; {取得主硬碟序號}
Function GetMACAddress:String; {取得網卡MACAddress}
Function Xnum(Snum:String):Int64; {轉換計算一}
Function Ynum(sSUM:String):String; {轉換計算二}
function GetGeorge(sDATE, sHD, sMacAdd:String):String; {取得註冊申請碼}
function ChkMary(SysName:String):Boolean; {註冊碼確認}

implementation

//==============================================================================
function GetIdeDiskSerialNumber: string; {取得主硬碟序號}
type
  TSrbIoControl = packed record
    HeaderLength: ULONG;
    Signature: array[0..7] of Char;
    Timeout: ULONG;
    ControlCode: ULONG;
    ReturnCode: ULONG;
    Length: ULONG;
  end;
  SRB_IO_CONTROL = TSrbIoControl;
  PSrbIoControl = ^TSrbIoControl;

  TIDERegs = packed record
    bFeaturesReg: Byte; // Used for specifying SMART "commands".
    bSectorCountReg: Byte; // IDE sector count register
    bSectorNumberReg: Byte; // IDE sector number register
    bCylLowReg: Byte; // IDE low order cylinder value
    bCylHighReg: Byte; // IDE high order cylinder value
    bDriveHeadReg: Byte; // IDE drive/head register
    bCommandReg: Byte; // Actual IDE command.
    bReserved: Byte; // reserved. Must be zero.
  end;
  IDEREGS = TIDERegs;
  PIDERegs = ^TIDERegs;
  TSendCmdInParams = packed record
  cBufferSize: DWORD;
  irDriveRegs: TIDERegs;
  bDriveNumber: Byte;
  bReserved: array[0..2] of Byte;
  dwReserved: array[0..3] of DWORD;
  bBuffer: array[0..0] of Byte;
  end;
  SENDCMDINPARAMS = TSendCmdInParams;
  PSendCmdInParams = ^TSendCmdInParams;

  TIdSector = packed record
    wGenConfig: Word;
    wNumCyls: Word;
    wReserved: Word;
    wNumHeads: Word;
    wBytesPerTrack: Word;
    wBytesPerSector: Word;
    wSectorsPerTrack: Word;
    wVendorUnique: array[0..2] of Word;
    sSerialNumber: array[0..19] of Char;
    wBufferType: Word;
    wBufferSize: Word;
    wECCSize: Word;
    sFirmwareRev: array[0..7] of Char;
    sModelNumber: array[0..39] of Char;
    wMoreVendorUnique: Word;
    wDoubleWordIO: Word;
    wCapabilities: Word;
    wReserved1: Word;
    wPIOTiming: Word;
    wDMATiming: Word;
    wBS: Word;
    wNumCurrentCyls: Word;
    wNumCurrentHeads: Word;
    wNumCurrentSectorsPerTrack: Word;
    ulCurrentSectorCapacity: ULONG;
    wMultSectorStuff: Word;
    ulTotalAddressableSectors: ULONG;
    wSingleWordDMA: Word;
    wMultiWordDMA: Word;
    bReserved: array[0..127] of Byte;
  end;
  PIdSector = ^TIdSector;const
  IDE_ID_FUNCTION = $EC;
  IDENTIFY_BUFFER_SIZE = 512;
  DFP_RECEIVE_DRIVE_DATA = $0007C088;
  IOCTL_SCSI_MINIPORT = $0004D008;
  IOCTL_SCSI_MINIPORT_IDENTIFY = $001B0501;
  DataSize = sizeof(TSendCmdInParams) - 1 + IDENTIFY_BUFFER_SIZE;
  BufferSize = SizeOf(SRB_IO_CONTROL) + DataSize;
  W9xBufferSize = IDENTIFY_BUFFER_SIZE + 16;var
  hDevice: THandle;
  cbBytesReturned: DWORD;
  pInData: PSendCmdInParams;
  pOutData: Pointer; // PSendCmdOutParams
  Buffer: array[0..BufferSize - 1] of Byte;
  srbControl: TSrbIoControl absolute Buffer;

  procedure ChangeByteOrder(var Data; Size: Integer);
  var
    ptr: PChar;
    i: Integer;
    c: Char;
  begin
    ptr := @Data;
    for i := 0 to (Size shr 1) - 1 do
    begin
      c := ptr^;
      ptr^ := (ptr + 1)^;
      (ptr + 1)^ := c;
      Inc(ptr, 2);
    end;
  end;

begin
  Result := '';
  FillChar(Buffer, BufferSize, #0);
  if Win32Platform = VER_PLATFORM_WIN32_NT then
  begin // Windows NT, Windows 2000
    // Get SCSI port handle
    hDevice := CreateFile('\\.\Scsi0:',
    GENERIC_READ or GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE,
    nil, OPEN_EXISTING, 0, 0);
    if hDevice = INVALID_HANDLE_VALUE then Exit;
    try
      srbControl.HeaderLength := SizeOf(SRB_IO_CONTROL);
      System.Move('SCSIDISK', srbControl.Signature, 8);
      srbControl.Timeout := 2;
      srbControl.Length := DataSize;
      srbControl.ControlCode := IOCTL_SCSI_MINIPORT_IDENTIFY;
      pInData := PSendCmdInParams(PChar(@Buffer)
      + SizeOf(SRB_IO_CONTROL));
      pOutData := pInData;
      with pInData^ do
      begin
        cBufferSize := IDENTIFY_BUFFER_SIZE;
        bDriveNumber := 0;
        with irDriveRegs do
        begin
          bFeaturesReg := 0;
          bSectorCountReg := 1;
          bSectorNumberReg := 1;
          bCylLowReg := 0;
          bCylHighReg := 0;
          bDriveHeadReg := $A0;
          bCommandReg := IDE_ID_FUNCTION;
        end;
      end;
      if not DeviceIoControl(hDevice, IOCTL_SCSI_MINIPORT,
      @Buffer, BufferSize, @Buffer, BufferSize,
      cbBytesReturned, nil) then
      Exit;
    finally
      CloseHandle(hDevice);
    end;
  end
  else
  begin // Windows 95 OSR2, Windows 98
    hDevice := CreateFile('\\.\SMARTVSD', 0, 0, nil,
    CREATE_NEW, 0, 0);
    if hDevice = INVALID_HANDLE_VALUE then Exit;
    try
      pInData := PSendCmdInParams(@Buffer);
      pOutData := @pInData^.bBuffer;
      with pInData^ do
      begin
      cBufferSize := IDENTIFY_BUFFER_SIZE;
      bDriveNumber := 0;
      with irDriveRegs do
      begin
      bFeaturesReg := 0;
      bSectorCountReg := 1;
      bSectorNumberReg := 1;
      bCylLowReg := 0;
      bCylHighReg := 0;
      bDriveHeadReg := $A0;
      bCommandReg := IDE_ID_FUNCTION;
      end;
      end;
      if not DeviceIoControl(hDevice, DFP_RECEIVE_DRIVE_DATA,
      pInData, SizeOf(TSendCmdInParams) - 1, pOutData,
      W9xBufferSize, cbBytesReturned, nil) then  Exit;
    finally
      CloseHandle(hDevice);
    end;
  end;

  with PIdSector(PChar(pOutData) + 16)^ do
  begin
    ChangeByteOrder(sSerialNumber, SizeOf(sSerialNumber));
    SetString(Result, sSerialNumber, SizeOf(sSerialNumber));
  end;
end;

{==============================================================================}
Function GetMACAddress:String; {取得網卡MACAddress}
Var NCB   : PNCB;
    Adapter :PAdapterStatus;

    URetCode :Pchar;
    RetCode  :char;
    I : Integer;
    Lenum  : PlanaEnum;
    _SystemID :String;
    TMPSTR :String;
Begin
  Result:='';
  _SystemID:='';
  Getmem(NCB,sizeof(TNCB));
  Fillchar(NCB^,Sizeof(TNCB),0);

  Getmem(Lenum,sizeof(TLanaEnum));
  Fillchar(Lenum^,Sizeof(TLanaEnum),0);

  Getmem(Adapter,sizeof(TAdapterStatus));
  Fillchar(Adapter^,Sizeof(TAdapterStatus),0);

  Lenum.Length:=chr(0);
  NCB.ncb_command:=chr(NCBENUM);
  NCB.ncb_buffer:=pointer(Lenum);
  NCB.ncb_length:=sizeof(Lenum);
  RetCode:=Netbios(NCB);

  i:=0;
  Repeat
    Fillchar(NCB^,Sizeof(TNCB),0);
    Ncb.ncb_command:= chr(NCBRESET);
    Ncb.ncb_lana_num:=lenum.lana[I];
    RetCode:= Netbios(Ncb);

    Fillchar(NCB^,Sizeof(TNCB),0);
    Ncb.ncb_command:= chr(NCBASTAT);
    Ncb.ncb_lana_num:= lenum.lana[I];
    // Must be 16
    Ncb.ncb_callname:='*               ';

    Ncb.ncb_buffer:=pointer(Adapter);

    Ncb.ncb_length:=sizeof(TAdapterStatus);
    RetCode:= Netbios(Ncb);
    if (RetCode=chr(0)) or (RetCode=chr(6)) then
       Begin
         _SystemId:=inttohex(ord(Adapter.adapter_address[0]),2)+
                    inttohex(ord(Adapter.adapter_address[1]),2)+
                    inttohex(ord(Adapter.adapter_address[2]),2)+
                    inttohex(ord(Adapter.adapter_address[3]),2)+
                    inttohex(ord(Adapter.adapter_address[4]),2)+
                    inttohex(ord(Adapter.adapter_address[5]),2);

       End;
       inc(i);
   until (I>=ord(Lenum.length)) or (_SystemID<>'000000000000');
   FreeMem(NCB);
   FreeMem(Adapter);
   FreeMem(Lenum);
   GetMacAddress:=_SystemID;
End;

{==============================================================================}
Function Xnum(Snum:String):Int64; {轉換計算一}
var
  iLen, iTime:Integer;
begin
  result := 0;
  iLen := length(Snum);
  for iTime := 1 to iLen do
  begin
    result := result + int64(ord(Snum[iTime]))*iTime;
  end;

end;

{==============================================================================}
Function Ynum(sSUM:String):String; {轉換計算二}
var
  iLen, iTime, iNum:Integer;
begin
  result := '';

  if Length(sSUM) mod 2 <> 0 then
    sSUM := sSUM + '0';

  iLen := length(sSUM) div 2;
  for iTime := 1 to iLen do
  begin
    iNum := StrToInt(Copy(sSUM, iTime*2-1, 2));
    result := result + IntToHex(iNum, 2);
  end;

end;

{==============================================================================}
function GetGeorge(sDATE, sHD, sMacAdd:String):String; {取得註冊申請碼}
var
  iTime, iLen, iNum:Integer;
  iDATE, iHD, iMacAdd, iSUM:Int64;
  sSUM, sGeorge:String;
begin
  iDATE := 0;
  iHD := 0;
  iMacAdd := 0;
  iSUM := 0;

  iDATE := Xnum(sDATE);
  iHD := Xnum(sHD);
  iMacAdd := Xnum(sMacAdd);

  iSUM := int64(iDATE*iHD);
  sSUM := IntToStr(iSUM);

  GetGeorge := Ynum(sSUM);
end;

{==============================================================================}
function ChkMary(SysName:String):Boolean; {註冊碼確認}
var
  pBuffer: Array[0..$FF] of char;
  aFile:TIniFile;
  SysDir, SDATE, SDATE2, SGEORGE, SMARY, SGIRL:String;
  iGIRL:Int64;
begin
  //取得系統目錄
  GetSystemDirectory(pBuffer, SizeOf(pBuffer));
  SysDir := pBuffer;

  aFile := TIniFile.Create(SysDir+'\'+SysName+'.ini');
  try
    //設定的日期
    SDATE := aFile.ReadString('SAM', 'SDATE', '');
    //設定的註冊碼
    SMARY := aFile.ReadString('SAM', 'SMARY', '');
  finally
    aFile.Free;
  end;

  SGEORGE := GetGEORGE(SDATE, GetIdeDiskSerialNumber, GetMACAddress);
  SDATE2 := copy(SDATE, 1, 8);
  iGIRL := Xnum(SGEORGE)*Xnum(SDATE2)* Xnum(SysName);
  SGIRL := Ynum(IntToStr(iGIRL));

  if SGIRL = SMARY then
    result := true
  else
    result := false;
end;

{==============================================================================}
{decimal 為預轉之十進位值 , nToCarry 為進位數 (不得大於 16)}

{##############################################################################}
{ 參考篇 }
{##############################################################################}

{下面提供兩個函式供快速寫入讀出 ini 中之變數}
{function TForm1._ReadString(VarName:string):string;
var MyIni: TIniFile;
IniFileName:string;
begin
IniFileName:=ChangeFileExt(ParamStr(0),'.INI'); //指定實體 ini 檔名
MyIni := TIniFile.Create(IniFileName);
Result:=MyIni.ReadString('Parameter',VarName,'');
MyIni.Free;
end;

procedure TForm1._WriteString(VarName,VarValue:string);
var MyIni: TIniFile;
IniFileName:string;
begin
IniFileName:=ChangeFileExt(ParamStr(0),'.INI'); //指定實體 ini 檔名
MyIni := TIniFile.Create(IniFileName);
MyIni.WriteString('Parameter',VarName,VarValue);
MyIni.Free;

end;}



end.
