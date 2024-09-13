/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
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
import MAVLink                              1.0

//-------------------------------------------------------------------------
//-- Temperature Indicator
Item {
    id:             _root
    anchors.top:    parent.top
    anchors.right:  parent.right
    width:          temperatureIndicatorRow.width

    property bool showIndicator: true
    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    Row {
        id:             temperatureIndicatorRow
        anchors.top:    parent.top
        anchors.right:  parent.right

        Loader {
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            sourceComponent:    temperatureVisual
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked: {
            mainWindow.showIndicatorPopup(_root, temperaturePopup)
        }
    }

    Component {
        id: temperatureVisual

        Row {
            anchors.top:    parent.top
            anchors.bottom: parent.bottom

            function getTemperatureColor() {
                if (!isNaN(_activeVehicle.temperature1.rawValue)) {
                    return qgcPal.text
                } else {
                    return qgcPal.colorRed // Error color if temperature is NaN or unavailable
                }
            }

            function getTemperatureText() {
                if (!isNaN(_activeVehicle.temperature1.rawValue)) {
                    return _activeVehicle.temperature1.rawValue.toFixed(1) + " °C"
                } else {
                    return "--.-- °C" // Placeholder text if temperature is unavailable
                }
            }

            QGCColoredImage {
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                width:              height
                sourceSize.width:   width
                source:             "/qmlimages/OAT.svg" // Use your black-and-white icon here
                fillMode:           Image.PreserveAspectFit
                color:              getTemperatureColor()
            }

            QGCLabel {
                text:                   getTemperatureText()
                font.pointSize:         ScreenTools.mediumFontPointSize
                color:                  getTemperatureColor()
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Component {
        id: temperaturePopup

        Rectangle {
            width:          mainLayout.width   + mainLayout.anchors.margins * 2
            height:         mainLayout.height  + mainLayout.anchors.margins * 2
            radius:         ScreenTools.defaultFontPixelHeight / 2
            color:          qgcPal.window
            border.color:   qgcPal.text

            ColumnLayout {
                id:                 mainLayout
                anchors.margins:    ScreenTools.defaultFontPixelWidth
                anchors.top:        parent.top
                anchors.right:      parent.right
                spacing:            ScreenTools.defaultFontPixelHeight

                QGCLabel {
                    Layout.alignment:   Qt.AlignCenter
                    text:               qsTr("Outside Air Temperature")
                    font.family:        ScreenTools.demiboldFontFamily
                }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel { text: qsTr("Temperature: ") }
                    QGCLabel { text: _activeVehicle.temperature1.rawValue.toFixed(1) + " °C" }
                }
            }
        }
    }
}
