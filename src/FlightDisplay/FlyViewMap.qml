/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                      2.11
import QtQuick.Controls             2.4
import QtLocation                   5.3
import QtPositioning                5.3
import QtQuick.Dialogs              1.2
import QtQuick.Layouts              1.11

import QGroundControl               1.0
import QGroundControl.Controllers   1.0
import QGroundControl.Controls      1.0
import QGroundControl.FlightDisplay 1.0
import QGroundControl.FlightMap     1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Vehicle       1.0
import MAVLink                      1.0

FlightMap {
    id:                         _root
    allowGCSLocationCenter:     true
    allowVehicleLocationCenter: !_keepVehicleCentered
    planView:                   false
    zoomLevel:                  QGroundControl.flightMapZoom
    center:                     QGroundControl.flightMapPosition

    property var pointTimestamps: []

    property Item pipState: _pipState
    QGCPipState {
        id:         _pipState
        pipOverlay: _pipOverlay
        isDark:     _isFullWindowItemDark
    }

    property var    rightPanelWidth
    property var    planMasterController
    property bool   pipMode:                    false   // true: map is shown in a small pip mode
    property var    toolInsets                          // Insets for the center viewport area

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property var    _planMasterController:      planMasterController
    property var    _geoFenceController:        planMasterController.geoFenceController
    property var    _rallyPointController:      planMasterController.rallyPointController
    property var    _activeVehicleCoordinate:   _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()
    property real   _toolButtonTopMargin:       parent.height - mainWindow.height + (ScreenTools.defaultFontPixelHeight / 2)
    property real   _toolsMargin:               ScreenTools.defaultFontPixelWidth * 0.75
    property var    _flyViewSettings:           QGroundControl.settingsManager.flyViewSettings
    property bool   _keepMapCenteredOnVehicle:  _flyViewSettings.keepMapCenteredOnVehicle.rawValue
    property bool   _showPositionSetpointLine:  _flyViewSettings.showPositionSetpointLine.rawValue  //AA Added - setpoint line
    property int    _glideRingMode:             _flyViewSettings.glideRingMode.rawValue
    property real   _glideRatio:                _flyViewSettings.glideRatio.rawValue
    property bool   _showBatteryRangeRing:      _flyViewSettings.showBatteryRangeRing.rawValue
    property var    _batteryCapacityFact:       _activeVehicle && _activeVehicle.parameterManager && _activeVehicle.parameterManager.parametersReady ? _batteryCapacityParameter() : null

    property bool   _showMannedTrafficIndicators:     _flyViewSettings.showMannedTrafficIndicators.rawValue  //AA Added - Manned
    property var    _horizontalMannedConflictDistance: _flyViewSettings.horizontalMannedConflictDistance.value  //AA Added - Manned
    property var    _verticalMannedConflictDistance:  _flyViewSettings.verticalMannedConflictDistance.value  //AA Added - Manned


    property bool   _showUASTrafficIndicators:     _flyViewSettings.showUASTrafficIndicators.rawValue  //AA Added - UAS
    property var    _horizontalUASConflictDistance: _flyViewSettings.horizontalUASConflictDistance.value  //AA Added - UAS
    property var    _verticalUASConflictDistance:  _flyViewSettings.verticalUASConflictDistance.value  //AA Added - UAS

    property bool   _disableVehicleTracking:    false
    property bool   _keepVehicleCentered:       pipMode ? true : false
    property bool   _saveZoomLevelSetting:      true

    function _adjustMapZoomForPipMode() {
        _saveZoomLevelSetting = false
        if (pipMode) {
            if (QGroundControl.flightMapZoom > 3) {
                zoomLevel = QGroundControl.flightMapZoom - 3
            }
        } else {
            zoomLevel = QGroundControl.flightMapZoom
        }
        _saveZoomLevelSetting = true
    }

    onPipModeChanged: _adjustMapZoomForPipMode()

    onVisibleChanged: {
        if (visible) {
            // Synchronize center position with Plan View
            center = QGroundControl.flightMapPosition
        }
    }

    onZoomLevelChanged: {
        if (_saveZoomLevelSetting) {
            QGroundControl.flightMapZoom = zoomLevel
        }
    }
    onCenterChanged: {
        QGroundControl.flightMapPosition = center
    }

    // We track whether the user has panned or not to correctly handle automatic map positioning
    Connections {
        target: gesture

        function onPanStarted() {       _disableVehicleTracking = true }
        function onFlickStarted() {     _disableVehicleTracking = true }
        function onPanFinished() {      panRecenterTimer.restart() }
        function onFlickFinished() {    panRecenterTimer.restart() }
    }

    function pointInRect(point, rect) {
        return point.x > rect.x &&
                point.x < rect.x + rect.width &&
                point.y > rect.y &&
                point.y < rect.y + rect.height;
    }

    property real _animatedLatitudeStart
    property real _animatedLatitudeStop
    property real _animatedLongitudeStart
    property real _animatedLongitudeStop
    property real animatedLatitude
    property real animatedLongitude

    onAnimatedLatitudeChanged: _root.center = QtPositioning.coordinate(animatedLatitude, animatedLongitude)
    onAnimatedLongitudeChanged: _root.center = QtPositioning.coordinate(animatedLatitude, animatedLongitude)

    NumberAnimation on animatedLatitude { id: animateLat; from: _animatedLatitudeStart; to: _animatedLatitudeStop; duration: 1000 }
    NumberAnimation on animatedLongitude { id: animateLong; from: _animatedLongitudeStart; to: _animatedLongitudeStop; duration: 1000 }

    function animatedMapRecenter(fromCoord, toCoord) {
        _animatedLatitudeStart = fromCoord.latitude
        _animatedLongitudeStart = fromCoord.longitude
        _animatedLatitudeStop = toCoord.latitude
        _animatedLongitudeStop = toCoord.longitude
        animateLat.start()
        animateLong.start()
    }

    // returns the rectangle formed by the four center insets
    // used for checking if vehicle is under ui, and as a target for recentering the view
    function _insetCenterRect() {
        return Qt.rect(toolInsets.leftEdgeCenterInset,
                       toolInsets.topEdgeCenterInset,
                       _root.width - toolInsets.leftEdgeCenterInset - toolInsets.rightEdgeCenterInset,
                       _root.height - toolInsets.topEdgeCenterInset - toolInsets.bottomEdgeCenterInset)
    }

    // returns the four rectangles formed by the 8 corner insets
    // used for detecting if the vehicle has flown under the instrument panel, virtual joystick etc
    function _insetCornerRects() {
        var rects = {
        "topleft":      Qt.rect(0,0,
                               toolInsets.leftEdgeTopInset,
                               toolInsets.topEdgeLeftInset),
        "topright":     Qt.rect(_root.width-toolInsets.rightEdgeTopInset,0,
                               toolInsets.rightEdgeTopInset,
                               toolInsets.topEdgeRightInset),
        "bottomleft":   Qt.rect(0,_root.height-toolInsets.bottomEdgeLeftInset,
                               toolInsets.leftEdgeBottomInset,
                               toolInsets.bottomEdgeLeftInset),
        "bottomright":  Qt.rect(_root.width-toolInsets.rightEdgeBottomInset,_root.height-toolInsets.bottomEdgeRightInset,
                               toolInsets.rightEdgeBottomInset,
                               toolInsets.bottomEdgeRightInset)}
        return rects
    }

    function recenterNeeded() {
        var vehiclePoint = _root.fromCoordinate(_activeVehicleCoordinate, false /* clipToViewport */)
        var centerRect = _insetCenterRect()
        //return !pointInRect(vehiclePoint,insetRect)

        // If we are outside the center inset rectangle, recenter
        if(!pointInRect(vehiclePoint, centerRect)){
            return true
        }

        // if we are inside the center inset rectangle
        // then additionally check if we are underneath one of the corner inset rectangles
        var cornerRects = _insetCornerRects()
        if(pointInRect(vehiclePoint, cornerRects["topleft"])){
            return true
        } else if(pointInRect(vehiclePoint, cornerRects["topright"])){
            return true
        } else if(pointInRect(vehiclePoint, cornerRects["bottomleft"])){
            return true
        } else if(pointInRect(vehiclePoint, cornerRects["bottomright"])){
            return true
        }

        // if we are inside the center inset rectangle, and not under any corner elements
        return false
    }

    function updateMapToVehiclePosition() {
        if (animateLat.running || animateLong.running) {
            return
        }
        // We let FlightMap handle first vehicle position
        if (_keepMapCenteredOnVehicle && firstVehiclePositionReceived && _activeVehicleCoordinate.isValid && !_disableVehicleTracking) {
            if (_keepVehicleCentered) {
                _root.center = _activeVehicleCoordinate
            } else {
                if (firstVehiclePositionReceived && recenterNeeded()) {
                    // Move the map such that the vehicle is centered within the inset area
                    var vehiclePoint = _root.fromCoordinate(_activeVehicleCoordinate, false /* clipToViewport */)
                    var centerInsetRect = _insetCenterRect()
                    var centerInsetPoint = Qt.point(centerInsetRect.x + centerInsetRect.width / 2, centerInsetRect.y + centerInsetRect.height / 2)
                    var centerOffset = Qt.point((_root.width / 2) - centerInsetPoint.x, (_root.height / 2) - centerInsetPoint.y)
                    var vehicleOffsetPoint = Qt.point(vehiclePoint.x + centerOffset.x, vehiclePoint.y + centerOffset.y)
                    var vehicleOffsetCoord = _root.toCoordinate(vehicleOffsetPoint, false /* clipToViewport */)
                    animatedMapRecenter(_root.center, vehicleOffsetCoord)
                }
            }
        }
    }

    function _degreesToRadians(degrees) {
        return degrees * Math.PI / 180
    }

    function _activeBattery() {
        if (!_activeVehicle || !_activeVehicle.batteries || _activeVehicle.batteries.count === 0) {
            return null
        }
        return _activeVehicle.batteries.get(0)
    }

    function _batteryCapacityParameter() {
        if (!_activeVehicle || !_activeVehicle.parameterManager) {
            return null
        }
        if (_activeVehicle.parameterManager.parameterExists(-1, "BAT1_CAPACITY")) {
            return _activeVehicle.parameterManager.getParameter(-1, "BAT1_CAPACITY")
        }
        if (_activeVehicle.parameterManager.parameterExists(-1, "BATT_CAPACITY")) {
            return _activeVehicle.parameterManager.getParameter(-1, "BATT_CAPACITY")
        }
        return null
    }

    function _batteryInFailsafe() {
        var battery = _activeBattery()
        if (!battery) {
            return false
        }
        return battery.chargeState.rawValue === MAVLink.MAV_BATTERY_CHARGE_STATE_LOW ||
                battery.chargeState.rawValue === MAVLink.MAV_BATTERY_CHARGE_STATE_CRITICAL ||
                battery.chargeState.rawValue === MAVLink.MAV_BATTERY_CHARGE_STATE_EMERGENCY ||
                battery.chargeState.rawValue === MAVLink.MAV_BATTERY_CHARGE_STATE_FAILED ||
                battery.chargeState.rawValue === MAVLink.MAV_BATTERY_CHARGE_STATE_UNHEALTHY
    }

    function _vehicleInFailsafe() {
        if (!_activeVehicle) {
            return false
        }
        var mode = _activeVehicle.flightMode ? _activeVehicle.flightMode.toLowerCase() : ""
        var latestError = _activeVehicle.latestError ? _activeVehicle.latestError.toLowerCase() : ""
        return mode.indexOf("failsafe") !== -1 ||
                mode.indexOf("fail safe") !== -1 ||
                latestError.indexOf("failsafe") !== -1 ||
                latestError.indexOf("fail safe") !== -1 ||
                (_activeVehicle.vehicleLinkManager && _activeVehicle.vehicleLinkManager.communicationLost) ||
                _batteryInFailsafe()
    }

    function _glideRingVisible() {
        return !pipMode &&
                _activeVehicle &&
                _activeVehicleCoordinate.isValid &&
                _glideRatio > 0 &&
                !isNaN(_activeVehicle.altitudeRelative.rawValue) &&
                _activeVehicle.altitudeRelative.rawValue > 0 &&
                (_glideRingMode === 1 || (_glideRingMode === 2 && _vehicleInFailsafe()))
    }

    function _windVector() {
        if (!_activeVehicle || !_activeVehicle.wind || isNaN(_activeVehicle.wind.speed.rawValue) || isNaN(_activeVehicle.wind.direction.rawValue)) {
            return Qt.point(0, 0)
        }
        var speed = Math.max(0, _activeVehicle.wind.speed.rawValue)
        var direction = _degreesToRadians(_activeVehicle.wind.direction.rawValue)
        return Qt.point(Math.sin(direction) * speed, Math.cos(direction) * speed)
    }

    function _airSpeedForGlide() {
        if (!_activeVehicle) {
            return 0
        }
        if (!isNaN(_activeVehicle.airSpeed.rawValue) && _activeVehicle.airSpeed.rawValue > 1) {
            return _activeVehicle.airSpeed.rawValue
        }
        if (!isNaN(_activeVehicle.groundSpeed.rawValue) && _activeVehicle.groundSpeed.rawValue > 1) {
            return _activeVehicle.groundSpeed.rawValue
        }
        return 0
    }

    function _buildGlideRingPath() {
        if (!_glideRingVisible()) {
            return []
        }
        var altitude = _activeVehicle.altitudeRelative.rawValue
        var stillAirDistance = altitude * _glideRatio
        var airSpeed = _airSpeedForGlide()
        var wind = _windVector()
        var path = []
        var stepDegrees = 5

        if (airSpeed <= 0) {
            for (var noWindBearing = 0; noWindBearing <= 360; noWindBearing += stepDegrees) {
                path.push(_activeVehicleCoordinate.atDistanceAndAzimuth(stillAirDistance, noWindBearing))
            }
            return path
        }

        var glideTime = stillAirDistance / airSpeed
        for (var bearing = 0; bearing <= 360; bearing += stepDegrees) {
            var radians = _degreesToRadians(bearing)
            var east = Math.sin(radians)
            var north = Math.cos(radians)
            var tailwind = wind.x * east + wind.y * north
            var crosswind = -wind.x * north + wind.y * east
            var groundSpeedAlongTrack = Math.sqrt(Math.max(0, airSpeed * airSpeed - crosswind * crosswind)) + tailwind
            var distance = Math.max(0, groundSpeedAlongTrack * glideTime)
            path.push(_activeVehicleCoordinate.atDistanceAndAzimuth(distance, bearing))
        }
        return path
    }

    function _batteryRemainingMah() {
        var battery = _activeBattery()
        if (!battery) {
            return NaN
        }

        var consumed = battery.mahConsumed ? battery.mahConsumed.rawValue : NaN
        var percent = battery.percentRemaining ? battery.percentRemaining.rawValue : NaN
        var configuredCapacity = _batteryCapacityFact && !isNaN(_batteryCapacityFact.rawValue) ? _batteryCapacityFact.rawValue * 0.8 : NaN

        if (!isNaN(configuredCapacity) && configuredCapacity > 0 && !isNaN(percent)) {
            return configuredCapacity * Math.max(0, Math.min(percent, 100)) / 100
        }
        if (!isNaN(configuredCapacity) && configuredCapacity > 0 && !isNaN(consumed)) {
            return Math.max(0, configuredCapacity - consumed)
        }
        if (!isNaN(consumed) && consumed > 0 && !isNaN(percent) && percent > 0 && percent < 100) {
            var totalCapacity = consumed / (1 - (percent / 100))
            return Math.max(0, totalCapacity - consumed)
        }
        return NaN
    }

    function _batteryRangeRadius() {
        if (!_showBatteryRangeRing || !_activeVehicle || !_activeVehicleCoordinate.isValid) {
            return 0
        }
        var battery = _activeBattery()
        if (!battery || !battery.current || isNaN(battery.current.rawValue) || battery.current.rawValue <= 0) {
            return 0
        }
        if (isNaN(_activeVehicle.groundSpeed.rawValue) || _activeVehicle.groundSpeed.rawValue <= 0) {
            return 0
        }

        var remainingMah = _batteryRemainingMah()
        if (isNaN(remainingMah) || remainingMah <= 0) {
            return 0
        }

        var hoursRemaining = remainingMah / (battery.current.rawValue * 1000)
        return Math.max(0, hoursRemaining * 3600 * _activeVehicle.groundSpeed.rawValue)
    }

    function _courseOverGround() {
        if (_activeVehicle && _activeVehicle.gps && !isNaN(_activeVehicle.gps.courseOverGround.rawValue)) {
            return _activeVehicle.gps.courseOverGround.rawValue
        }
        if (_activeVehicle && !isNaN(_activeVehicle.heading.rawValue)) {
            return _activeVehicle.heading.rawValue
        }
        return 0
    }

    function _tailwindForBearing(wind, bearing) {
        var radians = _degreesToRadians(bearing)
        var east = Math.sin(radians)
        var north = Math.cos(radians)
        return wind.x * east + wind.y * north
    }

    function _batteryRangeSeconds() {
        if (!_showBatteryRangeRing) {
            return 0
        }
        var battery = _activeBattery()
        if (!battery || !battery.current || isNaN(battery.current.rawValue) || battery.current.rawValue <= 0) {
            return 0
        }
        var remainingMah = _batteryRemainingMah()
        if (isNaN(remainingMah) || remainingMah <= 0) {
            return 0
        }
        return (remainingMah / (battery.current.rawValue * 1000)) * 3600
    }

    function _buildBatteryRangePath() {
        if (!_showBatteryRangeRing || !_activeVehicle || !_activeVehicleCoordinate.isValid) {
            return []
        }

        var rangeSeconds = _batteryRangeSeconds()
        if (rangeSeconds <= 0) {
            return []
        }

        var baseGroundSpeed = !isNaN(_activeVehicle.groundSpeed.rawValue) && _activeVehicle.groundSpeed.rawValue > 0 ? _activeVehicle.groundSpeed.rawValue : _airSpeedForGlide()
        var airSpeed = !isNaN(_activeVehicle.airSpeed.rawValue) && _activeVehicle.airSpeed.rawValue > 1 ? _activeVehicle.airSpeed.rawValue : 0
        var wind = _windVector()
        var path = []
        var stepDegrees = 5

        var windSpeed = Math.sqrt((wind.x * wind.x) + (wind.y * wind.y))
        if (baseGroundSpeed <= 0 || (wind.x === 0 && wind.y === 0) || airSpeed <= 0 || windSpeed >= airSpeed) {
            var radius = baseGroundSpeed > 0 ? baseGroundSpeed * rangeSeconds : _batteryRangeRadius()
            if (radius <= 0) {
                return []
            }
            for (var noWindBearing = 0; noWindBearing <= 360; noWindBearing += stepDegrees) {
                path.push(_activeVehicleCoordinate.atDistanceAndAzimuth(radius, noWindBearing))
            }
            return path
        }

        var currentTailwind = _tailwindForBearing(wind, _courseOverGround())
        for (var bearing = 0; bearing <= 360; bearing += stepDegrees) {
            var groundSpeedAlongTrack = baseGroundSpeed + (_tailwindForBearing(wind, bearing) - currentTailwind)
            var distance = Math.max(0, groundSpeedAlongTrack * rangeSeconds)
            path.push(_activeVehicleCoordinate.atDistanceAndAzimuth(distance, bearing))
        }
        return path
    }

    on_ActiveVehicleCoordinateChanged: {
        if (_keepMapCenteredOnVehicle && _activeVehicleCoordinate.isValid && !_disableVehicleTracking) {
            _root.center = _activeVehicleCoordinate
        }
    }

    Timer {
        id:         panRecenterTimer
        interval:   10000
        running:    false
        onTriggered: {
            _disableVehicleTracking = false
            updateMapToVehiclePosition()
        }
    }

    Timer {
        interval:       500
        running:        true
        repeat:         true
        onTriggered:    updateMapToVehiclePosition()
    }

    QGCMapPalette { id: mapPal; lightColors: isSatelliteMap }

    Connections {
        target:                 _missionController
        ignoreUnknownSignals:   true
        function onNewItemsFromVehicle() {
            var visualItems = _missionController.visualItems
            if (visualItems && visualItems.count !== 1) {
                mapFitFunctions.fitMapViewportToMissionItems()
                firstVehiclePositionReceived = true
            }
        }
    }

    // FAA VFR aeronautical chart rendered as a translucent layer on top of the
    // active base map. It is a second tiled Map (input-disabled) whose camera is
    // bound to the base map; reuses the same tile engine so offline-cached tiles
    // work here too.
    Map {
        id:             vfrOverlayMap
        anchors.fill:   parent
        z:              0
        enabled:        false   // pass all gestures/clicks through to the base map
        visible:        QGroundControl.settingsManager.flightMapSettings.vfrOverlayEnabled.rawValue && !pipMode
        opacity:        QGroundControl.settingsManager.flightMapSettings.vfrOverlayOpacity.rawValue
        plugin:         Plugin { name: "QGroundControl" }
        gesture.enabled: false
        color:          "transparent"

        center:         _root.center
        zoomLevel:      _root.zoomLevel
        bearing:        _root.bearing
        tilt:           _root.tilt
        fieldOfView:    _root.fieldOfView

        function updateVfrMapType() {
            var want = QGroundControl.settingsManager.flightMapSettings.vfrOverlayType.value
            for (var i = 0; i < vfrOverlayMap.supportedMapTypes.length; i++) {
                if (vfrOverlayMap.supportedMapTypes[i].name === want) {
                    vfrOverlayMap.activeMapType = vfrOverlayMap.supportedMapTypes[i]
                    return
                }
            }
        }

        Component.onCompleted: updateVfrMapType()

        Connections {
            target:                 QGroundControl.settingsManager.flightMapSettings.vfrOverlayType
            function onRawValueChanged() { vfrOverlayMap.updateVfrMapType() }
        }
    }

    MapFitFunctions {
        id:                         mapFitFunctions // The name for this id cannot be changed without breaking references outside of this code. Beware!
        map:                        _root
        usePlannedHomePosition:     false
        planMasterController:       _planMasterController
    }

    ObstacleDistanceOverlayMap {
        id: obstacleDistance
        showText: !pipMode
    }

    // Add trajectory lines to the map
    MapPolyline {
        id:         trajectoryPolyline
        line.width: 3
        line.color: "red"
        z:          QGroundControl.zOrderTrajectoryLines
        visible:    !pipMode

        Connections {
            target:                 QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                trajectoryPolyline.path = _activeVehicle ? _activeVehicle.trajectoryPoints.list() : []
            }
        }

        Connections {
            target: _activeVehicle ? _activeVehicle.trajectoryPoints : null
                        onPointAdded: {
                            trajectoryPolyline.addCoordinate(coordinate);
                            trajectoryPolyline.visible = true;
                            var currentTime = Date.now();
                            pointTimestamps.push(currentTime);

                        }
                        onUpdateLastPoint: trajectoryPolyline.replaceCoordinate(trajectoryPolyline.pathLength() - 1, coordinate)
                        onPointsCleared: {
                            trajectoryPolyline.path = [];
                            pointTimestamps = [];
                        }
                    }
        Timer {
            id: cleanupTimer
            interval: 5000
            repeat: true
            running: true
            onTriggered: {
                var settingIndex = QGroundControl.settingsManager.flyViewSettings.trajectoryLineDuration.rawValue;
                const indexToMilliseconds = [0, 15000, 30000, 60000, 120000, 300000];
                var durationFromSettings = settingIndex < indexToMilliseconds.length ? indexToMilliseconds[settingIndex] : 0;

                // If keeping forever, do nothing — don't rebuild arrays
                if (durationFromSettings === 0)
                    return;

                var currentTime = Date.now();
                var cutoffTime = currentTime - durationFromSettings;

                // Find first point that's within retention (timestamps are monotonic)
                var firstKeepIndex = 0;
                for (var i = 0; i < pointTimestamps.length; i++) {
                    if (pointTimestamps[i] >= cutoffTime) {
                        firstKeepIndex = i;
                        break;
                    }
                    // If we reach the end, all points are expired
                    if (i === pointTimestamps.length - 1) {
                        firstKeepIndex = pointTimestamps.length;
                    }
                }

                // Nothing to remove — skip the expensive path reassignment
                if (firstKeepIndex === 0)
                    return;

                // Slice instead of rebuilding element by element
                pointTimestamps = pointTimestamps.slice(firstKeepIndex);
                trajectoryPolyline.path = trajectoryPolyline.path.slice(firstKeepIndex);
            }
        }
    }

    // Add the vehicles to the map
    MapItemView {
        model: QGroundControl.multiVehicleManager.vehicles
        delegate: VehicleMapItem {
            vehicle:        object
            coordinate:     object.coordinate
            map:            _root
            size:           pipMode ? ScreenTools.defaultFontPixelHeight : ScreenTools.defaultFontPixelHeight * 6 // AA added Controls vehicle size when planning (*3 is normal)
            z:              QGroundControl.zOrderVehicles
        }
    }
    // Add distance sensor view
    MapItemView{
        model: QGroundControl.multiVehicleManager.vehicles
        delegate: ProximityRadarMapView {
            vehicle:        object
            coordinate:     object.coordinate
            map:            _root
            z:              QGroundControl.zOrderVehicles
        }
    }
    // Add ADSB vehicles to the map
    MapItemView {
        model: QGroundControl.adsbVehicleManager.adsbVehicles
        delegate: VehicleMapItem {
            coordinate:     object.coordinate
            altitude:       object.altitude
            callsign:       object.callsign
            heading:        object.heading
            alert:          object.alert
            emitterType:    object.emitterType
            map:            _root
            size:           pipMode ? ScreenTools.defaultFontPixelHeight : ScreenTools.defaultFontPixelHeight * 2.5
            z:              QGroundControl.zOrderVehicles
        }
    }


    // Add lines to ADSB vehicles to the map
    MapItemView {
        model: QGroundControl.adsbVehicleManager.adsbVehicles
        delegate: MapPolyline {
            visible: shouldShowTrafficIndicator(object) && get_proximity(object, _activeVehicle, getHorizontalConflictDistance(object) * 2, getVerticalConflictDistance(object) * 2)
            line.width: get_line_width(object, _activeVehicle, getHorizontalConflictDistance(object), getVerticalConflictDistance(object))
            line.color: get_line_color(object, _activeVehicle, getHorizontalConflictDistance(object), getVerticalConflictDistance(object))
            z: QGroundControl.zOrderVehicles + 1
            path: visible ? [object.coordinate, _activeVehicle.coordinate] : []

            function get_proximity(adsbVehicle, mainVehicle, horizontal_radius, vertical_radius) {
                if (!adsbVehicle || !adsbVehicle.coordinate.isValid || !mainVehicle || !mainVehicle.coordinate.isValid) {
                    return false
                }

                var vertical_distance = 0
                if (!isNaN(adsbVehicle.altitude)) {
                    vertical_distance = Math.abs(adsbVehicle.altitude - mainVehicle.coordinate.altitude)
                }
                var horizontal_distance = adsbVehicle.coordinate.distanceTo(mainVehicle.coordinate)

                //console.log("Vertical Distance: " + vertical_distance)
                //console.log("Horizontal Distance: " + horizontal_distance)
                //console.log("Vertical Radius: " + vertical_radius)
                //console.log("Horizontal Radius: " + horizontal_radius)

                return vertical_distance <= vertical_radius && horizontal_distance <= horizontal_radius
            }

            function isUAVorRID(adsbVehicle) {
                if (!adsbVehicle || !adsbVehicle.emitterType || !adsbVehicle.callsign) {
                    return false;
                }
                return adsbVehicle.emitterType === ADSBVehicle.EMITTER_TYPE_UAV || adsbVehicle.callsign.startsWith("RID-");
            }

            function shouldShowTrafficIndicator(adsbVehicle) {
                if (isUAVorRID(adsbVehicle) && _showUASTrafficIndicators) {
                    return true
                }
                if (!isUAVorRID(adsbVehicle) && _showMannedTrafficIndicators) {
                    return true
                }
                return false
            }

            function getHorizontalConflictDistance(adsbVehicle) {
                if (isUAVorRID(adsbVehicle)) {
                    return getHorizontalUASConflictDistance()
                }
                return getHorizontalMannedConflictDistance()
            }

            function getVerticalConflictDistance(adsbVehicle) {
                if (isUAVorRID(adsbVehicle)) {
                    return getVerticalUASConflictDistance()
                }
                return getVerticalMannedConflictDistance()
            }

            function getHorizontalMannedConflictDistance() {
                return _horizontalMannedConflictDistance
            }

            function getVerticalMannedConflictDistance() {
                return _verticalMannedConflictDistance
            }

            function getHorizontalUASConflictDistance() {
                return _horizontalUASConflictDistance
            }

            function getVerticalUASConflictDistance() {
                return _verticalUASConflictDistance
            }

            function get_line_width(adsbVehicle, mainVehicle, horizontal_radius, vertical_radius) {
                if (get_proximity(adsbVehicle, mainVehicle, horizontal_radius, vertical_radius)) {
                    return 4
                }
                return 2
            }

            function get_line_color(adsbVehicle, mainVehicle, horizontal_radius, vertical_radius) {
                var withinImmediateConflict = get_proximity(adsbVehicle, mainVehicle, horizontal_radius, vertical_radius)
                var withinProximity = get_proximity(adsbVehicle, mainVehicle, horizontal_radius * 2, vertical_radius * 2)

                if (withinImmediateConflict) {
                    return "red"
                } else if (withinProximity) {
                    return "yellow"
                } else {
                    return "transparent" // This should not be visible
                }
            }
        }
    }




    // Add the items associated with each vehicles flight plan to the map
    Repeater {
        model: QGroundControl.multiVehicleManager.vehicles

        PlanMapItems {
            map:                    _root
            largeMapView:           !pipMode
            planMasterController:   masterController
            vehicle:                _vehicle

            property var _vehicle: object

            PlanMasterController {
                id: masterController
                Component.onCompleted: startStaticActiveVehicle(object)
            }
        }
    }

    MapItemView {
        model: pipMode ? undefined : _missionController.directionArrows

        delegate: MapLineArrow {
            fromCoord:      object ? object.coordinate1 : undefined
            toCoord:        object ? object.coordinate2 : undefined
            arrowPosition:  2
            z:              QGroundControl.zOrderWaypointLines
        }
    }

    // Allow custom builds to add map items
    CustomMapItems {
        map:            _root
        largeMapView:   !pipMode
    }

    // MapCircle for Manned Aircraft Conflict Distance //AA added
    MapCircle {
        color:          "transparent"
        opacity:        1
        border.color:   "red"
        border.width:   4
        radius:         _horizontalMannedConflictDistance
        center:         _activeVehicleCoordinate
        visible:        _showMannedTrafficIndicators
    }

    // MapCircle for UAS Conflict Distance      //AA added
    MapCircle {
        color:          "transparent"
        opacity:        1
        border.color:   "red"
        border.width:   4
        radius:         _horizontalUASConflictDistance
        center:         _activeVehicleCoordinate
        visible:        _showUASTrafficIndicators
    }

    MapPolygon {
        path:           _buildGlideRingPath()
        color:          "#3347a6ff"
        border.color:   "#47a6ff"
        border.width:   3
        opacity:        0.85
        visible:        _glideRingVisible()
        z:              QGroundControl.zOrderMapItems + 1
    }

    MapPolygon {
        path:           _buildBatteryRangePath()
        color:          "transparent"
        border.color:   "#35e07a"
        border.width:   3
        visible:        !pipMode && path.length > 0
        z:              QGroundControl.zOrderMapItems + 1
    }

    GeoFenceMapVisuals {
        map:                    _root
        myGeoFenceController:   _geoFenceController
        interactive:            false
        planView:               false
        homePosition:           _activeVehicle && _activeVehicle.homePosition.isValid ? _activeVehicle.homePosition :  QtPositioning.coordinate()
    }

    MapPolyline {
            id:             positionSetpointLine
            visible:        _showPositionSetpointLine && _activeVehicle && _activeVehicle.positionSetpoint.isValid
            path:           _activeVehicle && _activeVehicle.positionSetpoint.isValid ? [_activeVehicle.coordinate, _activeVehicle.positionSetpoint ] : []
            z:              QGroundControl.zOrderMapItems + 1
            line.color:     "white"
            line.width:     2
        }

    // Rally points on map
    MapItemView {
        model: _rallyPointController.points

        delegate: MapQuickItem {
            id:             itemIndicator
            anchorPoint.x:  sourceItem.anchorPointX
            anchorPoint.y:  sourceItem.anchorPointY
            coordinate:     object.coordinate
            z:              QGroundControl.zOrderMapItems

            sourceItem: MissionItemIndexLabel {
                id:         itemIndexLabel
                label:      qsTr("R", "rally point map item label")
            }
        }
    }

    // Camera trigger points
    MapItemView {
        model: _activeVehicle ? _activeVehicle.cameraTriggerPoints : 0

        delegate: CameraTriggerIndicator {
            coordinate:     object.coordinate
            z:              QGroundControl.zOrderTopMost
        }
    }

    // GoTo Location visuals
    MapQuickItem {
        id:             gotoLocationItem
        visible:        false
        z:              QGroundControl.zOrderMapItems
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY
        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("Go here", "Go to location waypoint")
        }

        property bool inGotoFlightMode: _activeVehicle ? _activeVehicle.flightMode === _activeVehicle.gotoFlightMode : false

        onInGotoFlightModeChanged: {
            if (!inGotoFlightMode && gotoLocationItem.visible) {
                // Hide goto indicator when vehicle falls out of guided mode
                gotoLocationItem.visible = false
            }
        }

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                if (!activeVehicle) {
                    gotoLocationItem.visible = false
                }
            }
        }

        function show(coord) {
            gotoLocationItem.coordinate = coord
            gotoLocationItem.visible = true
        }

        function hide() {
            gotoLocationItem.visible = false
        }

        function actionConfirmed() {
            // We leave the indicator visible. The handling for onInGuidedModeChanged will hide it.
        }

        function actionCancelled() {
            hide()
        }
    }

    // Orbit editing visuals
    QGCMapCircleVisuals {
        id:             orbitMapCircle
        mapControl:     parent
        mapCircle:      _mapCircle
        visible:        false

        property alias center:              _mapCircle.center
        property alias clockwiseRotation:   _mapCircle.clockwiseRotation
        readonly property real defaultRadius: 30

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                if (!activeVehicle) {
                    orbitMapCircle.visible = false
                }
            }
        }

        function show(coord) {
            _mapCircle.radius.rawValue = defaultRadius
            orbitMapCircle.center = coord
            orbitMapCircle.visible = true
        }

        function hide() {
            orbitMapCircle.visible = false
        }

        function actionConfirmed() {
            // Live orbit status is handled by telemetry so we hide here and telemetry will show again.
            hide()
        }

        function actionCancelled() {
            hide()
        }

        function radius() {
            return _mapCircle.radius.rawValue
        }

        Component.onCompleted: globals.guidedControllerFlyView.orbitMapCircle = orbitMapCircle

        QGCMapCircle {
            id:                 _mapCircle
            interactive:        true
            radius.rawValue:    30
            showRotation:       true
            clockwiseRotation:  true
        }
    }

    // ROI Location visuals
    MapQuickItem {
        id:             roiLocationItem
        visible:        _activeVehicle && _activeVehicle.isROIEnabled
        z:              QGroundControl.zOrderMapItems
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY
        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("ROI here", "Make this a Region Of Interest")
        }

        //-- Visibilty controlled by actual state
        function show(coord) {
            roiLocationItem.coordinate = coord
        }

        function hide() {
        }

        function actionConfirmed() {
        }

        function actionCancelled() {
        }
    }

    // Orbit telemetry visuals
    QGCMapCircleVisuals {
        id:             orbitTelemetryCircle
        mapControl:     parent
        mapCircle:      _activeVehicle ? _activeVehicle.orbitMapCircle : null
        visible:        _activeVehicle ? _activeVehicle.orbitActive : false
    }

    MapQuickItem {
        id:             orbitCenterIndicator
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY
        coordinate:     _activeVehicle ? _activeVehicle.orbitMapCircle.center : QtPositioning.coordinate()
        visible:        orbitTelemetryCircle.visible

        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("Orbit", "Orbit waypoint")
        }
    }


    // Handle guided mode clicks
    MouseArea {
        anchors.fill: parent

        Popup {
            id: clickMenu
            modal: true

            property var coord

            function setCoordinates(mouseX, mouseY) {
                var newX = mouseX
                var newY = mouseY

                // Filtering coordinates
                if (newX + clickMenu.width > _root.width) {
                    newX = _root.width - clickMenu.width
                }
                if (newY + clickMenu.height > _root.height) {
                    newY = _root.height - clickMenu.height
                }

                // Set coordiantes
                x = newX
                y = newY
            }

            background: Rectangle {
                radius: ScreenTools.defaultFontPixelHeight * 0.5
                color: qgcPal.window
                border.color: qgcPal.text
            }

            ColumnLayout {
                id: mainLayout
                spacing: ScreenTools.defaultFontPixelWidth / 2

                QGCButton {
                    Layout.fillWidth: true
                    text: "Go to location"
                    visible: globals.guidedControllerFlyView.showGotoLocation
                    onClicked: {
                        if (clickMenu.opened) {
                            clickMenu.close()
                        }
                        gotoLocationItem.show(clickMenu.coord)
                        globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionGoto, clickMenu.coord, gotoLocationItem)
                    }
                }

                QGCButton {
                    Layout.fillWidth: true
                    text: "Orbit at location"
                    visible: globals.guidedControllerFlyView.showOrbit
                    onClicked: {
                        if (clickMenu.opened) {
                            clickMenu.close()
                        }
                        orbitMapCircle.show(clickMenu.coord)
                        globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionOrbit, clickMenu.coord, orbitMapCircle)
                    }
                }

                QGCButton {
                    Layout.fillWidth: true
                    text: "ROI at location"
                    visible: globals.guidedControllerFlyView.showROI
                    onClicked: {
                        if (clickMenu.opened) {
                            clickMenu.close()
                        }
                        roiLocationItem.show(clickMenu.coord)
                        globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionROI, clickMenu.coord, roiLocationItem)
                    }
                }

                QGCButton {
                    Layout.fillWidth: true
                    text: "Set home here"
                    visible: globals.guidedControllerFlyView.showSetHome
                    onClicked: {
                        if (clickMenu.opened) {
                            clickMenu.close()
                        }
                        globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionSetHome, clickMenu.coord)
                    }
                }
            }
        }

        onClicked: {
            if (!globals.guidedControllerFlyView.guidedUIVisible && (globals.guidedControllerFlyView.showGotoLocation || globals.guidedControllerFlyView.showOrbit || globals.guidedControllerFlyView.showROI || globals.guidedControllerFlyView.showSetHome)) {
                orbitMapCircle.hide()
                gotoLocationItem.hide()
                var clickCoord = _root.toCoordinate(Qt.point(mouse.x, mouse.y), false /* clipToViewPort */)
                clickMenu.coord = clickCoord
                clickMenu.setCoordinates(mouse.x, mouse.y)
                clickMenu.open()
            }
        }
    }

    MapScale {
        id:                 mapScale
        anchors.margins:    _toolsMargin
        anchors.left:       parent.left
        anchors.top:        parent.top
        mapControl:         _root
        buttonsOnLeft:      false
        visible:            !ScreenTools.isTinyScreen && QGroundControl.corePlugin.options.flyView.showMapScale && mapControl.pipState.state === mapControl.pipState.windowState

        property real centerInset: visible ? parent.height - y : 0
    }

}
