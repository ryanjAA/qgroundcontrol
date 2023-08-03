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

    property int _heightTotal: mainlabel.height+firstRow.height+secondRow.height+thirdRow.height+irNrLabel.height+fourthRow.height+(_margins*12)
    property var _irNrLevels: [ "Low" , "Medium" , "High" ]

    QGCLabel {
        id:                 mainlabel
        text:               qsTr("IR")
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
            text:           qsTr("DAY")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysSensorDayCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("THERMAL")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysSensorIrCommand();
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
            text:           qsTr("WhiteHot")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysIrPolarityWHCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("BlackHot")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysIrPolarityBHCommand();
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
            text:           qsTr("Color.P")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysIrColorPCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("NUC")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysIrNUCCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("B/W.P")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                joystickManager.cameraManagement.setSysIrBWPCommand();
            }
        }
    }

    QGCLabel {
        id:                 irNrLabel
        text:               qsTr("IR Noise Reduction")
        anchors.margins:    _margins
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.isMobile ? point_size : ScreenTools.mediumFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        thirdRow.bottom
        color:              "white"
        height:             ScreenTools.smallFontPointSize
    }

    RowLayout {
        id:                         fourthRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                irNrLabel.bottom
        anchors.margins:            _margins * 2
        spacing:                    _butMargins
        visible:                    true

        QGCComboBox {
            id:             irNrLevelsCombo
            sizeToContents: true
            centeredLabel:  true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.mediumFontPointSize
            leftPadding:    0
            rightPadding:   12
            model:          _irNrLevels
        }

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Set")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                if(irNrLevelsCombo.currentIndex >=0 )
                    joystickManager.cameraManagement.setSysSetIRNoiseReductionLevelCommand(irNrLevelsCombo.currentIndex);
            }
        }
    }
}
