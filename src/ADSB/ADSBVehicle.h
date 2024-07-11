/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QObject>
#include <QGeoCoordinate>
#include <QElapsedTimer>

#include "QGCMAVLink.h"

class ADSBVehicle : public QObject
{
    Q_OBJECT

public:
    enum class EmitterType : uint8_t {
        EMITTER_TYPE_NO_INFO =         ADSB_EMITTER_TYPE_NO_INFO,
        EMITTER_TYPE_LIGHT =           ADSB_EMITTER_TYPE_LIGHT,
        EMITTER_TYPE_SMALL =           ADSB_EMITTER_TYPE_SMALL,
        EMITTER_TYPE_LARGE =           ADSB_EMITTER_TYPE_LARGE,
        EMITTER_TYPE_HIGH_VORTEX_LA =  ADSB_EMITTER_TYPE_HIGH_VORTEX_LARGE,
        EMITTER_TYPE_HEAVY =           ADSB_EMITTER_TYPE_HEAVY,
        EMITTER_TYPE_HIGHLY_MANUV =    ADSB_EMITTER_TYPE_HIGHLY_MANUV,
        EMITTER_TYPE_ROTOCRAFT =       ADSB_EMITTER_TYPE_ROTOCRAFT,
        EMITTER_TYPE_UNASSIGNED =      ADSB_EMITTER_TYPE_UNASSIGNED,
        EMITTER_TYPE_GLIDER =          ADSB_EMITTER_TYPE_GLIDER,
        EMITTER_TYPE_LIGHTER_AIR =     ADSB_EMITTER_TYPE_LIGHTER_AIR,
        EMITTER_TYPE_PARACHUTE =       ADSB_EMITTER_TYPE_PARACHUTE,
        EMITTER_TYPE_ULTRA_LIGHT =     ADSB_EMITTER_TYPE_ULTRA_LIGHT,
        EMITTER_TYPE_UNASSIGNED2 =     ADSB_EMITTER_TYPE_UNASSIGNED2,
        EMITTER_TYPE_UAV =             ADSB_EMITTER_TYPE_UAV,
        EMITTER_TYPE_SPACE =           ADSB_EMITTER_TYPE_SPACE,
        EMITTER_TYPE_UNASSGINED3 =     ADSB_EMITTER_TYPE_UNASSGINED3,
        EMITTER_TYPE_EMERGENCY_SURF =  ADSB_EMITTER_TYPE_EMERGENCY_SURFACE,
        EMITTER_TYPE_SERVICE_SURFAC =  ADSB_EMITTER_TYPE_SERVICE_SURFACE,
        EMITTER_TYPE_POINT_OBSTACLE =  ADSB_EMITTER_TYPE_POINT_OBSTACLE
    };

    Q_ENUM(EmitterType);

    enum {
        CallsignAvailable =     1 << 1,
        LocationAvailable =     1 << 2,
        AltitudeAvailable =     1 << 3,
        HeadingAvailable =      1 << 4,
        AlertAvailable =        1 << 5,
    };

    typedef struct {
        uint32_t        icaoAddress;    // Required
        QString         callsign;
        QGeoCoordinate  location;
        double          altitude;
        double          heading;
        bool            alert;
        uint32_t        availableFlags;
        EmitterType     emitterType;
    } ADSBVehicleInfo_t;

    ADSBVehicle(const ADSBVehicleInfo_t & vehicleInfo, QObject* parent);

    Q_PROPERTY(int              icaoAddress READ icaoAddress    CONSTANT)
    Q_PROPERTY(QString          callsign    READ callsign       NOTIFY callsignChanged)
    Q_PROPERTY(QGeoCoordinate   coordinate  READ coordinate     NOTIFY coordinateChanged)
    Q_PROPERTY(double           altitude    READ altitude       NOTIFY altitudeChanged)     // NaN for not available
    Q_PROPERTY(double           heading     READ heading        NOTIFY headingChanged)      // NaN for not available
    Q_PROPERTY(bool             alert       READ alert          NOTIFY alertChanged)        // Collision path
    Q_PROPERTY(EmitterType      emitterType READ emitterType    NOTIFY emitterTypeChanged) // Vechicle type (MAVLink ADSB_EMITTER_TYPE)

    int             icaoAddress (void) const { return static_cast<int>(_icaoAddress); }
    QString         callsign    (void) const { return _callsign; }
    QGeoCoordinate  coordinate  (void) const { return _coordinate; }
    double          altitude    (void) const { return _altitude; }
    double          heading     (void) const { return _heading; }
    bool            alert       (void) const { return _alert; }
    EmitterType     emitterType (void) const { return _emitterType; }

    void update(const ADSBVehicleInfo_t & vehicleInfo);

    /// check if the vehicle is expired and should be removed
    bool expired();

signals:
    void coordinateChanged  ();
    void callsignChanged    ();
    void altitudeChanged    ();
    void headingChanged     ();
    void alertChanged       ();
    void emitterTypeChanged ();

private:
    uint32_t        _icaoAddress;
    QString         _callsign;
    QGeoCoordinate  _coordinate;
    double          _altitude;
    double          _heading;
    bool            _alert;
    EmitterType     _emitterType;

    QElapsedTimer   _lastUpdateTimer;

    static constexpr qint64 expirationTimeoutMs = 120000;   ///< timeout with no update in ms after which the vehicle is removed.
};

Q_DECLARE_METATYPE(ADSBVehicle::ADSBVehicleInfo_t)

