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
 * A pretend app to practise the back gesture on: a list of notes, and a
 * note. Tapping the highlighted note opens it; back() goes back to the
 * list. Legacy webOS did this with a pretend Photos app (albums, then
 * thumbnails, then a photo).
 */
Rectangle {
    id: notes

    //! "list" or "note"
    property string page: "list"
    //! The note to open, -1 for none.
    property int highlight: 0
    //! The note that is open.
    property int openIndex: -1

    readonly property var titles: ["Shopping list", "Ideas for the weekend", "Recipes to try"]
    readonly property var bodies: [
        "Bread, milk, coffee, apples and something for dinner.",
        "Walk along the river, visit the market, call Sam.",
        "Lentil soup, a lemon cake, and the curry from last time."
    ]

    signal opened(int index)
    signal missed(int index)

    function back() {
        if (page === "note") {
            page = "list";
            return true;
        }
        return false;
    }

    radius: Units.gu(1.2)
    color: "#f4f4f2"
    clip: true

    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Units.gu(5.5)
        radius: notes.radius
        color: "#3d4148"

        // Square off the header's lower corners.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.radius
            color: parent.color
        }

        Text {
            objectName: "mockTitle"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Units.gu(1.5)
            anchors.rightMargin: Units.gu(1.5)
            elide: Text.ElideRight
            color: "white"
            font.pixelSize: FontUtils.sizeToPixels("medium")
            font.bold: true
            text: notes.page === "note" ? notes.titles[notes.openIndex] : "Notes"
        }
    }

    Column {
        objectName: "mockList"
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: notes.page === "list"

        Repeater {
            model: notes.titles.length

            Item {
                id: row
                objectName: "mockRow" + index
                width: parent.width
                height: Units.gu(6)

                readonly property bool lit: index === notes.highlight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Units.gu(0.4)
                    radius: Units.gu(0.8)
                    color: row.lit ? "#d6ecff" : "transparent"
                    border.color: "#2b8fd6"
                    border.width: row.lit ? Units.gu(0.3) : 0

                    SequentialAnimation on opacity {
                        running: row.lit && notes.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.55; duration: 650 }
                        NumberAnimation { to: 1.0; duration: 650 }
                        onStopped: parent.opacity = 1
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Units.gu(1.5)
                    anchors.rightMargin: Units.gu(1.5)
                    elide: Text.ElideRight
                    color: "#222"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                    text: notes.titles[index]
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: "#d8d8d4"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (index === notes.highlight) {
                            notes.openIndex = index;
                            notes.page = "note";
                            notes.opened(index);
                        } else {
                            notes.missed(index);
                        }
                    }
                }
            }
        }
    }

    Text {
        objectName: "mockBody"
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Units.gu(1.5)
        visible: notes.page === "note"
        wrapMode: Text.Wrap
        color: "#222"
        font.pixelSize: FontUtils.sizeToPixels("medium")
        text: notes.openIndex >= 0 ? notes.bodies[notes.openIndex] : ""
    }
}
