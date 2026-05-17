/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "FlyViewSettings.h"

#include <QQmlEngine>
#include <QtQml>

FlyViewSettings::~FlyViewSettings() {
}

DECLARE_SETTINGGROUP(FlyView, "FlyView")

{
    qmlRegisterUncreatableType<FlyViewSettings>("QGroundControl.SettingsManager", 1, 0, "FlyViewSettings", "Reference only"); \
}

DECLARE_SETTINGSFACT(FlyViewSettings, guidedMinimumAltitude)
DECLARE_SETTINGSFACT(FlyViewSettings, guidedMaximumAltitude)
DECLARE_SETTINGSFACT(FlyViewSettings, showLogReplayStatusBar)
DECLARE_SETTINGSFACT(FlyViewSettings, alternateInstrumentPanel)
DECLARE_SETTINGSFACT(FlyViewSettings, showAdditionalIndicatorsCompass)
DECLARE_SETTINGSFACT(FlyViewSettings, lockNoseUpCompass)
DECLARE_SETTINGSFACT(FlyViewSettings, maxGoToLocationDistance)
DECLARE_SETTINGSFACT(FlyViewSettings, keepMapCenteredOnVehicle)
DECLARE_SETTINGSFACT(FlyViewSettings, showPositionSetpointLine)
DECLARE_SETTINGSFACT(FlyViewSettings, glideRingMode)
DECLARE_SETTINGSFACT(FlyViewSettings, glideRatio)
DECLARE_SETTINGSFACT(FlyViewSettings, showBatteryRangeRing)
DECLARE_SETTINGSFACT(FlyViewSettings, showSimpleCameraControl)
DECLARE_SETTINGSFACT(FlyViewSettings, showObstacleDistanceOverlay)
DECLARE_SETTINGSFACT(FlyViewSettings, updateHomePosition)
DECLARE_SETTINGSFACT(FlyViewSettings, enableCustomActions)
DECLARE_SETTINGSFACT(FlyViewSettings, customActionDefinitions)
DECLARE_SETTINGSFACT(FlyViewSettings, trajectoryLineDuration) //AA added
DECLARE_SETTINGSFACT(FlyViewSettings, showMannedTrafficIndicators) //AA Added
DECLARE_SETTINGSFACT(FlyViewSettings, horizontalMannedConflictDistance) //AA Added
DECLARE_SETTINGSFACT(FlyViewSettings, verticalMannedConflictDistance) //AA Added
DECLARE_SETTINGSFACT(FlyViewSettings, showUASTrafficIndicators) //AA Added
DECLARE_SETTINGSFACT(FlyViewSettings, horizontalUASConflictDistance) //AA Added
DECLARE_SETTINGSFACT(FlyViewSettings, verticalUASConflictDistance) //AA Added
