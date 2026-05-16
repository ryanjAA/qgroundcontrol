/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "FAAMapProvider.h"

// FAA-operated ArcGIS Online hosted tile caches. Note ESRI tile addressing is
// {zoom}/{row=y}/{col=x}, the opposite arg order from XYZ providers.
static const QString VFRSectionalUrl =
    QStringLiteral("https://tiles.arcgis.com/tiles/ssFJjBXIUyZDrSYZ/arcgis/rest/services/VFR_Sectional/MapServer/tile/%1/%2/%3");

QString FAAVFRSectionalMapProvider::_getURL(const int x, const int y, const int zoom, QNetworkAccessManager* networkManager) {
    Q_UNUSED(networkManager)
    // The chart cache has no tiles above its native resolution; returning an
    // empty URL makes the renderer/downloader skip the request instead of
    // hammering the server with 404s.
    if (zoom > maxZoomSupported()) {
        return QString();
    }
    return VFRSectionalUrl.arg(zoom).arg(y).arg(x);
}

static const QString VFRTerminalUrl =
    QStringLiteral("https://tiles.arcgis.com/tiles/ssFJjBXIUyZDrSYZ/arcgis/rest/services/VFR_Terminal/MapServer/tile/%1/%2/%3");

QString FAAVFRTerminalMapProvider::_getURL(const int x, const int y, const int zoom, QNetworkAccessManager* networkManager) {
    Q_UNUSED(networkManager)
    if (zoom > maxZoomSupported()) {
        return QString();
    }
    return VFRTerminalUrl.arg(zoom).arg(y).arg(x);
}
