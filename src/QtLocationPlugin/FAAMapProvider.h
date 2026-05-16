/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "MapProvider.h"

// FAA aeronautical raster charts, served from the FAA's own ArcGIS Online
// hosted tile caches (Web Mercator, anonymous access, ESRI {z}/{y}/{x} order).
class FAAVFRSectionalMapProvider : public MapProvider {
    Q_OBJECT
  public:
    FAAVFRSectionalMapProvider(QObject* parent = nullptr)
        : MapProvider(QStringLiteral("https://www.faa.gov/"), QStringLiteral(""),
                      AVERAGE_TILE_SIZE, QGeoMapType::CustomMap, parent) {}

    int maxZoomSupported() const override { return 12; }

    QString _getURL(const int x, const int y, const int zoom, QNetworkAccessManager* networkManager) override;
};

class FAAVFRTerminalMapProvider : public MapProvider {
    Q_OBJECT
  public:
    FAAVFRTerminalMapProvider(QObject* parent = nullptr)
        : MapProvider(QStringLiteral("https://www.faa.gov/"), QStringLiteral(""),
                      AVERAGE_TILE_SIZE, QGeoMapType::CustomMap, parent) {}

    int maxZoomSupported() const override { return 12; }

    QString _getURL(const int x, const int y, const int zoom, QNetworkAccessManager* networkManager) override;
};
