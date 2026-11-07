Gesture Tutorial
================

Summary
-------
The LuneOS gesture tutorial: back, Card View and closing apps, tried out.

A card that lets the user try the gestures LuneOS is driven by, as the
legacy webOS 2.x first use tutorial did: the back gesture along the gesture
area (twice, in a mock notes list), the swipe up to Card View and the tap
back into the card, a few more gestures to read about, and closing an app
by flicking its card away. Without the gesture area (Settings, Appearance,
"Gesture Area" off) back is explained instead of practised, and Card View is
reached by swiping up from the bottom edge.

The Summary line above is read by webos_modules_init (webOS.cmake) as the
project summary, and configure stops without it: keep the heading and keep
it to one line.

Launch parameters
-----------------

 - `{}`: the tutorial, from the launcher.
 - `{"firstUse": true}`: the tutorial, started by the shell
   (luna-next-cardshell's `Connectors/GestureTutorial.qml`) once first use is
   over. The system preference `needToRunTutorial` is set and the reminder
   activity created at once, so leaving the tutorial any way at all leaves
   the reminders in place.
 - `{"reminder": n}`: the reminder activity fired for the n-th time. A
   notification is posted ("tap to start the Gesture Tutorial") and the app
   quits without showing a card; after the third, the reminders stop. If the
   tutorial is open already, the activity is only moved on.

Going through to the last page sets `needToRunTutorial` false and
`gestureTutorialDone` true - the shell then skips its own one-time
"Dismissing Cards" note - and cancels the reminders.

The reminder activity is `org.webosports.app.tutorial.reminder`: a precise
24 hour schedule from 10:00 local time the next morning, as legacy's
systemui TutorialDashboard. Its callback launches this app through SAM, a
call the hub makes on the app's behalf, with the app's own permissions.

Tests
-----

On the build host, with luneos-components checked out next to this
repository:

    tools/run-tests.sh [path to luneos-components]

runs

 - `tests/tst_service.qml`: what `TutorialService.qml` asks of the system,
   call by call, against a recorder in place of the bus;
 - `tests/tst_tutorial.qml`: the tutorial gone through, with and without the
   gesture area, and quit;
 - `tests/tst_screens.qml`: every step at each screen in `PROFILES` - by
   default `mindphone` (480x800), `q25` (720x720), `tp` (1024x768) and
   `radon` (720x1600) - checking that text, notes, the gesture hint and the
   buttons are inside the window and clear of each other. Each step is saved
   as `build/test-output/ui/<profile>-<step>.png`.
