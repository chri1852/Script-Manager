# Script-Manager
A Powershell / WinForms app to manage Powershell scripts. This app can hold a script, a description for it, and where the script itself is located. There is also a flag to mark the script as potentially dangerous. This app also allows the creation of playlists of scripts which will run each script once the last one has finished. This can be useful in the case where you have a number of smaller script that fix specific issues. Adding new scripts and playlists should be pretty self explainatory. Example scripts and playlists have been prepopulated to demonstrate.

To run just place in a folder, right click ScriptManager.ps1, and run with powershell.

It is assumed in this that all scripts are located in the same folder as ScriptManager.ps1, or in a sub folder.