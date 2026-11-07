import QtQuick
import QtTest

import LunaNext.Common 0.1

/*
 * The app - qml/main.qml - on one screen per run (see tools/run-tests.sh),
 * at every step, each saved as build/test-output/ui/<profile>-<step>.png.
 * Checks that the words, the pretend notes and the buttons are inside the
 * window and clear of one another. Card View is the window's windowState
 * going to Qt.WindowMinimized, as the shell sets it. On a screen with a
 * notch and rounded corners (radon) the shots show the parts of the panel
 * that are not there in red.
 */
TestCase {
    id: test
    name: "Screens"
    when: windowShown

    readonly property string shotDir: decodeURIComponent(Qt.resolvedUrl("../build/test-output/ui").toString()
                                                         .replace(/^file:\/\//, ""))
    readonly property string profile: Settings.profileName
    property var app: null

    function init_data() {
        return [{ tag: Settings.profileName + " " + Settings.displayWidth + "x" + Settings.displayHeight }];
    }

    Component {
        id: panelMask
        // What the panel does not show: the cutouts and the rounded corners.
        Canvas {
            anchors.fill: parent
            z: 100000
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "rgba(255, 0, 0, 0.6)";
                var r = Settings.displayCornerRadii;
                var w = width, h = height;
                if (r.length === 4) {
                    ctx.beginPath();
                    ctx.moveTo(0, 0); ctx.lineTo(r[0], 0); ctx.arc(r[0], r[0], r[0], -Math.PI / 2, Math.PI, true); ctx.closePath();
                    ctx.moveTo(w, 0); ctx.lineTo(w, r[1]); ctx.arc(w - r[1], r[1], r[1], 0, -Math.PI / 2, true); ctx.closePath();
                    ctx.moveTo(w, h); ctx.lineTo(w - r[2], h); ctx.arc(w - r[2], h - r[2], r[2], Math.PI / 2, 0, true); ctx.closePath();
                    ctx.moveTo(0, h); ctx.lineTo(0, h - r[3]); ctx.arc(r[3], h - r[3], r[3], Math.PI, Math.PI / 2, true); ctx.closePath();
                    ctx.fill();
                }
                var cuts = Settings.displayCutouts;
                for (var i = 0; i < cuts.length; i++)
                    ctx.fillRect(cuts[i].x, cuts[i].y, cuts[i].width, cuts[i].height);
            }
        }
    }

    function shot(name) {
        wait(300);
        var mask = null;
        if (Settings.displayCutouts.length > 0 || Settings.displayCornerRadii.length > 0) {
            mask = panelMask.createObject(app.contentItem);
            mask.requestPaint();
            wait(100);
        }
        var done = false;
        var ok = app.contentItem.grabToImage(function(result) {
            result.saveToFile(shotDir + "/" + profile + "-" + name + ".png");
            done = true;
        });
        verify(ok, "grab " + name);
        tryVerify(function() { return done; }, 5000, "saved " + name);
        if (mask)
            mask.destroy();
    }

    function find(objectName) {
        function look(item) {
            if (!item)
                return null;
            if (item.objectName === objectName)
                return item;
            var kids = item.children || [];
            for (var i = 0; i < kids.length; i++) {
                var found = look(kids[i]);
                if (found)
                    return found;
            }
            return null;
        }
        var it = look(app.contentItem);
        verify(it !== null, "found " + objectName);
        return it;
    }

    function box(item) {
        return item.mapToItem(app.contentItem, 0, 0, item.width, item.height);
    }

    // Of some size, and wholly inside the window.
    function onScreen(item, what) {
        verify(item.width > 0 && item.height > 0, what + " has a size: " + item.width + "x" + item.height);
        var b = box(item);
        verify(b.x >= -0.5 && b.y >= -0.5
               && b.x + b.width <= app.width + 0.5 && b.y + b.height <= app.height + 0.5,
               what + " inside the " + app.width + "x" + app.height + " window: "
               + b.x + "," + b.y + " " + b.width + "x" + b.height);
        return b;
    }

    function above(upper, lower, what) {
        verify(upper.y + upper.height <= lower.y + 0.5,
               what + ": " + (upper.y + upper.height) + " over " + lower.y);
    }

    // The words at the top: inside, and above whatever is under them.
    function checkWords(step) {
        var title = find("title");
        var t = onScreen(title, step + " title");
        verify(title.contentWidth <= title.width + 0.5, step + " title fits across");
        var body = find("body");
        var lowest = t;
        if (body.visible) {
            lowest = onScreen(body, step + " body");
            above(t, lowest, step + " title over the body");
        }
        var feedback = find("feedback");
        if (feedback.visible) {
            var f = onScreen(feedback, step + " feedback");
            above(lowest, f, step + " body over the feedback");
            lowest = f;
        }
        var buttons = find("buttons");
        if (buttons.visible) {
            var b = onScreen(buttons, step + " buttons");
            above(lowest, b, step + " words over the buttons");
        }
        return lowest;
    }

    function init() {
        var component = Qt.createComponent(Qt.resolvedUrl("../qml/main.qml"));
        if (component.status === Component.Error)
            fail(component.errorString());
        app = component.createObject(null, { width: Settings.displayWidth, height: Settings.displayHeight });
        verify(app !== null, "main.qml made");
        tryVerify(function() { return app.visible; }, 2000, "the launch shows the window");
        compare(app.mode, "tutorial");
        app.requestActivate();
        waitForRendering(app.contentItem);
    }

    function cleanup() {
        if (app) {
            app.destroy();
            app = null;
        }
        wait(50);
    }

    function test_steps() {
        var t = app.tutorial;
        app.firstUse = true;
        shot("intro");
        checkWords("intro");

        t.goTo("back");
        shot("back-list");
        var words = checkWords("back");
        var notes = onScreen(find("mockNotes"), "the notes");
        above(words, notes, "the words over the notes");
        above(notes, box(find("gestureHintFinger")), "the notes over the fingertip's path");
        verify(notes.height >= Settings.displayHeight * 0.1, "the notes big enough to tap: " + notes.height);

        mouseClick(find("mockRow1"));
        shot("back-missed");
        checkWords("back missed");
        above(box(find("feedback")), box(find("mockNotes")), "the feedback over the notes");

        mouseClick(find("mockRow0"));
        shot("back-note");
        checkWords("back note");
        onScreen(find("gestureHintFinger"), "the finger");
        onScreen(find("gestureHintStrip"), "the strip");

        var names = ["backDone", "up", "upDone", "more", "close"];
        for (var i = 0; i < names.length; i++) {
            t.goTo(names[i]);
            shot(names[i]);
            var lowest = checkWords(names[i]);
            if (names[i] === "more") {
                for (var r = 0; r < t.moreRows.length; r++) {
                    var row = onScreen(find("moreRow" + r), "more row " + r);
                    above(lowest, row, "more row " + r + " in order");
                    lowest = row;
                }
                above(lowest, box(find("buttons")), "the rows over the buttons");
            }
        }

        // Card View: the shell minimises the window
        t.goTo("up");
        app.windowState = Qt.WindowMinimized;
        compare(t.step, "cardView");
        shot("cardView");
        checkWords("cardView");
        app.windowState = Qt.WindowMaximized;
        compare(t.step, "upDone");
    }

    function test_noGestureArea() {
        app.tutorial.gestureArea = false;
        app.tutorial.goTo("backInfo");
        shot("noga-backInfo");
        checkWords("backInfo");
        app.tutorial.goTo("up");
        shot("noga-up");
        checkWords("up without gesture area");
        onScreen(find("gestureHintStrip"), "the edge line");
    }
}
