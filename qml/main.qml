/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.6
import Eos.Window 0.1
import LunaNext.Common 0.1
import LuneOS.Components 1.0
import LuneOS.System 1.0

/*
 * The Gesture Tutorial.
 *
 * Launched three ways:
 *  - {"firstUse": true}: by the shell, once first use is over. The tutorial
 *    is then pending until it is gone through: see TutorialService.
 *  - {} (or anything else): from the launcher, or from a reminder's
 *    notification.
 *  - {"reminder": n}: by its own reminder activity. No window: a
 *    notification is posted, the activity put right for the next day, and
 *    the app quits.
 *
 * qml-runner hands the parameters of the first launch over as the "params"
 * context property, before the window exists; the window's launchParams
 * only take them once it is on screen (AppLoader::setLaunchParams needs a
 * native window), which a reminder never is. Relaunches come through
 * LaunchParams.
 */
WebOSWindow {
    id: window

    width: Settings.displayWidth
    height: Settings.displayHeight
    windowType: "_WEBOS_WINDOW_TYPE_CARD"
    title: "Gesture Tutorial"
    color: "#0a0d12"
    visible: false

    //! "", "tutorial" or "reminder"
    property string mode: ""
    property bool firstUse: false
    //! For the tests: what "now" is when the reminders are scheduled.
    property var clock: function () { return new Date(); }

    readonly property bool carded: windowState === Qt.WindowMinimized

    property alias service: tutorialService
    property alias tutorial: lessons

    TutorialService {
        id: tutorialService
    }

    // The shell's own setting: no gesture area, no back gesture.
    Tweak {
        id: gestureAreaTweak
        owner: "luna-next-cardshell"
        serviceName: "org.webosports.app.tutorial"
        key: "showGestureArea"
        defaultValue: true
    }

    LaunchParams {
        window: window
        onLaunched: (params) => window.handleLaunch(params)
    }

    function handleLaunch(params) {
        params = params || {};
        if (typeof params.reminder === "number") {
            if (mode === "tutorial") {
                // Open already: keep the activity going, say nothing.
                tutorialService.remind(params.reminder, true, null);
                return;
            }
            mode = "reminder";
            quitFailsafe.start();
            tutorialService.remind(params.reminder, false, function () { Qt.quit(); });
            return;
        }
        if (params.firstUse === true)
            firstUse = true;
        startTutorial();
    }

    function startTutorial() {
        if (mode !== "tutorial") {
            mode = "tutorial";
            quitFailsafe.stop();
            if (firstUse)
                tutorialService.markPending(clock(), null);
        }
        window.show();
        window.visible = true;
        window.requestActivate();
        lessons.forceActiveFocus();
    }

    // A reminder's calls answer in well under a second; this is for a bus
    // that does not answer at all.
    Timer {
        id: quitFailsafe
        interval: 10000
        onTriggered: Qt.quit()
    }

    // The shell relaunching a reminder instance (its notification tapped
    // while it was still finishing) shows the window by itself.
    onVisibleChanged: if (visible && mode === "reminder") startTutorial()

    Component.onCompleted: {
        var initial = (typeof params !== "undefined" && params) ? params : {};
        handleLaunch(JSON.parse(JSON.stringify(initial)));
    }

    Tutorial {
        id: lessons
        objectName: "tutorial"
        anchors.fill: parent
        gestureArea: gestureAreaTweak.value !== false
        firstUse: window.firstUse
        carded: window.carded

        onCompleted: tutorialService.markDone(null)
        // As the first use app ends: the card goes with the process.
        onQuitRequested: Qt.quit()
    }
}
