/****************************************************************************
 *
 * (c) 2009-2023 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
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
import QGroundControl.SettingsManager       1.0
import MAVLink                              1.0

//-------------------------------------------------------------------------
//-- Air Temperature and Humidity Indicator
Item {
    id:             _root
    anchors.top:    parent.top
    anchors.right:  parent.right
    // Size to actual content: icon + label + a right-side gap so the longer
    // combined "xx/yy °C" string doesn't crowd the next toolbar indicator.
    width:          tempIcon.width + tempLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 2

    property bool showIndicator: true
    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _unitsSettings: QGroundControl.settingsManager.unitsSettings

    // 1Hz pulser used to flash the icon/label red when ESC temp is critical.
    property bool _pulser: false
    Timer { interval: 500; running: true; repeat: true; onTriggered: _root._pulser = !_root._pulser }

    // ESC thermal thresholds (Celsius — sensor publishes °C regardless of UI unit setting).
    readonly property real _escTempCritC: 95
    readonly property real _escTempWarnC: 80

    function _isNum(v) { return v !== undefined && v !== null && !isNaN(v) }

    function _extTempC() {
        return (_activeVehicle && _activeVehicle.hygrometer && _activeVehicle.hygrometer.externalFuseTemp
                && _isNum(_activeVehicle.hygrometer.externalFuseTemp.rawValue))
               ? _activeVehicle.hygrometer.externalFuseTemp.rawValue : undefined
    }
    function _escTempC() {
        return (_activeVehicle && _activeVehicle.hygrometer && _activeVehicle.hygrometer.escTemp
                && _isNum(_activeVehicle.hygrometer.escTemp.rawValue))
               ? _activeVehicle.hygrometer.escTemp.rawValue : undefined
    }
    function _primaryBattery() {
        return (_activeVehicle && _activeVehicle.batteries && _activeVehicle.batteries.count > 0)
               ? _activeVehicle.batteries.get(0) : undefined
    }
    // Power Module temp (INA238 DIETEMP) arrives via standard MAVLink BATTERY_STATUS.temperature.
    function _powerModuleTempC() {
        var battery = _primaryBattery()
        return (battery && battery.temperature && _isNum(battery.temperature.rawValue))
               ? battery.temperature.rawValue : undefined
    }
    function _pitotTempC() {
        return (_activeVehicle && _activeVehicle.temperature && _activeVehicle.temperature.temperaturePressDiff
                && _isNum(_activeVehicle.temperature.temperaturePressDiff.rawValue))
               ? _activeVehicle.temperature.temperaturePressDiff.rawValue : undefined
    }
    function _autopilotTempC() {
        return (_activeVehicle && _activeVehicle.temperature && _activeVehicle.temperature.temperature1
                && _isNum(_activeVehicle.temperature.temperature1.rawValue))
               ? _activeVehicle.temperature.temperature1.rawValue : undefined
    }

    function _unitSuffix() {
        return _unitsSettings.temperatureUnits.value === UnitsSettings.TemperatureUnitsCelsius ? " °C" : " °F"
    }

    // Top-bar label per spec: ext/esc combined, else single ext, else single esc,
    // else pitot (OAT proxy in flight), else power module, else autopilot, else "--".
    function _iconLabelText() {
        var ext = _extTempC(), esc = _escTempC()
        if (_isNum(ext) && _isNum(esc)) {
            return Math.round(convertTemperature(ext)) + "/" + Math.round(convertTemperature(esc)) + _unitSuffix()
        }
        if (_isNum(ext))                 return formatTemperatureNoDecimal(ext)
        if (_isNum(esc))                 return formatTemperatureNoDecimal(esc)
        if (_isNum(_pitotTempC()))       return formatTemperatureNoDecimal(_pitotTempC())
        if (_isNum(_powerModuleTempC())) return formatTemperatureNoDecimal(_powerModuleTempC())
        if (_isNum(_autopilotTempC()))   return formatTemperatureNoDecimal(_autopilotTempC())
        return formatTemperatureNoDecimal(undefined)
    }

    // Icon/label color driven by ESC temp. No ESC reading → neutral.
    function _alertColor() {
        var esc = _escTempC()
        if (!_isNum(esc))           return qgcPal.text
        if (esc >= _escTempCritC)   return _pulser ? "red" : qgcPal.text
        if (esc >= _escTempWarnC)   return "orange"
        return qgcPal.colorGreen
    }

    function convertTemperature(tempCelsius) {
        return _unitsSettings.temperatureUnits.value === UnitsSettings.TemperatureUnitsCelsius
                ? tempCelsius
                : (tempCelsius * 9/5) + 32; // Convert to Fahrenheit
    }

    // Only round temperature for the label next to the icon
    function formatTemperatureNoDecimal(value) {
        if (value !== undefined && value !== null && !isNaN(value)) {
            return Math.round(convertTemperature(value)) + (_unitsSettings.temperatureUnits.value === UnitsSettings.TemperatureUnitsCelsius ? " °C" : " °F");
        } else {
            return "--";
        }
    }

    // Keep full precision for the detailed temperature in the popup
    function formatTemperature(value) {
        if (value !== undefined && value !== null && !isNaN(value)) {
            return convertTemperature(value).toFixed(1) + (_unitsSettings.temperatureUnits.value === UnitsSettings.TemperatureUnitsCelsius ? " °C" : " °F");
        } else {
            return "--.--";
        }
    }

    function formatHumidity(value) {
        if (value !== undefined && value !== null && !isNaN(value)) {
            return value.toFixed(1) + " %";
        } else {
            return "--.--";
        }
    }

    Component {
        id: tempInfoPopup
        Rectangle {
            width:  tempCol.width   + ScreenTools.defaultFontPixelWidth  * 3
            height: tempCol.height  + ScreenTools.defaultFontPixelHeight * 2
            radius: ScreenTools.defaultFontPixelHeight * 0.5
            color:  qgcPal.window
            border.color:   qgcPal.text
            Column {
                id:                 tempCol
                spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                width:              tempGrid.width
                anchors.margins:    ScreenTools.defaultFontPixelHeight
                anchors.centerIn:   parent

                GridLayout {
                    id:                 tempGrid
                    anchors.margins:    ScreenTools.defaultFontPixelHeight
                    columnSpacing:      ScreenTools.defaultFontPixelWidth
                    columns:            2
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        text: qsTr("External Temp:")
                    }

                    // Full precision for external temperature (SHT3x @ 0x44)
                    QGCLabel {
                        text: formatTemperature(_activeVehicle && _activeVehicle.hygrometer && _activeVehicle.hygrometer.externalFuseTemp
                            ? _activeVehicle.hygrometer.externalFuseTemp.rawValue
                            : undefined)
                    }

                    // ESC Temp (SHT3x @ 0x45): only present once a value has arrived
                    property bool _hasEscTemp: _activeVehicle && _activeVehicle.hygrometer && _activeVehicle.hygrometer.escTemp
                                               && _activeVehicle.hygrometer.escTemp.rawValue !== undefined
                                               && !isNaN(_activeVehicle.hygrometer.escTemp.rawValue)

                    QGCLabel {
                        text: qsTr("ESC Temp:")
                        visible: tempGrid._hasEscTemp
                    }

                    QGCLabel {
                        text: formatTemperature(_activeVehicle && _activeVehicle.hygrometer && _activeVehicle.hygrometer.escTemp
                            ? _activeVehicle.hygrometer.escTemp.rawValue
                            : undefined)
                        visible: tempGrid._hasEscTemp
                    }

                    QGCLabel {
                        text: qsTr("Humidity:")
                    }

                    QGCLabel {
                        text: formatHumidity(_activeVehicle && _activeVehicle.hygrometer && _activeVehicle.hygrometer.humidity
                            ? _activeVehicle.hygrometer.humidity.rawValue
                            : undefined)
                    }

                    // Power Module temp: only present once a finite value has arrived.
                    property bool _hasPowerModuleTemp: _isNum(_powerModuleTempC())

                    QGCLabel {
                        text: qsTr("Power Module:")
                        visible: tempGrid._hasPowerModuleTemp
                    }

                    // Full precision for power module (shunt) temperature
                    QGCLabel {
                        text: formatTemperature(_powerModuleTempC())
                        visible: tempGrid._hasPowerModuleTemp
                    }

                    QGCLabel {
                        text: qsTr("Pitot Tube:")
                    }

                    // Full precision for pitot tube temperature
                    QGCLabel {
                        text: formatTemperature(_activeVehicle && _activeVehicle.temperature && _activeVehicle.temperature.temperaturePressDiff
                                ? _activeVehicle.temperature.temperaturePressDiff.rawValue
                                : undefined)
                    }

                    QGCLabel {
                        text: qsTr("Autopilot:")
                    }

                    // Full precision for autopilot temperature
                    QGCLabel {
                        text: formatTemperature(_activeVehicle && _activeVehicle.temperature && _activeVehicle.temperature.temperature1
                                ? _activeVehicle.temperature.temperature1.rawValue
                                : undefined)
                    }
                }
            }
        }
    }

    QGCColoredImage {
        id:                 tempIcon
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        width:              height
        sourceSize.height:  height
        source:             "/qmlimages/OAT.svg"
        fillMode:           Image.PreserveAspectFit
        color:              _alertColor()
    }

    QGCLabel {
        id: tempLabel
        anchors.verticalCenter: tempIcon.verticalCenter
        anchors.left: tempIcon.right
        text: _iconLabelText()
        color: _alertColor()
        font.family: ScreenTools.demiboldFontFamily
        visible: showIndicator
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            mainWindow.showIndicatorPopup(_root, tempInfoPopup)
        }
    }
}
