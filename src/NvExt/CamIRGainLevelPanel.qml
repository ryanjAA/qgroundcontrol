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

    property int _heightTotal: mainlabel.height+firstRow.height+secondRow.height+thirdRow.height+(_margins*10)

    QGCLabel {
        id:                 mainlabel
        text:               qsTr("IR Gain/Level")
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
            text:           qsTr("Gain Inc")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysIrGainLevelCommand(3);
            }
        }

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Gain Dec")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysIrGainLevelCommand(2);
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
            text:           qsTr("Level Inc")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysIrGainLevelCommand(1);
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Level Dec")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysIrGainLevelCommand(0);
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
            text:           qsTr("Reset Gain/Level")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysIrGainLevelCommand(4);
            }
        }
    }
}
