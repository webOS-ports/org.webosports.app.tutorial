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
import QtQuick.Controls 2.0
import QtQuick.Controls.LuneOS 2.0
import LunaNext.Common 0.1

/*
 * The lessons, one step at a time.
 *
 * Modelled on legacy webOS 2.x's Gesture Tutorial (com.palm.app.firstuse,
 * the back-tutorial-main scene), which had the user try the back gesture in
 * a pretend app and then the up gesture to Card View, saying so when a swipe
 * was the wrong one. Webos 3.0 on the TouchPad had no tutorial, only a
 * one-time "Dismissing Cards" note the first time a card went to Card View;
 * that is the last lesson here, and the one the tutorial ends with.
 *
 * Nothing here talks to the system. What it needs to know comes in:
 *  - gestureArea: the shell's gesture area is shown. When it is not, there
 *    is no back gesture at all (the shell's back is a swipe left along it),
 *    and Card View is a flick up from the bottom edge of the screen.
 *  - carded: the window is in Card View (the shell has minimised it).
 *  - back(): the shell's back gesture reached the window (as Escape).
 * and goes out as completed() (the last lesson was reached: the tutorial
 * counts as done) and quitRequested().
 */
FocusScope {
    id: tutorial

    property bool gestureArea: true
    property bool firstUse: false
    property bool carded: false

    readonly property var steps: gestureArea
        ? ["intro", "back", "backDone", "up", "cardView", "upDone", "more", "close"]
        : ["intro", "backInfo", "up", "cardView", "upDone", "more", "close"]
    property string step: "intro"
    readonly property int stepIndex: steps.indexOf(step)

    //! The back lesson: how many times the user has gone back (two to pass).
    property int backRounds: 0
    //! A word about the last try, when it was not the gesture asked for.
    property string feedback: ""

    signal completed()
    signal quitRequested()

    focus: true

    function next() {
        var i = stepIndex;
        if (i >= 0 && i < steps.length - 1)
            goTo(steps[i + 1]);
    }

    function goTo(name) {
        feedback = "";
        step = name;
        if (name === "back") {
            backRounds = 0;
            notes.highlight = 0;
            notes.page = "list";
        }
        if (name === "close")
            completed();
    }

    // The shell's back gesture.
    function back() {
        if (step !== "back")
            return;
        if (!notes.back()) {
            feedback = "That was the back gesture, but there is nothing to go back to yet. Open the highlighted note first.";
            return;
        }
        feedback = "";
        backRounds += 1;
        if (backRounds >= 2)
            goTo("backDone");
        else
            notes.highlight = 2;
    }

    Keys.onEscapePressed: (event) => { back(); event.accepted = true; }
    Keys.onBackPressed: (event) => { back(); event.accepted = true; }

    onCardedChanged: {
        if (carded) {
            if (step === "up")
                goTo("cardView");
            else if (step === "back")
                feedback = "That swipe went up, which opens Card View. For back, keep your finger moving sideways along the strip.";
        } else if (step === "cardView") {
            goTo("upDone");
        }
    }

    readonly property string title: {
        switch (step) {
        case "intro": return firstUse ? "Welcome to LuneOS" : "Gesture Tutorial";
        case "back":
        case "backInfo": return "Going back";
        case "backDone": return "That is back";
        case "up": return "Card View";
        case "cardView": return "This is Card View";
        case "upDone": return "Back in the app";
        case "more": return "A few more";
        case "close": return "Closing apps";
        }
        return "";
    }

    readonly property string body: {
        switch (step) {
        case "intro":
            return "LuneOS is driven by a few simple gestures. This short tutorial lets you try the ones you need every day. It takes about a minute.";
        case "back":
            if (notes.page === "note")
                return backRounds === 0
                    ? "To go back, swipe from right to left along the gesture area: the strip just below the screen."
                    : "And back once more: swipe from right to left along the gesture area.";
            return backRounds === 0 ? "Tap the highlighted note to open it."
                                    : "Well done. Now open the other highlighted note.";
        case "backInfo":
            return "The gesture area is switched off, so there is no back gesture: use the back button in each app. You can switch the gesture area on in Settings, under Appearance.";
        case "backDone":
            return "The back gesture takes you one step back, in every app. Next: Card View.";
        case "up":
            return gestureArea
                ? "Every open app is a card. To see them all, swipe up from the gesture area onto the screen."
                : "Every open app is a card. To see them all, flick up from the bottom edge of the screen.";
        case "cardView":
            return "Tap this card to open it again.";
        case "upDone":
            return gestureArea
                ? "Swiping up always takes you to Card View. Tapping the gesture area does too, and tapping it again opens the card."
                : "A flick up from the bottom edge always takes you to Card View.";
        case "more":
            return "";
        case "close":
            return carded ? "Now flick this card up, off the top of the screen."
                          : "To close an app, go to Card View and flick its card up, off the top of the screen. Close this tutorial that way now, or tap Done.";
        }
        return "";
    }

    readonly property var moreRows: {
        var rows = [
            "In Card View, swipe left or right to move between your cards.",
            "In Card View, swipe up once more for the launcher with all your apps.",
            "Tap the icons at the top right of the screen for the system menu."
        ];
        if (gestureArea)
            rows.push("Swipe from left to right along the gesture area to take a screenshot.");
        return rows;
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#223040" }
            GradientStop { position: 1.0; color: "#0a0d12" }
        }
    }

    // Where we are: one dot per step, after the welcome.
    Row {
        id: dots
        objectName: "progressDots"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Units.gu(2.4)
        anchors.leftMargin: Units.gu(2)
        spacing: Units.gu(0.8)
        visible: tutorial.step !== "intro" && !tutorial.carded

        Repeater {
            model: tutorial.steps.length - 1
            Rectangle {
                width: Units.gu(1)
                height: width
                radius: width / 2
                color: index < tutorial.stepIndex ? "#4db2ff" : "#56606c"
            }
        }
    }

    Text {
        id: quitLink
        objectName: "quitLink"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Units.gu(1.2)
        anchors.rightMargin: Units.gu(1)
        padding: Units.gu(1)
        visible: tutorial.step !== "intro" && tutorial.step !== "close" && !tutorial.carded
        text: "Quit"
        color: "#9fb0c0"
        font.pixelSize: FontUtils.sizeToPixels("medium")
        MouseArea {
            anchors.fill: parent
            onClicked: tutorial.quitRequested()
        }
    }

    Column {
        id: words
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: tutorial.carded ? Units.gu(8) : Units.gu(6)
        anchors.leftMargin: Units.gu(2.5)
        anchors.rightMargin: Units.gu(2.5)
        spacing: Units.gu(1.5)

        Text {
            id: titleText
            objectName: "title"
            width: parent.width
            wrapMode: Text.Wrap
            color: "white"
            // Read from Card View too, where the card is drawn much smaller.
            font.pixelSize: tutorial.carded ? Units.gu(6) : Units.gu(3.6)
            horizontalAlignment: tutorial.carded ? Text.AlignHCenter : Text.AlignLeft
            text: tutorial.title
        }

        Text {
            id: bodyText
            objectName: "body"
            width: parent.width
            wrapMode: Text.Wrap
            color: "#d6dde4"
            font.pixelSize: tutorial.carded ? Units.gu(4.4) : FontUtils.sizeToPixels("large")
            horizontalAlignment: tutorial.carded ? Text.AlignHCenter : Text.AlignLeft
            visible: text.length > 0
            text: tutorial.body
        }

        Text {
            id: feedbackText
            objectName: "feedback"
            width: parent.width
            wrapMode: Text.Wrap
            color: "#ffc266"
            font.pixelSize: FontUtils.sizeToPixels("medium")
            visible: text.length > 0 && !tutorial.carded
            text: tutorial.feedback
        }

        Repeater {
            model: tutorial.step === "more" ? tutorial.moreRows : []
            Row {
                width: words.width
                spacing: Units.gu(1.2)
                Rectangle {
                    width: Units.gu(1)
                    height: width
                    radius: width / 2
                    color: "#4db2ff"
                    y: Units.gu(0.8)
                }
                Text {
                    objectName: "moreRow" + index
                    width: parent.width - Units.gu(2.2)
                    wrapMode: Text.Wrap
                    color: "#d6dde4"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                    text: modelData
                }
            }
        }
    }

    MockNotes {
        id: notes
        objectName: "mockNotes"
        anchors.top: words.bottom
        anchors.topMargin: Units.gu(2)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - Units.gu(5), Units.gu(50))
        // Clear of the fingertip going along the foot of the window.
        height: Math.max(Units.gu(10), Math.min(Units.gu(26), tutorial.height - hint.reach - Units.gu(1.5) - y))
        visible: tutorial.step === "back"
        onMissed: tutorial.feedback = "Tap the highlighted note."
        onOpened: tutorial.feedback = ""
    }

    GestureHint {
        id: hint
        objectName: "gestureHint"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        edgeOnly: !tutorial.gestureArea
        direction: {
            if (tutorial.carded)
                return "none";
            if (tutorial.step === "back" && notes.page === "note")
                return "left";
            // Not on the last lesson: it would run through Done, and the
            // flick there is the card's, not the gesture area's.
            if (tutorial.step === "up")
                return "up";
            return "none";
        }
    }

    Row {
        id: buttons
        objectName: "buttons"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Units.gu(4)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Units.gu(2)
        visible: !tutorial.carded && (tutorial.step === "intro" || tutorial.step === "backDone"
                                     || tutorial.step === "backInfo" || tutorial.step === "upDone"
                                     || tutorial.step === "more" || tutorial.step === "close")

        readonly property real buttonWidth: Math.min(Units.gu(20), (tutorial.width - Units.gu(7)) / 2)

        Button {
            id: leftButton
            objectName: "leftButton"
            width: buttons.buttonWidth
            visible: tutorial.step === "intro"
            text: tutorial.firstUse ? "Skip" : "Close"
            LuneOSButton.mainColor: LuneOSButton.grayColor
            onClicked: tutorial.quitRequested()
        }

        Button {
            id: rightButton
            objectName: "rightButton"
            width: buttons.buttonWidth
            text: tutorial.step === "intro" ? "Start" : tutorial.step === "close" ? "Done" : "Next"
            LuneOSButton.mainColor: LuneOSButton.blueColor
            onClicked: {
                if (tutorial.step === "close")
                    tutorial.quitRequested();
                else
                    tutorial.next();
            }
        }
    }
}
