import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs  1.2
import QtQuick.Layouts  1.2

import QGroundControl               1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controllers   1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.SettingsManager 1.0

Rectangle {
    height:             _heightTotal
    color:              Qt.rgba(0.0,0.0,0.0,0.25)
    visible:            true

    property int _heightTotal: mainlabel.height+firstRow.height+secondRow.height+thirdRow.height+fourthRow.height+lastRow.height+(_margins*12)


    QGCLabel {
        id:                 mainlabel
        text:               qsTr("MODE")
        anchors.margins:    ScreenTools.isMobile ? _margins * 1.6 : _margins
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.largeFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        parent.top
        height:             ScreenTools.defaultFontPixelHeight
        color:              "White"
    }

    RowLayout {
        id:                         firstRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                mainlabel.bottom
        anchors.margins:            _margins * 4
        spacing:                    _butMargins
        visible:                    true

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("HOLD")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysModeHoldCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("OBS")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysModeObsCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("GRR")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysModeGrrCommand();
            }
        }
    }

    RowLayout {
        id:                         secondRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                firstRow.bottom
        anchors.margins:            _margins
        spacing:                    _butMargins
        visible:                    true

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("PILOT")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysModePilotCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("STOW")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysModeStowCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("EPR")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysModeEprCommand();
            }
        }
    }

    RowLayout {
        id:                         thirdRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                secondRow.bottom
        anchors.margins:            _margins
        spacing:                    _butMargins
        visible:                    true

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("RETRACT")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysModeRetractCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("RETRACT.R")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysModeRetractUnlockCommand();
            }
        }
    }

    RowLayout {
        id:                         fourthRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                thirdRow.bottom
        anchors.margins:            _margins
        spacing:                    _butMargins
        visible:                    true

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Nadir")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysNadirCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Nadir Scan")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysNadirScanCommand();
            }
        }

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("2D Scan")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysMode2DScanCommand();
            }
        }
    }

    RowLayout {
        id:                         lastRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                fourthRow.bottom
        anchors.margins:            _margins
        spacing:                    _butMargins
        visible:                    true

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Motors Off")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setCameraMotorState(false);
            }
        }

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Motors On")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setCameraMotorState(true);
            }
        }

    }
}


