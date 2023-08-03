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

    property int _heightTotal: mainlabel.height+streamModeLabel.height+
                               firstRow.height+pipModeLabel.height+
                               secondRow.height+sbsModeLabel.height
                               +thirdRow.height+(_margins*16)

    property var _streamModesStr: [ "Ch-0 Day/IR : Ch-1 Dis    ",
                                    "Ch-0 Day    : Ch-1 IR    ",
                                    "Ch-0 Day    : Ch-1 Fusion    ",
                                    "Ch-0 Day    : Ch-1 PIP    ",
                                    "Ch-0 Day    : Ch-1 SBS    ",
                                    "Ch-0 IR     : Ch-1 Fusion    ",
                                    "Ch-0 IR     : Ch-1 PIP    ",
                                    "Ch-0 IR     : Ch-1 SBS    ",
                                    "Ch-0 Fusion : Ch-1 Dis    ",
                                    "Ch-0 PIP    : Ch-1 Dis    ",
                                    "Ch-0 SBS    : Ch-1 Dis    "]

    property var _pipModesStr:     ["Visable Large    ",
                                    "IR Large    "]

    property var _sbsModesStr:     ["Visable Left    ",
                                    "IR Left    "]

    function setStreamModes(modesCombo){
        //var modesCombo = streamModeCombo.currentIndex;

        switch( modesCombo ){

            case 0:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(1, 0);
            }
            break
            case 1:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(1, 2);
            }
            break
            case 2:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(1, 3);
            }
            break
            case 3:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(1, 4);
            }
            break
            case 4:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(1, 5);
            }
            break
            case 5:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(2, 3);
            }
            break
            case 6:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(2, 4);
            }
            break
            case 7:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(2, 5);
            }
            break
            case 8:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(3, 0);
            }
            break
            case 9:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(4, 0);
            }
            break
            case 10:
            {
                joystickManager.cameraManagement.setSysStreamModeCommand(5, 0);
            }
            break
        }
    }


    QGCLabel {
        id:                 mainlabel
        text:               qsTr("STREAM CTRL")
        anchors.margins:    ScreenTools.isMobile ? _margins * 1.6 : _margins
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.largeFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        parent.top
        height:             ScreenTools.defaultFontPixelHeight
        color:              "White"
    }

    QGCLabel {
        id:                 streamModeLabel
        text:               qsTr("Stream Mode")
        anchors.margins:    _margins * 2
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.isMobile ? point_size : ScreenTools.mediumFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        mainlabel.bottom
        color:              "white"
        height:             ScreenTools.smallFontPointSize
    }

    RowLayout {
        id:                         firstRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                streamModeLabel.bottom
        anchors.margins:            _margins * 2
        spacing:                    _butMargins
        visible:                    true

        QGCComboBox {
            id:             streamModeCombo
            sizeToContents: true
            centeredLabel:  true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.mediumFontPointSize
            leftPadding:    0
            rightPadding:   0
            model:          _streamModesStr
        }

        QGCButton {
            id:             streamModeSetButton
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Set")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                setStreamModes(streamModeCombo.currentIndex)
            }
        }
    }

    QGCLabel {
        id:                 pipModeLabel
        text:               qsTr("Picture In Picture Mode")
        anchors.margins:    _margins * 2
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.isMobile ? point_size : ScreenTools.mediumFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        firstRow.bottom
        color:              "white"
        height:             ScreenTools.smallFontPointSize
    }

    RowLayout {
        id:                         secondRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                pipModeLabel.bottom
        anchors.margins:            _margins * 2
        spacing:                    _butMargins
        visible:                    true

        QGCComboBox {
            id:             pipModeCombo
            sizeToContents: true
            centeredLabel:  true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.mediumFontPointSize
            leftPadding:    0
            rightPadding:   0
            model:          _pipModesStr
        }

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Set")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                if(pipModeCombo.currentIndex >=0 )
                    joystickManager.cameraManagement.setSysPIPModeCommand(pipModeCombo.currentIndex);
            }
        }
    }

    QGCLabel {
        id:                 sbsModeLabel
        text:               qsTr("Side By Side Mode")
        anchors.margins:    _margins * 2
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.isMobile ? point_size : ScreenTools.mediumFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        secondRow.bottom
        color:              "white"
        height:             ScreenTools.smallFontPointSize
    }

    RowLayout {
        id:                         thirdRow
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                sbsModeLabel.bottom
        anchors.margins:            _margins * 2
        spacing:                    _butMargins
        visible:                    true

        QGCComboBox {
            id:             sbsModeCombo
            sizeToContents: true
            centeredLabel:  true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.mediumFontPointSize
            leftPadding:    0
            rightPadding:   0
            model:          _sbsModesStr
        }

        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Set")
            leftPadding:    0
            rightPadding:   0
            onReleased: {
                if(sbsModeCombo.currentIndex >=0 )
                    joystickManager.cameraManagement.setSysSBSModeCommand(sbsModeCombo.currentIndex);
            }
        }

    }    
}
