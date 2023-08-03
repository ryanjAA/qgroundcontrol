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

    property int _heightTotal: mainlabel.height+localUnstabPosCombo.height+
                               firstRow.height+localPosBtn.height+
                               globalposlabel.height+secondRow.height+
                               globalPosBtn.height+
                               (_margins*15)

     property var _positionsStr: ["Local Position", "Un-stabilized Position"]

    property Fact _localPositionRoll: QGroundControl.settingsManager.appSettings.localPositionRoll
    property Fact _localPositionPitch: QGroundControl.settingsManager.appSettings.localPositionPitch
    property Fact _globalPositionElevation: QGroundControl.settingsManager.appSettings.globalPositionElevation
    property Fact _globalPositionAzimuth: QGroundControl.settingsManager.appSettings.globalPositionAzimuth

    QGCLabel {
        id:                 mainlabel
        text:               qsTr("POSITION")
        anchors.margins:    ScreenTools.isMobile ? _margins * 1.6 : _margins
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.largeFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        parent.top
        color:              "white"
        height:             ScreenTools.defaultFontPixelHeight
    }

    QGCComboBox {
        id:                         localUnstabPosCombo
        sizeToContents:             true
        centeredLabel:              true
        font.pointSize:             ScreenTools.isMobile? point_size : ScreenTools.mediumFontPointSize
        anchors.margins:            _margins * 4
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                mainlabel.bottom
        model:                      _positionsStr
    }


    RowLayout {
        id:                         firstRow
        anchors.top:                localUnstabPosCombo.bottom
        anchors.margins:            _margins * 2
        visible:                    true

        QGCLabel {
            text:                   qsTr(" Roll")
            color:                  "white"
            font.pointSize:         ScreenTools.isMobile ? point_size : 9
        }

        FactTextField {
            id:                     _localPosRoll
            Layout.preferredWidth:  ScreenTools.isMobile ? 90 : 45
            maximumLength:          6
            font.pointSize:         ScreenTools.isMobile ? point_size : 9
            fact:                   _localPositionRoll
        }

        QGCLabel {
            text:                   qsTr("Pitch")
            color:                  "white"
            font.pointSize:         ScreenTools.isMobile ? point_size : 9
        }

        FactTextField {
            id:                     _localPosPitch
            Layout.preferredWidth:  ScreenTools.isMobile ? 90 : 45
            maximumLength:          6
            font.pointSize:         ScreenTools.isMobile ? point_size : 9
            fact:                   _localPositionPitch
        }
    }

    QGCButton {
        id:                         localPosBtn
        showBorder:                 true
        anchors.margins:            _margins
        anchors.top:                firstRow.bottom
        font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
        pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
        text:                       qsTr("Set")
        anchors.horizontalCenter:   parent.horizontalCenter
        leftPadding:                0
        rightPadding:               0

        onReleased: {
            if(localUnstabPosCombo.currentIndex === 0)
                joystickManager.cameraManagement.setSysModeLocalPositionCommand(_localPosPitch.text, _localPosRoll.text);
            else if(localUnstabPosCombo.currentIndex === 1)
                joystickManager.cameraManagement.setSysModeUnstabilizedPositionCommand(_localPosPitch.text, _localPosRoll.text);
        }
    }


    QGCLabel {
        id:                 globalposlabel
        text:               qsTr("Global")
        anchors.margins:    _margins
        font.family:        ScreenTools.demiboldFontFamily
        font.pointSize:     ScreenTools.isMobile ? point_size : ScreenTools.mediumFontPointSize
        anchors.horizontalCenter:  parent.horizontalCenter
        anchors.top:        localPosBtn.bottom
        color:              "white"
        height:             ScreenTools.smallFontPointSize
    }

    RowLayout {
        id:                         secondRow
        anchors.top:                globalposlabel.bottom
        anchors.margins:            _margins * 2
        visible:                    true

        QGCLabel {
            text:                   qsTr(" Elev")
            color:                  "white"
            font.pointSize:         ScreenTools.isMobile ? point_size : 9
        }

        FactTextField {
            id:                     _globalPosElev
            Layout.preferredWidth:  ScreenTools.isMobile ? 90 : 45
            maximumLength:          6
            font.pointSize:         ScreenTools.isMobile ? point_size : 9
            fact:                   _globalPositionElevation
        }

        QGCLabel {
            text:                   qsTr("Az")
            color:                  "white"
            font.pointSize:         ScreenTools.isMobile ? point_size : 9
        }

        FactTextField {
            id:                     _globalPosAz
            Layout.preferredWidth:  ScreenTools.isMobile ? 90 : 45
            maximumLength:          6
            font.pointSize:         ScreenTools.isMobile ? point_size : 9
            fact:                   _globalPositionAzimuth
        }
    }

    QGCButton {
        id:                         globalPosBtn
        showBorder:                 true
        anchors.margins:            _margins
        anchors.top:                secondRow.bottom
        font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
        pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
        text:                       qsTr("Set Global Position")
        anchors.horizontalCenter:   parent.horizontalCenter
        leftPadding:                0
        rightPadding:               0

        onReleased: {
            joystickManager.cameraManagement.setSysModeGlobalPositionCommand(_globalPosElev.text, _globalPosAz.text);
        }
    }
}


