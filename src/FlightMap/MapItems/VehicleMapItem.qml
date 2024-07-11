/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick              2.3
import QtLocation           5.3
import QtPositioning        5.3
import QtGraphicalEffects   1.0

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Vehicle       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ADSBVehicle   1.0

/// Marker for displaying a vehicle location on the map
MapQuickItem {
    id: _root

    property var    vehicle                                                         /// Vehicle object, undefined for ADSB vehicle
    property var    map
    property double altitude:       Number.NaN                                      ///< NAN to not show
    property string callsign:       ""                                              ///< Vehicle callsign
    property double heading:        vehicle ? vehicle.heading.value : Number.NaN    ///< Vehicle heading, NAN for none
    property real   size:           ScreenTools.defaultFontPixelHeight * 3          /// Default size for icon, most usage overrides this
    property bool   alert:          false                                           /// Collision alert
    property var    emitterType:    ADSBVehicle.EMITTER_TYPE_NO_INFO

    anchorPoint.x:  vehicleItem.width  / 2
    anchorPoint.y:  vehicleItem.height / 2
    visible:        coordinate.isValid

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool   _adsbVehicle:   vehicle ? false : true
    property var    _map:           map
    property bool   _multiVehicle:  QGroundControl.multiVehicleManager.vehicles.count > 1

    function isSpecialCallsign(callsign) {
            if (!callsign) return false;
            var normalizedCallsign = callsign.toString().trim().toUpperCase();
            return normalizedCallsign.startsWith("TEST") || normalizedCallsign.startsWith("RID-"); //AA - Adjust "Callsign" as needed
        }

    sourceItem: Item {
        id:         vehicleItem
        width:      vehicleIcon.width
        height:     vehicleIcon.height
        opacity:    _adsbVehicle || vehicle === _activeVehicle ? 1.0 : 0.5

        Rectangle {
            id:                 vehicleShadow
            anchors.fill:       vehicleIcon
            color:              Qt.rgba(1,1,1,1)
            radius:             width * 0.5
            visible:            false
        }
        DropShadow {
            anchors.fill:       vehicleShadow
            visible:            vehicleIcon.visible && _adsbVehicle
            horizontalOffset:   4
            verticalOffset:     4
            radius:             32.0
            samples:            65
            color:              Qt.rgba(0.94,0.91,0,0.5)
            source:             vehicleShadow
        }
        Image {
            function getAdsbIcon(emitterType, alert) {
                            switch (emitterType) {
                                case ADSBVehicle.EMITTER_TYPE_LIGHT:
                                case ADSBVehicle.EMITTER_TYPE_SMALL:
                                case ADSBVehicle.EMITTER_TYPE_LARGE:
                                case ADSBVehicle.EMITTER_TYPE_HEAVY:
                                case ADSBVehicle.EMITTER_TYPE_HIGHLY_MANUV:
                                case ADSBVehicle.EMITTER_TYPE_GLIDER:
                                case ADSBVehicle.EMITTER_TYPE_ULTRA_LIGHT:
                                    return alert ? "/qmlimages/AlertAircraft.svg" : "/qmlimages/AwarenessAircraft.svg"
                                case ADSBVehicle.EMITTER_TYPE_UAV:
                                    return alert ? "/qmlimages/AlertDrone.svg" : "/qmlimages/AwarenessDrone.svg"
                                case ADSBVehicle.EMITTER_TYPE_ROTOCRAFT:
                                    return alert ? "/qmlimages/AlertHeli.svg" : "/qmlimages/AwarenessHeli.svg"
                                case ADSBVehicle.EMITTER_TYPE_PARACHUTE:
                                    return alert ? "/qmlimages/AlertPara.svg" : "/qmlimages/AwarenessPara.svg"
                                case ADSBVehicle.EMITTER_TYPE_NO_INFO:
                                case ADSBVehicle.EMITTER_TYPE_HIGH_VORTEX_LARGE:
                                case ADSBVehicle.EMITTER_TYPE_UNASSIGNED:
                                case ADSBVehicle.EMITTER_TYPE_LIGHTER_AIR:
                                case ADSBVehicle.EMITTER_TYPE_UNASSIGNED2:
                                case ADSBVehicle.EMITTER_TYPE_SPACE:
                                case ADSBVehicle.EMITTER_TYPE_UNASSGINED3:
                                case ADSBVehicle.EMITTER_TYPE_EMERGENCY_SURFACE:
                                case ADSBVehicle.EMITTER_TYPE_SERVICE_SURFACE:
                                case ADSBVehicle.EMITTER_TYPE_POINT_OBSTACLE:
                                default:
                                    return alert ? "/qmlimages/AlertUnknown.svg" : "/qmlimages/AwarenessUnknown.svg"
                            }
                        }

            id:                 vehicleIcon
            /*
            source:             _adsbVehicle ? (callsign.startsWith("TEST") ? "/qmlimages/RID.svg" :
                                (callsign.startsWith("RID-") ? "/qmlimages/RID.svg" :
                                (alert ? "/qmlimages/AlertAircraft.svg" : "/qmlimages/AwarenessAircraft.svg"))) :
                                vehicle.vehicleImageOpaque //AA works for previous K75 testing

             */
            source:             _adsbVehicle ? (callsign.startsWith("TEST") ? "/qmlimages/RID.svg" :
                                (callsign.startsWith("RID-") ? "/qmlimages/RID.svg" :
                                getAdsbIcon(emitterType, alert))) : vehicle.vehicleImageOpaque //AA ADSB cascading model, alter TEST if needed for specific tests.
            mipmap:             true
            width:              _root.size
            sourceSize.width:   _root.size
            fillMode:           Image.PreserveAspectFit
            transform: Rotation {
                origin.x:       vehicleIcon.width  / 2
                origin.y:       vehicleIcon.height / 2
                angle:          isNaN(heading) ? 0 : heading
            }
        }

        QGCMapLabel {
            id:                         vehicleLabel
                              anchors.top:                parent.bottom
                              anchors.horizontalCenter:   parent.horizontalCenter
                              map:                        _map
                              text:                       vehicleLabelText()
                              font.pointSize:             _adsbVehicle ? ScreenTools.defaultFontPointSize : ScreenTools.smallFontPointSize
                              visible:                    _adsbVehicle ? !isNaN(altitude) : _multiVehicle
                              function vehicleLabelText() {
                                  // Base label text with altitude for ADS-B vehicles
                                  if (_adsbVehicle) {
                                      var labelText = "Alt: " + (isNaN(altitude) ? "N/A" : QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(altitude).toFixed(0) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString);

                                      // Add the horizontal distance only if the active vehicle and its coordinate are available
                                      if (_activeVehicle && _activeVehicle.coordinate) {
                                          labelText += "\nHor: " + getDistanceToActiveVehicle(coordinate, _activeVehicle.coordinate);
                                      }

                                      // Add the vertical distance only if the active vehicle and its AMSL altitude are available
                                      if (_activeVehicle && _activeVehicle.altitudeAMSL && !isNaN(_activeVehicle.altitudeAMSL.rawValue)) {
                                          var verticalDistanceMeters = Math.abs(altitude - _activeVehicle.altitudeAMSL.rawValue);
                                          var verticalDistanceInPreferredUnits = QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(verticalDistanceMeters).toFixed(0);
                                          labelText += "\nVer: " + verticalDistanceInPreferredUnits + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString;
                                      }

                                      // Append the callsign at the end, ensuring it's displayed even if there's no active vehicle
                                      labelText += "\nCS: " + (callsign ? callsign : "N/A");

                                      return labelText;
                                  } else if (_multiVehicle) {
                                      // For non-ADS-B vehicles when multiple vehicles are present
                                        return qsTr("Vehicle %1").arg(vehicle.id ? vehicle.id : "N/A");
                                  }

                                  // Default return if none of the above conditions are met
                                    return "N/A";
                              }


                      function getDistanceToActiveVehicle(adsbCoord, activeCoord) {
                          var distanceMeters = adsbCoord.distanceTo(activeCoord); // Calculate distance in meters
                          var distanceMiles = distanceMeters / 1609.34; // Convert meters to miles

                          if (distanceMiles < 2) {
                              // Display in feet if less than 2 miles
                              var distanceFeet = distanceMiles * 5280; // Convert miles to feet
                              return distanceFeet.toFixed(0) + " ft";
                          } else {
                              // Display in miles if 2 miles or more
                              return distanceMiles.toFixed(1) + " mi";
                          }
                      }

        }
    }
}
