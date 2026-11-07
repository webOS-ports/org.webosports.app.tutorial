import QtQuick
import QtTest

import "../qml"

/*
 * TutorialService: what it asks of the system, call by call, against a
 * recorder in place of the bus.
 */
TestCase {
    id: test
    name: "TutorialService"

    QtObject {
        id: recorder
        property var calls: []
        // uri -> the reply, or "error" for a call that fails on the bus
        property var replies: ({})

        function call(uri, payload, onSuccess, onError) {
            calls.push({ uri: uri, params: JSON.parse(payload) });
            var reply = replies[uri];
            if (reply === "error")
                onError({ payload: JSON.stringify({ errorText: "no such service" }) });
            else
                onSuccess({ payload: JSON.stringify(reply || { returnValue: true }) });
        }
    }

    TutorialService {
        id: service
        bus: recorder
    }

    readonly property string prefs: "luna://com.webos.service.systemservice"
    readonly property string am: "luna://com.webos.service.activitymanager"

    function init() {
        recorder.calls = [];
        recorder.replies = {};
    }

    function uris() {
        return recorder.calls.map(function (c) { return c.uri; });
    }

    function test_reminderStart_data() {
        return [
            { tag: "afternoon", now: new Date(2026, 10, 7, 15, 30, 12), at: "2026-11-08 10:00:00" },
            { tag: "before ten", now: new Date(2026, 10, 7, 8, 5), at: "2026-11-08 10:00:00" },
            { tag: "end of the year", now: new Date(2026, 11, 31, 23, 59), at: "2027-01-01 10:00:00" },
            { tag: "end of February", now: new Date(2028, 1, 28, 12, 0), at: "2028-02-29 10:00:00" }
        ];
    }

    function test_reminderStart(data) {
        compare(service.reminderStart(data.now), data.at);
    }

    function test_markPending() {
        var finished = false;
        service.markPending(new Date(2026, 10, 7, 15, 30), function () { finished = true; });
        compare(uris(), [prefs + "/setPreferences", am + "/create"]);
        compare(recorder.calls[0].params, { needToRunTutorial: true });

        var create = recorder.calls[1].params;
        compare(create.start, true);
        compare(create.replace, true);
        compare(create.activity.name, "org.webosports.app.tutorial.reminder");
        compare(create.activity.type, { persist: true, foreground: true });
        compare(create.activity.schedule, { start: "2026-11-08 10:00:00", interval: "24h", precise: true, local: true, skip: true });
        compare(create.activity.callback, {
            method: "luna://com.webos.service.applicationmanager/launch",
            params: { id: "org.webosports.app.tutorial", params: { reminder: 1 } }
        });
        verify(finished, "done called");
    }

    function test_markDone() {
        var finished = false;
        service.markDone(function () { finished = true; });
        compare(uris(), [prefs + "/setPreferences", am + "/cancel"]);
        compare(recorder.calls[0].params, { needToRunTutorial: false, gestureTutorialDone: true });
        compare(recorder.calls[1].params, { activityName: "org.webosports.app.tutorial.reminder" });
        verify(finished, "done called");
    }

    // A cancel of an activity that is not there answers an error: still done.
    function test_markDone_noActivity() {
        recorder.replies[am + "/cancel"] = { returnValue: false, errorText: "Activity not found" };
        var finished = false;
        service.markDone(function () { finished = true; });
        verify(finished, "done called");
    }

    function test_remind_first() {
        recorder.replies[prefs + "/getPreferences"] = { returnValue: true, needToRunTutorial: true };
        var finished = false;
        service.remind(1, false, function () { finished = true; });
        compare(uris(), [prefs + "/getPreferences", "luna://com.webos.notification/createToast", am + "/complete"]);
        compare(recorder.calls[0].params, { keys: ["needToRunTutorial"] });

        var toast = recorder.calls[1].params;
        compare(toast.sourceId, "org.webosports.app.tutorial");
        compare(toast.onclick, { appId: "org.webosports.app.tutorial", params: {} });
        verify(toast.message.length > 0, "a message");
        compare(toast.iconUrl, "/usr/palm/applications/org.webosports.app.tutorial/icon.png");

        var complete = recorder.calls[2].params;
        compare(complete.activityName, "org.webosports.app.tutorial.reminder");
        compare(complete.restart, true);
        compare(complete.callback.params.params, { reminder: 2 });
        verify(finished, "done called");
    }

    function test_remind_last() {
        recorder.replies[prefs + "/getPreferences"] = { returnValue: true, needToRunTutorial: true };
        var finished = false;
        service.remind(3, false, function () { finished = true; });
        compare(uris(), [prefs + "/getPreferences", "luna://com.webos.notification/createToast",
                         prefs + "/setPreferences", am + "/cancel"]);
        compare(recorder.calls[2].params, { needToRunTutorial: false });
        verify(finished, "done called");
    }

    function test_remind_doneSince() {
        recorder.replies[prefs + "/getPreferences"] = { returnValue: true, needToRunTutorial: false };
        var finished = false;
        service.remind(2, false, function () { finished = true; });
        compare(uris(), [prefs + "/getPreferences", am + "/cancel"]);
        verify(finished, "done called");
    }

    // Never set (a reminder left over from an older install): no reminder.
    function test_remind_neverSet() {
        recorder.replies[prefs + "/getPreferences"] = { returnValue: true };
        service.remind(1, false, null);
        compare(uris(), [prefs + "/getPreferences", am + "/cancel"]);
    }

    // The tutorial is open: no notification, but the activity goes on.
    function test_remind_quiet() {
        recorder.replies[prefs + "/getPreferences"] = { returnValue: true, needToRunTutorial: true };
        service.remind(1, true, null);
        compare(uris(), [prefs + "/getPreferences", am + "/complete"]);
    }

    // A toast that did not come (notificationmgr: "UI is not yet ready",
    // the activity having fired during boot) is not counted - not even the
    // last one.
    function test_remind_toastRefused_data() {
        return [
            { tag: "error reply", reply: { returnValue: false, errorText: "UI is not yet ready" } },
            { tag: "no service", reply: "error" }
        ];
    }

    function test_remind_toastRefused(data) {
        recorder.replies[prefs + "/getPreferences"] = { returnValue: true, needToRunTutorial: true };
        recorder.replies["luna://com.webos.notification/createToast"] = data.reply;
        var finished = false;
        service.remind(3, false, function () { finished = true; });
        compare(uris(), [prefs + "/getPreferences", "luna://com.webos.notification/createToast", am + "/complete"]);
        compare(recorder.calls[2].params.restart, true);
        compare(recorder.calls[2].params.callback.params.params, { reminder: 3 }, "the same one again");
        verify(finished, "done called");
    }

    // A preference that cannot be read does not end the reminders.
    function test_remind_prefsUnreadable() {
        recorder.replies[prefs + "/getPreferences"] = "error";
        var finished = false;
        service.remind(1, false, function () { finished = true; });
        compare(uris(), [prefs + "/getPreferences", "luna://com.webos.notification/createToast", am + "/complete"]);
        verify(finished, "done called");
    }
}
