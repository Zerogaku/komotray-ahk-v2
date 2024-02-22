;;  _  _____  __  __  ___  ____   ___  
;; | |/ / _ \|  \/  |/ _ \|  _ \ / _ \ 
;; | ' / | | | |\/| | | | | | | | | | |
;; | . \ |_| | |  | | |_| | |_| | |_| |
;; |_|\_\___/|_|  |_|\___/|____/ \___/ 
;;                                     

;MsgBox "Currently running Komodo"

#Include lib\JSONGO\jsongo.v2.ahk
#Include lib\CJSON\JSON.ahk


global IconPath := A_ScriptDir . "/assets/icons/"
global KomorebiConfig := "C:\Users\Null\komorebi.json"
IconState := -1
global Screen := 0

if (ProcessExist("komorebi.exe")) {
    StartKomorebi(false)
}

PipeName := "komodo"
PipePath := "\\.\pipe\" . PipeName
OpenMode := 0x01  ; access_inbound
PipeMode := 0x04 | 0x02 | 0x01  ; type_message | readmode_message | nowait
BufferSize := 64 * 1024


; create pipe with api
;Pipe := DllCall("CreateNamedPipe", "Str", PipePath, "UInt", OpenMode, "UInt", PipeMode, "UInt", 1, "UInt", BufferSize, "UInt", BufferSize, "UInt", 0, "Ptr", 0, "Ptr")
; Create pipe with API, ensuring creation only if it doesn't exist
Pipe := DllCall("CreateNamedPipe", "Str", PipePath, "UInt", OpenMode,
                "UInt", PipeMode, "UInt", 1, "UInt", BufferSize, "UInt", BufferSize,
                "UInt", 0, "Ptr", 0, "Ptr")

if (Pipe = 0) {
    MsgBox "Error creating named pipe: " %A_LastError%
    ExitApp
}

;; log
;TrayTip "log: " . Pipe, "CreatedNamedPipe", 16
;SetTimer HideTrayTip, -3000
;HideTrayTip() {
;    TrayTip
;}

;subscribe to komodo

Komorebi("subscribe " . PipeName)

DllCall("ConnectNamedPipe", "Ptr", Pipe, "Ptr", 0) ; set PipeMode = nowait to avoid getting stuck when paused

;TrayTip "log: " . varTest, "ConnectedNamedPipe", 16
;SetTimer HideTrayTip, -3000
;HideTrayTip() {
;    TrayTip
;}


;Komorebi(arg) {
;    RunWait("komorebic.exe " . arg, , "Hide")
;}

BytesToRead := 0
Bytes:= 0
Loop {

    ExitCode := DllCall("PeekNamedPipe", "Ptr", Pipe, "Ptr", 0, "UInt", 1, "Ptr", 0, "UintP", &BytesToRead, "Ptr", 0)
    ; TrayTip "log: " . ExitCode, "PeekNamedPipe", 16
    ; SetTimer HideTrayTip, -3000
    ; HideTrayTip() {
    ;     TrayTip
    ; }

    if (!ExitCode || !BytesToRead) {
        Sleep 50
        Continue
    }

    DllCall("ReadFile", "Ptr", Pipe, "Str", &Data, "UInt", BufferSize, "PtrP", &Bytes, "Ptr", 0)

    if (Bytes <= 1) {
        Continue
    }


    State := JSON.Load(StrGet(Data, Bytes, "UTF-8")).state
    Paused := State.is_paused
    Screen := State.Monitors.focused
    ScreenQ := State.Monitors.elements[Screen + 1]
    Workspace := ScreenQ.workspaces.focused
    WorkspaceQ := ScreenQ.workspaces.elements[Workspace + 1]

    ; Update tray icon
    if (Paused | Screen << 1 | Workspace << 4 != IconState) {
        UpdateIcon(Paused, Screen, Workspace, ScreenQ.name, WorkspaceQ.name)
        IconState := Paused | Screen << 1 | Workspace << 4 ; use 3 bits for monitor (i.e. up to 8 monitors)
    }

}

Komorebi(arg) {
    RunWait("komorebic.exe " . arg, , "Hide")
}

UpdateIcon(paused, screen, workspace, screenName, workspaceName) {
    TrayTip workspaceName . " on " . screenName
    icon := IconPath . workspace + 1 . "-" . screen + 1 . ".ico"
    if (!paused && FileExist(icon)) {

        TraySetIcon icon
    }
    else {
        TraySetIcon IconPath . "pause.ico" ; also used as fallback
    }
}

StartKomorebi(reloadTray:=true) {
    Komorebi("stop")
    Komorebi("start -c " . KomorebiConfig . " --ahk")
    if (reloadTray) {
        ReloadTray()
    }
}

ReloadTray(*) {
    DllCall("CloseHandle", "Ptr", Pipe)
    Reload
}
