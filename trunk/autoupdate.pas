unit autoupdate;

(*

Usage:

1) Create the file update.ini in the same folder as the main application.
2) Contents of update.ini

[default]
updatefile=/etc/updateinfo.ini
method=ftp
[params]
host=myhost.com
port=21
user=myusername
pass=mypassword

This connects to the ftp server and looks for the file /etc/updateinfo.ini
who tells  TAutoUpdate where is the update zip file containing all the new files,
then the file is unzipped and executes update.exe, the file in charge
of upgrading the program.

3) Execute the update to update:

with TAutoUpdate.Create('update.ini') do
begin
  Execute;
  Free;
end;

Params for method FTP:
----------------------
host, port, user and oass

Params for method HTTP:
-----------------------
host, port

Sample update.ini with Http method:

[default]
updatefile=updateinfo.ini
method=http
[params]
host=myhost.com
port=80
    
*)

interface

uses
  ShellApi,
  Forms,
  Dialogs;

type
  TOnNewVersion = function: Boolean;

  TUpdateMethod = class
  private
    FUpdateFile: string;
  protected
    function CheckForNewVersion(out AInstaller: string): Boolean;
    function GetInstallerFileName(AInstaller: string): string;
    procedure Uncompress(AZipFile: string);
    function GetFile(AFileName, ALocalFile: string): Boolean; virtual; abstract;
    procedure InstallNewVersion(AInstaller: string);
    property UpdateFile: string read FUpdateFile write FUpdateFile;
  end;

  TFtpUpdateMethod = class(TUpdateMethod)
  private
    FUser: string;
    FPass: string;
    FHost: string;
    FPort: string;
  public
    constructor Create(AHost, APort, AUser, APass: string);
    function GetFile(AFileName, ALocalFile: string): Boolean; override;
  end;

  THttpUpdateMethod = class(TUpdateMethod)
  private
    FHost: string;
    FPort: string;
  public
    constructor Create(AHost, APort: string);
    function GetFile(AFileName, ALocalFile: string): Boolean; override;
  end;

  TAutoUpdate = class
  private
    FOnNewVersion: TOnNewVersion;
    FUpdateMethod: TUpdateMethod;
  public
    constructor create(AIniFile: string);
    procedure Execute;
    property OnNewVersion: TOnNewVersion read FOnNewVersion write FOnNewVersion;
  end;

implementation

uses
  FtpSend,
  HttpSend,
  Controls,
  SysUtils,
  IniFiles,
  AbUnZper,
  AbUtils,
  AbArcTyp, Classes, StrUtils;

{ TAutoUpdate }

constructor TAutoUpdate.Create(AIniFile: string);
var
  lIniFile: TIniFile;
  lMethod: string;
  lUser: string;
  lPass: string;
  lHost: string;
  lPort: string;
  lDirectory: string;

begin
  inherited Create;
  lIniFile := TIniFile.Create(AIniFile);
  lMethod := UpperCase(lIniFile.ReadString('default', 'method', 'ftp'));

  lHost := lIniFile.ReadString('params', 'host', '');
  lPort := lIniFile.ReadString('params', 'port', '');
  lUser := lIniFile.ReadString('params', 'user', '');
  lPass := lIniFile.ReadString('params', 'pass', '');
  lDirectory := lIniFile.ReadString('params', 'directory', '');

  (* Depending on the method of storage FTP, HTTP or Shared folder
     the appropriate class is instantiated *)
  if lMethod = 'FTP' then
    FUpdateMethod := TFtpUpdateMethod.Create(lHost, lPort, lUser, lPass)
  else
  if lMethod = 'HTTP' then
    FUpdateMethod := THttpUpdateMethod.Create(lHost, lPort);

  FUpdateMethod.UpdateFile := lIniFile.ReadString('default', 'updatefile', '');
end;

procedure TAutoUpdate.Execute;
var
  lInstaller: string;
  lResult: Boolean;
begin
  (* Checks for an update in the configured server *)
  if FUpdateMethod.CheckForNewVersion(lInstaller) then
  begin
    if Assigned(FOnNewVersion) then
      lResult := FOnNewVersion
    else
      lResult := MessageDlg('There''s a new version. Do you want to update?.',
         mtConfirmation, [mbYes, mbNo], 0) = mrYes;

    if lResult then
      FUpdateMethod.InstallNewVersion(lInstaller);
  end;
end;

{ TFtpUpdateMethod }


constructor TFtpUpdateMethod.Create(AHost, APort, AUser, APass: string);
begin
  FHost := AHost;
  FPort := APort;
  FUser := AUser;
  FPass := APass;
end;

function TFtpUpdateMethod.GetFile(AFileName, ALocalFile: string): Boolean;
begin
  (* Gets a file from the FTP server *)
  Result := FtpGetFile(FHost, FPort, AFileName, ALocalFile, FUser, FPass);
end;

{ TUpdateMethod }

function TUpdateMethod.CheckForNewVersion(out AInstaller: string): Boolean;
var
  lFile: string;
  lCurrentInstaller: string;
  lNewInstaller: string;

  function ExtractFileName(AFileWithPath: string): string;
  (* Extract only the file name from strings like:
     /etc/updates/install.ini or c:\updates\install.ini *)
  var
    lPos: Integer;
  begin
    Result := '';
    lPos := Length(AFileWithPath);
    repeat
      Result := AFileWithPath[lPos] + Result;
      Dec(lPos);
    until (lPos = 0) or (AFileWithPath[lPos] in ['/', '\']);
  end;

begin
  (* This gets the update file and store locally in the same folder
     as the application *)
  lFile := ExtractFilePath(ParamStr(0)) + ExtractFileName(FUpdateFile);
  lCurrentInstaller := GetInstallerFileName(lFile);
  Result := GetFile(FUpdateFile, lFile);
  if Result then
    lNewInstaller := GetInstallerFileName(lFile);

  (* Now, after downloaded the updateinfo.ini file, it is compared
     with the one already on the client side, if they are the same,
     the result is False meaning it isn't a new version. *)
  Result := Result and (lCurrentInstaller <> lNewInstaller);
  if Result then
    AInstaller := lNewInstaller;
end;

function TUpdateMethod.GetInstallerFileName(AInstaller: string): string;
(* reads the "installer" key from an .ini file,
   this key tells where the .zip file containing updater.exe
   and all the new files is placed.

   Example:

   [default]
   installer=/etc/new-installer-1.0.zip *)
var
  lIni: TIniFile;
begin
  lIni := TIniFile.Create(AInstaller);
  try
    Result := lIni.ReadString('default', 'installer', '');
  finally
    lIni.Free;
  end;
end;

procedure TUpdateMethod.InstallNewVersion(AInstaller: string);
var
  lZipFile: string;
  lUpdater: string;
  lPath: string;
  lOldPath: string;
begin
  lOldPath := ExtractFilePath(ParamStr(0));
  lZipFile := lOldPath + 'update\install.zip';
  lPath := lOldPath + 'update';
  (* Remove the Update directory if it exists *)
  RemoveDir(lPath);
  (* Create the directory again, this time it's empty *)
  CreateDir(lPath);
  (* Get the zip file from the server *)
  if GetFile(AInstaller, lZipFile) then
  begin
    (* Unzip and execute the updater.exe file that must reside
       inside the zip. *)
    SetCurrentDir(lPath);
    Uncompress(lZipFile);
    (* Execute updater.exe and terminate the application,
       updater.exe must copy all the files to the apropriate folder
       and re-execute the application. *)
    lUpdater := lPath + '\updater.exe';
    ShellExecute(0, nil, PChar(lUpdater), nil, nil, 1 {SW_SHOWNORMAL});
    Application.Terminate;
  end;
end;

procedure TUpdateMethod.Uncompress(AZipFile: string);
var
  lUnzipper: TAbUnZipper;
begin
  lUnzipper := TAbUnZipper.Create(nil);
  try
    lUnzipper.FileName := AZipFile;
    lUnzipper.BaseDirectory := GetCurrentDir;
    lUnzipper.ExtractOptions := [eoCreateDirs, eoRestorePath];
    lUnzipper.ExtractFiles('*.*');
  finally
    lUnzipper.Free;
  end;
end;

{ THttpUpdateMethod }

constructor THttpUpdateMethod.Create(AHost, APort: string);
begin
  FHost := AHost;
  FPort := APort;
end;

function THttpUpdateMethod.GetFile(AFileName, ALocalFile: string): Boolean;
var
  lStream: TMemoryStream;
  lUrl: string;
begin
  (* Gets a file from the HTTP server *)
  lStream := TMemoryStream.Create;
  try
    lUrl := 'http://' + FHost + ':' + FPort + '/' + AFileName;
    Result := HttpGetBinary(lUrl, lStream);
    if Result then
    begin
      lStream.Position := 0;
      lStream.SaveToFile(ALocalFile);
    end;
  finally
    lStream.Free;
  end;
end;

end.


