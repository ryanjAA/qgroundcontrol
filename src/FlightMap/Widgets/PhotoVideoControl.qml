/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.4
import QtPositioning            5.2
import QtQuick.Layouts          1.2
import QtQuick.Controls         1.4
import QtQuick.Dialogs          1.2
import QtGraphicalEffects       1.0

import QGroundControl                   1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.Palette           1.0
import QGroundControl.Vehicle           1.0
import QGroundControl.Controllers       1.0
import QGroundControl.FactSystem        1.0
import QGroundControl.FactControls      1.0

Rectangle {
    height:     _presentedCamPanel.height
    width:      _presentedCamPanel.width
    color:      "#80000000"
    radius:     _margins    

    property real   _margins:                                   ScreenTools.defaultFontPixelHeight / 2
    property real   _butMargins:                                ScreenTools.defaultFontPixelHeight / 4
    property real   _rightPanelWidth:                           ScreenTools.defaultFontPixelWidth * 40

    /* nextvision panel resources */
    property int    _panel_index:                               0
    property int    _panel_index_min:                           0
    property int    _panel_index_max:                           12
    property real   point_size:     point_sizes[QGroundControl.settingsManager.appSettings.camControlFontSize.rawValue]
    property var    point_sizes:    [ScreenTools.smallFontPointSize, ScreenTools.mediumFontPointSize, ScreenTools.largeFontPointSize]

    MouseArea {
        anchors.fill:       parent
        enabled:            true
        onClicked:{}
    }

    function updatePanelIndex(dir) {
        if ( _panel_index + dir >= _panel_index_max )
            _panel_index = 0;
        else if ( _panel_index + dir < _panel_index_min )
            _panel_index = _panel_index_max - 1;
        else
            _panel_index += dir
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }    

    property var camQuickPages: ["qrc:/nvqml/CamQuickPanel.qml","qrc:/nvqml/CamQuick1Panel.qml","qrc:/nvqml/CamQuick2Panel.qml"]
    property var pages:         [camQuickPages[QGroundControl.settingsManager.appSettings.quickViewMode.rawValue],
        "qrc:/nvqml/CamModePanel.qml", "qrc:/nvqml/CamIRPanel.qml", "qrc:/nvqml/CamIRGainLevelPanel.qml",
        "qrc:/nvqml/CamRecPanel.qml","qrc:/nvqml/CamPosPanel.qml", "qrc:/nvqml/CamFModePanel.qml",
        "qrc:/nvqml/CamObjDetPanel.qml","qrc:/nvqml/CamMiscPanel.qml", "qrc:/nvqml/CamStreamControlPanel.qml",
        "qrc:/nvqml/CamVMDControlPanel.qml","qrc:/nvqml/CamTrackControlPanel.qml"]

    Loader {
        id:                 _presentedCamPanel
        source:             pages[_panel_index]
        width:              _rightPanelWidth
    }

    QGCColoredImage {
        anchors.margins:    _margins
        anchors.top:        parent.top
        anchors.right:      parent.right
        source:             "/res/buttonRight.svg"
        height:             ScreenTools.isMobile ? ScreenTools.defaultFontPixelHeight * 2.0 : ScreenTools.defaultFontPixelHeight
        width:              height * 1.2
        sourceSize.height:  height * 1.2
        color:              "white"
        fillMode:           Image.PreserveAspectFit
        visible:            true

        QGCMouseArea {
            fillItem:   parent
            onClicked:
                  updatePanelIndex(1)
        }
    }

    QGCColoredImage {
        anchors.margins:    _margins
        anchors.top:        parent.top
        anchors.left:       parent.left
        source:             "/res/buttonLeft.svg"
        height:             ScreenTools.isMobile ? ScreenTools.defaultFontPixelHeight * 2.0 : ScreenTools.defaultFontPixelHeight
        width:              height * 1.2
        sourceSize.height:  height * 1.2
        color:              "white"
        fillMode:           Image.PreserveAspectFit
        visible:            true

        QGCMouseArea {
            fillItem:   parent
            onClicked:
                updatePanelIndex(-1)
        }
    }            

    ColumnLayout {
        //id:                         mainLayout
        anchors.margins:            _margins
        anchors.top:                parent.top
        anchors.horizontalCenter:   parent.horizontalCenter
        spacing:                    ScreenTools.defaultFontPixelHeight / 2

        // Photo/Video Mode Selector
        // IMPORTANT: This control supports both mavlink cameras and simple video streams. Do no reference anything here which is not
        // using the unified properties/functions.
        /*Rectangle {
            Layout.alignment:   Qt.AlignHCenter
            width:              ScreenTools.defaultFontPixelWidth * 10
            height:             width / 2
            color:              qgcPal.windowShadeLight
            radius:             height * 0.5
            visible:            _showModeIndicator

            //-- Video Mode
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:                  parent.height
                height:                 parent.height
                color:                  _modeIndicatorPhotoMode ? qgcPal.windowShadeLight : qgcPal.window
                radius:                 height * 0.5
                anchors.left:           parent.left
                border.color:           qgcPal.text
                border.width:           _modeIndicatorPhotoMode ? 0 : 1

                QGCColoredImage {
                    height:             parent.height * 0.5
                    width:              height
                    anchors.centerIn:   parent
                    source:             "/qmlimages/camera_video.svg"
                    fillMode:           Image.PreserveAspectFit
                    sourceSize.height:  height
                    color:              _modeIndicatorPhotoMode ? qgcPal.text : qgcPal.colorGreen
                    MouseArea {
                        anchors.fill:   parent
                        enabled:        _switchToVideoModeAllowed
                        onClicked:      setCameraMode(false)
                    }
                }
            }
            //-- Photo Mode
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:                  parent.height
                height:                 parent.height
                color:                  _modeIndicatorPhotoMode ? qgcPal.window : qgcPal.windowShadeLight
                radius:                 height * 0.5
                anchors.right:          parent.right
                border.color:           qgcPal.text
                border.width:           _modeIndicatorPhotoMode ? 1 : 0
                QGCColoredImage {
                    height:             parent.height * 0.5
                    width:              height
                    anchors.centerIn:   parent
                    source:             "/qmlimages/camera_photo.svg"
                    fillMode:           Image.PreserveAspectFit
                    sourceSize.height:  height
                    color:              _modeIndicatorPhotoMode ? qgcPal.colorGreen : qgcPal.text
                    MouseArea {
                        anchors.fill:   parent
                        enabled:        _switchToPhotoModeAllowed
                        onClicked:      setCameraMode(true)
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment:   Qt.AlignHCenter
            spacing:            0
            visible:            _showModeIndicator && !_mavlinkCamera && _simpleCameraAvailable && _videoStreamInPhotoMode

            QGCRadioButton {
                id:             videoGrabRadio
                font.pointSize: ScreenTools.smallFontPointSize
                text:           qsTr("Video Grab")
            }
            QGCRadioButton {
                font.pointSize: ScreenTools.smallFontPointSize
                text:           qsTr("Camera Trigger")
                checked:        true
            }
        }

        // Take Photo, Start/Stop Video button
        // IMPORTANT: This control supports both mavlink cameras and simple video streams. Do no reference anything here which is not
        // using the unified properties/functions.
        Rectangle {
            Layout.alignment:   Qt.AlignHCenter
            color:              Qt.rgba(0,0,0,0)
            width:              ScreenTools.defaultFontPixelWidth * 6
            height:             width
            radius:             width * 0.5
            border.color:       qgcPal.buttonText
            border.width:       3

            Rectangle {
                anchors.centerIn:   parent
                width:              parent.width * (_isShootingInCurrentMode ? 0.5 : 0.75)
                height:             width
                radius:             _isShootingInCurrentMode ? 0 : width * 0.5
                color:              _canShootInCurrentMode ? qgcPal.colorRed : qgcPal.colorGrey
            }

            MouseArea {
                anchors.fill:   parent
                enabled:        _canShootInCurrentMode
                onClicked:      toggleShooting()
            }
        }

        //-- Status Information
        ColumnLayout {
            Layout.alignment:   Qt.AlignHCenter
            spacing:            0

            QGCLabel {
                Layout.alignment:   Qt.AlignHCenter
                text:               _cameraName
                visible:            _cameraName !== ""
            }
            QGCLabel {
                Layout.alignment:   Qt.AlignHCenter
                text:               (_mavlinkCameraInVideoMode && _mavlinkCamera.videoStatus === QGCCameraControl.VIDEO_CAPTURE_STATUS_RUNNING) ? _mavlinkCamera.recordTimeStr : "00:00:00"
                font.pointSize:     ScreenTools.largeFontPointSize
                visible:            _mavlinkCameraInVideoMode && _mavlinkCamera.capturesVideo
            }
            QGCLabel {
                Layout.alignment:   Qt.AlignHCenter
                text:               _activeVehicle ? ('00000' + _activeVehicle.cameraTriggerPoints.count).slice(-5) : "00000"
                font.pointSize:     ScreenTools.largeFontPointSize
                visible:            _modeIndicatorPhotoMode
            }
            QGCLabel {
                Layout.alignment:   Qt.AlignHCenter
                text:               _mavlinkCamera ? qsTr("Free Space: ") + _mavlinkCamera.storageFreeStr : ""
                font.pointSize:     ScreenTools.defaultFontPointSize
                visible:            _mavlinkCameraStorageReady
            }
            QGCLabel {
                Layout.alignment:   Qt.AlignHCenter
                text:               _mavlinkCamera ? qsTr("Battery: ") + _mavlinkCamera.batteryRemainingStr : ""
                font.pointSize:     ScreenTools.defaultFontPointSize
                visible:            _mavlinkCameraBatteryReady
            }
        }*/
    }




















}
