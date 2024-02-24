;;  _  _____  __  __  ___ _____ ____      _ __   __
;; | |/ / _ \|  \/  |/ _ \_   _|  _ \    / \\ \ / /
;; | ' / | | | |\/| | | | || | | |_) |  / _ \\ V / 
;; | . \ |_| | |  | | |_| || | |  _ <  / ___ \| |  
;; |_|\_\___/|_|  |_|\___/ |_| |_| \_\/_/   \_\_|  
;;                                               

#Requires AutoHotkey v2.0
#SingleInstance Force

;#Include lib\JSONGO\jsongo.v2.ahk
#Include lib\CJSON\JSON.ahk

; Set common config options
AutoStartKomorebi := true
global IconPath := A_ScriptDir . "/assets/icons/"
global KomorebiConfig := "C:\Users\Null\komorebi.json"

; ======================================================================
; Initialization
; ======================================================================

; Set up tray menu
A_TrayMenu.Delete()
A_TrayMenu.Add("Pause Komorebi", PauseKomorebi)
A_TrayMenu.Add("Restart Komorebi", StartKomorebi)
A_TrayMenu.Add()
A_TrayMenu.Add("Reload Tray", ReloadTray)
A_TrayMenu.Add("Exit tray", ExitTray)

; Define default action and activate it with single click
A_TrayMenu.Default := "Pause Komorebi"
A_TrayMenu.ClickCount := 1

; Initialize internal states
IconState := -1
global Screen := 0
global LastTaskbarScroll := 0

; Start the komorebi server
; ErrorLevel := ProcessExist("komorebi.exe")
; if (!ErrorLevel && AutoStartKomorebi) {
;     StartKomorebi(false)
; }

; ======================================================================
; Event Handler
; ======================================================================

; Set up pipe
PipeName := "komotray"
PipePath := "\\.\pipe\" . PipeName
OpenMode := 0x01  ; access_inbound
PipeMode := 0x04 | 0x02 | 0x01  ; type_message | readmode_message | nowait
BufferSize := 64 * 1024

; Create named pipe instance
Pipe := DllCall("CreateNamedPipe", "Str", PipePath, "UInt", OpenMode,
                "UInt", PipeMode, "UInt", 1, "UInt", BufferSize, "UInt", BufferSize,
                "UInt", 0, "Ptr", 0, "Ptr")

if (Pipe = -1) {
    MsgBox "CreateNamedPipe: " A_LastError
    ExitTray()
}

; Wait for Komorebi to connect
Komorebi("subscribe " . PipeName)
DllCall("ConnectNamedPipe", "Ptr", Pipe, "Ptr", 0) ; set PipeMode = nowait to avoid getting stuck when paused
; if (!DllCall("ConnectNamedPipe", "Ptr", Pipe, "Ptr", 0)) {
;     MsgBox "Error connecting named pipe: " A_LastError
;     ExitApp
; }


; Subscribe to Komorebi events
BytesToRead := 0
Bytes:= 0
; Data:=''
Loop {
    ; Continue if buffer is empty
    ExitCode := DllCall("PeekNamedPipe", "Ptr", Pipe, "Ptr", 0, "UInt", 1, "Ptr", 0, "UintP", &BytesToRead, "Ptr", 0)
    ; MsgBox "The exitcode is: " ExitCode " the BytesToRead is: " BytesToRead

    if (!ExitCode || !BytesToRead) {
        Sleep 50
        continue
    }

    ; Read the buffer
    ; VarSetStrCapacity(&Data, BufferSize)
    Data := Buffer(BufferSize, 0)
    DllCall("ReadFile", "Ptr", Pipe,
            "Ptr", Data.Ptr,
            "UInt", BufferSize,
            "UintP", &Bytes,
            "Ptr", 0)
    ; TestData := StrGet(&Data, Bytes, "UTF-8")
    ; MsgBox "testing" TestData
    ; MsgBox "Buffersize is: " BufferSize " Bytes is: " Bytes
    ; MsgBox "Data is: " Data
    ; Strip new lines
    ; MsgBox Bytes
    if (Bytes <= 1) {
        continue
    }

    dataString := StrGet(Data, Bytes, "UTF-8")
    ; MsgBox dataString
    State := JSON.Load(dataString)["state"]
    Paused := State["is_paused"]
    Screen := State["monitors"]["focused"]
    ScreenQ := State["monitors"]["elements"][Screen + 1]
    Workspace := ScreenQ["workspaces"]["focused"]
    WorkspaceQ := ScreenQ["workspaces"]["elements"][Workspace + 1]

    ; Update tray icon
    if (Paused | Screen << 1 | Workspace << 4 != IconState) {
       UpdateIcon(Paused, Screen, Workspace, ScreenQ["name"], WorkspaceQ["name"])
       IconState := Paused | Screen << 1 | Workspace << 4 ; use 3 bits for monitor (i.e. up to 8 monitors)
    }
}

; ======================================================================
; Key Bindings
; ======================================================================

; Alt + scroll to cycle workspaces
!WheelUp::ScrollWorkspace("previous")
!WheelDown::ScrollWorkspace("next")

; Scroll taskbar to cycle workspaces
; #Hotif MouseIsOver("ahk_class Shell_TrayWnd") || MouseIsOver("ahk_class Shell_SecondaryTrayWnd")
;     WheelUp::ScrollWorkspace("previous")
;     WheelDown::ScrollWorkspace("next")
; #Hotif

; ======================================================================
; Functions
; ======================================================================

; if komorebic is unresponsive, any command that uses komorebic will create extra instances, as the previous commands will stall, replacing RunWait with Run instead, is just a temporary thing for the script itself, if komorebic is still unresponsive then new instances will still spawn, killing the instances in taskmanager is the solution
Komorebi(arg) {
    RunWait("komorebic.exe " . arg, , "Hide")
}

UpdateIcon(paused, screen, workspace, screenName, workspaceName) {

    ; Show TrayTip on workspace switch, a bit jarring though
    ; TrayTip workspaceName . " on " . screenName, , 16
    ; SetTimer HideTrayTip, -800
    ; HideTrayTip(){
    ;   TrayTip 
    ; }

    icon := IconPath . workspace + 1 . "-" . screen + 1 . ".ico"
    if (!paused && FileExist(icon)) {
        TraySetIcon icon
    }
    else {
        TraySetIcon IconPath . "pause.ico" ; also used as fallback
    }
}

StartKomorebi(*) {
    Komorebi("stop")
    Komorebi("start -c " . KomorebiConfig . " --ahk")
    ReloadTray()
}

ReloadTray(*) {
    DllCall("CloseHandle", "Ptr", Pipe)
    Reload
}

PauseKomorebi(*) {
    Komorebi("toggle-pause")
}

ExitTray(*) {
    DllCall("CloseHandle", "Ptr", Pipe)
    Komorebi("stop")
    ExitApp
}

ScrollWorkspace(dir) {
    ; This adds a state-dependent debounce timer to address an issue where a single wheel
    ; click spawns multiple clicks when a web browser is in focus.
    _isBrowser := WinActive("ahk_class Chrome_WidgetWin_1") || WinActive("ahk_class MozillaWindowClass")
    _t := _isBrowser ? 800 : 100
    ; Total debounce time = _t[this_call] + _t[last_call] to address interim focus changes
    if (A_PriorKey != A_ThisHotkey) || (A_TickCount - LastTaskbarScroll > _t) {
        LastTaskbarScroll := A_TickCount + _t
        Komorebi("mouse-follows-focus disable")
        Komorebi("cycle-workspace " . dir)
        ; ToDo: only re-enable if it was enabled before
        Komorebi("mouse-follows-focus enable")
    }
}


; ======================================================================
; Auxiliary Functions
; ======================================================================

MouseIsOver(WinTitle) {
    MouseGetPos(, , &Win)
    return WinExist(WinTitle . " ahk_id " . Win)
}
