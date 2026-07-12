/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "CompInfoParam.h"
#include "JsonHelper.h"
#include "FactMetaData.h"
#include "FirmwarePlugin.h"
#include "FirmwarePluginManager.h"
#include "QGCApplication.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSaveFile>
#include <QXmlStreamReader>

QGC_LOGGING_CATEGORY(CompInfoParamLog, "CompInfoParamLog")

const char* CompInfoParam::_jsonParametersKey           = "parameters";
const char* CompInfoParam::_cachedMetaDataFilePrefix    = "ParameterFactMetaData";
const char* CompInfoParam::_indexedNameTag              = "{n}";

namespace {
const char* kPX4FirmwareParamXmlSizeKey = "parameter_xml_size";
const char* kPX4FirmwareParamXmlKey     = "parameter_xml";
const char* kPX4FirmwareMavAutopilotKey = "mav_autopilot";

bool _readFileBytes(const QString& fileName, QByteArray& bytes, QString& errorString)
{
    QFile file(fileName);
    if (!file.open(QIODevice::ReadOnly)) {
        errorString = QStringLiteral("Unable to open %1: %2").arg(fileName, file.errorString());
        return false;
    }

    bytes = file.readAll();
    return true;
}

bool _px4MetaDataVersionInfo(const QByteArray& metaDataBytes, const QString& sourceName, int& majorVersion, int& minorVersion, QString& errorString)
{
    majorVersion = -1;
    minorVersion = -1;

    QXmlStreamReader xml(metaDataBytes);
    while (!xml.atEnd() && (majorVersion == -1 || minorVersion == -1)) {
        xml.readNext();
        if (!xml.isStartElement()) {
            continue;
        }

        if (xml.name() == QStringLiteral("parameter_version_major")) {
            bool convertOk = false;
            majorVersion = xml.readElementText().toInt(&convertOk);
            if (!convertOk) {
                errorString = QStringLiteral("%1 has an invalid parameter_version_major value").arg(sourceName);
                return false;
            }
        } else if (xml.name() == QStringLiteral("parameter_version_minor")) {
            bool convertOk = false;
            minorVersion = xml.readElementText().toInt(&convertOk);
            if (!convertOk) {
                errorString = QStringLiteral("%1 has an invalid parameter_version_minor value").arg(sourceName);
                return false;
            }
        }
    }

    if (xml.hasError()) {
        errorString = QStringLiteral("%1 is not valid XML: %2").arg(sourceName, xml.errorString());
        return false;
    }
    if (majorVersion == -1) {
        errorString = QStringLiteral("%1 is missing parameter_version_major").arg(sourceName);
        return false;
    }
    if (minorVersion == -1) {
        errorString = QStringLiteral("%1 is missing parameter_version_minor").arg(sourceName);
        return false;
    }
    if (majorVersion != 1) {
        errorString = QStringLiteral("%1 has unsupported parameter metadata major version %2").arg(sourceName).arg(majorVersion);
        return false;
    }

    return true;
}

bool _jsonStringValueBytes(const QByteArray& jsonDocBytes, const QString& key, QByteArray& valueBytes, QString& errorString)
{
    const QByteArray keyBytes = QByteArray("\"") + key.toUtf8() + QByteArray("\"");
    const int keyIndex = jsonDocBytes.indexOf(keyBytes);
    if (keyIndex == -1) {
        errorString = QStringLiteral("Firmware file is missing %1").arg(key);
        return false;
    }

    const int colonIndex = jsonDocBytes.indexOf(':', keyIndex + keyBytes.count());
    if (colonIndex == -1) {
        errorString = QStringLiteral("Firmware file has an invalid %1 entry").arg(key);
        return false;
    }

    const int quoteStart = jsonDocBytes.indexOf('"', colonIndex + 1);
    if (quoteStart == -1) {
        errorString = QStringLiteral("Firmware file has an invalid %1 string").arg(key);
        return false;
    }

    int quoteEnd = -1;
    bool escaped = false;
    for (int i = quoteStart + 1; i < jsonDocBytes.count(); ++i) {
        const char ch = jsonDocBytes.at(i);
        if (escaped) {
            escaped = false;
            continue;
        }
        if (ch == '\\') {
            escaped = true;
            continue;
        }
        if (ch == '"') {
            quoteEnd = i;
            break;
        }
    }

    if (quoteEnd == -1) {
        errorString = QStringLiteral("Firmware file has an unterminated %1 string").arg(key);
        return false;
    }

    valueBytes = jsonDocBytes.mid(quoteStart + 1, quoteEnd - quoteStart - 1);
    valueBytes.replace("\\/", "/");
    return true;
}

bool _decompressPX4FirmwareJsonValue(const QJsonObject& jsonObject, const QByteArray& jsonDocBytes, const QString& sizeKey, const QString& bytesKey, QByteArray& decompressedBytes, QString& errorString)
{
    if (!jsonObject.contains(sizeKey)) {
        errorString = QStringLiteral("Firmware file is missing %1").arg(sizeKey);
        return false;
    }

    const int decompressedSize = jsonObject.value(sizeKey).toInt();
    if (decompressedSize <= 0) {
        errorString = QStringLiteral("Firmware file has invalid decompressed size for %1").arg(sizeKey);
        return false;
    }

    QByteArray raw64;
    if (!_jsonStringValueBytes(jsonDocBytes, bytesKey, raw64, errorString)) {
        return false;
    }

    QByteArray raw;
    raw.append(static_cast<char>((decompressedSize >> 24) & 0xFF));
    raw.append(static_cast<char>((decompressedSize >> 16) & 0xFF));
    raw.append(static_cast<char>((decompressedSize >> 8) & 0xFF));
    raw.append(static_cast<char>((decompressedSize >> 0) & 0xFF));
    raw.append(QByteArray::fromBase64(raw64));

    decompressedBytes = qUncompress(raw);
    if (decompressedBytes.isEmpty()) {
        errorString = QStringLiteral("Firmware file has 0 length %1").arg(bytesKey);
        return false;
    }
    if (decompressedBytes.count() != decompressedSize) {
        errorString = QStringLiteral("Size for decompressed %1 does not match stored size: Expected(%2) Actual(%3)").arg(bytesKey).arg(decompressedSize).arg(decompressedBytes.count());
        return false;
    }

    return true;
}

bool _cachePX4MetaDataBytes(const QByteArray& metaDataBytes, const QString& sourceName, QString& errorString, QString* cachedMetaDataFile)
{
    int newMajorVersion = -1;
    int newMinorVersion = -1;
    if (!_px4MetaDataVersionInfo(metaDataBytes, sourceName, newMajorVersion, newMinorVersion, errorString)) {
        return false;
    }

    QSettings settings;
    QDir cacheDir = QFileInfo(settings.fileName()).dir();
    if (!cacheDir.exists() && !cacheDir.mkpath(QStringLiteral("."))) {
        errorString = QStringLiteral("Unable to create metadata cache directory: %1").arg(cacheDir.absolutePath());
        return false;
    }

    const QString cacheFileName = cacheDir.filePath(QStringLiteral("ParameterFactMetaData.%1.%2.xml").arg(MAV_AUTOPILOT_PX4).arg(newMajorVersion));
    QSaveFile cacheFile(cacheFileName);
    if (!cacheFile.open(QIODevice::WriteOnly)) {
        errorString = QStringLiteral("Unable to open metadata cache file %1: %2").arg(cacheFileName, cacheFile.errorString());
        return false;
    }

    if (cacheFile.write(metaDataBytes) != metaDataBytes.count()) {
        errorString = QStringLiteral("Unable to write metadata cache file %1: %2").arg(cacheFileName, cacheFile.errorString());
        return false;
    }

    if (!cacheFile.commit()) {
        errorString = QStringLiteral("Unable to commit metadata cache file %1: %2").arg(cacheFileName, cacheFile.errorString());
        return false;
    }

    qCDebug(CompInfoParamLog) << "Cached PX4 parameter metadata" << cacheFileName << "major:minor" << newMajorVersion << newMinorVersion;
    if (cachedMetaDataFile) {
        *cachedMetaDataFile = cacheFileName;
    }

    return true;
}

bool _cachePX4MetaDataFromFirmwareFile(const QString& firmwareFileName, QString& errorString, QString* cachedMetaDataFile)
{
    QByteArray firmwareBytes;
    if (!_readFileBytes(firmwareFileName, firmwareBytes, errorString)) {
        return false;
    }

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(firmwareBytes, &parseError);
    if (doc.isNull() || !doc.isObject()) {
        errorString = QStringLiteral("%1 is not a valid PX4 firmware JSON file: %2").arg(firmwareFileName, parseError.errorString());
        return false;
    }

    const QJsonObject px4Json = doc.object();
    if (px4Json.contains(kPX4FirmwareMavAutopilotKey) && px4Json.value(kPX4FirmwareMavAutopilotKey).toInt(MAV_AUTOPILOT_PX4) != MAV_AUTOPILOT_PX4) {
        errorString = QStringLiteral("%1 does not contain PX4 parameter metadata").arg(firmwareFileName);
        return false;
    }

    QByteArray parameterXmlBytes;
    if (!_decompressPX4FirmwareJsonValue(px4Json, firmwareBytes, kPX4FirmwareParamXmlSizeKey, kPX4FirmwareParamXmlKey, parameterXmlBytes, errorString)) {
        return false;
    }

    return _cachePX4MetaDataBytes(parameterXmlBytes, firmwareFileName, errorString, cachedMetaDataFile);
}
}

CompInfoParam::CompInfoParam(uint8_t compId, Vehicle* vehicle, QObject* parent)
    : CompInfo(COMP_METADATA_TYPE_PARAMETER, compId, vehicle, parent)
{

}

void CompInfoParam::setJson(const QString& metadataJsonFileName)
{
    qCDebug(CompInfoParamLog) << "setJson: metadataJsonFileName" << metadataJsonFileName;

    if (metadataJsonFileName.isEmpty()) {
        // This will fall back to using the old FirmwarePlugin mechanism for parameter meta data.
        // In this case paramter metadata is loaded through the _parameterMajorVersionKnown call which happens after parameter are downloaded
        return;
    }

    QString         errorString;
    QJsonDocument   jsonDoc;

    if (!JsonHelper::isJsonFile(metadataJsonFileName, jsonDoc, errorString)) {
        qCWarning(CompInfoParamLog) << "Metadata json file open failed: compid:" << compId << errorString;
        return;
    }
    QJsonObject jsonObj = jsonDoc.object();

    QList<JsonHelper::KeyValidateInfo> keyInfoList = {
        { JsonHelper::jsonVersionKey,   QJsonValue::Double, true },
        { _jsonParametersKey,           QJsonValue::Array,  true },
    };
    if (!JsonHelper::validateKeys(jsonObj, keyInfoList, errorString)) {
        qCWarning(CompInfoParamLog) << "Metadata json validation failed: compid:" << compId << errorString;
        return;
    }

    int version = jsonObj[JsonHelper::jsonVersionKey].toInt();
    if (version != 1) {
        qCWarning(CompInfoParamLog) << "Metadata json unsupported version" << version;
        return;
    }

    _noJsonMetadata = false;
    _manualPX4MetaDataFile.clear();
    _clearOpaqueParameterMetaData();

    // Discard any previously parsed metadata so a re-pull from the vehicle
    // replaces it rather than duplicating into the indexed list / leaking the
    // old FactMetaData objects. Only done now that the new json validated, so a
    // failed re-pull leaves the existing metadata intact.
    _clearJsonParameterMetaData();

    QJsonArray rgParameters = jsonObj[_jsonParametersKey].toArray();
    for (QJsonValue parameterValue: rgParameters) {
        QMap<QString, QString> emptyDefineMap;

        if (!parameterValue.isObject()) {
            qCWarning(CompInfoParamLog) << "Metadata json read failed: compid:" << compId << "parameters array contains non-object";
            return;
        }

        FactMetaData* newMetaData = FactMetaData::createFromJsonObject(parameterValue.toObject(), emptyDefineMap, this);

        if (newMetaData->name().contains(_indexedNameTag)) {
            _indexedNameMetaDataList.append(RegexFactMetaDataPair_t(newMetaData->name(), newMetaData));
        } else {
            _nameToMetaDataMap[newMetaData->name()] = newMetaData;
        }
    }
}

void CompInfoParam::_clearJsonParameterMetaData(void)
{
    qDeleteAll(_nameToMetaDataMap);
    _nameToMetaDataMap.clear();
    for (const RegexFactMetaDataPair_t& pair : _indexedNameMetaDataList) {
        delete pair.second;
    }
    _indexedNameMetaDataList.clear();
}

void CompInfoParam::_clearOpaqueParameterMetaData(void)
{
    delete _opaqueParameterMetaData;
    _opaqueParameterMetaData = nullptr;
}

void CompInfoParam::usePX4MetaDataFile(const QString& metaDataFile)
{
    _manualPX4MetaDataFile = metaDataFile;
    _noJsonMetadata = true;
    _clearJsonParameterMetaData();
    _clearOpaqueParameterMetaData();
}

FactMetaData* CompInfoParam::factMetaDataForName(const QString& name, FactMetaData::ValueType_t type)
{
    FactMetaData* factMetaData = nullptr;

    if (_noJsonMetadata) {
        QObject* opaqueMetaData = _getOpaqueParameterMetaData();
        if (opaqueMetaData) {
            factMetaData = vehicle->firmwarePlugin()->_getMetaDataForFact(opaqueMetaData, name, type, vehicle->vehicleType());
        }
    }

    if (!factMetaData) {
        if (_nameToMetaDataMap.contains(name)) {
            factMetaData = _nameToMetaDataMap[name];
        } else {
            // We didn't get any direct matches. Try an indexed name.
            for (int i=0; i<_indexedNameMetaDataList.count(); i++) {
                const RegexFactMetaDataPair_t& pair = _indexedNameMetaDataList[i];

                QString indexedName = pair.first;
                QString indexedRegex("(\\d+)");
                indexedName.replace(_indexedNameTag, indexedRegex);

                QRegularExpression      regex(indexedName);
                QRegularExpressionMatch match = regex.match(name);

                QStringList captured = match.capturedTexts();
                if (captured.count() == 2) {
                    factMetaData = new FactMetaData(*pair.second, this);
                    factMetaData->setName(name);

                    QString shortDescription = factMetaData->shortDescription();
                    shortDescription.replace(_indexedNameTag, captured[1]);
                    factMetaData->setShortDescription(shortDescription);
                    QString longDescription = factMetaData->shortDescription();
                    longDescription.replace(_indexedNameTag, captured[1]);
                    factMetaData->setLongDescription(longDescription);
                }
            }

            if (!factMetaData) {
                factMetaData = new FactMetaData(type, this);
                int i = name.indexOf("_");
                if (i > 0) {
                    factMetaData->setGroup(name.left(i));
                }
                if (compId != MAV_COMP_ID_AUTOPILOT1) {
                    factMetaData->setCategory(tr("Component %1").arg(compId));
                }
            }
            _nameToMetaDataMap[name] = factMetaData;
        }
    }

    return factMetaData;
}

FirmwarePlugin* CompInfoParam::_anyVehicleTypeFirmwarePlugin(MAV_AUTOPILOT firmwareType)
{
    FirmwarePluginManager*  pluginMgr               = qgcApp()->toolbox()->firmwarePluginManager();
    MAV_TYPE                anySupportedVehicleType = QGCMAVLink::vehicleClassToMavType(pluginMgr->supportedVehicleClasses(QGCMAVLink::firmwareClass(firmwareType))[0]);

    return pluginMgr->firmwarePluginForAutopilot(firmwareType, anySupportedVehicleType);
}

QString CompInfoParam::_parameterMetaDataFile(Vehicle* vehicle, MAV_AUTOPILOT firmwareType, int& majorVersion, int& minorVersion)
{
    bool            cacheHit            = false;
    int             wantedMajorVersion  = 1;
    FirmwarePlugin* fwPlugin            = _anyVehicleTypeFirmwarePlugin(firmwareType);

    if (firmwareType != MAV_AUTOPILOT_PX4) {
        return fwPlugin->_internalParameterMetaDataFile(vehicle);
    } else {
        // Only PX4 support the old style cached metadata
        QSettings   settings;
        QDir        cacheDir = QFileInfo(settings.fileName()).dir();

        // First look for a direct cache hit
        int cacheMinorVersion, cacheMajorVersion;
        QFile cacheFile(cacheDir.filePath(QString("%1.%2.%3.xml").arg(_cachedMetaDataFilePrefix).arg(firmwareType).arg(wantedMajorVersion)));
        if (cacheFile.exists()) {
            fwPlugin->_getParameterMetaDataVersionInfo(cacheFile.fileName(), cacheMajorVersion, cacheMinorVersion);
            if (wantedMajorVersion != cacheMajorVersion) {
                qWarning() << "Parameter meta data cache corruption:" << cacheFile.fileName() << "major version does not match file name" << "actual:excepted" << cacheMajorVersion << wantedMajorVersion;
            } else {
                qCDebug(CompInfoParamLog) << "Direct cache hit on file:major:minor" << cacheFile.fileName() << cacheMajorVersion << cacheMinorVersion;
                cacheHit = true;
            }
        }

        if (!cacheHit) {
            // No direct hit, look for lower param set version
            QString wildcard = QString("%1.%2.*.xml").arg(_cachedMetaDataFilePrefix).arg(firmwareType);
            QStringList cacheHits = cacheDir.entryList(QStringList(wildcard), QDir::Files, QDir::Name);

            // Find the highest major version number which is below the vehicles major version number
            int cacheHitIndex = -1;
            cacheMajorVersion = -1;
            QRegExp regExp(QString("%1\\.%2\\.(\\d*)\\.xml").arg(_cachedMetaDataFilePrefix).arg(firmwareType));
            for (int i=0; i< cacheHits.count(); i++) {
                if (regExp.exactMatch(cacheHits[i]) && regExp.captureCount() == 1) {
                    int majorVersion = regExp.capturedTexts()[0].toInt();
                    if (majorVersion > cacheMajorVersion && majorVersion < wantedMajorVersion) {
                        cacheMajorVersion = majorVersion;
                        cacheHitIndex = i;
                    }
                }
            }

            if (cacheHitIndex != -1) {
                // We have a cache hit on a lower major version, read minor version as well
                int majorVersion;
                cacheFile.setFileName(cacheDir.filePath(cacheHits[cacheHitIndex]));
                fwPlugin->_getParameterMetaDataVersionInfo(cacheFile.fileName(), majorVersion, cacheMinorVersion);
                if (majorVersion != cacheMajorVersion) {
                    qWarning() << "Parameter meta data cache corruption:" << cacheFile.fileName() << "major version does not match file name" << "actual:excepted" << majorVersion << cacheMajorVersion;
                    cacheHit = false;
                } else {
                    qCDebug(CompInfoParamLog) << "Indirect cache hit on file:major:minor:want" << cacheFile.fileName() << cacheMajorVersion << cacheMinorVersion << wantedMajorVersion;
                    cacheHit = true;
                }
            }
        }

        int internalMinorVersion, internalMajorVersion;
        QString internalMetaDataFile = fwPlugin->_internalParameterMetaDataFile(vehicle);
        fwPlugin->_getParameterMetaDataVersionInfo(internalMetaDataFile, internalMajorVersion, internalMinorVersion);
        qCDebug(CompInfoParamLog) << "Internal metadata file:major:minor" << internalMetaDataFile << internalMajorVersion << internalMinorVersion;
        if (cacheHit) {
            // Cache hit is available, we need to check if internal meta data is a better match, if so use internal version
            if (internalMajorVersion == wantedMajorVersion) {
                if (cacheMajorVersion == wantedMajorVersion) {
                    // A direct cache hit came from flashed/imported firmware, so prefer it over bundled metadata.
                    cacheHit = true;
                } else {
                    // Direct internal hit, but not direct hit in cache, use internal
                    cacheHit = false;
                }
            } else {
                if (cacheMajorVersion == wantedMajorVersion) {
                    // Direct hit on cache, no direct hit on internal, use cache
                    cacheHit = true;
                } else {
                    // No direct hit anywhere, use internal
                    cacheHit = false;
                }
            }
        }

        QString metaDataFile;
        if (cacheHit && !qgcApp()->runningUnitTests()) {
            majorVersion = cacheMajorVersion;
            minorVersion = cacheMinorVersion;
            metaDataFile = cacheFile.fileName();
        } else {
            majorVersion = internalMajorVersion;
            minorVersion = internalMinorVersion;
            metaDataFile = internalMetaDataFile;
        }
        qCDebug(CompInfoParamLog) << "_parameterMetaDataFile returning file:major:minor" << metaDataFile << majorVersion << minorVersion;

        return metaDataFile;
    }
}

void CompInfoParam::_cachePX4MetaDataFile(const QString& metaDataFile)
{
    QString errorString;
    if (!cachePX4MetaDataFile(metaDataFile, errorString)) {
        qgcApp()->showAppMessage(errorString);
    }
}

bool CompInfoParam::cachePX4MetaDataFile(const QString& metaDataFile, QString& errorString, QString* cachedMetaDataFile)
{
    QByteArray metaDataBytes;
    if (!_readFileBytes(metaDataFile, metaDataBytes, errorString)) {
        return false;
    }

    return _cachePX4MetaDataBytes(metaDataBytes, metaDataFile, errorString, cachedMetaDataFile);
}

bool CompInfoParam::cachePX4MetaDataFromFile(const QString& metaDataFile, QString& errorString, QString* cachedMetaDataFile)
{
    const QString suffix = QFileInfo(metaDataFile).suffix().toLower();
    if (suffix == QStringLiteral("xml")) {
        return cachePX4MetaDataFile(metaDataFile, errorString, cachedMetaDataFile);
    }
    if (suffix == QStringLiteral("px4") || suffix == QStringLiteral("apj")) {
        return _cachePX4MetaDataFromFirmwareFile(metaDataFile, errorString, cachedMetaDataFile);
    }

    errorString = tr("Unsupported metadata file type. Select a PX4 firmware file (.px4/.apj) or parameter metadata XML file (.xml).");
    return false;
}

QObject* CompInfoParam::_getOpaqueParameterMetaData(void)
{
    if (!_noJsonMetadata) {
        qWarning() << "CompInfoParam::_getOpaqueParameterMetaData _noJsonMetadata == false";
    }

    if (!_opaqueParameterMetaData && compId == MAV_COMP_ID_AUTOPILOT1) {
        // Load best parameter meta data set
        int majorVersion, minorVersion;
        QString metaDataFile = _manualPX4MetaDataFile;
        if (metaDataFile.isEmpty()) {
            metaDataFile = _parameterMetaDataFile(vehicle, vehicle->firmwareType(), majorVersion, minorVersion);
        }
        qCDebug(CompInfoParamLog) << "Loading meta data the old way file" << metaDataFile;
        _opaqueParameterMetaData = vehicle->firmwarePlugin()->_loadParameterMetaData(metaDataFile);
    }

    return _opaqueParameterMetaData;
}
