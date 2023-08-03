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
    id: widgetQuick
    height:             _heightTotal
    color:              Qt.rgba(0.0,0.0,0.0,0.25)
    visible:            true

    property int _heightTotal: mainlabel.height+firstRow.height+
                               secondRow.height+thirdRow.height+
                               fourthRow.height+
                               lastRow.height+
                               (_margins*12)

    QGCLabel {
        id:                 mainlabel
        text:               qsTr("QUICK")
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
            text:           qsTr("Zoom In")
            leftPadding:    0
            rightPadding:   0
            onPressed: {
                joystickManager.cameraManagement.setSysZoomInCommand();
            }
            onReleased: {
                joystickManager.cameraManagement.setSysZoomStopCommand();
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Zoom Out")
            leftPadding:    0
            rightPadding:   0
            onPressed: {
                joystickManager.cameraManagement.setSysZoomOutCommand();
            }
            onReleased: {
                joystickManager.cameraManagement.setSysZoomStopCommand();
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
            text:           qsTr("Near")
            leftPadding:    0
            rightPadding:   0
            onPressed: {
                joystickManager.cameraManagement.setSysSetFocusState(true, false, false);
            }
            onReleased: {
                joystickManager.cameraManagement.setSysSetFocusState(false, false, false);
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Inf")
            leftPadding:    0
            rightPadding:   0
            onPressed: {
                joystickManager.cameraManagement.setSysSetFocusState(false, false, true);
            }
            onReleased: {
                joystickManager.cameraManagement.setSysSetFocusState(false, false, false);
            }
        }
        QGCButton {
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:           qsTr("Far")
            leftPadding:    0
            rightPadding:   0
            onPressed: {
                joystickManager.cameraManagement.setSysSetFocusState(false, true, false);
            }
            onReleased: {
                joystickManager.cameraManagement.setSysSetFocusState(false, false, false);
            }
        }
    }

    RowLayout {
        id:                         fifthRowOptional
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                fourthRow.bottom
        anchors.margins:            _margins
        spacing:                    _butMargins
        visible:                    false

        QGCButton {
            id:             rescueBtn
            showBorder:     true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size * 1.5 : ScreenTools.defaultFontPointSize * 1.5
            text:           qsTr("")
            leftPadding:    17
            rightPadding:   17
            onPressed: {
                if (fifthRowOptional.visible)
                    joystickManager.cameraManagement.doRescue();
            }

            Timer {
                interval: 200; running: true; repeat: true
                onTriggered: {

                    if (fifthRowOptional.visible == false)
                    {
                        fifthRowOptional.visible = joystickManager.cameraManagement.getShouldUiEnabledRescueElement();
                        if (fifthRowOptional.visible)
                        {
                            widgetQuick.height += fifthRowOptional.height;
                            lastRow.anchors.topMargin += fifthRowOptional.height + _butMargins;
                            lastRow.update();
                            repeat = false;
                        }
                    }
                }
            }

            QGCColoredImage {
                source:         "qrc:///qmlimages/resources/dark_rescue_icon.png"
                fillMode:       Image.PreserveAspectFit
                color:          "transparent"
                anchors.fill:   parent
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

        QGCLabel {
            text:                   qsTr(" FOV[deg]")
            font.pointSize:         ScreenTools.isMobile ? point_size : 9
            color:                  "White"
        }

        QGCTextField {
            id:                     _fovDeg
            Layout.preferredWidth:  ScreenTools.isMobile ? 90 : 45
            maximumLength:          6
            font.pointSize:         ScreenTools.isMobile ? point_size : 9
            text:                   qsTr("62.0")
        }

        QGCButton {
            showBorder:                 true
            font.pointSize: ScreenTools.isMobile? point_size : ScreenTools.smallFontPointSize
            pointSize:      ScreenTools.isMobile? point_size : ScreenTools.defaultFontPointSize
            text:                       qsTr("Set")
            leftPadding:                0
            rightPadding:               0
            onReleased: {
                joystickManager.cameraManagement.setSysFOVCommand(_fovDeg.text);
            }
        }
    }
}
