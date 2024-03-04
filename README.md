# Komotray for v2 of Autohotkey
Some tweaks have been made to make the script more independant and not a wrapper, so it does not spawn komorebi by default nor does it include your Autohotkey bindings, but it does make it subscribe to the named pipe (komotray) on startup.

## Some quirks 
* The script icon won't update when using a hotkey to pause, clicking on the icon does however. [Possibly related](https://github.com/da-rth/yasb/issues/54)
* ~~If the current workspace has an app open, the icon will update if you switch to another workspace, but if the current workspace does not have an app currently open, and you swap to another inactive workspace, the workspace icon won't update. [Possibly related](https://github.com/da-rth/yasb/issues/131)~~ fixed in latest release of komorebi
* Scrolling on the taskbar does not work and will spit out an error, might be a syntax issue. However Alt+Scroll up or down works, The ScrollWorkspace function makes the icon switch almost instant, where as binding Alt+Scroll to the komorebic commands like: `!WheelUp::CycleWorkspace("next")` in the regular ahk config will make the icon updating inconsistant and slow.

## Possible future implementations
* Make the icon display Stacking information
