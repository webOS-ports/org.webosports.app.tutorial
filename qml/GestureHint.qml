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
import LunaNext.Common 0.1

/*
 * A fingertip showing a gesture, over a glow along the bottom of the window.
 *
 * Laid along the foot of the tutorial's window, which is where the shell's
 * gesture area is: the strip directly under the card. Legacy webOS drew the
 * same thing with prerendered frames (a glow over the gesture area, a hand
 * and swipe arrows); this is drawn here, so it scales with the screen.
 *
 *  - "left": along the strip, right to left - the back gesture.
 *  - "up": from the strip up onto the screen - Card View.
 *  - "none": nothing.
 *
 * edgeOnly: the device's gesture area is switched off, so the glow is a thin
 * line on the very edge of the screen, where a flick up starts instead.
 */
Item {
    id: hint

    property string direction: "none"
    property bool edgeOnly: false
    property color glowColor: "#4db2ff"
    readonly property bool running: direction !== "none" && visible

    //! How much of the foot of the window the gesture along the strip
    //! takes: the fingertip, wholly on the screen, centred on the strip.
    readonly property real reach: finger.height + Units.gu(0.5)

    height: Units.gu(16)

    // The gesture area, glowing.
    Rectangle {
        id: strip
        objectName: "gestureHintStrip"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        // Lifted so the fingertip, centred on it, stays on the screen. The
        // edge line stays on the very edge, where the flick starts.
        anchors.bottomMargin: hint.edgeOnly ? 0 : (finger.height - height) / 2 + Units.gu(0.5)
        width: parent.width * (hint.edgeOnly ? 1.0 : 0.7)
        height: hint.edgeOnly ? Units.gu(0.4) : Units.gu(0.8)
        radius: height / 2
        color: hint.glowColor
        visible: hint.direction !== "none"
        opacity: 0.35

        SequentialAnimation on opacity {
            running: hint.running
            loops: Animation.Infinite
            NumberAnimation { to: 0.9; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
        }
    }

    // The trail the finger leaves.
    Rectangle {
        id: trail
        visible: finger.visible
        color: hint.glowColor
        opacity: finger.opacity * 0.5
        radius: Units.gu(0.6)
        height: hint.direction === "up" ? Math.max(0, strip.y - finger.y) : Units.gu(1.2)
        width: hint.direction === "up" ? Units.gu(1.2) : Math.max(0, finger._startX - finger.x)
        x: hint.direction === "up" ? finger.x + finger.width / 2 - width / 2 : finger.x + finger.width / 2
        y: hint.direction === "up" ? finger.y + finger.height / 2 : finger.y + finger.height / 2 - height / 2
    }

    // The fingertip: a white dot with a soft ring.
    Rectangle {
        id: finger
        objectName: "gestureHintFinger"
        width: Units.gu(4)
        height: width
        radius: width / 2
        color: "transparent"
        border.color: "white"
        border.width: Units.gu(0.3)
        visible: hint.direction !== "none"
        opacity: 0

        readonly property real _startX: hint.width / 2 + strip.width / 2 - width
        readonly property real _endX: hint.width / 2 - strip.width / 2
        readonly property real _stripY: Math.min(strip.y + strip.height / 2 - height / 2, hint.height - height)
        readonly property real _topY: 0
        readonly property real _centreX: hint.width / 2 - width / 2

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.55
            height: width
            radius: width / 2
            color: "white"
        }

        x: hint.direction === "up" ? _centreX : _startX
        y: _stripY
    }

    SequentialAnimation {
        id: leftAnimation
        running: hint.running && hint.direction === "left"
        loops: Animation.Infinite
        // Both, every time: the up animation leaves the finger elsewhere.
        PropertyAction { target: finger; property: "x"; value: finger._startX }
        PropertyAction { target: finger; property: "y"; value: finger._stripY }
        NumberAnimation { target: finger; property: "opacity"; to: 1; duration: 250 }
        NumberAnimation { target: finger; property: "x"; to: finger._endX; duration: 900; easing.type: Easing.InOutQuad }
        NumberAnimation { target: finger; property: "opacity"; to: 0; duration: 250 }
        PauseAnimation { duration: 700 }
        onStopped: { finger.opacity = 0; finger.x = finger._startX; }
    }

    SequentialAnimation {
        id: upAnimation
        running: hint.running && hint.direction === "up"
        loops: Animation.Infinite
        PropertyAction { target: finger; property: "x"; value: finger._centreX }
        PropertyAction { target: finger; property: "y"; value: finger._stripY }
        NumberAnimation { target: finger; property: "opacity"; to: 1; duration: 250 }
        NumberAnimation { target: finger; property: "y"; to: finger._topY; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { target: finger; property: "opacity"; to: 0; duration: 250 }
        PauseAnimation { duration: 700 }
        onStopped: { finger.opacity = 0; finger.x = finger._centreX; finger.y = finger._stripY; }
    }
}
