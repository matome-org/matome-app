#define MatomeVersion GetEnv("MATOME_VERSION")
#define MatomePackageDir GetEnv("MATOME_PACKAGE_DIR")
#define MatomeDistDir GetEnv("MATOME_DIST_DIR")

[Setup]
AppId={{38377ac5-340d-5f43-8113-12ec96787c9d}
AppName=Matome
AppVersion={#MatomeVersion}
AppPublisher=MATOME
DefaultDirName={localappdata}\Programs\Matome
DefaultGroupName=Matome
OutputDir={#MatomeDistDir}
OutputBaseFilename=matome-windows-x86_64-v{#MatomeVersion}
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile={#MatomePackageDir}\LICENSE

[Files]
Source: "{#MatomePackageDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Matome"; Filename: "{app}\matome-studio.exe"
