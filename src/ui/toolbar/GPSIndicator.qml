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

//-------------------------------------------------------------------------
//-- GPS Indicator
Item {
    id:             _root
    width:          (gpsValuesColumn.x + gpsValuesColumn.width) * 1.1
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property bool showIndicator: true

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool _pulser: false // Switches on/off at 1Hz, used to flash elements on alert

    Component {
        id: gpsInfo

        Rectangle {
            width:  gpsCol.width   + ScreenTools.defaultFontPixelWidth  * 3
            height: gpsCol.height  + ScreenTools.defaultFontPixelHeight * 2
            radius: ScreenTools.defaultFontPixelHeight * 0.5
            color:  qgcPal.window
            border.color:   qgcPal.text

            Column {
                id:                 gpsCol
                spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                width:              Math.max(gpsGrid.width, gpsLabel.width)
                anchors.margins:    ScreenTools.defaultFontPixelHeight
                anchors.centerIn:   parent

                QGCLabel {
                    id:             gpsLabel
                    text:           (_activeVehicle && _activeVehicle.gps.count.value >= 0) ? qsTr("GPS Status") : qsTr("GPS Data Unavailable")
                    font.family:    ScreenTools.demiboldFontFamily
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: qgcPal.buttonText
                }

                GridLayout {
                    id:                 gpsGrid
                    visible:            (_activeVehicle && _activeVehicle.gps.count.value >= 0)
                    anchors.margins:    ScreenTools.defaultFontPixelHeight
                    columnSpacing:      ScreenTools.defaultFontPixelWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 2

                    QGCLabel {
                                            text: qsTr("GPS Count:")
                                            color: qgcPal.buttonText // Default color for pop-up
                                        }
                                        QGCLabel {
                                            text: _activeVehicle ? _activeVehicle.gps.count.valueString : qsTr("N/A", "No data to display")
                                            color: qgcPal.buttonText // Default color for pop-up
                                        }

                                        QGCLabel {
                                            text: qsTr("GPS Lock:")
                                            color: qgcPal.buttonText // Default color for pop-up
                                        }
                                        QGCLabel {
                                            text: _activeVehicle ? _activeVehicle.gps.lock.enumStringValue : qsTr("N/A", "No data to display")
                                            color: qgcPal.buttonText // Default color for pop-up
                                        }

                                        QGCLabel {
                                            text: qsTr("HDOP:")
                                            color: qgcPal.buttonText // Default color for pop-up
                                        }
                                        QGCLabel {
                                            text: _activeVehicle ? _activeVehicle.gps.hdop.valueString : qsTr("--.--", "No data to display")
                                            color: qgcPal.buttonText // Default color for pop-up
                                        }

                                        QGCLabel {
                                            text: qsTr("VDOP:")
                                            color: qgcPal.buttonText // Default color for pop-up
                                        }
                                        QGCLabel {
                                            text: _activeVehicle ? _activeVehicle.gps.vdop.valueString : qsTr("--.--", "No data to display")
                                            color: qgcPal.buttonText // Default color for pop-up
                                        }

                                        QGCLabel {
                                            text: qsTr("Course Over Ground:")
                                            color: qgcPal.buttonText // Default color for pop-up
                                        }
                                        QGCLabel {
                                            text: _activeVehicle ? _activeVehicle.gps.courseOverGround.valueString : qsTr("--.--", "No data to display")
                                            color: qgcPal.buttonText // Default color for pop-up
                                        }
                }
            }
        }
    }

    QGCColoredImage {
        id:                 gpsIcon
        width:              height
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        source:             "/qmlimages/Gps.svg"
        fillMode:           Image.PreserveAspectFit
        sourceSize.height:  height
        opacity:            (_activeVehicle && _activeVehicle.gps.count.value >= 0) ? 1 : 0.5
        color: getColorByHDOPOrEnum()
    }

    Column {
        id:                     gpsValuesColumn
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
        anchors.left:           gpsIcon.right

        QGCLabel {
            //anchors.horizontalCenter:   hdopValue.horizontalCenter
            //visible:                    _activeVehicle && !isNaN(_activeVehicle.gps.hdop.value)
            anchors.horizontalCenter:   gpsLock.horizontalCenter
            visible:                    _activeVehicle && _activeVehicle.gps.count.valueString !== ""
            color: getColorByHDOPOrEnum() // Change text color based on HDOP or Enum
            text:                       _activeVehicle ? _activeVehicle.gps.count.valueString : ""
        }

        QGCLabel {
                    id: gpsLock
                    visible: _activeVehicle && _activeVehicle.gps.lock.enumStringValue !== ""
                    color: getColorByHDOPOrEnum() // Change text color based on HDOP or Enum
                    text: getLockText()

                    function getLockText() {
                        if (!_activeVehicle) return ""
                        const lockEnum = _activeVehicle.gps.lock.enumIndex
                        if (lockEnum === 0 || lockEnum === 1) return "No Lock"
                        if (lockEnum === 2) return "2D Lock"
                        if (lockEnum === 3) return "3D Lock"
                        if (lockEnum === 4) return "3D DGPS"
                        if (lockEnum === 5 || lockEnum === 6) return "RTK"

                        return _activeVehicle.gps.lock.enumStringValue
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    mainWindow.showIndicatorPopup(_root, gpsInfo)
                }
            }

            Timer {
                    interval: 500; running: true; repeat: true
                    onTriggered: _pulser = !_pulser
                }

            function getColorByHDOPOrEnum() {
                if (!_activeVehicle) return qgcPal.buttonText;

                // Check HDOP value first
                const hdopValue = _activeVehicle.gps.hdop.value;
                if (hdopValue > 3) return _pulser ? "red" : qgcPal.buttonText;   // Pulse red if HDOP is above 3
                if (hdopValue > 2.5) return "orange";  // Orange if HDOP is above 2.5

                // If HDOP is good, check GPS lock enum status
                const lockEnum = _activeVehicle.gps.lock.enumIndex;
                if (lockEnum === 0 || lockEnum === 1) return _pulser ? "red" : qgcPal.buttonText; // Pulse red if no lock
                if (lockEnum === 2) return "orange";
                if (lockEnum === 3 || lockEnum === 4 || lockEnum === 5 || lockEnum === 6) return qgcPal.colorGreen;

                return qgcPal.buttonText; // Default color
            }
        }

