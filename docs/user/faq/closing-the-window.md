---
title: Does closing the window quit LightZ?
description: On a Mac, closing the LightZ window with the red button or ⌘W quits the app, after it checks for running tasks and unsaved changes.
order: 30
verified: 0.14.0
---

On a Mac, yes. Closing LightZ's main window quits the app, the same as **LightZ** > **Quit LightZ** (⌘Q). Many Mac apps keep running with no window open; LightZ doesn't.

These all do the same thing when the main window is the one in front:

- the red close button in the top-left corner of the window
- **File** > **Close Window** (⌘W)
- **LightZ** > **Quit LightZ** (⌘Q)

## Does it ask first?

Only when something would be lost:

- A task that can be stopped is still running, such as an import or an export. LightZ asks **Quit while tasks are running?** Choose **Cancel** to keep working, or **Quit Anyway** to stop the task and quit.
- Some changes couldn't be written to disk, for example because a drive was unplugged. LightZ tries to save them again, and if that still fails it asks **Quit with unsaved changes?** Choose **Cancel** to stay, **Try Saving Again** once the drive is back, or **Quit Anyway** to give up those changes.

With nothing running and everything saved, the window closes and LightZ quits at once. As the app quits, LightZ saves your settings and closes your library. If either save fails, the error goes to the log file and the app quits anyway.

The second window (**Window** > **Second Window**) is different: its red button, or ⌘W while it is in front, closes only that window, and LightZ keeps running.

## Can I keep LightZ open without a window?

No. To get the window out of the way, minimize it with the yellow button or **Window** > **Minimize** (⌘M), or hide the app with **LightZ** > **Hide LightZ** (⌘H). Both keep your place and any running task going.
