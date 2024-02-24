# Komotray for v2 of Autohotkey
Some tweaks have been made to make the script more independant (not a wrapper), so it does not spawn komorebi by default nor does it include your Autohotkey bindings, but it does make it subscribe to the named pipe (komotray)

## some quirks 
- The script icon won't update when using a hotkey, clicking on the icon does however.
- switching workspaces won't always update the icon, but opening a window in said workspace will. A common scenario is if you jump from workspace 1 to any other workspace, the icon will update but when switching to another inactive worksace from that point the script it won't update the icon.   
To be more specific, if the workspace has an app open the icon will update if you choose another workspace, but if said workspace does not have an app currently open, and you swap to another inactive workspace, the workspace won't update.
- Scrolling on the taskbar does not work and will spit out an error, might be a syntax issue. However Alt+Scroll up or down works, The ScrollWorkspace function makes the icon switch almost instant, where as binding Alt+Scroll to the komorebic commands like: `!WheelUp::CycleWorkspace("next")` in the regular ahk config will make the icon updating inconsistant and slow.

## Possible implementations
- Make the icon display Stacking information
