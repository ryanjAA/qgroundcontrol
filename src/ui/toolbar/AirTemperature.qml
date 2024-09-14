/****************************************************************************
 *
 * (c) 2009-2023 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Layouts  1.11

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.MultiVehicleManager   1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Palette               1.0
import QGroundControl.SettingsManager       1.0
import MAVLink                              1.0

//-------------------------------------------------------------------------
//-- Air Temperature Indicator
Item {
    id:             _root
    anchors.top:    parent.top
    anchors.right:  parent.right
    width:          tempIcon.width * 1.1

    property bool showIndicator: true
    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _unitsSettings: QGroundControl.settingsManager.unitsSettings

    function convertTemperature(tempCelsius) {
        return _unitsSettings.temperatureUnits.value === UnitsSettings.TemperatureUnitsCelsius
                ? tempCelsius
                : (tempCelsius * 9/5) + 32; // Convert to Fahrenheit
    }

    function formatTemperature(value, label) {
        if (value !== undefined && value !== null && !isNaN(value)) {
            return convertTemperature(value).toFixed(1) + (_unitsSettings.temperatureUnits.value === UnitsSettings.TemperatureUnitsCelsius ? " °C" : " °F");
        } else {
            console.log(label + " temperature is undefined or invalid");  // Add log for debugging
            return "--.--";
        }
    }

    Component {
        id: tempInfoPopup
        Rectangle {
            width:  tempCol.width   + ScreenTools.defaultFontPixelWidth  * 3
            height: tempCol.height  + ScreenTools.defaultFontPixelHeight * 2
            radius: ScreenTools.defaultFontPixelHeight * 0.5
            color:  qgcPal.window
            border.color:   qgcPal.text
            Column {
                id:                 tempCol
                spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                width:              tempGrid.width
                anchors.margins:    ScreenTools.defaultFontPixelHeight
                anchors.centerIn:   parent

                GridLayout {
                    id:                 tempGrid
                    anchors.margins:    ScreenTools.defaultFontPixelHeight
                    columnSpacing:      ScreenTools.defaultFontPixelWidth
                    columns:            2
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        text: qsTr("External Probe:")
                    }

                    QGCLabel {
                        text: formatTemperature(_activeVehicle && _activeVehicle.hygrometer && _activeVehicle.hygrometer.hygroTemp
                            ? _activeVehicle.hygrometer.hygroTemp.rawValue
                            : undefined, "External Probe")
                    }

                    QGCLabel {
                        text: qsTr("Pitot Tube:")
                    }

                    QGCLabel {
                        text: formatTemperature(_activeVehicle && _activeVehicle.temperature && _activeVehicle.temperature.temperature1
                            ? _activeVehicle.temperature.temperature1.rawValue
                            : undefined, "Pitot Tube")
                    }
                }
            }
        }
    }

    QGCColoredImage {
        id:                 tempIcon
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        width:              height
        sourceSize.height:  height
        source:             "/qmlimages/OAT.svg"
        fillMode:           Image.PreserveAspectFit
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            mainWindow.showIndicatorPopup(_root, tempInfoPopup)
        }
    }
}
