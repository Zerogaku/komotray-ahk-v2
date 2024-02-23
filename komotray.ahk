;;   **   **   *******   ****     ****   *******   ********** *******       **     **    **
;;  /**  **   **/////** /**/**   **/**  **/////** /////**/// /**////**     ****   //**  ** 
;;  /** **   **     //**/**//** ** /** **     //**    /**    /**   /**    **//**   //****  
;;  /****   /**      /**/** //***  /**/**      /**    /**    /*******    **  //**   //**   
;;  /**/**  /**      /**/**  //*   /**/**      /**    /**    /**///**   **********   /**   
;;  /**//** //**     ** /**   /    /**//**     **     /**    /**  //** /**//////**   /**   
;;  /** //** //*******  /**        /** //*******      /**    /**   //**/**     /**   /**   
;;  //   //   ///////   //         //   ///////       //     //     // //      //    //    

;MsgBox "Currently running Komodo"

#Requires AutoHotkey v2.0
#SingleInstance Force

;#Include lib\JSONGO\jsongo.v2.ahk
#Include lib\CJSON\JSON.ahk

global IconPath := A_ScriptDir . "/assets/icons/"
global KomorebiConfig := "C:\Users\Null\komorebi.json"


; Set up tray menu
; Menu, Tray, NoStandard
; Menu, Tray, add, Pause Komorebi, PauseKomorebi
; Menu, Tray, add, Restart Komorebi, StartKomorebi
; Menu, Tray, add  ; separator line
; Menu, Tray, add, Reload Tray, ReloadTray
; Menu, Tray, add, Exit Tray, ExitTray

A_TrayMenu.Delete()
A_TrayMenu.Add("Pause Komorebi", PauseKomorebi)
A_TrayMenu.Add("Restart Komorebi", StartKomorebi)
A_TrayMenu.Add()
A_TrayMenu.Add("Reload Tray", ReloadTray)
A_TrayMenu.Add("Exit tray", ExitTray)

IconState := -1
global Screen := 0
global LastTaskbarScroll := 0

;if (ProcessExist("komorebi.exe")) {
;    StartKomorebi(false)
;}

PipeName := "komotray"
PipePath := "\\.\pipe\" . PipeName
OpenMode := 0x01  ; access_inbound
PipeMode := 0x04 | 0x02 | 0x01  ; type_message | readmode_message | nowait
BufferSize := 64 * 1024

; create pipe with api
Pipe := DllCall("CreateNamedPipe", "Str", PipePath, "UInt", OpenMode,
                "UInt", PipeMode, "UInt", 1, "UInt", BufferSize, "UInt", BufferSize,
                "UInt", 0, "Ptr", 0, "Ptr")
;subscribe to komodo
if (Pipe = -1) {
    MsgBox "CreateNamedPipe: " A_LastError
    ExitTray()
}

Komorebi("subscribe " . PipeName)
DllCall("ConnectNamedPipe", "Ptr", Pipe, "Ptr", 0) ; set PipeMode = nowait to avoid getting stuck when paused


BytesToRead := 0
Bytes:= 0
Loop {
    ExitCode := DllCall("PeekNamedPipe", "Ptr", Pipe, "Ptr", 0, "UInt", 1, "Ptr", 0, "UintP", BytesToRead, "Ptr", 0)

    if (!ExitCode || !BytesToRead) {
        Sleep 50
        continue
    }

    ; Data := Buffer(BufferSize, 0)
    VarSetStrCapacity(&Data, BufferSize)
    DllCall("ReadFile", "Ptr", Pipe, "Str", Data, "UInt", BufferSize, "UintP", Bytes, "Ptr", 0)

    if (Bytes <= 1) {
        continue
    }

    State := JSON.Load(StrGet(&Data, Bytes, "UTF-8")).state
    Paused := State.is_paused
    Screen := State.monitors.focused
    ScreenQ := State.monitors.elements[Screen + 1]
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
