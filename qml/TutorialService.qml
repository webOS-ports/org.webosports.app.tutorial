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
import LuneOS.Service 1.0

/*
 * What the tutorial keeps on the system: whether it still has to be done,
 * and the reminders for when it was not.
 *
 * Legacy webOS (2.x) did the same between the first use app and systemui:
 * a tutorial skipped during first use set the system preference
 * "needToRunTutorial", and systemui then showed "Check out the gesture
 * tutorial" each morning at 10:00 for three days, from an activitymanager
 * activity named "TutorialDashboard" (luna-systemui's
 * tutorialdashboard-assistant.js). Here the app does both itself:
 *
 *  - markPending(): the tutorial was started by the shell after first use.
 *    needToRunTutorial is set and the reminder activity created straight
 *    away, so that leaving the tutorial in any way - Skip, Quit, the card
 *    flicked away, the app killed - leaves the reminders in place. There is
 *    nothing to do on the way out, which is when there is no time for it.
 *  - markDone(): the tutorial was gone through. needToRunTutorial is
 *    cleared, gestureTutorialDone set (the shell then does not show its own
 *    "Dismissing Cards" hint, which the tutorial has just taught), and the
 *    reminders cancelled.
 *  - remind(n): the activity fired for the n-th time. A notification is
 *    posted, unless the tutorial was done in the meantime, and the activity
 *    is completed with a restart for the next day - or cancelled after the
 *    last one.
 *
 * The activity's callback launches this app with {"reminder": n}: a
 * callback is made as the app that created the activity, so it needs no
 * more than the app's own permissions.
 *
 * Everything goes through bus.call(uri, payload, onSuccess, onError), a
 * LunaService on the device; the tests put a recorder in its place.
 */
QtObject {
    id: service

    readonly property string appId: "org.webosports.app.tutorial"
    readonly property string activityName: appId + ".reminder"
    //! How many mornings the reminder comes, as legacy's three.
    property int reminderCount: 3
    //! The hour, local time, it comes at: legacy's 10:00.
    property int reminderHour: 10

    readonly property string _prefs: "luna://com.webos.service.systemservice"
    readonly property string _activities: "luna://com.webos.service.activitymanager"
    readonly property string _notifications: "luna://com.webos.notification"
    readonly property string _launch: "luna://com.webos.service.applicationmanager/launch"

    property var bus: LunaService {
        name: service.appId
        usePrivateBus: true
    }

    // done(ok, reply): ok is false for an error reply and for no reply.
    function _call(uri, params, done) {
        bus.call(uri, JSON.stringify(params),
                 function (message) {
                     var reply = {};
                     try {
                         reply = JSON.parse(message.payload);
                     } catch (e) {
                         reply = {};
                     }
                     if (done)
                         done(reply.returnValue !== false, reply);
                 },
                 function (message) {
                     console.warn("Tutorial: " + uri + " failed: " + (message ? message.payload : ""));
                     if (done)
                         done(false, {});
                 });
    }

    function _two(digits) {
        return (digits < 10 ? "0" : "") + digits;
    }

    /*
     * The first reminder: the next morning at reminderHour, local time, as
     * activitymanager takes it ("YYYY-MM-DD HH:MM:SS" with "local": true).
     */
    function reminderStart(now) {
        var at = new Date(now.getTime());
        at.setDate(at.getDate() + 1);
        at.setHours(reminderHour, 0, 0, 0);
        return at.getFullYear() + "-" + _two(at.getMonth() + 1) + "-" + _two(at.getDate())
                + " " + _two(at.getHours()) + ":00:00";
    }

    function _callback(count) {
        return {
            "method": _launch,
            "params": { "id": appId, "params": { "reminder": count } }
        };
    }

    function scheduleReminder(now, done) {
        _call(_activities + "/create", {
                  "start": true,
                  "replace": true,
                  "activity": {
                      "name": activityName,
                      "description": "Reminds of the gesture tutorial, which was not gone through",
                      "type": { "persist": true, "foreground": true },
                      // activitymanager takes a start with an interval
                      // only for a precise schedule (ActivityExtractor:
                      // "Unless precise time is specified, time intervals
                      // may not specify a start or end time"), which then
                      // fires at start + n * interval: 10:00 each day.
                      "schedule": {
                          "start": reminderStart(now),
                          "interval": "24h",
                          "precise": true,
                          "local": true,
                          "skip": true
                      },
                      "callback": _callback(1)
                  }
              }, done);
    }

    function cancelReminder(done) {
        // Answers an error when there is none, which is all right.
        _call(_activities + "/cancel", { "activityName": activityName }, done);
    }

    function markPending(now, done) {
        _call(_prefs + "/setPreferences", { "needToRunTutorial": true }, function () {
            scheduleReminder(now, done);
        });
    }

    function markDone(done) {
        _call(_prefs + "/setPreferences", { "needToRunTutorial": false, "gestureTutorialDone": true },
              function () {
                  cancelReminder(done);
              });
    }

    function postReminder(done) {
        _call(_notifications + "/createToast", {
                  "sourceId": appId,
                  "message": "Learn the LuneOS gestures: tap to start the Gesture Tutorial.",
                  "iconUrl": "/usr/palm/applications/" + appId + "/icon.png",
                  "onclick": { "appId": appId, "params": {} }
              }, done);
    }

    /*
     * The activity fired for the count-th time. quiet: the tutorial is open
     * already, so there is nothing to remind of; the activity still has to
     * be completed or cancelled, or it never fires again.
     */
    function remind(count, quiet, done) {
        _call(_prefs + "/getPreferences", { "keys": ["needToRunTutorial"] }, function (ok, reply) {
            // The activity is only there while the tutorial is pending, so a
            // preference that cannot be read is taken as still pending: one
            // bad answer must not end the reminders for good.
            if (ok && reply.needToRunTutorial !== true) {
                // Done since, or never asked for: no more reminders.
                cancelReminder(done);
                return;
            }
            // shown: the reminder reached the user. One that did not - the
            // activity fired while the shell was still starting, which
            // notificationmgr refuses with "UI is not yet ready" - is not
            // counted: tomorrow's comes with the same number.
            var finish = function (shown) {
                if (!shown) {
                    _call(_activities + "/complete", {
                              "activityName": activityName,
                              "restart": true,
                              "callback": _callback(count)
                          }, done);
                } else if (count >= reminderCount) {
                    // As legacy after the last day: stop asking.
                    _call(_prefs + "/setPreferences", { "needToRunTutorial": false }, function () {
                        cancelReminder(done);
                    });
                } else {
                    _call(_activities + "/complete", {
                              "activityName": activityName,
                              "restart": true,
                              "callback": _callback(count + 1)
                          }, done);
                }
            };
            if (quiet)
                finish(true);
            else
                postReminder(function (ok) {
                    finish(ok);
                });
        });
    }
}
