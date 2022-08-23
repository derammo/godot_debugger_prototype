# Debugger 'Thread List' UI prototype

This UI replaces the stack dump view in the non-threaded Debugger in the Godot Editor.

To test it, mash the buttons at the bottom of Main.tscn to send the various `signal`s that this UI element receives when running in ScriptEditorDebugger.

Click on the title bar all the way to the left to pop the context menu for column selection.  When running with https://github.com/godotengine/godot/pull/64369, this uses right mouse button context menu as is standard.

Click on the columns to sort by columns that support sorting.

Hover over anything for more info.

Click on the pin checkboxes to pin threads of interest to the top (so sorting doesn't make you lose your place.)
