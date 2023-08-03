import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Dialogs  1.2
import QtQuick.Layouts  1.2

import QGroundControl               1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controllers   1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0

Rectangle {
    height:             _heightTotal
    color:              Qt.rgba(0.0,0.0,0.0,0.25)
    visible:            true

    property int _heightTotal: mainlabel.height
                               +actTracker.height+firstRow.height
                               +primTracker.height+secondRow.height
                               +trackerROI.height+thirdRow.height+(_margins*8)

    QGCLabel {
        id:                 mainlabel
        text:               qsTr("TRACK")
        anchors.margins:    ScreenTools.isMobile ? _margins * 1.6 : _margins
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.largeFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        parent.top
        height:             ScreenTools.defaultFontPixelHeight
        color:              "white"
    }

    QGCLabel {
        id:                 actTracker
        text:               qsTr("Active Tracker")
        anchors.margins:    _margins
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.isMobile? point_size : ScreenTools.mediumFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        mainlabel.bottom
        height:             ScreenTools.smallFontPointSize
        color:              "white"
    }

    RowLayout {
        id:                         firstRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                actTracker.bottom
        anchors.margins:            _margins
        spacing:                    5
        visible:                    true

            QGCRadioButton {
                font.pointSize: ScreenTools.smallFontPointSize
                text:           qsTr("0")
                checked:        true
                onClicked:      joystickManager.cameraManagement.setSysActiveTrackerCommand(0);
            }
            QGCRadioButton {
                font.pointSize: ScreenTools.smallFontPointSize
                text:           qsTr("1")
                onClicked:      joystickManager.cameraManagement.setSysActiveTrackerCommand(1);
            }

            QGCRadioButton {
                font.pointSize: ScreenTools.smallFontPointSize
                text:           qsTr("2")
                onClicked:      joystickManager.cameraManagement.setSysActiveTrackerCommand(2);
            }
            QGCRadioButton {
                font.pointSize: ScreenTools.smallFontPointSize
                text:           qsTr("3")
                onClicked:      joystickManager.cameraManagement.setSysActiveTrackerCommand(3);
            }
            QGCRadioButton {
                font.pointSize: ScreenTools.smallFontPointSize
                text:           qsTr("4")
                onClicked:      joystickManager.cameraManagement.setSysActiveTrackerCommand(4);
            }
    }

    QGCLabel {
        id:                 primTracker
        text:               qsTr("Primary Tracker")
        anchors.margins:    _margins
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.isMobile? point_size : ScreenTools.mediumFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        firstRow.bottom
        height:             ScreenTools.smallFontPointSize
        color:              "white"
    }

    RowLayout {
        id:                         secondRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                primTracker.bottom
        anchors.margins:            _margins
        spacing:                    5
        visible:                    true

        QGCRadioButton {
            font.pointSize: ScreenTools.smallFontPointSize
            text:           qsTr("0")
            checked:        true
            onClicked:      joystickManager.cameraManagement.setSysPrimaryTrackerCommand(0);
        }
        QGCRadioButton {
            font.pointSize: ScreenTools.smallFontPointSize
            text:           qsTr("1")
            onClicked:      joystickManager.cameraManagement.setSysPrimaryTrackerCommand(1);
        }
        QGCRadioButton {
            font.pointSize: ScreenTools.smallFontPointSize
            text:           qsTr("2")
            onClicked:      joystickManager.cameraManagement.setSysPrimaryTrackerCommand(2);
        }
        QGCRadioButton {
            font.pointSize: ScreenTools.smallFontPointSize
            text:           qsTr("3")
            onClicked:      joystickManager.cameraManagement.setSysPrimaryTrackerCommand(3);
        }
        QGCRadioButton {
            font.pointSize: ScreenTools.smallFontPointSize
            text:           qsTr("4")
            onClicked:      joystickManager.cameraManagement.setSysPrimaryTrackerCommand(4);
        }
    }

    QGCLabel {
        id:                 trackerROI
        text:               qsTr("Tracker ROI")
        anchors.margins:    _margins
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.isMobile? point_size : ScreenTools.mediumFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        secondRow.bottom
        height:             ScreenTools.smallFontPointSize
        color:              "white"
    }

    RowLayout {
        id:                         thirdRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                trackerROI.bottom
        anchors.margins:            _margins
        spacing:                    5
        visible:                    true

        QGCRadioButton {
            font.pointSize: ScreenTools.smallFontPointSize
            text:           qsTr("0")
            checked:        true
            onClicked:      joystickManager.cameraManagement.setSysTrackerROICommand(0);
        }
        QGCRadioButton {
            font.pointSize: ScreenTools.smallFontPointSize
            text:           qsTr("1")
            onClicked:      joystickManager.cameraManagement.setSysTrackerROICommand(1);
        }
        QGCRadioButton {
            font.pointSize: ScreenTools.smallFontPointSize
            text:           qsTr("2")
            onClicked:      joystickManager.cameraManagement.setSysTrackerROICommand(2);
        }
        QGCRadioButton {
            font.pointSize: ScreenTools.smallFontPointSize
            text:           qsTr("3")
            onClicked:      joystickManager.cameraManagement.setSysTrackerROICommand(3);
        }
        QGCRadioButton {
            font.pointSize: ScreenTools.smallFontPointSize
            text:           qsTr("4")
            onClicked:      joystickManager.cameraManagement.setSysTrackerROICommand(4);
        }
    }
}


