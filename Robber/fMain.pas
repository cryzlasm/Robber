unit fMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, Vcl.ValEdit, Vcl.ComCtrls, FileCtrl, IOUtils,
  Vcl.ImgList, ShellAPI, ClipBrd, DLLHijack, DigitalSignature, Vcl.Menus,
  System.TypInfo, Vcl.ExtCtrls, Vcl.Samples.Spin, PNGImage;

type
  TfrmMain = class(TForm)
    pumTree: TPopupMenu;
    miCopy: TMenuItem;
    imglMain: TImageList;
    miOpenPath: TMenuItem;
    tvApplication: TTreeView;
    edSearchPath: TEdit;
    btnScan: TButton;
    btnAbout: TButton;
    btnBrowsePath: TButton;
    rgMustScanImageType: TRadioGroup;
    rgScanOptions: TRadioGroup;
    gbColorConfig: TGroupBox;
    sedBestChoiceDLLCount: TSpinEdit;
    sedGoodChoiceExeSize: TSpinEdit;
    sedGoodChoiceDLLCount: TSpinEdit;
    sedBestChoiceExeSize: TSpinEdit;
    lblBestChoice: TLabel;
    lblGoodChoice: TLabel;
    iBestChoice: TImage;
    iGoodChoice: TImage;

    procedure btnBrowsePathClick(Sender: TObject);
    procedure btnAboutClick(Sender: TObject);
    procedure miCopyClick(Sender: TObject);
    procedure miOpenPathClick(Sender: TObject);
    procedure btnScanClick(Sender: TObject);
  private
    procedure ScanHijack();
    procedure ScanImportMethods;
    procedure CollapseALLItems;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses fAbout;

procedure TfrmMain.btnBrowsePathClick(Sender: TObject);
var
  Dir: String;
begin
  // Display select directory dialog to perform scan on user selected directory
  SelectDirectory('Select directory : ', '', Dir);
  if (System.SysUtils.DirectoryExists(Dir)) then
    if (DirectoryExists(Dir)) then
    begin
      edSearchPath.Text := Dir;
      btnScan.Enabled := true;
    end;
end;

procedure TfrmMain.btnScanClick(Sender: TObject);
begin
  btnBrowsePath.Enabled := false;
  btnScan.Enabled := false;

  // Clear all last scan
  tvApplication.Items.Clear;

  // Scan for hijackable executables
  ScanHijack();

  // Scan method imports of execut
  ScanImportMethods;

  btnBrowsePath.Enabled := true;

  MessageDlg('Scan compelete', mtInformation, [mbOK], 0);
end;

procedure TfrmMain.miCopyClick(Sender: TObject);
begin
  // Copy selected item text
  Clipboard.Open;
  try
    Clipboard.AsText := tvApplication.Selected.Text;
  finally
    Clipboard.Close;
  end;
end;

procedure TfrmMain.miOpenPathClick(Sender: TObject);
var
  SelectedAppDirectorey: string;
begin
  // Get selected item
  SelectedAppDirectorey := LowerCase(tvApplication.Selected.Text);

  // Check if selected file is DLL , combine host application directory + DLL name to get DLL path
  if (ExtractFileExt(SelectedAppDirectorey) = '.dll') then
    SelectedAppDirectorey := ExtractFilePath(tvApplication.Selected.Parent.Text)
      + tvApplication.Selected.Text;

  // Check if Selected item exists , explore it's directory in windows explorer and select it int explorer
  if (FileExists(SelectedAppDirectorey)) then
    ShellExecute(0, nil, PChar('explorer.exe'),
      PChar('/select, "' + PChar(SelectedAppDirectorey) + '"'), nil, SW_NORMAL);
end;

procedure TfrmMain.btnAboutClick(Sender: TObject);
begin
  // Show about form
  TfrmAbout.Execute;
end;

procedure TfrmMain.ScanHijack();
var
  EachFile: String;
  FileSize: Cardinal;
  ImageTypeString: String;
  App, DLLs, Scale, Sign, ImageTypeNode: TTreeNode;

  // DLL Hijack
  PEFile: TDLLHijack;
  ImportDLLs: TStringList;
  DLLName: string;

  // Signature
  Signature: TDigitalSignature;
  IsSigned: Boolean;
  SignerCompany: string;

  HijackRate: THijackRate;
begin
  for EachFile in TDirectory.GetFiles(edSearchPath.Text, '*.exe',
    TSearchOption.soAllDirectories) do
  begin
    try
      IsSigned := false;
      //
      ImportDLLs := TStringList.Create;
      PEFile := TDLLHijack.Create(EachFile);
      Signature := TDigitalSignature.Create(EachFile);
      try
        PEFile.GetHijackableImportedDLL(ImportDLLs);
        if (ImportDLLs.Count = 0) then
          Continue
        else
        begin
          // Check must scan signed applications or all applications
          if (rgScanOptions.ItemIndex = 1) then
          begin
            IsSigned := Signature.IsCodeSigned;
            if (IsSigned = false) then
              Continue;
          end;

          // Check image type that must be scanner
          case rgMustScanImageType.ItemIndex of
            1:
              begin
                if (PEFile.IsX86Image = False) then
                  Continue;
              end;

            2:
              begin
                if (PEFile.IsX86Image = True) then
                  Continue;
              end;
          end;

          App := tvApplication.Items.Add(nil, EachFile);

          FileSize := PEFile.GetFileSize;
          Scale := tvApplication.Items.AddChild(App, Format('File Size : %d KB',
            [FileSize]));
          Scale.ImageIndex := 1;
          Scale.SelectedIndex := Scale.ImageIndex;

          // Image type (x86, x64)
          if (PEFile.IsX86Image = true) then
            ImageTypeString := 'x86'
          else
            ImageTypeString := 'x64';

          ImageTypeNode := tvApplication.Items.AddChild(App,
            Format('ImageType : %s', [ImageTypeString]));
          ImageTypeNode.ImageIndex := 8;
          ImageTypeNode.SelectedIndex := ImageTypeNode.ImageIndex;

          // Check application signed or user select scan all applications and
          // ShowSigner checkbox checked then add Sign By node to application node
          if (IsSigned = true) OR (rgScanOptions.ItemIndex = 0) then
          begin
            SignerCompany := Signature.SignerCompany;
            if (Trim(SignerCompany) <> '') then
            begin
              Sign := tvApplication.Items.AddChild(App,
                Format('Sign by : %s', [SignerCompany]));
              Sign.ImageIndex := 7;
              Sign.SelectedIndex := Sign.ImageIndex;
            end;
          end;
        end;

        // Rate current application to hijack :D
        HijackRate := PEFile.GetHijackRate(sedBestChoiceDLLCount.Value,
          sedBestChoiceExeSize.Value, sedGoodChoiceDLLCount.Value,
          sedGoodChoiceExeSize.Value);

        case HijackRate of
          Best:
            App.ImageIndex := 4;
          Good:
            App.ImageIndex := 5;
          Bad:
            App.ImageIndex := 6;
        end;
        App.SelectedIndex := App.ImageIndex;

        // Check DLL is inside current application , if exists show it
        for DLLName in ImportDLLs do
          if (FileExists(ExtractFilePath(EachFile) + DLLName)) then
          begin
            DLLs := tvApplication.Items.AddChild(App, DLLName);
            DLLs.ImageIndex := 2;
            DLLs.SelectedIndex := DLLs.ImageIndex;
          end;
        Application.ProcessMessages;
      finally
        Signature.Free;
        ImportDLLs.Free;
        PEFile.Free;
      end;
    except
      // Handle any exception like AccessDenied here
    end;
    Application.ProcessMessages;
  end;
end;

procedure TfrmMain.ScanImportMethods;
var
  PEFile: TDLLHijack;
  Methods: TStringList;
  TreeViewIndex: Integer;

  EachDLL: Integer;
  DLLName, MethodName: string;
  Method: TTreeNode;
begin
  TreeViewIndex := 0;

  Methods := TStringList.Create;
  try
    for EachDLL := tvApplication.Items.Count - 1 downto 0 do
    begin
      DLLName := tvApplication.Items[EachDLL].Text;
      if (ExtractFileExt(DLLName) <> '.dll') then
        Continue
      else
      begin
        TreeViewIndex := EachDLL;
        tvApplication.Select(tvApplication.Items[TreeViewIndex]);

        PEFile := TDLLHijack.Create(tvApplication.Selected.Parent.Text);
        try
          PEFile.GetDLLMethods(DLLName, Methods);

          // List DLL names
          for MethodName in Methods do
          begin
            Method := tvApplication.Items.AddChild(tvApplication.Selected,
              MethodName);
            Method.ImageIndex := 3;
            Method.SelectedIndex := Method.ImageIndex;
          end;
        finally
          PEFile.Free;
        end;
      end;

      Application.ProcessMessages;
    end;
  finally
    Methods.Free;
  end;

  // Collapse all items
  CollapseALLItems;
end;

procedure TfrmMain.CollapseALLItems;
var
  ItemCount: Integer;
begin
  // Colpase all items exists in tvApplication
  for ItemCount := 0 to tvApplication.Items.Count - 1 do
    tvApplication.Items[ItemCount].Collapse(true);
end;

end.
