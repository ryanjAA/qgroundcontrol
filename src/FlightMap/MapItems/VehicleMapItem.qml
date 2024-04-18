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

    anchorPoint.x:  vehicleItem.width  / 2
    anchorPoint.y:  vehicleItem.height / 2
    visible:        coordinate.isValid

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool   _adsbVehicle:   vehicle ? false : true
    property var    _map:           map
    property bool   _multiVehicle:  QGroundControl.multiVehicleManager.vehicles.count > 1

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
            id:                 vehicleIcon
            source:             _adsbVehicle ? (alert ? "/qmlimages/AlertAircraft.svg" : "/qmlimages/AwarenessAircraft.svg") : vehicle.vehicleImageOpaque
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
