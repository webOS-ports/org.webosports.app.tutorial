import QtQuick
import QtTest

import "../qml"

/*
 * The lessons, walked through as a user would: taps on the buttons and the
 * pretend notes, Escape for the shell's back gesture, and carded for the
 * window going to Card View and back.
 */
TestCase {
    id: test
    name: "Tutorial"
    when: windowShown
    // A TestCase is not drawn unless told to: the buttons would not be visible.
    visible: true
    width: 480
    height: 800

    Component {
        id: tutorialComponent
        Tutorial {
            width: test.width
            height: test.height
        }
    }

    SignalSpy { id: completedSpy; signalName: "completed" }
    SignalSpy { id: quitSpy; signalName: "quitRequested" }

    property var t: null

    function make(props) {
        t = createTemporaryObject(tutorialComponent, test, props || {});
        verify(t !== null, "made");
        completedSpy.clear();
        quitSpy.clear();
        completedSpy.target = t;
        quitSpy.target = t;
        t.forceActiveFocus();
        waitForRendering(t);
        return t;
    }

    function find(objectName, from) {
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
        var it = look(from || t);
        verify(it !== null, "found " + objectName);
        return it;
    }

    function tap(objectName) {
        var it = find(objectName);
        verify(it.visible, objectName + " visible");
        mouseClick(it);
        wait(20);
    }

    function test_intro_data() {
        return [
            { tag: "first use", firstUse: true, title: "Welcome to LuneOS", left: "Skip" },
            { tag: "from the launcher", firstUse: false, title: "Gesture Tutorial", left: "Close" }
        ];
    }

    function test_intro(data) {
        make({ firstUse: data.firstUse });
        compare(t.step, "intro");
        compare(find("title").text, data.title);
        compare(find("leftButton").text, data.left);
        compare(find("rightButton").text, "Start");
        verify(!find("quitLink").visible, "no Quit on the welcome");
        tap("leftButton");
        compare(quitSpy.count, 1);
        compare(completedSpy.count, 0, "skipping is not doing");
    }

    // The whole tutorial, with the gesture area.
    function test_walkThrough() {
        make({ firstUse: true });
        tap("rightButton");
        compare(t.step, "back");
        var notes = find("mockNotes");
        verify(notes.visible, "the notes");
        compare(notes.page, "list");
        compare(find("gestureHint").direction, "none", "no gesture asked for yet");

        // A note that is not the one asked for
        tap("mockRow1");
        compare(notes.page, "list");
        compare(t.feedback, "Tap the highlighted note.");

        // Back with nothing to go back to
        t.back();
        verify(t.feedback.indexOf("nothing to go back to") >= 0, t.feedback);
        compare(t.backRounds, 0);

        tap("mockRow0");
        compare(notes.page, "note");
        compare(t.feedback, "");
        compare(find("gestureHint").direction, "left");
        verify(t.body.indexOf("right to left") >= 0, t.body);

        // The shell's back gesture, as the window gets it
        keyClick(Qt.Key_Escape);
        compare(notes.page, "list");
        compare(t.backRounds, 1);
        compare(notes.highlight, 2);
        verify(t.body.indexOf("other highlighted note") >= 0, t.body);

        tap("mockRow2");
        compare(notes.page, "note");
        // Up instead of back: said so, and the lesson stays
        t.carded = true;
        verify(t.feedback.indexOf("Card View") >= 0, t.feedback);
        t.carded = false;
        compare(t.step, "back");

        keyClick(Qt.Key_Escape);
        compare(t.step, "backDone");
        compare(find("rightButton").text, "Next");

        tap("rightButton");
        compare(t.step, "up");
        compare(find("gestureHint").direction, "up");
        // In the middle, though the back lesson left the finger at one end
        var hintItem = find("gestureHint");
        var finger = find("gestureHintFinger", hintItem);
        tryVerify(function () { return finger.opacity > 0.5; }, 3000, "the finger shown");
        compare(Math.round(finger.x + finger.width / 2), Math.round(hintItem.width / 2));
        verify(t.body.indexOf("gesture area") >= 0, t.body);
        verify(!find("buttons").visible, "no button: the gesture is the way on");
        // Escape outside the back lesson does nothing
        keyClick(Qt.Key_Escape);
        compare(t.step, "up");

        t.carded = true;
        compare(t.step, "cardView");
        compare(find("title").text, "This is Card View");
        compare(find("gestureHint").direction, "none");
        verify(!find("quitLink").visible, "nothing to tap in Card View but the card");
        t.carded = false;
        compare(t.step, "upDone");

        tap("rightButton");
        compare(t.step, "more");
        compare(t.moreRows.length, 4);
        verify(find("moreRow3").text.indexOf("screenshot") >= 0);

        compare(completedSpy.count, 0);
        tap("rightButton");
        compare(t.step, "close");
        compare(completedSpy.count, 1, "reaching the last lesson is doing the tutorial");
        compare(find("rightButton").text, "Done");
        verify(!find("quitLink").visible, "Done, not Quit");
        compare(find("gestureHint").direction, "none", "nothing running through Done");
        t.carded = true;
        verify(t.body.indexOf("flick this card") >= 0, t.body);
        t.carded = false;
        tap("rightButton");
        compare(quitSpy.count, 1);
        compare(completedSpy.count, 1);
    }

    // With the gesture area switched off there is no back gesture to teach.
    function test_noGestureArea() {
        make({ gestureArea: false });
        compare(t.steps.indexOf("back"), -1);
        tap("rightButton");
        compare(t.step, "backInfo");
        verify(t.body.indexOf("Settings, under Appearance") >= 0, t.body);
        keyClick(Qt.Key_Escape);
        compare(t.step, "backInfo");
        tap("rightButton");
        compare(t.step, "up");
        verify(t.body.indexOf("bottom edge") >= 0, t.body);
        verify(find("gestureHint").edgeOnly);
        t.carded = true;
        t.carded = false;
        compare(t.step, "upDone");
        verify(t.body.indexOf("gesture area") < 0, t.body);
        tap("rightButton");
        compare(t.moreRows.length, 3, "no screenshot swipe without the gesture area");
    }

    function test_quitHalfWay() {
        make({ firstUse: true });
        tap("rightButton");
        verify(find("quitLink").visible);
        tap("quitLink");
        compare(quitSpy.count, 1);
        compare(completedSpy.count, 0);
    }

    // Card View outside the up lesson: nothing moves on by itself.
    function test_cardedElsewhere() {
        make();
        t.carded = true;
        t.carded = false;
        compare(t.step, "intro");
        t.goTo("more");
        t.carded = true;
        t.carded = false;
        compare(t.step, "more");
    }

    // Back to the start of the back lesson when it is done again.
    function test_backLessonAgain() {
        make();
        t.goTo("back");
        tap("mockRow0");
        t.back();
        compare(t.backRounds, 1);
        t.goTo("back");
        compare(t.backRounds, 0);
        compare(find("mockNotes").highlight, 0);
        compare(find("mockNotes").page, "list");
    }
}
