#define MyAppName "Desktop Pet"
#define MyAppExeName "desktop-pet.exe"
#define MyAppExePath "{app}\" + MyAppExeName
#define MyAppVersion "0.1.0"
#define MyAppPublisher "desktop-pet"
#define MyAppURL "https://example.invalid/"
#define MyAppId "{F0D6A4C4-2B3E-4E5D-A1E2-8F8D5A34F1D3}"
#define MySourceDir "payload"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=output
OutputBaseFilename=DesktopPet-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "zh-CN"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "autostart"; Description: "开机自动启动"; Flags: unchecked

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{#MyAppExePath}"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{#MyAppExePath}"""; Tasks: autostart; Flags: uninsdeletevalue

[Run]
Filename: "{#MyAppExePath}"; Description: "运行 {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
var
  DeleteUserDataCheckBox: TNewCheckBox;

function GetGodotUserDataDir(): string;
begin
  Result := ExpandConstant('{userappdata}\Godot\app_userdata\desktop-pet');
end;

procedure InitializeUninstallProgressForm();
begin
  DeleteUserDataCheckBox := TNewCheckBox.Create(UninstallProgressForm);
  DeleteUserDataCheckBox.Parent := UninstallProgressForm;
  DeleteUserDataCheckBox.Caption := '同时清除记忆目录（AppData）';
  DeleteUserDataCheckBox.Checked := False;
  DeleteUserDataCheckBox.Left := ScaleX(8);
  DeleteUserDataCheckBox.Top := UninstallProgressForm.StatusLabel.Top + UninstallProgressForm.StatusLabel.Height + ScaleY(12);
  DeleteUserDataCheckBox.Width := UninstallProgressForm.ClientWidth - ScaleX(16);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  UserDataDir: string;
begin
  if CurUninstallStep <> usUninstall then
    exit;

  if (DeleteUserDataCheckBox <> nil) and DeleteUserDataCheckBox.Checked then begin
    UserDataDir := GetGodotUserDataDir();
    if DirExists(UserDataDir) then
      DelTree(UserDataDir, True, True, True);
  end;
end;
