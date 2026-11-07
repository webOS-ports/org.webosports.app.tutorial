# The Gesture Tutorial: QML only, so nothing is compiled. The LS2 role and
# permission files are made by the recipe (webos_app) from appinfo.json's
# requiredPermissions.
cmake_minimum_required(VERSION 3.16)
project(org.webosports.app.tutorial NONE)

include(webOS/webOS)
webos_modules_init(1 0 0 QUALIFIER RC3)
webos_component(1 0 0)

set(APP_DIR ${WEBOS_INSTALL_WEBOS_APPLICATIONSDIR}/org.webosports.app.tutorial)

install(DIRECTORY qml DESTINATION ${APP_DIR})
install(FILES appinfo.json icon.png icon-256x256.png DESTINATION ${APP_DIR})
