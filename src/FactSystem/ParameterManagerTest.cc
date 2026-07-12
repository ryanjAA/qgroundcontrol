/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


#include "ParameterManagerTest.h"
#include "MultiVehicleManager.h"
#include "QGCApplication.h"
#include "ParameterManager.h"
#include "CompInfoParam.h"
#include "ComponentInformationManager.h"
#include "FactMetaData.h"
#include "FirmwarePlugin.h"
#include "FirmwarePluginManager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QScopedPointer>
#include <QTemporaryFile>

namespace {
QByteArray _testPX4MetaDataXml(const QString& shortDescription)
{
    return QStringLiteral(
        "<parameters>"
        "<version>3</version>"
        "<parameter_version_major>1</parameter_version_major>"
        "<parameter_version_minor>999</parameter_version_minor>"
        "<group name=\"AAGS Test\">"
        "<parameter name=\"AAGS_DUMMY\" default=\"0\" type=\"INT32\">"
        "<short_desc>Dummy parameter</short_desc>"
        "</parameter>"
        "<parameter name=\"SYS_AUTOSTART\" default=\"0\" type=\"INT32\">"
        "<short_desc>%1</short_desc>"
        "<long_desc>%1</long_desc>"
        "</parameter>"
        "</group>"
        "</parameters>").arg(shortDescription).toUtf8();
}

bool _writeTempFile(QTemporaryFile& file, const QByteArray& bytes)
{
    if (!file.open()) {
        return false;
    }
    if (file.write(bytes) != bytes.count()) {
        return false;
    }
    file.close();
    return true;
}

bool _readTempFile(const QString& fileName, QByteArray& bytes)
{
    QFile file(fileName);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }
    bytes = file.readAll();
    return true;
}

QByteArray _px4CompressedJsonString(const QByteArray& bytes)
{
    QByteArray compressed = qCompress(bytes);
    compressed.remove(0, 4);
    return compressed.toBase64();
}
}

/// Test failure modes which should still lead to param load success
void ParameterManagerTest::_noFailureWorker(MockConfiguration::FailureMode_t failureMode)
{
    Q_ASSERT(!_mockLink);
    _mockLink = MockLink::startPX4MockLink(false, failureMode);

    MultiVehicleManager* vehicleMgr = qgcApp()->toolbox()->multiVehicleManager();
    QVERIFY(vehicleMgr);

    // Wait for the Vehicle to get created
    QSignalSpy spyVehicle(vehicleMgr, SIGNAL(activeVehicleAvailableChanged(bool)));
    QCOMPARE(spyVehicle.wait(5000), true);
    QCOMPARE(spyVehicle.count(), 1);
    QList<QVariant> arguments = spyVehicle.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);

    Vehicle* vehicle = vehicleMgr->activeVehicle();
    QVERIFY(vehicle);

    // We should get progress bar updates during load
    QSignalSpy spyProgress(vehicle->parameterManager(), SIGNAL(loadProgressChanged(float)));
    QCOMPARE(spyProgress.wait(2000), true);
    arguments = spyProgress.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QVERIFY(arguments.at(0).toFloat() > 0.0f);

    // When param load is complete we get the param ready signal
    QSignalSpy spyParamsReady(vehicleMgr, SIGNAL(parameterReadyVehicleAvailableChanged(bool)));
    QCOMPARE(spyParamsReady.wait(60000), true);
    arguments = spyParamsReady.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);

    // Progress should have been set back to 0
    arguments = spyProgress.takeLast();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toFloat(), 0.0f);
}


void ParameterManagerTest::_noFailure(void)
{
    _noFailureWorker(MockConfiguration::FailNone);
}

void ParameterManagerTest::_requestListMissingParamSuccess(void)
{
    _noFailureWorker(MockConfiguration::FailMissingParamOnInitialReqest);
}

// Test no response to param_request_list
void ParameterManagerTest::_requestListNoResponse(void)
{
    // Will pop error about request failure
    setExpectedMessageBox(QMessageBox::Ok);

    Q_ASSERT(!_mockLink);
    _mockLink = MockLink::startPX4MockLink(false, MockConfiguration::FailParamNoReponseToRequestList);

    MultiVehicleManager* vehicleMgr = qgcApp()->toolbox()->multiVehicleManager();
    QVERIFY(vehicleMgr);

    // Wait for the Vehicle to get created
    QSignalSpy spyVehicle(vehicleMgr, SIGNAL(activeVehicleAvailableChanged(bool)));
    QCOMPARE(spyVehicle.wait(5000), true);
    QCOMPARE(spyVehicle.count(), 1);
    QList<QVariant> arguments = spyVehicle.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);

    Vehicle* vehicle = vehicleMgr->activeVehicle();
    QVERIFY(vehicle);

    QSignalSpy spyParamsReady(vehicleMgr, SIGNAL(parameterReadyVehicleAvailableChanged(bool)));
    QSignalSpy spyProgress(vehicle->parameterManager(), SIGNAL(loadProgressChanged(float)));

    // We should not get any progress bar updates, nor a parameter ready signal
    QCOMPARE(spyProgress.wait(500), false);
    QCOMPARE(spyParamsReady.wait(40000), false);

    // User should have been notified
    checkExpectedMessageBox();
}

// MockLink will fail to send a param on initial request, it will also fail to send it on subsequent
// param_read requests.
void ParameterManagerTest::_requestListMissingParamFail(void)
{
    // Will pop error about missing params
    setExpectedMessageBox(QMessageBox::Ok);

    Q_ASSERT(!_mockLink);
    _mockLink = MockLink::startPX4MockLink(false, MockConfiguration::FailMissingParamOnAllRequests);

    MultiVehicleManager* vehicleMgr = qgcApp()->toolbox()->multiVehicleManager();
    QVERIFY(vehicleMgr);

    // Wait for the Vehicle to get created
    QSignalSpy spyVehicle(vehicleMgr, SIGNAL(activeVehicleAvailableChanged(bool)));
    QCOMPARE(spyVehicle.wait(5000), true);
    QCOMPARE(spyVehicle.count(), 1);
    QList<QVariant> arguments = spyVehicle.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);

    Vehicle* vehicle = vehicleMgr->activeVehicle();
    QVERIFY(vehicle);

    QSignalSpy spyParamsReady(vehicleMgr, SIGNAL(parameterReadyVehicleAvailableChanged(bool)));
    QSignalSpy spyProgress(vehicle->parameterManager(), SIGNAL(loadProgressChanged(float)));

    // We will get progress bar updates, since it will fail after getting partially through the request
    QCOMPARE(spyProgress.wait(2000), true);
    arguments = spyProgress.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QVERIFY(arguments.at(0).toFloat() > 0.0f);

    // We should get a parameters ready signal, but Vehicle should indicate missing params
    QCOMPARE(spyParamsReady.wait(40000), true);
    QCOMPARE(vehicle->parameterManager()->missingParameters(), true);

    // User should have been notified
    checkExpectedMessageBox();
}

void ParameterManagerTest::_FTPnoFailure()
{
    Q_ASSERT(!_mockLink);
    _mockLink = MockLink::startAPMArduPlaneMockLink(false, MockConfiguration::FailParamNoReponseToRequestList);
    _mockLink->mockLinkFTP()->enableBinParamFile(true);
    MultiVehicleManager* vehicleMgr = qgcApp()->toolbox()->multiVehicleManager();
    QVERIFY(vehicleMgr);

    // Wait for the Vehicle to get created
    QSignalSpy spyVehicle(vehicleMgr, SIGNAL(activeVehicleAvailableChanged(bool)));
    // When param load is complete we get the param ready signal
    QSignalSpy spyParamsReady(vehicleMgr, SIGNAL(parameterReadyVehicleAvailableChanged(bool)));
    QCOMPARE(spyVehicle.wait(5000), true);
    QCOMPARE(spyVehicle.count(), 1);
    QList<QVariant> arguments = spyVehicle.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);
    Vehicle* vehicle = vehicleMgr->activeVehicle();
    QVERIFY(vehicle);

    spyParamsReady.wait(5000);
    QCOMPARE(spyParamsReady.count(), 1);
    arguments = spyParamsReady.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);

    // Request all parameters again and check the progress bar. The initial parameterdownload
    // is so fast that I cannot connect to the loadprogress early enough.
    QSignalSpy spyProgress(vehicle->parameterManager(), SIGNAL(loadProgressChanged(float)));
    vehicle->parameterManager()->refreshAllParameters();
    spyParamsReady.wait(5000);
    QVERIFY(spyProgress.count() > 1);
    arguments = spyProgress.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QVERIFY(arguments.at(0).toFloat() > 0.0f);
    // Progress should have been set back to 0
    arguments = spyProgress.takeLast();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toFloat(), 0.0f);
}

void ParameterManagerTest::_FTPChangeParam()
{
    Q_ASSERT(!_mockLink);
    _mockLink = MockLink::startAPMArduPlaneMockLink(false, MockConfiguration::FailParamNoReponseToRequestList);
    _mockLink->mockLinkFTP()->enableBinParamFile(true);
    MultiVehicleManager* vehicleMgr = qgcApp()->toolbox()->multiVehicleManager();
    QVERIFY(vehicleMgr);

    // Wait for the Vehicle to get created
    QSignalSpy spyVehicle(vehicleMgr, SIGNAL(activeVehicleAvailableChanged(bool)));
    // When param load is complete we get the param ready signal
    QSignalSpy spyParamsReady(vehicleMgr, SIGNAL(parameterReadyVehicleAvailableChanged(bool)));
    QCOMPARE(spyVehicle.wait(5000), true);
    QCOMPARE(spyVehicle.count(), 1);
    QList<QVariant> arguments = spyVehicle.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);
    Vehicle* vehicle = vehicleMgr->activeVehicle();
    QVERIFY(vehicle);

    if (spyParamsReady.count() == 0)
        spyParamsReady.wait(5000);
    QCOMPARE(spyParamsReady.count(), 1);
    arguments = spyParamsReady.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);

    // Now try to change a parameter and check the progress
    QSignalSpy spyProgress(vehicle->parameterManager(), SIGNAL(loadProgressChanged(float)));
    Fact* fact = vehicle->parameterManager()->getParameter(MAV_COMP_ID_AUTOPILOT1, "THR_MIN");
    QVERIFY(fact);
    float value = fact->rawValue().toFloat();
    QCOMPARE(value, 0.0);
    float testvalue = 0.87f;
    QVariant sendv = testvalue;
    fact->setRawValue(sendv); // This should trigger a parameter upload to the vehicle
    /* That should set the progress to 0.5 and then back to 0 */
    spyProgress.wait(1000);
    if (spyProgress.count() < 2)
        spyProgress.wait(1000);
    QCOMPARE(spyProgress.count(), 2);
    arguments = spyProgress.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QVERIFY(arguments.at(0).toFloat() > 0.4f);

    // Progress should have been set back to 0
    Q_ASSERT(!spyProgress.empty());
    arguments = spyProgress.takeLast();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toFloat(), 0.0f);
}

void ParameterMetadataImportTest::_cachePX4MetadataFromXml(void)
{
    const QByteArray xmlBytes = _testPX4MetaDataXml(QStringLiteral("Imported XML metadata"));
    QTemporaryFile xmlFile(QDir::temp().filePath(QStringLiteral("aags-metadata-XXXXXX.xml")));
    QVERIFY(_writeTempFile(xmlFile, xmlBytes));

    QString errorString;
    QString cachedFile;
    QVERIFY2(CompInfoParam::cachePX4MetaDataFromFile(xmlFile.fileName(), errorString, &cachedFile), qPrintable(errorString));
    QVERIFY(QFileInfo::exists(cachedFile));

    QByteArray cachedBytes;
    QVERIFY(_readTempFile(cachedFile, cachedBytes));
    QCOMPARE(cachedBytes, xmlBytes);
}

void ParameterMetadataImportTest::_cachePX4MetadataFromFirmware(void)
{
    const QByteArray xmlBytes = _testPX4MetaDataXml(QStringLiteral("Imported firmware metadata"));
    QJsonObject firmwareJson;
    firmwareJson[QStringLiteral("mav_autopilot")] = MAV_AUTOPILOT_PX4;
    firmwareJson[QStringLiteral("parameter_xml_size")] = xmlBytes.count();
    firmwareJson[QStringLiteral("parameter_xml")] = QString::fromUtf8(_px4CompressedJsonString(xmlBytes));

    QTemporaryFile firmwareFile(QDir::temp().filePath(QStringLiteral("aags-firmware-XXXXXX.px4")));
    QVERIFY(_writeTempFile(firmwareFile, QJsonDocument(firmwareJson).toJson(QJsonDocument::Compact)));

    QString errorString;
    QString cachedFile;
    QVERIFY2(CompInfoParam::cachePX4MetaDataFromFile(firmwareFile.fileName(), errorString, &cachedFile), qPrintable(errorString));
    QVERIFY(QFileInfo::exists(cachedFile));

    QByteArray cachedBytes;
    QVERIFY(_readTempFile(cachedFile, cachedBytes));
    QCOMPARE(cachedBytes, xmlBytes);
}

void ParameterMetadataImportTest::_loadedPX4MetadataUsesImportedXml(void)
{
    const QString importedDescription = QStringLiteral("Imported metadata lookup description");
    const QByteArray xmlBytes = _testPX4MetaDataXml(importedDescription);
    QTemporaryFile xmlFile(QDir::temp().filePath(QStringLiteral("aags-lookup-XXXXXX.xml")));
    QVERIFY(_writeTempFile(xmlFile, xmlBytes));

    QString errorString;
    QString cachedFile;
    QVERIFY2(CompInfoParam::cachePX4MetaDataFromFile(xmlFile.fileName(), errorString, &cachedFile), qPrintable(errorString));

    FirmwarePlugin* plugin = qgcApp()->toolbox()->firmwarePluginManager()->firmwarePluginForAutopilot(MAV_AUTOPILOT_PX4, MAV_TYPE_FIXED_WING);
    QVERIFY(plugin);

    QScopedPointer<QObject> opaqueMetaData(plugin->_loadParameterMetaData(cachedFile));
    QVERIFY(opaqueMetaData);

    FactMetaData* metaData = plugin->_getMetaDataForFact(opaqueMetaData.data(), QStringLiteral("SYS_AUTOSTART"), FactMetaData::valueTypeInt32, MAV_TYPE_FIXED_WING);
    QVERIFY(metaData);

    QCOMPARE(metaData->shortDescription(), importedDescription);
    QCOMPARE(metaData->longDescription(), importedDescription);
}
