cmake_minimum_required(VERSION 3.16)
# usage: build/build-updater.sh configures this once per arch and merges the apps.
project(CctoolsUpdater LANGUAGES OBJC)

find_package(MavericksShipyard REQUIRED)
# spec: INGREDIENTS.md "How the updater is built" -- clang22, like everything else this repo compiles
set(MAVERICKS_REQUIRE_APPLECLANG OFF)
include(Mavericks)
include(MavericksSparkle)

mavericks_resolve_version(CCT_VERSION)

mavericks_add_updater_app(
  PRODUCT cctools
  PRODUCT_NAME "Mavericks cctools"
  ALLOW_GENERIC
  VERSION "${CCT_VERSION}"
  LOG_PREFIX "MavCctoolsUpdater"
  CONFIRM_TITLE "Mavericks cctools updated"
  CONFIRM_BODY "cctools and ld64 in /usr/local/mavergreen/cctools were updated."
  RELAUNCH_MARKER "/tmp/.mavericks-cctools-updater-relaunched"
)
