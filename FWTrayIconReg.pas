////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Project   : Fangorn Wizards Lab Exstension Library v1.35
//  * Unit Name : FWTrayIcon
//  * Purpose   : Registering a class to work with the system tray.
//  * Author    : Alexander (Rouse_) Bagel
//  * Copyright : © Fangorn Wizards Lab 1998 - 2003.
//  * Version   : 1.18
//  ****************************************************************************
//

{ Corrections were made to comply with Delphi 2009 requirements.               }
{ Date last modified by Newman:  December 18, 2025                             }
{ Github Repository <https://github.com/valient-newman>                        }

unit FWTrayIconReg;

interface

{$I DFS.INC}

uses
  Windows, Classes, SysUtils, Controls, TypInfo, Graphics, ImgList,
  {$IFDEF VER130}
    DsgnIntf
  {$ELSE}
    DesignIntf, DesignEditors, VCLEditors
  {$ENDIF};

type
  // Editor for property About
  TFWAboutPropertyEditor = class(TStringProperty)
    function GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
  end;

  // Editor for properties AnimFrom, AnimTo
  TImageIndexProperty = class(TIntegerProperty, ICustomPropertyListDrawing)
  protected
    function GetImages: TImageList; virtual;
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure SetValue(const Value: string); override;
    procedure GetValues(Proc: TGetStrProc); override;
{$IFDEF DFS_COMPILER_5_UP}
    procedure ListMeasureHeight(const Value: string; ACanvas: TCanvas;
      var AHeight: Integer);
    procedure ListMeasureWidth(const Value: string; ACanvas: TCanvas;
      var AWidth: Integer);
    procedure ListDrawValue(const Value: string; ACanvas: TCanvas;
      const ARect: TRect; ASelected: Boolean); 
{$ENDIF}
  end;


procedure Register;

implementation

uses FWTrayIcon, Math, Types;

procedure Register;
begin
  RegisterComponents('DFS', [TFWTrayIcon]);
  RegisterPropertyEditor(TypeInfo(String), TFWTrayIcon, 'About', TFWAboutPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TShortCut), TFWTrayIcon, 'ShortCut', TShortCutProperty);
  RegisterPropertyEditor(TypeInfo(TImageIndex), TFWAnimate, 'AnimFrom', TImageIndexProperty);
  RegisterPropertyEditor(TypeInfo(TImageIndex), TFWAnimate, 'AnimTo', TImageIndexProperty);
end;

{ TAboutPropertyEditor }

procedure TFWAboutPropertyEditor.Edit;
begin
  inherited;
  {$IFDEF DFS_COMPILER_12_UP}
  MessageBoxEx(0,
    PWideChar('Fangorn Wizards Lab Exstension Library v1.35'+ #13#10 +
    '© Fangorn Wizards Lab 1998 - 2003' + #13#10 +
    'Author: Alexander (Rouse_) Bagel' + #13#10 +
    'Corrections made by Valient Newman.' + #13#10#13#10 +
    'Current "shell32.dll" version ' + IntToStr(TFWTrayIcon.GetShellVersion)),
    'About...',  MB_ICONASTERISK, LANG_NEUTRAL);
  {$ELSE}
  MessageBoxEx(0,
    PAnsiChar('Fangorn Wizards Lab Exstension Library v1.35'+ #13#10 +
    '© Fangorn Wizards Lab 1998 - 2003' + #13#10 +
    'Author: Alexander (Rouse_) Bagel' + #13#10 +
    'Corrections made by Valient Newman.' + #13#10#13#10 +
    'Current "shell32.dll" version ' + IntToStr(TFWTrayIcon.GetShellVersion)),
    'About...',  MB_ICONASTERISK, LANG_NEUTRAL);
  {$ENDIF}


end;

function TFWAboutPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := inherited GetAttributes + [paDialog];
end;

{ TImageIndexProperty }

function TImageIndexProperty.GetImages: TImageList;
var
  EditedComponent: TPersistent;
  PropInfo: PPropInfo;
begin
  Result := nil;
  try
    EditedComponent := GetComponent(0) as TPersistent;
    if EditedComponent <> nil then
    begin
      PropInfo :=
        Typinfo.GetPropInfo(PTypeInfo(EditedComponent.ClassType.ClassInfo), 'Images');
      if PropInfo <> nil then
        Result := TObject(GetOrdProp(EditedComponent, PropInfo)) as TImageList;
    end;
  except
  end;
end;

function TImageIndexProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paValueList];
end;

procedure TImageIndexProperty.SetValue(const Value: String);
begin
  if Value = '' then
    inherited SetValue('-1')
  else
    inherited SetValue(Value);
end;

procedure TImageIndexProperty.GetValues(Proc: TGetStrProc);
var
  ImageList: TImageList;
  I: Integer;
begin
  Proc('-1');
  ImageList := GetImages;
  if ImageList <> nil then
    for I := 0 to ImageList.Count - 1 do
      Proc(IntToStr(I));
end;

{$IFDEF DFS_COMPILER_5_UP}
procedure TImageIndexProperty.ListDrawValue(const Value: string;
  ACanvas: TCanvas; const ARect: TRect; ASelected: Boolean);
var
  ImageList: TImageList;
  vRight, vTop: Integer;
  ImageIndex: Integer;
begin
  ImageList := GetImages;
  if ImageList <> nil then
  begin
    if ImageList.Count = 0 then Exit;
    vRight := ARect.Left + ImageList.Width + 4;
    with ACanvas do
    begin
      ImageIndex := StrToInt(Value);
      ACanvas.FillRect(ARect);
      if ImageIndex = -1 then Exit;
      ImageList.Draw(ACanvas, ARect.Left + 2, ARect.Top + 2, ImageIndex, True);
      vTop := ARect.Top + ((ARect.Bottom - ARect.Top -
        ACanvas.TextHeight(IntToStr(ImageIndex))) div 2);
      ACanvas.TextOut(vRight, vTop, IntToStr(ImageIndex));
    end;
  end;
end;

procedure TImageIndexProperty.ListMeasureWidth(const Value: string;
  ACanvas: TCanvas; var AWidth: Integer);
var
  ImageList: TImageList;
begin
  ImageList := GetImages;
  if ImageList <> nil then
    if ImageList.Count > 0 then
      AWidth := AWidth + ImageList.Width + 4;
end;

procedure TImageIndexProperty.ListMeasureHeight(const Value: string;
  ACanvas: TCanvas; var AHeight: Integer);
var
  ImageList: TImageList;
begin
  ImageList := GetImages;
  if ImageList <> nil then
    if ImageList.Count > 0 then
      if Value = '-1' then
        AHeight := 0
      else
        AHeight := Max(AHeight, ImageList.Height + 4);
end;
{$ENDIF}


end.
