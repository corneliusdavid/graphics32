unit TestBitmapLoadSave;

interface

uses
  Classes, Types,
  FileTestFramework,
  GR32;

type
  TTestTCustomBitmap32 = class(TFileTestCase)
  strict private
    FBitmap32: TCustomBitmap32;
    FExpectedCrc: Cardinal;
    FIgnoreRes: boolean;
  private
    procedure TestSaveToStream(TopDown: boolean);
    procedure TestSaveToStreamDIB(TopDown: boolean);
    procedure ValidateCRC(Bitmap: TCustomBitmap32);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestLoadFromFile;
    procedure TestLoadFromStream;
    procedure TestLoadFromStreamRelative;
    procedure TestLoadFromStreamDIB;
    procedure TestLoadFromResourceName;

    procedure TestSaveToStreamTopDown;
    procedure TestSaveToStreamBottomUp;
    procedure TestSaveToStreamTopDownDIB;
    procedure TestSaveToStreamBottomUpDIB;
    procedure TestSaveToFile;

    procedure TestClipboard;
  end;

implementation

uses
  Windows,
  Graphics,
  SysUtils,
  IOUtils,
  Clipbrd,
  TestFramework,
  ZLib; // CRC32

// Define GENERATE_BITMAPS to generate the test bitmaps based on a template bitmap.
// The application should be executed twice; Once with RGBA_FORMAT globally defined
// and once without it defined.
{-$define GENERATE_BITMAPS}

// Define GENERATE_RC_SCRIPT to have the resource names dumped to a text file
// that can be used in the RC script.
{-$define GENERATE_RC_SCRIPT}

// Define GENERATE_CRC_TABLE to have the CRC values dumped to a text file
// that can be used in the following table.
{-$define GENERATE_CRC_TABLE}

const
  // CRC32 checksum of TBitmap32 pixel data after load.
  // If the checksum match then we assume that the size of the bitmap and the pixel colors match.
  Checksums: array[0..67] of record
    Name: string;
    Checksum: Cardinal;
    // IgnoreRes=True means that MS Resource Compiler alters bitmap so we cannot test it.
    // Notably the resource compiler is unable to handle BI_BITFIELDS with a color table.
    IgnoreRes: boolean;
  end = (
    // Generated by TBitmap32
    (Name: 'bgra_v1_bottomup_colortable';       Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v1_bottomup_no_colortable';    Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v1_topdown_colortable';        Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v1_topdown_no_colortable';     Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v2_bottomup_colortable';       Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v2_bottomup_no_colortable';    Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v2_topdown_colortable';        Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v2_topdown_no_colortable';     Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v3_bottomup_colortable';       Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'bgra_v3_bottomup_no_colortable';    Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v3_topdown_colortable';        Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'bgra_v3_topdown_no_colortable';     Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v4_bottomup_colortable';       Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'bgra_v4_bottomup_no_colortable';    Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v4_topdown_colortable';        Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'bgra_v4_topdown_no_colortable';     Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v5_bottomup_colortable';       Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'bgra_v5_bottomup_no_colortable';    Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'bgra_v5_topdown_colortable';        Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'bgra_v5_topdown_no_colortable';     Checksum: $AB3074DA; IgnoreRes: False),

    // It is not possible to store channels in RGB order in v1 format so rgba_v1 makes no sense.
    (Name: 'rgba_v1_bottomup_colortable';       Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v1_bottomup_no_colortable';    Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v1_topdown_colortable';        Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v1_topdown_no_colortable';     Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v2_bottomup_colortable';       Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v2_bottomup_no_colortable';    Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v2_topdown_colortable';        Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v2_topdown_no_colortable';     Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v3_bottomup_colortable';       Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'rgba_v3_bottomup_no_colortable';    Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v3_topdown_colortable';        Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'rgba_v3_topdown_no_colortable';     Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v4_bottomup_colortable';       Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'rgba_v4_bottomup_no_colortable';    Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v4_topdown_colortable';        Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'rgba_v4_topdown_no_colortable';     Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v5_bottomup_colortable';       Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'rgba_v5_bottomup_no_colortable';    Checksum: $AB3074DA; IgnoreRes: False),
    (Name: 'rgba_v5_topdown_colortable';        Checksum: $AB3074DA; IgnoreRes: True),
    (Name: 'rgba_v5_topdown_no_colortable';     Checksum: $AB3074DA; IgnoreRes: False),

    // Bmp suite
    (Name: 'pal1';                              Checksum: $EB74525F; IgnoreRes: False),
    (Name: 'pal1bg';                            Checksum: $461E3E42; IgnoreRes: False),
    (Name: 'pal1wb';                            Checksum: $EB74525F; IgnoreRes: False),
    (Name: 'pal4';                              Checksum: $963878B9; IgnoreRes: False),
    (Name: 'pal4gs';                            Checksum: $38C07071; IgnoreRes: False),
    (Name: 'pal4rle';                           Checksum: $963878B9; IgnoreRes: False),
    (Name: 'pal8-0';                            Checksum: $A66B800E; IgnoreRes: False),
    (Name: 'pal8';                              Checksum: $A66B800E; IgnoreRes: False),
    (Name: 'pal8gs';                            Checksum: $FCFD7A5A; IgnoreRes: False),
    (Name: 'pal8nonsquare';                     Checksum: $9C51A082; IgnoreRes: False),
    (Name: 'pal8os2';                           Checksum: $216B88F1; IgnoreRes: False),
    (Name: 'pal8rle';                           Checksum: $A66B800E; IgnoreRes: False),
    (Name: 'pal8topdown';                       Checksum: $980784BA; IgnoreRes: False),
    (Name: 'pal8v4';                            Checksum: $A66B800E; IgnoreRes: False),
    (Name: 'pal8v5';                            Checksum: $A66B800E; IgnoreRes: False),
    (Name: 'pal8w124';                          Checksum: $C587558C; IgnoreRes: False),
    (Name: 'pal8w125';                          Checksum: $28FB03E9; IgnoreRes: False),
    (Name: 'pal8w126';                          Checksum: $7E8FACEE; IgnoreRes: False),
    (Name: 'rgb16-565';                         Checksum: $2B0C3870; IgnoreRes: False),
    (Name: 'rgb16-565pal';                      Checksum: $2B0C3870; IgnoreRes: True),
    (Name: 'rgb16';                             Checksum: $C2A5F1C7; IgnoreRes: False),
    (Name: 'rgb16bfdef';                        Checksum: $C2A5F1C7; IgnoreRes: False),
    (Name: 'rgb24';                             Checksum: $0BDF42DF; IgnoreRes: False),
    (Name: 'rgb24pal';                          Checksum: $0BDF42DF; IgnoreRes: False),
    (Name: 'rgb32';                             Checksum: $0BDF42DF; IgnoreRes: False),
    (Name: 'rgb32bf';                           Checksum: $0BDF42DF; IgnoreRes: False),
    (Name: 'rgb32bfdef';                        Checksum: $0BDF42DF; IgnoreRes: False),
    // Additional
    (Name: 'rgb32fakealpha';                    Checksum: $23821D77; IgnoreRes: False)
  );

{ TOffsetStream }

type
  TOffsetStream = class(TMemoryStream)
  private
    FOffset: Int64;
  public
    constructor Create(AOffset: Int64);
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    property Offset: Int64 read FOffset;
  end;

constructor TOffsetStream.Create(AOffset: Int64);
begin
  inherited Create;
  FOffset := AOffset;
  Size := FOffset;
  Position := FOffset;
end;

function TOffsetStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := inherited;
  if (Result < FOffset) then
    raise ETestFailure.CreateFmt('Seek before start of relative stream. Start: %d, Position: %d', [FOffset, Result]);
end;

type
  TBitmap32Cracker = class(TBitmap32);

procedure TTestTCustomBitmap32.SetUp;
begin
  FBitmap32 := TBitmap32.Create;

  var Name := TPath.GetFileNameWithoutExtension(TestFileName);
  var Found := False;

  FExpectedCrc := 0;
  FIgnoreRes := True;

  for var Checksum in Checksums do
    if (SameText(Checksum.Name, Name)) then
    begin
      FExpectedCrc := Checksum.Checksum;
      FIgnoreRes := Checksum.IgnoreRes;
      Found := True;
      break;
    end;

  if (not Found) then
    Self.Status(Format('%s not found in CRC list', [Name]));
end;

procedure TTestTCustomBitmap32.TearDown;
begin
  FBitmap32.Free;
  FBitmap32 := nil;
end;

procedure TTestTCustomBitmap32.ValidateCRC(Bitmap: TCustomBitmap32);
begin
  if (FExpectedCrc = 0) then
  begin
    Check(True);
    exit;
  end;

  var Crc: Cardinal := crc32(0, nil, 0);
  if (not Bitmap.Empty) then
    Crc := crc32(Crc, PByte(Bitmap.Bits), Bitmap.Width*Bitmap.Height*SizeOf(DWORD));

  CheckEquals(Crc, FExpectedCrc, 'Bitmap checksum validation failed');
end;

procedure TTestTCustomBitmap32.TestClipboard;

  procedure OpenClipboard;
  begin
    try

      Clipboard.Open;

    except
      on E: EClipboardException do
      begin
        Sleep(100);
        Clipboard.Open;
      end;
    end;
  end;

begin
  if (not TPath.GetFileName(TestFileName).StartsWith('bgra')) and (not TPath.GetFileName(TestFileName).StartsWith('rgba')) then
  begin
    Check(True);
    exit;
  end;

  FBitmap32.LoadFromFile(TestFileName);

  OpenClipboard;
  try

    // Can we copy to clipboard?
    Clipboard.Assign(FBitmap32);

  finally
    // We need to close the clipboard in order for it to generate synthesized formats
    Clipboard.Close;
  end;

  OpenClipboard;
  try

    // Is the expected data on the clipboard?
    Check(Clipboard.HasFormat(CF_DIBV5), 'CF_DIBV5 clipboard format');

    // Can the clipboard synthesize CF_DIB from CF_DIBV5?
    Check(Clipboard.HasFormat(CF_DIB), 'CF_DIB synthesized clipboard format');
    Check(Clipboard.HasFormat(CF_BITMAP), 'CF_BITMAP synthesized clipboard format');

    // Can we paste from the clipboard?
    FBitmap32.Clear;
    FBitmap32.Assign(Clipboard);

    Check(not FBitmap32.Empty, 'TBitmap32 empty after paste');
    ValidateCRC(FBitmap32);

    var Bitmap := TBitmap.Create;
    try
      // Can we copy from the clipboard to TBitmap?
      Bitmap.Assign(Clipboard);

      Check(not Bitmap.Empty, 'TBitmap empty after paste');

      // Can we paste from whatever TBitmap puts on the clipboard
      Clipboard.Assign(Bitmap);
    finally
      Bitmap.Free;
    end;
  finally
    Clipboard.Close;
  end;

  OpenClipboard;
  try
    FBitmap32.Assign(Clipboard);
    Check(not FBitmap32.Empty, 'TBitmap32 empty after paste from TBitmap');

    Clipboard.Clear;
  finally
    Clipboard.Close;
  end;
end;

procedure TTestTCustomBitmap32.TestLoadFromStream;
begin
  var Stream := TFileStream.Create(TestFileName, fmOpenRead or fmShareDenyWrite);
  try

    FBitmap32.Clear;
    FBitmap32.LoadFromStream(Stream);

  finally
    Stream.Free;
  end;

  ValidateCRC(FBitmap32);
  Check(not FBitmap32.Empty);
end;

procedure TTestTCustomBitmap32.TestLoadFromStreamRelative;
begin
  // Prefix BMP data with some junk
  var Stream := TOffsetStream.Create(Random(1024));
  try

    // Load BMP from file into relative stream position
    var FileStream := TFileStream.Create(TestFileName, fmOpenRead or fmShareDenyWrite);
    try
      Stream.CopyFrom(FileStream, FileStream.Size);

      Assert(Stream.Size = Stream.Offset + FileStream.Size);
    finally
      FileStream.Free;
    end;

    FBitmap32.Clear;

    // Load BMP from relative position
    Stream.Position := Stream.Offset;
    FBitmap32.LoadFromStream(Stream);

  finally
    Stream.Free;
  end;

  ValidateCRC(FBitmap32);
  Check(not FBitmap32.Empty);
end;

procedure TTestTCustomBitmap32.TestLoadFromStreamDIB;
begin
  if (not TPath.GetFileName(TestFileName).StartsWith('bgra')) and (not TPath.GetFileName(TestFileName).StartsWith('rgba')) then
  begin
    Check(True);
    exit;
  end;

  var Stream := TFileStream.Create(TestFileName, fmOpenRead or fmShareDenyWrite);
  try
    // Skip file header
    Stream.Seek(SizeOf(TBitmapFileHeader), soFromCurrent);

    FBitmap32.Clear;
    TBitmap32Cracker(FBitmap32).LoadFromDIBStream(Stream, Stream.Size - SizeOf(TBitmapFileHeader));

  finally
    Stream.Free;
  end;

  ValidateCRC(FBitmap32);
  Check(not FBitmap32.Empty);
end;

procedure TTestTCustomBitmap32.TestLoadFromFile;
begin
  FBitmap32.Clear;
  FBitmap32.LoadFromFile(TestFileName);

  ValidateCRC(FBitmap32);
  Check(not FBitmap32.Empty);
end;

procedure TTestTCustomBitmap32.TestLoadFromResourceName;
begin
  var ResName := TPath.GetFileNameWithoutExtension(TestFileName);
  ResName := ResName.Replace('-', '_', [rfReplaceAll]);

  FBitmap32.Clear;
  FBitmap32.LoadFromResourceName(HInstance, ResName);

  if (not FIgnoreRes) then
    ValidateCRC(FBitmap32);
  Check(not FBitmap32.Empty);
end;

procedure TTestTCustomBitmap32.TestSaveToStream(TopDown: boolean);
begin
  FBitmap32.LoadFromFile(TestFileName);

  var Stream := TOffsetStream.Create(Random(1024)); // Test relative save/load while we're at it
  try
    FBitmap32.SaveToStream(Stream, TopDown);
    Stream.Position := Stream.Offset;

    FBitmap32.Clear;
    FBitmap32.LoadFromStream(Stream);

    // Also verify that TBitmap can handle the file we just saved.
    // Bitmap content isn't checked.
    var Bitmap := TBitmap.Create;
    try
      Stream.Position := Stream.Offset;
      Bitmap.LoadFromStream(Stream);
    finally
      Bitmap.Free;
    end;

    // Ditto for WIC
    var WICImage := TWICImage.Create;
    try
      Stream.Position := Stream.Offset;
      WICImage.LoadFromStream(Stream);
    finally
      WICImage.Free;
    end;

  finally
    Stream.Free;
  end;

  ValidateCRC(FBitmap32);
  Check(not FBitmap32.Empty);
end;

procedure TTestTCustomBitmap32.TestSaveToStreamTopDown;
begin
  TestSaveToStream(True);
end;

procedure TTestTCustomBitmap32.TestSaveToStreamBottomUp;
begin
  TestSaveToStream(False);
end;

procedure TTestTCustomBitmap32.TestSaveToStreamDIB(TopDown: boolean);
begin
  FBitmap32.LoadFromFile(TestFileName);

  var Stream := TOffsetStream.Create(Random(1024)); // Test relative save/load while we're at it
  try

    for var InfoHeaderVersion := Low(TBitmap32.TInfoHeaderVersion) to High(TBitmap32.TInfoHeaderVersion) do
    begin
      Stream.Size := Stream.Offset;

      TBitmap32Cracker(FBitmap32).SaveToDIBStream(Stream, TopDown, InfoHeaderVersion);
      Stream.Position := Stream.Offset;

      FBitmap32.Clear;
      TBitmap32Cracker(FBitmap32).LoadFromDIBStream(Stream, Stream.Size - Stream.Position);

      ValidateCRC(FBitmap32);
      Check(not FBitmap32.Empty);
    end;

  finally
    Stream.Free;
  end;

end;

procedure TTestTCustomBitmap32.TestSaveToStreamTopDownDIB;
begin
  if (not TPath.GetFileName(TestFileName).StartsWith('bgra')) and (not TPath.GetFileName(TestFileName).StartsWith('rgba')) then
  begin
    Check(True);
    exit;
  end;

  TestSaveToStreamDIB(True);
end;

procedure TTestTCustomBitmap32.TestSaveToStreamBottomUpDIB;
begin
  if (not TPath.GetFileName(TestFileName).StartsWith('bgra')) and (not TPath.GetFileName(TestFileName).StartsWith('rgba')) then
  begin
    Check(True);
    exit;
  end;

  TestSaveToStreamDIB(False);
end;

procedure TTestTCustomBitmap32.TestSaveToFile;
begin
  FBitmap32.LoadFromFile(TestFileName);

  var NewFilename := TGUID.NewGuid.ToString + '.bmp';
  FBitmap32.SaveToFile(NewFilename, True);
  try

    FBitmap32.Clear;
    FBitmap32.LoadFromFile(NewFilename);

    // Also verify that TBitmap can handle the file we just saved.
    // Bitmap content isn't checked.
    var Bitmap := TBitmap.Create;
    try
      Bitmap.LoadFromFile(NewFilename);
    finally
      Bitmap.Free;
    end;

  finally
    TFile.Delete(NewFilename);
  end;

  ValidateCRC(FBitmap32);
  Check(not FBitmap32.Empty);
end;

{$if defined(GENERATE_BITMAPS)}
procedure GenerateBitmaps;
const
  sUpDown: array[boolean] of string = ('bottomup', 'topdown');
  sColorTable: array[boolean] of string = ('_no_colortable', '_colortable');
{$if defined(RGBA_FORMAT)}
  sPrefix = 'rgba';
{$else}
  sPrefix = 'bgra';
{$ifend}
  sFilenameTemplate = '.\Data\%s_v%d_%s%s.bmp';
var
  Filename: string;
begin
  var Bitmap := TBitmap32.Create;
  try
    Bitmap.LoadFromFile('template.bmp');

    for var InfoHeaderVersion := Low(TBitmap32.TInfoHeaderVersion) to High(TBitmap32.TInfoHeaderVersion) do
    begin
      for var SaveTopDown := False to True do
      begin
        for var IncludeColorTable := False to True do
        begin
          Filename := Format(sFilenameTemplate, [sPrefix, Ord(InfoHeaderVersion)+1, sUpDown[SaveTopDown], sColorTable[IncludeColorTable]]);
          TBitmap32Cracker(Bitmap).SaveToFile(Filename, SaveTopDown, InfoHeaderVersion, IncludeColorTable);
        end;
      end;
    end;
  finally
    Bitmap.Free;
  end;
end;
{$ifend}

{$if defined(GENERATE_RC_SCRIPT)}
procedure GenerateRcScript;
begin
  if (TFile.Exists('rc_script.txt')) then
    TFile.Delete('rc_script.txt');

  for var Filename in TDirectory.GetFiles('.\Data', '*.bmp', TSearchOption.soAllDirectories) do
  begin
    var Name := TPath.GetFileNameWithoutExtension(Filename).Replace('-', '_').ToUpper;

    // Output the text that needs to be added to the RC script
    TFile.AppendAllText('rc_script.txt', Format('%-40s BITMAP "%s"'#13#10, [Name, Filename.Replace('\', '\\', [rfReplaceAll])]));
  end;
end;
{$ifend}

{$if defined(GENERATE_CRC_TABLE)}
procedure GenerateCrcTable;
begin
  if (TFile.Exists('crc_list.txt')) then
    TFile.Delete('crc_list.txt');

  var Bitmap := TBitmap32.Create;
  try
    for var Filename in TDirectory.GetFiles('.\Data', '*.bmp', TSearchOption.soAllDirectories) do
    begin
      Bitmap.Clear;
      Bitmap.LoadFromFile(Filename);

      var Crc: Cardinal := crc32(0, nil, 0);

      if (not Bitmap.Empty) then
        Crc := crc32(Crc, PByte(Bitmap.Bits), Bitmap.Width*Bitmap.Height*SizeOf(DWORD));

      var Name := TPath.GetFileNameWithoutExtension(Filename);

      // Output the text that needs to be added to the CRC table
      TFile.AppendAllText('crc_list.txt', Format('(Name: ''%s''; Checksum: $%.8X; IgnoreRes: False),'#13#10, [Name, Crc]));
    end;
  finally
    Bitmap.Free;
  end;
end;
{$ifend}

initialization
{$if defined(GENERATE_BITMAPS)}
  GenerateBitmaps;
{$ifend}

{$if defined(GENERATE_RC_SCRIPT)}
  GenerateRcScript;
{$ifend}

{$if defined(GENERATE_CRC_TABLE)}
  GenerateCrcTable;
{$ifend}

  var TestSuite := TFolderTestSuite.Create('Load and save bitmap', TTestTCustomBitmap32, '.\Data', '*.bmp', True);
  RegisterTest(TestSuite);
end.


