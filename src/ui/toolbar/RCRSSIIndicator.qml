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
//-- RC RSSI Indicator
Item {
    id:             _root
    width:          rssiRow.width * 1.1
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property bool showIndicator: _activeVehicle.supportsRadio && QGroundControl.settingsManager.appSettings.showRcRssiIndicator.rawValue //AA RC RSSI - Only if checkbox is enabled


    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property bool   _useElrsChannel:        QGroundControl.settingsManager.appSettings.useElrsRssiChannel
                                                ? QGroundControl.settingsManager.appSettings.useElrsRssiChannel.rawValue
                                                : false

    //-- ELRS: ch16 = RSSI, ch15 = LQ, scaled 1000-2000us -> 0-100%
    property real   _ch16Raw:               (_activeVehicle && _useElrsChannel)
                                            ? _activeVehicle.rcChannel16 : 0
    property real   _ch15Raw:               (_activeVehicle && _useElrsChannel)
                                            ? _activeVehicle.rcChannel15 : 0
    property int    _elrsRSSI:              Math.min(100, Math.max(0, Math.round((_ch16Raw - 1000) / 10)))

    property int    _elrsLQ:                Math.min(100, Math.max(0, Math.round((_ch15Raw - 1000) / 10)))


    //-- Unified RSSI value: use ch16 when ELRS mode enabled, otherwise normal rcRSSI
    property int    _effectiveRSSI:         _useElrsChannel ? _elrsRSSI : (_activeVehicle ? _activeVehicle.rcRSSI : 0)
    property var    _rcRSSIWarning:         QGroundControl.settingsManager.appSettings.rcRSSIWarning
    property var    _rcRSSIAlert:           QGroundControl.settingsManager.appSettings.rcRSSIAlert
    property bool   _rcpulser:              false
    property bool _rcDataFresh:     false
    property bool _rcSignalHealthy: _activeVehicle
                                    ? (_activeVehicle.sensorsHealthBits & 65536)
                                    : false


   //-- Availability: ELRS mode just needs ch16 in range; normal mode uses existing logic
    property bool _rcRSSIAvailable: _activeVehicle
                                    ? (_useElrsChannel
                                       ? (_rcSignalHealthy && _ch16Raw >= 1000 && _ch16Raw <= 2000)
                                       : (_activeVehicle.rcRSSI > 0 && _activeVehicle.rcRSSI <= 100))
                                    : false

    Timer {
        id:         rcStalenessTimer
        interval:   2000    // 2 seconds - at 25Hz we should get a packet every 40ms
        running:    _useElrsChannel && _activeVehicle
        repeat:     false
        onTriggered: _rcDataFresh = false
    }

    Connections {
        target: _activeVehicle ? _activeVehicle : null
        onRcChannel16Changed: {
            _rcDataFresh = true
            rcStalenessTimer.restart()
        }
    }

    function linkColor() {
        if (!_activeVehicle) {
            return qgcPal.buttonText;
        } else if (!_rcRSSIAvailable) {
                    // RC lost - flash red
                    return _rcpulser ? "red" : qgcPal.buttonText;
        } else if (_effectiveRSSI > _rcRSSIWarning.rawValue) {
            return "green";
        } else if (_effectiveRSSI > _rcRSSIAlert.rawValue) {
            return "orange";
        } else {
            return _rcpulser ? "red" : qgcPal.buttonText;
        }
    }

    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: _rcpulser = !_rcpulser
    }

    Component {
        id: rcRSSIInfo

        Rectangle {
            width:  rcrssiCol.width   + ScreenTools.defaultFontPixelWidth  * 3
            height: rcrssiCol.height  + ScreenTools.defaultFontPixelHeight * 2
            radius: ScreenTools.defaultFontPixelHeight * 0.5
            color:  qgcPal.window
            border.color:   qgcPal.text

            Column {
                id:                 rcrssiCol
                spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                width:              Math.max(rcrssiGrid.width, rssiLabel.width)
                anchors.margins:    ScreenTools.defaultFontPixelHeight
                anchors.centerIn:   parent

                QGCLabel {
                    id:             rssiLabel
                    text:           _activeVehicle
                                                            ? (_rcRSSIAvailable
                                                                ? (_useElrsChannel
                                                                    ? qsTr("RC Signal Strength")
                                                                    : qsTr("RC Signal Strength Status"))
                                                                : qsTr("RC Signal Strength Unavailable"))
                                                            : qsTr("N/A", "No data available")
                    font.family:    ScreenTools.demiboldFontFamily
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                /*
                                QGCLabel { visible: _useElrsChannel; text: "fresh: " + _rcDataFresh }
                                QGCLabel { visible: _useElrsChannel; text: "healthy: " + _rcSignalHealthy }
                                QGCLabel { visible: _useElrsChannel; text: "ch16: " + _ch16Raw }
                                QGCLabel { visible: _useElrsChannel; text: "healthBits: " + _activeVehicle.sensorsHealthBits }
                                QGCLabel { visible: _useElrsChannel; text: "enabledBits: " + _activeVehicle.sensorsEnabledBits }
                */

                GridLayout {
                    id:                 rcrssiGrid
                    visible:            _rcRSSIAvailable
                    anchors.margins:    ScreenTools.defaultFontPixelHeight
                    columnSpacing:      ScreenTools.defaultFontPixelWidth
                    columns:            2
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel { text: qsTr("RSSI:") }
                    QGCLabel { text: _activeVehicle ? (_effectiveRSSI + "%") : "0%" }

                                        QGCLabel { visible: _useElrsChannel; text: qsTr("Link Quality:") }
                                        QGCLabel { visible: _useElrsChannel; text: _elrsLQ + "%" }

                }
            }
        }
    }

    Row {
        id:             rssiRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth
        visible:        showIndicator // Show or hide based on the checkbox

        QGCColoredImage {
            width:              height
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            sourceSize.height:  height
            source:             "/qmlimages/RC.svg"
            fillMode:           Image.PreserveAspectFit
            opacity:            _rcRSSIAvailable ? 1 : 1
            color:              linkColor()
        }

        SignalStrength {
            anchors.verticalCenter: parent.verticalCenter
            size:                   parent.height * 0.5
            percent:                _rcRSSIAvailable ? _effectiveRSSI : 0
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked: {
            mainWindow.showIndicatorPopup(_root, rcRSSIInfo)
        }
    }
    //DEBUG FOR ELRS RSSI
        /*Component.onCompleted: {
            console.log("useElrsChannel:", _useElrsChannel)
            console.log("rcRSSI:", _activeVehicle ? _activeVehicle.rcRSSI : "no vehicle")
            console.log("rcChannel16:", _activeVehicle ? _activeVehicle.rcChannel16 : "no vehicle")
            console.log("rcRSSIAvailable:", _rcRSSIAvailable)
            console.log("effectiveRSSI:", _effectiveRSSI)
        }

        Connections {
            target: QGroundControl.multiVehicleManager
            onActiveVehicleChanged: {
                console.log("Vehicle connected - rcChannel16:", _activeVehicle ? _activeVehicle.rcChannel16 : "no vehicle")
                console.log("rcRSSIAvailable:", _rcRSSIAvailable)
                console.log("effectiveRSSI:", _effectiveRSSI)
            }
    }*/
    Connections {
        target: QGroundControl.multiVehicleManager
        onActiveVehicleChanged: {
            if (_activeVehicle && _useElrsChannel) {
                _rcDataFresh = true
                rcStalenessTimer.restart()
            }
        }
    }
    Component.onCompleted: {
        if (_activeVehicle && _useElrsChannel) {
            _rcDataFresh = true
            rcStalenessTimer.restart()
        }
    }
}
