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
// Latest changes:
// March 20, 2003 - property ShortCut added
// March 24, 2005 - code slightly tidied up, comments added
//
// Additional information:
// http://msdn.microsoft.com/library/default.asp?url=/library/en-us/shellcc/platform/shell/reference/functions/shell_notifyicon.asp
// http://msdn.microsoft.com/library/default.asp?url=/library/en-us/shellcc/platform/shell/reference/structures/notifyicondata.asp
// http://msdn.microsoft.com/library/default.asp?url=/library/en-us/shellcc/platform/commctls/tooltip/usingtooltips.asp
// http://msdn.microsoft.com/msdnmag/issues/02/11/cqa/default.aspx
//

{ Corrections were made to comply with Delphi 2009 requirements.               }
{ Date last modified by Newman:  December 18, 2025                             }
{ Github Repository <https://github.com/valient-newman>                        }
{ The component has realization issues for instance with hint display and      }
{ the use of this component is on your own risk.                               }
{ The software is provided as is without any garanties and warranty.           }

unit FWTrayIcon;

interface

{$I DFS.INC}

uses
  Windows, Messages, Classes, Menus,
  Graphics, Forms, SysUtils, Controls, ImgList, CommCtrl;

type
  // We will scold with this :)
  TFWTrayException = class(Exception);

  // The button for the context menu may be different.
  TFWPopupBtn = (btnLeft, btnRight, btnMiddle);

  // The default button can also be different ;)
  TFWShowHideBtn = TFWPopupBtn;

  // Two ways to react to our tray icon:
  // on single and double click
  TFWShowHideStyle = (shDoubleClick, shSingleClick);

  // Three tray icon animation styles
  // asLine - icons are shown one after another from ImageList from first to last
  // asCircle - icons are shown one after another from the ImageList from the first to the last and back
  // asFlash - the icon placed in the Icon property blinks
  TFWAnimateStyle = (asFlash, asLine, asCircle);

  // Icon style when displaying BalloonHint
  TFWBalloonHintStyle = (bhsNone, bhsInfo, bhsWarning, bhsError);

  // Possible hint delay range
  TFWBalloonTimeout = 10..30;

  // Basic and additional structure for working with the tray
  _NOTIFYICONDATAA_V1 = record
    cbSize: DWORD;
    Wnd: HWND;
    uID: UINT;
    uFlags: UINT;
    uCallbackMessage: UINT;
    hIcon: HICON;
    szTip: array [0..63] of AnsiChar;
  end;

  DUMMYUNIONNAME = record
    case Integer of
      0: (
        uTimeout: UINT);
      1: (
        uVersion: UINT);
  end;

  _NOTIFYICONDATAA_V2 = record
    cbSize: DWORD;
    Wnd: HWND;
    uID: UINT;
    uFlags: UINT;
    uCallbackMessage: UINT;
    hIcon: HICON;

    // Structure extension for Shell32.dll version five
    szTip: array [0..MAXCHAR] of AnsiChar;
    dwState: DWORD;
    dwStateMask: DWORD;
    szInfo: array [0..MAXBYTE] of AnsiChar;
    UNIONNAME: DUMMYUNIONNAME;
    //uTimeout: UINT;
    szInfoTitle:  array [0..63] of AnsiChar;
    dwInfoFlags: DWORD;

    // Structure extension for Shell32.dll version six
    // guidItem: DWORD;
  end;

  // We will receive information about the library in this structure.
  PDllVersionInfo = ^TDllVersionInfo;
  TDllVersionInfo = packed record
    cbSize: DWORD;
    dwMajorVersion: DWORD;
    dwMinorVersion: DWORD;
    dwBuildNumber: DWORD;
    dwPlatformId: DWORD;
  end;

  TFWTrayIcon = class;

  // The class responsible for animation of the tray icon
  // We'll have to inherit from TComponent
  TFWAnimate = class(TPersistent)
  private
    FOwner: TFWTrayIcon;
    FActive: Boolean;            // Animation start/stop flag
    FAnimFrom: TImageIndex;      // The initial frame of the animation
    FStyle: TFWAnimateStyle;     // Animation style
    FTime: Integer;              // Animation speed
    FAnimTo: TImageIndex;        // The final frame of the animation
    procedure SetAnimateStyle(const Value: TFWAnimateStyle);
    procedure SetAnimateTime(const Value: Integer);
    procedure SetImages(const Value: TImageList);
    function GetIndex: Integer;
    procedure SetIndex(Value: Integer);
    procedure SetActive(const Value: Boolean);
    function GetImages: TImageList;
  protected
    procedure Animated(const Value: Boolean); virtual;
    procedure RefreshTimer;
  public
    constructor Create(const AOwner: TFWTrayIcon);
    destructor Destroy; override;
    property CurrentImageIndex: Integer read Getindex write SetIndex;
  published
    property Active: Boolean read FActive write SetActive default False;
    property Images: TImageList read GetImages write SetImages;
    property Time: Integer read FTime write SetAnimateTime default 500;
    property AnimFrom: TImageIndex read FAnimFrom write FAnimFrom default -1;
    property AnimTo: TImageIndex read FAnimTo write FAnimTo default -1;
    property Style: TFWAnimateStyle read FStyle write SetAnimateStyle default asFlash;
  end;

  // Main class
  TFWTrayIcon = class(TComponent)
  private
    FAbout: String;
    FAnimate: TFWAnimate;

    FAnimateHandle: HWND;               // Animation timer handle
    FHandle: HWND;                      // Handle of our component
    FOwnerHandle: HWND;                 // Form handle

    FTrayIcon: _NOTIFYICONDATAA_V1;     // Structure for displaying an icon
    FPopupMenu: TPopupMenu;             // Component context menu
    FIcon: TIcon;                       // Primary icon for display
    FHint: String;                      // Icon hint
    FStartMinimized: Boolean;           // The flag responsible for hiding the application on startup

    FPopupBtn: TFWPopupBtn;             // The variable specifies which button will display the context menu.

    FShowHideBtn: TFWShowHideBtn;       // The variable specifies which button will be used to show and hide the application.

    FShowHideStyle: TFWShowHideStyle;   // Show/hide application style (single - double click)

    FAutoShowHide: Boolean;             // A flag that determines whether the component will control the display of the main window or not (if not, the component executes the default menu item in the context menu)

    FMinimizeToTray: Boolean;           // Flag that determines whether the form is hidden when minimized
    FCloseToTray: Boolean;              // Flag that blocks the application from closing and hides the main form when closing.

    FDesignPreview: Boolean;            // A flag that allows you to test the icon in DesignTime

    FCloses: Boolean;                   // A flag indicating whether the program terminates or not.

    FShortCut: TShortCut;               // Hotkey for animation or default menu item execution

    FVisible: Boolean;                  // Tray icon display flag...

    WM_TASKBARCREATED: Cardinal;        // The message we'll receive after recreating the panel...
                          
    // Variables for events
    FOnAnimated: TNotifyEvent;
    FOnClick: TNotifyEvent;
    FOnDblClick: TNotifyEvent;
    FOnHide: TNotifyEvent;
    FOnMouseDown: TMouseEvent;
    FOnMouseMove: TMouseMoveEvent;
    FOnMouseUp: TMouseEvent;
    FOnPopup: TNotifyEvent;
    FOnShow: TNotifyEvent;
    FOnLoaded: TNotifyEvent;
    FOnClose: TNotifyEvent;
    FOnBalloonShow: TNotifyEvent;
    FOnBalloonHide: TNotifyEvent;
    FOnBalloonTimeout: TNotifyEvent;
    FOnBalloonUserClick: TNotifyEvent;

    FImages: TImageList;         // Icons for animation
    FImageChangeLink: TChangeLink;

    // Temporary variables required for the component to work
    FOldWndProc, FHookProc: Integer;      // Addresses of the old and new window functions
    FCurrentIcon: TIcon;                  // Current refresh icon
    FCurrentImage: Integer;               // Current animation frame number
    FTmpStep: Integer;                    // Variable defining animation direction for asCircle
    FTmpHot: Integer;                     // Global hotkey :)
    FFirstChange: Boolean;                // To correctly respond to changes in the ImageList

    // Procedures and functions responsible for the correct response of the component to changes
    procedure SetDesignPreview(const Value: Boolean);
    procedure SetIcon(const Value: TIcon);
    procedure SetHint(const Value: String);
    procedure SetShortCut(const Value: TShortCut);
    function GetAnimate: Boolean;
    procedure SetVisible(const Value: Boolean);
    function IsMainFormHiden: Boolean;
    procedure SetCloseToTray(const Value: Boolean);
    procedure ImageListChange(Sender: TObject);
  protected
    // Ancillary procedures

    // Window procedure of the component
    procedure WndProc(var Message: TMessage); virtual;
    procedure UpdateTray; virtual;
    procedure ShowHideForm; virtual;
    // A procedure that replaces the main window procedure of the application and the main form
    procedure HookWndProc(var Message: TMessage); virtual;
    function HookAppProc(var Message: TMessage): Boolean;

    procedure MouseDown(const State: TShiftState;
      const Button: TFWShowHideBtn; const MouseButton: TMouseButton); virtual;
    procedure MouseUp(const State: TShiftState; const MouseButton: TMouseButton); virtual;
    procedure DblClick(const Button: TFWShowHideBtn); virtual;
    procedure OnImageChange(Sender: TObject); virtual;
    class procedure AddInstande;
    class procedure ReleaseInstance;
    // These are calls to our handlers.
    procedure DoAnimate; virtual;
    procedure DoClick; virtual;
    procedure DoClose; virtual;
    procedure DoDblClick; virtual;
    procedure DoHide; virtual;
    procedure DoLoaded; virtual;
    procedure DoMouseDown(Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer); virtual;
    procedure DoMouseMove(Shift: TShiftState;
      X, Y: Integer); virtual;
    procedure DoMouseUp(Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer); virtual;
    procedure DoPopup; virtual;
    procedure DoShow; virtual;
    procedure DoBalloonShow; virtual;
    procedure DoBalloonHide; virtual;
    procedure DoBalloonTimeout; virtual;
    procedure DoBalloonUserClick; virtual;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Loaded; override;
    destructor Destroy; override;
    class function GetShellVersion: Integer;
    class function InstancesCount: Integer;
    // Main Form Control Procedures
    procedure CloseMainForm; // Closes the program
    procedure HideMainForm;  // Hides the form
    procedure ShowMainForm;  // ПоказываShows
    procedure ShowTaskButton;
    procedure HideTaskButton;

    // Showing BalloonHint as an informational message
   {$IFDEF DFS_COMPILER_12_UP}
   // Delphi 2009 and higher
    function ShowBalloonHint(const Hint, Title: AnsiString;
      Style: TFWBalloonHintStyle; TimeOut: TFWBalloonTimeout): Boolean;
   {$ELSE}
    function ShowBalloonHint(const Hint, Title: String;
      Style: TFWBalloonHintStyle; TimeOut: TFWBalloonTimeout): Boolean;
   {$ENDIF}
    // Properties
    property Handle: HWND read FHandle;
    property IsMainFormHide: Boolean read IsMainFormHiden;
    property IsCloses: Boolean read FCloses;
    property IsAnimate: Boolean read GetAnimate;
    property Owner;
  published
    property About: String read FAbout write FAbout;
    property Animate: TFWAnimate read FAnimate write FAnimate;
    property PopupMenu: TPopupMenu read FPopupMenu write FPopupMenu;
    property Icon: TIcon read FIcon write SetIcon;
    property Hint: String read FHint write SetHint;
    property StartMinimized: Boolean read FStartMinimized write FStartMinimized default False;
    property PopupBtn: TFWPopupBtn read FPopupBtn write FPopupBtn default btnRight;
    property ShowHideBtn: TFWShowHideBtn read FShowHideBtn write FShowHideBtn default btnLeft;
    property ShowHideStyle: TFWShowHideStyle read FShowHideStyle write FShowHideStyle default shDoubleClick;
    property AutoShowHide: Boolean read FAutoShowHide write FAutoShowHide default True;
    property MinimizeToTray: Boolean read FMinimizeToTray write FMinimizeToTray default False;
    property CloseToTray: Boolean read FCloseToTray write SetCloseToTray default False;
    property DesignPreview: Boolean read FDesignPreview write SetDesignPreview default False;
    property ShortCut: TShortCut read FShortCut write SetShortCut default 0;
    property Visible: Boolean read FVisible write SetVisible default True;

    property OnAnimated: TNotifyEvent read FOnAnimated write FOnAnimated;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
    property OnHide: TNotifyEvent read FOnHide write FOnHide;
    property OnMouseDown: TMouseEvent read FOnMouseDown write FOnMouseDown;
    property OnMouseMove: TMouseMoveEvent read FOnMouseMove write FOnMouseMove;
    property OnMouseUp: TMouseEvent read FOnMouseUp write FOnMouseUp;
    property OnLoaded: TNotifyEvent read FOnLoaded write FOnLoaded;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnBalloonShow: TNotifyEvent read FOnBalloonShow write FOnBalloonShow;
    property OnBalloonHide: TNotifyEvent read FOnBalloonHide write FOnBalloonHide;
    property OnBalloonTimeout: TNotifyEvent read FOnBalloonTimeout write FOnBalloonTimeout;
    property OnBalloonUserClick: TNotifyEvent read FOnBalloonUserClick write FOnBalloonUserClick;
  end;

implementation
// Or add dcr to dpk
{$R 'FWTrayIcon.dcr'}


uses Math;

  function Shell_NotifyIcon(dwMessage: DWORD; lpData: Pointer): BOOL; stdcall;
    external 'shell32.dll' name 'Shell_NotifyIconA';

const
  NIM_ADD         = $00000000;
  NIM_MODIFY      = $00000001;
  NIM_DELETE      = $00000002;

  NIF_MESSAGE     = $00000001;
  NIF_ICON        = $00000002;
  NIF_TIP         = $00000004;
  NIF_STATE       = $00000008;
  NIF_INFO        = $00000010;
  NIF_GUID        = $00000020;

  NIIF_NONE       = $00000000;
  NIIF_INFO       = $00000001;
  NIIF_WARNING    = $00000002;
  NIIF_ERROR      = $00000003;

  NIN_BALLOONSHOW      = WM_USER + 2;
  NIN_BALLOONHIDE      = WM_USER + 3;
  NIN_BALLOONTIMEOUT   = WM_USER + 4;
  NIN_BALLOONUSERCLICK = WM_USER + 5;

  NOTIFYICONDATA_SIZE = $58;
  NOTIFYICONDATA_V2_SIZE = $1E8;

  NEED_SHELL_VER = 5;

  SNoTimers = 'Not enough timers available';
  WM_ICON_MESSAGE = WM_USER + $4625;
  ANIMATE_TIMER = 100;

var
  FWTrayIconInstances: Integer = 0;

function GetShiftState: TShiftState;
begin
  Result := [];
  if GetKeyState(VK_SHIFT) < 0 then
    Include(Result, ssShift);
  if GetKeyState(VK_CONTROL) < 0 then
    Include(Result, ssCtrl);
  if GetKeyState(VK_MENU) < 0 then
    Include(Result, ssAlt);
end;

{ TFWAnimate }

//  Starting and stopping the animation timer
// =============================================================================
procedure TFWAnimate.Animated(const Value: Boolean);
begin
  if Value then
  begin
    if FOwner.FAnimateHandle <> 0 then
      Exit
    else
      FOwner.FAnimateHandle :=
        SetTimer(FOwner.FHandle, ANIMATE_TIMER, FTime, nil);
  end
  else
  begin
    if FOwner.FAnimateHandle <> 0 then
      KillTimer(FOwner.FHandle, ANIMATE_TIMER);
    FOwner.FAnimateHandle := 0;
  end;
end;

constructor TFWAnimate.Create(const AOwner: TFWTrayIcon);
begin
  if AOwner = nil then
    raise TFWTrayException.Create('AOwner is nil');
  inherited Create;
  FOwner := AOwner;
  FActive := False;
  FTime := 500;
  FStyle := asFlash;
  FAnimFrom := -1;
  FAnimTo := -1;
end;

destructor TFWAnimate.Destroy;
begin
  Animated(False);
  inherited;
end;

function TFWAnimate.GetImages: TImageList;
begin
  Result := FOwner.FImages;
end;

//  Reading the value of the current animation image index
// =============================================================================
function TFWAnimate.Getindex: Integer;
begin
  Result := FOwner.FCurrentImage;
end;

//  Setting a new value for the animation timer
// =============================================================================
procedure TFWAnimate.RefreshTimer;
begin
  if FOwner.FAnimateHandle <> 0 then
    KillTimer(FOwner.FHandle, ANIMATE_TIMER);
  if FActive then
    FOwner.FAnimateHandle :=
      SetTimer(FOwner.FHandle, ANIMATE_TIMER, FTime, nil);
end;

//  Start/stop icon animation
// =============================================================================
procedure TFWAnimate.SetActive(const Value: Boolean);
begin
  FActive := Value;
  if (csDesigning in FOwner.ComponentState) and not FOwner.DesignPreview then
  begin
    Animated(False);
    Exit;
  end;
  Animated(Value);
  if not Value then
  begin
    FOwner.FCurrentImage := 0;
    FOwner.FCurrentIcon.Assign(FOwner.FIcon);
    FOwner.FTrayIcon.hIcon := FOwner.FCurrentIcon.Handle;
    Shell_NotifyIcon(NIM_MODIFY, @FOwner.FTrayIcon);
  end;
end;

//  Setting a new animation style
// =============================================================================
procedure TFWAnimate.SetAnimateStyle(const Value: TFWAnimateStyle);
begin
  if FStyle = Value then Exit;
  FStyle := Value;
  case Value of
    asFlash:
      FOwner.FCurrentImage := 0;
    asLine:
      FOwner.FCurrentImage := AnimFrom;
    asCircle:
    begin
      FOwner.FCurrentImage := AnimFrom;
      FOwner.FTmpStep := 1;
    end;
  end;
end;

procedure TFWAnimate.SetAnimateTime(const Value: Integer);
begin
  FTime := Value;
  RefreshTimer;
end;

// Setting the current animation index
// =============================================================================
procedure TFWAnimate.SetIndex(Value: Integer);
begin
  if Value < FAnimFrom then
    Value := FAnimFrom
  else
    if Value > FAnimTo then
      Value := FAnimTo;
  FOwner.FCurrentImage := Value;
end;

procedure TFWAnimate.SetImages(const Value: TImageList);
begin
  if Images <> nil then
    Images.UnRegisterChanges(FOwner.FImageChangeLink);
  FOwner.FImages := Value;
  if Images <> nil then
  begin
    Images.RegisterChanges(FOwner.FImageChangeLink);
    Images.FreeNotification(FOwner);
  end
  else
  begin
    AnimFrom := -1;
    AnimTo := -1;
  end;
end;

{ TFWTrayIcon }

//
// =============================================================================
class procedure TFWTrayIcon.AddInstande;
begin
  Inc(FWTrayIconInstances);
end;

//  Closing the main form
// =============================================================================
procedure TFWTrayIcon.CloseMainForm;
begin
  Shell_NotifyIcon(NIM_DELETE, @FTrayIcon);
  FCloses := True;       // Выставляем нужные флаги
  FCloseToTray := False;
  TForm(Owner).Close; // Закрываем главную форму
end;

//  Class constructor
// =============================================================================
constructor TFWTrayIcon.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  // We allow only one instance of a class to be created in an application.
  AddInstande;
  if InstancesCount > 1 then
    raise TFWTrayException.Create('Too many instances of TFWTrayIcon.');

  // Subscribe to receive notifications about the re-creation of Taskbar
  WM_TASKBARCREATED := RegisterWindowMessage('TaskbarCreated');

  // The address of our window procedure will be the component handle.
  {$WARNINGS OFF}
  FHandle := AllocateHWnd(WndProc);
  {$WARNINGS ON}

  if not (csDesigning in ComponentState) then
  begin
    // We replace the main window procedure of the application with our own
    if AOwner <> nil then
    begin
      FOldWndProc := GetWindowLong(TForm(AOwner).Handle, GWL_WNDPROC);
      {$WARNINGS OFF}
      FHookProc := Integer(MakeObjectInstance(HookWndProc));
      {$WARNINGS ON}
      Application.HookMainWindow(HookAppProc);
      SetWindowLong(TForm(AOwner).Handle, GWL_WNDPROC, FHookProc);
      FOwnerHandle := TForm(AOwner).Handle;
    end
    else
      FOwnerHandle := 0;
  end;

  FTrayIcon.cbSize := NOTIFYICONDATA_SIZE;
  FTrayIcon.uFlags := NIF_ICON or NIF_TIP or NIF_MESSAGE;
  FTrayIcon.Wnd := FHandle;
  FTrayIcon.uCallbackMessage := WM_ICON_MESSAGE;
  FTrayIcon.szTip[0] := #0;

  FAnimate := TFWAnimate.Create(Self);

  FIcon := TIcon.Create; // Creating a basic icon
  FCurrentIcon := TIcon.Create; // And a temporary icon

  // Initialize the remaining values to default
  FStartMinimized := False;
  FPopupBtn := btnRight;
  FShowHideBtn := btnLeft;
  FShowHideStyle := shDoubleClick;
  FAutoShowHide := True;
  FMinimizeToTray := False;
  FCloseToTray := False;
  FDesignPreview := False;
  FTmpStep := 1;
  FCloses := False;
  FShortCut := 0;
  FVisible := True;
  FImageChangeLink := TChangeLink.Create;
  FImageChangeLink.OnChange := ImageListChange;
  FFirstChange := False;
end;

//  The general procedure for all Left, Middle, Right buttons is to double-click on the icon
// =============================================================================
procedure TFWTrayIcon.DblClick(const Button: TFWShowHideBtn);
var
  I: Integer;
begin
  if (csDesigning in ComponentState) then Exit;
  // Event generation
  DoDblClick;

  // Hide/show the main form
  if (FShowHideStyle = shDoubleClick) and
     (FShowHideBtn = Button) and
     FAutoShowHide then
     begin
       ShowHideForm;
       Exit;
     end;

  // Execute a menu item by default
  if (FShowHideStyle = shDoubleClick) and
     (FShowHideBtn = Button) and
     (not FAutoShowHide) then
    if Assigned(FPopupMenu) then
    begin
      for I:= 0 to TPopUpMenu(FPopupMenu).Items.Count - 1 do
        if TPopUpMenu(FPopupMenu).Items[i].Default then
          TPopUpMenu(FPopupMenu).Items[i].Click;
    end;
end;

//  The very class destructor
// =============================================================================
destructor TFWTrayIcon.Destroy;
begin
  ReleaseInstance;
  KillTimer(FHandle, 1); // and an icon refresh timer
  Shell_NotifyIcon(NIM_DELETE, @FTrayIcon); // Deleting the icon
  FIcon.Free;    // Freeing up occupied resources
  FCurrentIcon.Free;
  FAnimate.Free;
  FreeAndNil(FImageChangeLink);  
  {$WARNINGS OFF}
  DeallocateHWnd(FHandle); // Freeing up window procedures
  {$WARNINGS ON}
  if FOwnerHandle <> 0 then
  begin
    Application.UnhookMainWindow(HookAppProc);
    SetWindowLong(FOwnerHandle, GWL_WNDPROC, FOldWndProc);
    {$WARNINGS OFF}
    FreeObjectInstance(Pointer(FHookProc));
    {$WARNINGS ON}
  end;
  inherited;
end;

//  The next 15 procedures are simply wrappers for calling component events.
// =============================================================================
procedure TFWTrayIcon.DoAnimate;
begin
  if Assigned(FOnAnimated) then FOnAnimated(Self);
end;

procedure TFWTrayIcon.DoBalloonHide;
begin
  if Assigned(FOnBalloonHide) then FOnBalloonHide(Self);
end;

procedure TFWTrayIcon.DoBalloonShow;
begin
  if Assigned(FOnBalloonShow) then FOnBalloonShow(Self);
end;

procedure TFWTrayIcon.DoBalloonTimeout;
begin
  if Assigned(FOnBalloonTimeout) then FOnBalloonTimeout(Self);
end;

procedure TFWTrayIcon.DoBalloonUserClick;
begin
  if Assigned(FOnBalloonUserClick) then FOnBalloonUserClick(Self);
end;

procedure TFWTrayIcon.DoClick;
begin
  if Assigned(FOnClick) then FOnClick(Self);
end;

procedure TFWTrayIcon.DoClose;
begin
  if Assigned(FOnClose) then FOnClose(Self);
end;

procedure TFWTrayIcon.DoDblClick;
begin
  if Assigned(FOnDblClick) then FOnDblClick(Self);
end;

procedure TFWTrayIcon.DoHide;
begin
  if Assigned(FOnHide) then FOnHide(Self);
end;

procedure TFWTrayIcon.DoLoaded;
begin
  if Assigned(FOnLoaded) then FOnLoaded(Self);
end;

procedure TFWTrayIcon.DoMouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if Assigned(FOnMouseDown) then FOnMouseDown(Self, Button, Shift, X, Y);
end;

procedure TFWTrayIcon.DoMouseMove(Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(FOnMouseMove) then FOnMouseMove(Self, Shift, X, Y);
end;

procedure TFWTrayIcon.DoMouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if Assigned(FOnMouseUp) then FOnMouseUp(Self, Button, Shift, X, Y);
end;

procedure TFWTrayIcon.DoPopup;
begin
  if Assigned(FOnPopup) then FOnPopup(Self);
end;

procedure TFWTrayIcon.DoShow;
begin
  if Assigned(FOnShow) then FOnShow(Self);
end;   

//  Shows whether the animation timer is currently spinning.
// =============================================================================
function TFWTrayIcon.GetAnimate: Boolean;
begin
  Result := FAnimateHandle <> 0;
end;

//  The function returns the version of shell32.dll - necessary for the class work
// =============================================================================
class function TFWTrayIcon.GetShellVersion: Integer;
type
  TDllGetVersionProc = function (var pdvi: TDllVersionInfo): HRESULT; stdcall;
var
  DllGetVersion: TDllGetVersionProc;
  hLib: HINST;
  Version: TDllVersionInfo;
begin
  Result := 0;
  hLib := LoadLibrary('shell32.dll');
  try
    if hLib <> 0 then
    begin
      @DllGetVersion := GetProcAddress(hLib, PChar('DllGetVersion'));
      if @DllGetVersion <> nil then
      begin
        Version.cbSize := SizeOf(TDllVersionInfo);
        if Succeeded(DllGetVersion(Version)) then
          Result := Version.dwMajorVersion;
      end;
    end;
  finally
    FreeLibrary(hLib);
  end;
end;

//  Hiding the main form
// =============================================================================
procedure TFWTrayIcon.HideMainForm;
begin
  Application.Minimize;
  HideTaskButton;
  Application.MainForm.Visible := False;   // Hiding the main form
  DoHide;                                  // Generate an event
end;

//  Removing a button from the TaskBar
// =============================================================================
procedure TFWTrayIcon.HideTaskButton;
begin
  ShowWindow(Application.Handle, SW_HIDE);
end;

//  New application window procedure
// =============================================================================
function TFWTrayIcon.HookAppProc(var Message: TMessage): Boolean;
begin
  Result := False;
  with Message do
    case Msg of
      WM_SIZE:  // We catch the minimization message and, depending on the state of the flag, hide the form
        if FMinimizeToTray and (wParam = SIZE_MINIMIZED) then
          HideMainForm;
      WM_CLOSE: // We block the closing message sent to the application if necessary.
      begin
        if FCloseToTray then
        begin
          HookAppProc := True;
          DoClose;
          HideMainForm;
          Exit;
        end;
      end;
    end;
  inherited;
end;

//  New form window procedure
// =============================================================================
procedure TFWTrayIcon.HookWndProc(var Message: TMessage);
begin
  with Message do
  begin
    case Msg of
      WM_CLOSE: // We block, if necessary, the closing message received by the form
      begin
        if FCloseToTray then
        begin
          DoClose;
          HideMainForm;
          Exit;
        end;
      end;
    end;
    // We send all other messages to the old window procedure.
    Result := CallWindowProc(Pointer(FOldWndProc), FOwnerHandle,
    	Msg, wParam, lParam);
  end;
  inherited;
end;

//  Reacting to changes in ImageList
// =============================================================================
procedure TFWTrayIcon.ImageListChange(Sender: TObject);
begin
  if FImages.Count = 0 then
  begin
    Animate.FAnimFrom := -1;
    Animate.FAnimTo := -1;
  end;
end;

//  Debug function - returns the number of copies of a class
// =============================================================================
class function TFWTrayIcon.InstancesCount: Integer;
begin
  Result := FWTrayIconInstances;
end;

//  The function shows whether the form is hidden or not
// =============================================================================
function TFWTrayIcon.IsMainFormHiden: Boolean;
begin
  Result := not IsWindowVisible(FOwnerHandle);
end;

//  This procedure will be executed in RunTime and will hide our application when launched if necessary
// =============================================================================
procedure TFWTrayIcon.Loaded;
begin
  inherited Loaded;
  if (csDesigning in ComponentState) then Exit;

  DoLoaded;
  // At the very beginning, let's look: if we haven't placed our own icon in the Icon property,
  //  then the main icon of the component will be taken from the application icon
  if FIcon.Handle = 0 then
    FIcon.Assign(Application.Icon);
  FCurrentIcon.Assign(FIcon);
  FTrayIcon.hIcon := FCurrentIcon.Handle;

  FIcon.OnChange := OnImageChange;

  // Hiding the main form of the application
  if (FStartMinimized) and not (csDesigning in ComponentState) then
  begin
    Application.ShowMainForm := False;
    ShowWindow(Application.Handle, SW_HIDE);
  end;
  // Adding an icon to the tray
  if FVisible then
    Shell_NotifyIcon(NIM_ADD, @FTrayIcon);
  UpdateTray;
end;

//  General procedure for all buttons Left, Middle, Right - button pressed
// =============================================================================
procedure TFWTrayIcon.MouseDown(const State: TShiftState;
  const Button: TFWShowHideBtn; const MouseButton: TMouseButton);
var
  P: TPoint;
  Shift: TShiftState;
  I: Integer;
begin
  if (csDesigning in ComponentState) then Exit;
  
  // Determining coordinates
  GetCursorPos(P);
  
  // Event generation
  Shift := GetShiftState + State;
  DoMouseDown(MouseButton, Shift, P.X, P.Y);

  // Hide/show the main form
  if (FShowHideStyle = shSingleClick) and
     (FShowHideBtn = Button) and
     FAutoShowHide then
     begin
       ShowHideForm;
       Exit;
     end;

  // Show pop-up menu
  if (FPopupBtn = Button) then
    if Assigned(FPopupMenu) then
    begin
      Application.ProcessMessages;
      SetForegroundWindow((Owner as TWinControl).Handle);
      TPopUpMenu(FPopupMenu).Popup(P.X, P.Y);
      DoPopup;
      Exit;
    end;

  // Execute a menu item by default
  if (FShowHideStyle = shSingleClick) and
     (FShowHideBtn = Button) and
     (not FAutoShowHide) then
    if Assigned(FPopupMenu) then
    begin
      for I:= 0 to TPopUpMenu(FPopupMenu).Items.Count - 1 do
        if TPopUpMenu(FPopupMenu).Items[i].Default then
          TPopUpMenu(FPopupMenu).Items[i].Click;
    end;
end;

//  General procedure for all buttons Left, Middle, Right - button released
// =============================================================================
procedure TFWTrayIcon.MouseUp(const State: TShiftState;
  const MouseButton: TMouseButton);
var
  P: TPoint;
  Shift: TShiftState;
begin
  if (csDesigning in ComponentState) then Exit;
  GetCursorPos(P);
  Shift := GetShiftState + State;
  DoMouseUp(MouseButton, Shift, P.X, P.Y);
  DoClick;
end;

//  We catch notifications to avoid getting caught by AV :)
// =============================================================================
procedure TFWTrayIcon.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = PopupMenu then FPopupMenu := nil;
    if AComponent = Animate.Images then
    begin
      FImages := nil;
      Animate.AnimFrom := -1;
      Animate.AnimTo := -1;
    end;
  end;
end;

//  Catching icon changes
// =============================================================================
procedure TFWTrayIcon.OnImageChange(Sender: TObject);
begin
  FIcon.OnChange := nil;
  if FIcon.Handle = 0 then
    FIcon.Assign(Application.Icon);
  FCurrentIcon.Assign(FIcon);
  FTrayIcon.hIcon := FCurrentIcon.Handle;
  UpdateTray;
  FIcon.OnChange := OnImageChange;
end;

//  Debug procedure - decreases the class copy count
// =============================================================================
class procedure TFWTrayIcon.ReleaseInstance;
begin
  Dec(FWTrayIconInstances);
end;

//  We lock the ability to close using Alt+F4
// =============================================================================
procedure TFWTrayIcon.SetCloseToTray(const Value: Boolean);
begin
  FCloseToTray := Value;
end;

//  We provide the ability to view the result of working with the icon directly in the application
// =============================================================================
procedure TFWTrayIcon.SetDesignPreview(const Value: Boolean);
begin
  if Value = FDesignPreview then Exit;
  FDesignPreview := Value;
  if (csDesigning in ComponentState) then
    if Value then
    begin
      // We show either the application icon
      if FIcon.Handle = 0 then
        FTrayIcon.hIcon := Application.Icon.Handle
      else // Or your own icon
        FTrayIcon.hIcon := FIcon.Handle;
      Shell_NotifyIcon(NIM_ADD, @FTrayIcon);
      // Duplicate into animation class
      FAnimate.SetActive(FAnimate.Active);
    end
    else
      Shell_NotifyIcon(NIM_DELETE, @FTrayIcon);
end;

//  A new hint for our icon (not to be confused with BalloonHint)
// =============================================================================

procedure TFWTrayIcon.SetHint(const Value: String);
begin
  FHint := Value;
  UpdateTray;
end;

//  Assigning a new main icon...
// =============================================================================
procedure TFWTrayIcon.SetIcon(const Value: TIcon);
begin
  FIcon.Assign(Value);
  FCurrentIcon.Assign(FIcon);
  // I know, I know, I was just too lazy to duplicate the code ;)
  if (csDesigning in ComponentState) then
  begin
    DesignPreview := not DesignPreview;
    DesignPreview := not DesignPreview;
  end;
end;

//  We're trying to set a hotkey for our icon - something like clicking on the icon.
// =============================================================================
procedure TFWTrayIcon.SetShortCut(const Value: TShortCut);
var
  State: TShiftState;
  Vk, Mods: Word;
begin
  FShortCut := Value;
  if (csDesigning in ComponentState) then Exit;
  if FTmpHot <> 0 then DeleteAtom(FTmpHot);
  if FShortCut = 0 then Exit;
  FTmpHot := GlobalAddAtom('Fangorn Wizards Lab Tray Icon {71E330D0-B618-4A0D-AAB3-EF853FA5FEDD}');
  if FTmpHot <> 0 then
  begin
    Mods := 0;
    ShortCutToKey(FShortCut, Vk, State);
    if (ssShift in State) then Mods:= MOD_SHIFT;
    if (ssAlt in State) then Mods:= Mods + MOD_ALT;
    if (ssCtrl in State) then Mods:= Mods + MOD_CONTROL;
    RegisterHotKey(FHandle, FTmpHot, Mods, VK);
  end;
end;

//  Show or remove our icon from the tray
// =============================================================================
procedure TFWTrayIcon.SetVisible(const Value: Boolean);
begin
  FVisible := Value;
  if (csDesigning in ComponentState) then Exit;
  if Value then
    Shell_NotifyIcon(NIM_ADD, @FTrayIcon)
  else
    Shell_NotifyIcon(NIM_DELETE, @FTrayIcon);
end;

//  Showing BalloonHint as an informational message
// =============================================================================
{$IFDEF DFS_COMPILER_12_UP}
// Delphi 2009 and higher
function TFWTrayIcon.ShowBalloonHint(const Hint, Title: AnsiString;
      Style: TFWBalloonHintStyle; TimeOut: TFWBalloonTimeout): Boolean;
{$ELSE}
function TFWTrayIcon.ShowBalloonHint(const Hint, Title: String;
      Style: TFWBalloonHintStyle; TimeOut: TFWBalloonTimeout): Boolean;
{$ENDIF}
const
  BalloonStyle: array[TFWBalloonHintStyle] of Byte =
    (NIIF_NONE, NIIF_INFO, NIIF_WARNING, NIIF_ERROR);
var
  BalonNID: _NOTIFYICONDATAA_V2;
begin
  // We perform this procedure only if the version of Shell32.dll is greater than the fourth
  Result := GetShellVersion >= NEED_SHELL_VER;
  if not Result then Exit;
  // To display BalloonHint we use a slightly extended structure
  ZeroMemory(@BalonNID, NOTIFYICONDATA_V2_SIZE);
  BalonNID.cbSize := NOTIFYICONDATA_V2_SIZE;
  // Copy the required properties from the old structure
  BalonNID.Wnd := FTrayIcon.Wnd;
  BalonNID.uID := FTrayIcon.uID;
  // Add our data
  StrPCopy(BalonNID.szInfo, Hint);
  StrPCopy(BalonNID.szInfoTitle, Title);
  BalonNID.UNIONNAME.uTimeout := TimeOut * 1000;
  BalonNID.dwInfoFlags := BalloonStyle[Style];
  // Let's put up the flag!!!
  BalonNID.uFlags := NIF_INFO;
  // Voila ;)
  Shell_NotifyIcon(NIM_MODIFY, @BalonNID);
end;
 
//  The procedure hides or shows the main form depending on the flag
// =============================================================================
procedure TFWTrayIcon.ShowHideForm;
begin
  if IsWindowVisible(FOwnerHandle) then
    HideMainForm
  else
    ShowMainForm;
end;

//  Showing the main form
// =============================================================================
procedure TFWTrayIcon.ShowMainForm;
var
  hWnd, hCurWnd, dwThreadID, dwCurThreadID: THandle;
  OldTimeOut: DWORD;
  AResult: Boolean;
begin
  ShowTaskButton;
  Application.MainForm.Visible := True;   // Showing the main form

  // We place our form in front of all windows.
  hWnd := Application.Handle;
  SystemParametersInfo(SPI_GETFOREGROUNDLOCKTIMEOUT, 0, @OldTimeOut, 0);
  SystemParametersInfo(SPI_SETFOREGROUNDLOCKTIMEOUT, 0, Pointer(0), 0);
  SetWindowPos(hWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
  hCurWnd := GetForegroundWindow;
  AResult := False;
  while not AResult do
  begin
    dwThreadID := GetCurrentThreadId;
    dwCurThreadID := GetWindowThreadProcessId(hCurWnd);
    AttachThreadInput(dwThreadID, dwCurThreadID, True);
    AResult := SetForegroundWindow(hWnd);
    AttachThreadInput(dwThreadID, dwCurThreadID, False);
  end;
  SetWindowPos(hWnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
  SystemParametersInfo(SPI_SETFOREGROUNDLOCKTIMEOUT, 0, Pointer(OldTimeOut), 0); 

  // Generate an event
  DoShow;
end;

//  Showing the button on the TaskBar
// =============================================================================
procedure TFWTrayIcon.ShowTaskButton;
begin
  ShowWindow(Application.Handle, SW_RESTORE);
end;

//  The procedure is responsible for correctly filling the structure for displaying the icon in the tray.
// =============================================================================
procedure TFWTrayIcon.UpdateTray;
begin
  if (csDesigning in ComponentState) and not DesignPreview then Exit;
  if FHint = '' then
    FTrayIcon.szTip[0] := #0
  else
  if FHint <> '' then
  begin
    Move(FHint[1], FTrayIcon.szTip[0], Length(FHint));
    FTrayIcon.szTip[Length(FHint)] := #0;
  end;
  if FVisible then
    Shell_NotifyIcon(NIM_MODIFY, @FTrayIcon);
end;

//  Window procedure of the component
// =============================================================================
procedure TFWTrayIcon.WndProc(var Message: TMessage);
var
  P: TPoint;
  Shift: TShiftState;
  I: Integer;
begin
  inherited;
  try
    with Message do
    begin
      case Msg of
        WM_HOTKEY: // React to a hotkey
        begin
          if WParam <> FTmpHot then Exit;
          if FAutoShowHide then
            ShowHideForm
          else
            if Assigned(FPopupMenu) then
            begin
              for I:= 0 to TPopUpMenu(FPopupMenu).Items.Count - 1 do
                if TPopUpMenu(FPopupMenu).Items[i].Default then
                  TPopUpMenu(FPopupMenu).Items[i].Click;
            end;
          Exit;
        end;

        // Processing messages from the system timer
        WM_TIMER:
        begin
          if not FVisible then Exit;
          case WParam of
            ANIMATE_TIMER:
            begin // Animation timer
              case FAnimate.Style of

                // Flashing the main icon
                asFlash:
                begin
                  FCurrentImage := Integer(not Boolean(FCurrentImage));
                  if Boolean(FCurrentImage) then
                    FCurrentIcon.Assign(FIcon)
                  else
                  begin
                    // FCurrentIcon.ReleaseHandle;
                    FCurrentIcon.Handle := 0;
                  end;
                  FTrayIcon.hIcon := FCurrentIcon.Handle;
                  Shell_NotifyIcon(NIM_MODIFY, @FTrayIcon);
                end;

                // We show the frames one by one from the beginning to the end
                // and return to the beginning
                asLine:
                begin
                  if not Assigned(FAnimate.Images) then
                  begin
                    FAnimate.Active := False;
                    Result := DefWindowProc(FHandle, Msg, WParam, LParam);
                    Exit;
                  end;
                  Inc(FCurrentImage);
                  if (FCurrentImage > FAnimate.AnimTo)
                    or (FCurrentImage > FAnimate.Images.Count - 1) then
                    FCurrentImage := FAnimate.AnimFrom;
                  FAnimate.Images.GetIcon(FCurrentImage, FCurrentIcon);
                  FTrayIcon.hIcon := FCurrentIcon.Handle;
                  Shell_NotifyIcon(NIM_MODIFY, @FTrayIcon);
                end;

                // We show the frames one by one from the beginning to the end
                // and then from the end to the beginning, i.e. in a circle :)
                asCircle:
                begin
                  if not Assigned(FAnimate.Images) then
                  begin
                    FAnimate.Active := False;
                    Result := DefWindowProc(FHandle, Msg, WParam, LParam);
                    Exit;
                  end;
                  Inc(FCurrentImage, FTmpStep);
                  if (FCurrentImage > FAnimate.AnimTo)
                    or (FCurrentImage > FAnimate.Images.Count - 1) then
                  begin
                    Dec(FCurrentImage, 2);
                    FTmpStep:= -1;
                  end;
                  if (FCurrentImage < FAnimate.AnimFrom)
                    or (FCurrentImage < 0) then
                  begin
                    Inc(FCurrentImage, 2);
                    FTmpStep:= 1;
                  end;
                  FAnimate.Images.GetIcon(FCurrentImage, FCurrentIcon);
                  FTrayIcon.hIcon := FCurrentIcon.Handle;
                  Shell_NotifyIcon(NIM_MODIFY, @FTrayIcon);
                end;
              end;
            end;
          end;
          DoAnimate;
          Exit;
        end;

        // Tray processing
        WM_ICON_MESSAGE:
        begin
          case LParam of

            // The button is pressed
            WM_LBUTTONDOWN: MouseDown([ssLeft], btnLeft, mbLeft);
            WM_MBUTTONDOWN: MouseDown([ssMiddle], btnMiddle, mbMiddle);
            WM_RBUTTONDOWN: MouseDown([ssRight], btnRight, mbRight);

            // The button is released
            WM_LBUTTONUP: MouseUp([ssLeft], mbLeft);
            WM_MBUTTONUP: MouseUp([ssMiddle], mbMiddle);
            WM_RBUTTONUP: MouseUp([ssRight], mbRight);

            // Double click
            WM_LBUTTONDBLCLK: DblClick(btnLeft);
            WM_MBUTTONDBLCLK: DblClick(btnMiddle);
            WM_RBUTTONDBLCLK: DblClick(btnRight);

            // Move the cursor over the application icon in the tray
            WM_MOUSEMOVE:
            begin
              GetCursorPos(P);
              Shift := GetShiftState;
              DoMouseMove(Shift, P.X, P.Y);
            end;
            // BalloonHint handlers
            NIN_BALLOONSHOW:
              DoBalloonShow;
            NIN_BALLOONHIDE:
              DoBalloonHide;
            NIN_BALLOONTIMEOUT:
              DoBalloonTimeout;
            NIN_BALLOONUSERCLICK:
              DoBalloonUserClick;
          end; { case }
        end; { begin }
      else
        // TASKBAR crashed - need to re-add the icon
        if Msg = WM_TASKBARCREATED then
        begin
          if (csDesigning in ComponentState) then Exit;
          UpdateTray;
          if FVisible then
            Shell_NotifyIcon(NIM_ADD, @FTrayIcon);
        end;
      end; { case }

    end; { with }
  finally
    with Message do
      Result := DefWindowProc(FHandle, Msg, WParam, LParam);
  end;
end;


end.

