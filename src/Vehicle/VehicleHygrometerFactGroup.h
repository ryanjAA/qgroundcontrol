/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "FactGroup.h"
#include "QGCMAVLink.h"

class VehicleHygrometerFactGroup : public FactGroup
{
    Q_OBJECT

public:
    VehicleHygrometerFactGroup(QObject* parent = nullptr);

    Q_PROPERTY(Fact* externalFuseTemp   READ externalFuseTemp   CONSTANT)
    Q_PROPERTY(Fact* humidity           READ humidity           CONSTANT)
    Q_PROPERTY(Fact* escTemp            READ escTemp            CONSTANT)

    Fact* externalFuseTemp                  () { return &_externalFuseTempFact; }
    Fact* humidity                          () { return &_humidityFact; }
    Fact* escTemp                           () { return &_escTempFact; }

    // Overrides from FactGroup
    virtual void handleMessage(Vehicle* vehicle, mavlink_message_t& message) override;

    static const char* _externalFuseTempFactName;
    static const char* _humidityFactName;
    static const char* _escTempFactName;

    // SHT3x I2C addresses published in HYGROMETER_SENSOR.id by firmware.
    static constexpr uint8_t _sht3xExternalFuseAddr = 0x44;
    static constexpr uint8_t _sht3xEscAddr          = 0x45;

protected:
    void _handleHygrometerSensor        (mavlink_message_t& message);

    Fact _externalFuseTempFact;
    Fact _humidityFact;
    Fact _escTempFact;
};
