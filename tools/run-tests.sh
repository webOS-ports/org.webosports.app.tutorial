#!/bin/sh
# Runs the app's tests on the build host, with luneos-components' desktop
# stand-ins for the LuneOS modules:
#
#  - tests/tst_service.qml: what the app asks of the system (preferences,
#    the reminder activity, the notification), against a recorder.
#  - tests/tst_tutorial.qml: the lessons walked through.
#  - tests/tst_screens.qml: the app at every step, once per screen in
#    PROFILES - by default the MindPhone, the Q25, the TouchPad and the
#    FuriPhone FLX1s (radon) - each step saved as
#    build/test-output/ui/<profile>-<step>.png.
#
#   tools/run-tests.sh [path to luneos-components [qmltestrunner arguments]]
#
# The stand-ins read their profile (and with it the grid unit) once, as they
# load, and qmltestrunner takes no --profile, so each screen runs against a
# copy of LunaNext.Common whose default profile is that screen.
set -e
cd "$(dirname "$0")/.."
LC=${1:-../luneos-components}
[ $# -gt 0 ] && shift
if [ ! -d "$LC/test/imports" ]; then
    echo "luneos-components not found at $LC -- pass its path" >&2
    exit 1
fi
LC=$(cd "$LC" && pwd)
PROFILES=${PROFILES:-mindphone q25 tp radon}
CONF=$(mktemp -d)
trap 'rm -rf "$CONF"' EXIT
mkdir -p build/test-output/ui

run() {
    XDG_CONFIG_HOME=$CONF/config XDG_CACHE_HOME=$CONF/cache QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen} \
    QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS \
        ${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner} \
        -import "$LC/modules" -import "$LC/test/imports" "$@"
}

status=0
for t in tests/tst_service.qml tests/tst_tutorial.qml; do
    echo "--- $t"
    run -input "$t" "$@" || status=1
done

for profile in $PROFILES; do
    common=$CONF/profile-$profile/LunaNext/Common
    mkdir -p "$common"
    cp "$LC"/test/imports/LunaNext/Common/* "$common/"
    sed -i "s/^var defaultProfile = .*/var defaultProfile = \"$profile\";/" "$common/SettingsStub.js"
    if ! grep -q "^var defaultProfile = \"$profile\";" "$common/SettingsStub.js"; then
        echo "could not select profile $profile in SettingsStub.js" >&2
        status=1
        continue
    fi
    rm -rf "$CONF/config" "$CONF/cache"
    echo "--- tests/tst_screens.qml ($profile)"
    run -import "$CONF/profile-$profile" -input tests/tst_screens.qml "$@" || status=1
done
exit $status
