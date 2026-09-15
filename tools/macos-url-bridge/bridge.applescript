-- Transport-only bridge: forwards articulate:// URLs from macOS to the Articulate 360 Desktop App inside one Wine prefix.
-- It never logs, parses, or rewrites the URL.
on open location theURL
	if theURL does not start with "articulate://" then return
	if theURL contains "'" or theURL contains "\"" or theURL contains " " then return
	set prefixPath to (POSIX path of (path to home folder)) & "StorylineLab/prefixes/wine-dotnet48-noadmintask"
	set exePath to "C:\\Program Files\\Articulate\\360\\Desktop Application x64\\Articulate 360 Desktop App.exe"
	do shell script "WINEARCH=win64 WINEPREFIX=" & quoted form of prefixPath & " WINEDEBUG=-all /opt/local/bin/wine " & quoted form of exePath & " " & quoted form of theURL & " >/dev/null 2>&1 &"
end open location
on run
	display dialog "Articulate 360 URL bridge: this app only handles articulate:// links from the browser." buttons {"OK"} default button 1
end run
