/****************************************************************************
 *
 * (c) 2009-2023 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "VehicleHygrometerFactGroup.h"
#include "Vehicle.h"
#include "QGCGeo.h"

const char* VehicleHygrometerFactGroup::_externalFuseTempFactName = "externalFuseTemp";
const char* VehicleHygrometerFactGroup::_humidityFactName         = "humidity";
const char* VehicleHygrometerFactGroup::_escTempFactName          = "escTemp";

VehicleHygrometerFactGroup::VehicleHygrometerFactGroup(QObject* parent)
    : FactGroup(1000, ":/json/Vehicle/HygrometerFact.json", parent)
    , _externalFuseTempFact      (0, _externalFuseTempFactName,  FactMetaData::valueTypeDouble)
    , _humidityFact              (0, _humidityFactName,          FactMetaData::valueTypeDouble)
    , _escTempFact               (0, _escTempFactName,           FactMetaData::valueTypeDouble)
{
    _addFact(&_externalFuseTempFact,        _externalFuseTempFactName);
    _addFact(&_humidityFact,                _humidityFactName);
    _addFact(&_escTempFact,                 _escTempFactName);

    _externalFuseTempFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _humidityFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _escTempFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
}

void VehicleHygrometerFactGroup::handleMessage(Vehicle* /* vehicle */, mavlink_message_t& message)
{
    switch (message.msgid) {
    case MAVLINK_MSG_ID_HYGROMETER_SENSOR:
       _handleHygrometerSensor(message);
       break;
    default:
        break;
    }
}

void VehicleHygrometerFactGroup::_handleHygrometerSensor(mavlink_message_t& message)
{
    mavlink_hygrometer_sensor_t hygrometer;
    mavlink_msg_hygrometer_sensor_decode(&message, &hygrometer);

    // PX4 now publishes the SHT3x I2C address in .id; route by address, not by instance index.
    switch (hygrometer.id) {
    case _sht3xExternalFuseAddr:
        _externalFuseTempFact.setRawValue(hygrometer.temperature / 100.f);
        _humidityFact.setRawValue(hygrometer.humidity);
        break;
    case _sht3xEscAddr:
        _escTempFact.setRawValue(hygrometer.temperature / 100.f);
        break;
    default:
        qWarning() << "HYGROMETER_SENSOR: unexpected id 0x" << QString::number(hygrometer.id, 16);
        break;
    }
}
