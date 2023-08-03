/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "VideoSettings.h"
#include "QGCApplication.h"
#include "VideoManager.h"

#include <QQmlEngine>
#include <QtQml>
#include <QVariantList>
#include <QUdpSocket>

#ifndef QGC_DISABLE_UVC
#include <QCameraInfo>
#endif

const char* VideoSettings::videoSourceNoVideo           = QT_TRANSLATE_NOOP("VideoSettings", "No Video Available");
const char* VideoSettings::videoDisabled                = QT_TRANSLATE_NOOP("VideoSettings", "Video Stream Disabled");
const char* VideoSettings::videoSourceRTSP              = QT_TRANSLATE_NOOP("VideoSettings", "RTSP Video Stream");
const char* VideoSettings::videoSourceUDPH264           = QT_TRANSLATE_NOOP("VideoSettings", "UDP h.264 Video Stream");
const char* VideoSettings::videoSourceUDPH265           = QT_TRANSLATE_NOOP("VideoSettings", "UDP h.265 Video Stream");
const char* VideoSettings::videoSourceTCP               = QT_TRANSLATE_NOOP("VideoSettings", "TCP-MPEG2 Video Stream");
const char* VideoSettings::videoSourceMPEGTS            = QT_TRANSLATE_NOOP("VideoSettings", "MPEG-TS (h.264) Video Stream");
const char* VideoSettings::videoSource3DRSolo           = QT_TRANSLATE_NOOP("VideoSettings", "3DR Solo (requires restart)");
const char* VideoSettings::videoSourceParrotDiscovery   = QT_TRANSLATE_NOOP("VideoSettings", "Parrot Discovery");
const char* VideoSettings::videoSourceYuneecMantisG     = QT_TRANSLATE_NOOP("VideoSettings", "Yuneec Mantis G");

DECLARE_SETTINGGROUP(Video, "Video")
{
    qmlRegisterUncreatableType<VideoSettings>("QGroundControl.SettingsManager", 1, 0, "VideoSettings", "Reference only");

    // Setup enum values for videoSource settings into meta data
    QVariantList videoSourceList;
#ifdef QGC_GST_STREAMING
    videoSourceList.append(videoSourceRTSP);
#ifndef NO_UDP_VIDEO
    videoSourceList.append(videoSourceUDPH264);
    videoSourceList.append(videoSourceUDPH265);
#endif
    videoSourceList.append(videoSourceTCP);
    videoSourceList.append(videoSourceMPEGTS);
    videoSourceList.append(videoSource3DRSolo);
    videoSourceList.append(videoSourceParrotDiscovery);
    videoSourceList.append(videoSourceYuneecMantisG);
#endif
#ifndef QGC_DISABLE_UVC
    QList<QCameraInfo> cameras = QCameraInfo::availableCameras();
    for (const QCameraInfo &cameraInfo: cameras) {
        videoSourceList.append(cameraInfo.description());
    }
#endif
    if (videoSourceList.count() == 0) {
        _noVideo = true;
        videoSourceList.append(videoSourceNoVideo);
    } else {
        videoSourceList.insert(0, videoDisabled);
    }

    // make translated strings
    QStringList videoSourceCookedList;
    for (const QVariant& videoSource: videoSourceList) {
        videoSourceCookedList.append( VideoSettings::tr(videoSource.toString().toStdString().c_str()) );
    }

    _nameToMetaDataMap[videoSourceName]->setEnumInfo(videoSourceCookedList, videoSourceList);

    const QVariantList removeForceVideoDecodeList{
#ifdef Q_OS_LINUX
        VideoDecoderOptions::ForceVideoDecoderDirectX3D,
        VideoDecoderOptions::ForceVideoDecoderVideoToolbox,
#endif
#ifdef Q_OS_WIN
        VideoDecoderOptions::ForceVideoDecoderVAAPI,
        VideoDecoderOptions::ForceVideoDecoderVideoToolbox,
#endif
#ifdef Q_OS_MAC
        VideoDecoderOptions::ForceVideoDecoderDirectX3D,
        VideoDecoderOptions::ForceVideoDecoderVAAPI,
#endif
    };

    for(const auto& value : removeForceVideoDecodeList) {
        _nameToMetaDataMap[forceVideoDecoderName]->removeEnumInfo(value);
    }

    // Set default value for videoSource
    _setDefaults();
}

void VideoSettings::_setDefaults()
{
    if (_noVideo) {
        _nameToMetaDataMap[videoSourceName]->setRawDefaultValue(videoSourceNoVideo);
    } else {
        _nameToMetaDataMap[videoSourceName]->setRawDefaultValue(videoDisabled);
    }
}

DECLARE_SETTINGSFACT(VideoSettings, aspectRatio)
DECLARE_SETTINGSFACT(VideoSettings, videoFit)
DECLARE_SETTINGSFACT(VideoSettings, gridLines)
DECLARE_SETTINGSFACT(VideoSettings, showRecControl)
DECLARE_SETTINGSFACT(VideoSettings, recordingFormat)
DECLARE_SETTINGSFACT(VideoSettings, maxVideoSize)
DECLARE_SETTINGSFACT(VideoSettings, enableStorageLimit)
DECLARE_SETTINGSFACT(VideoSettings, rtspTimeout)
DECLARE_SETTINGSFACT(VideoSettings, streamEnabled)
DECLARE_SETTINGSFACT(VideoSettings, disableWhenDisarmed)
DECLARE_SETTINGSFACT(VideoSettings, lowLatencyMode)
DECLARE_SETTINGSFACT(VideoSettings, udpFwdEn)
DECLARE_SETTINGSFACT(VideoSettings, udpFwdSrcPort)
DECLARE_SETTINGSFACT(VideoSettings, udpFwdDstIP)
DECLARE_SETTINGSFACT(VideoSettings, udpFwdDstPort)


DECLARE_SETTINGSFACT_NO_FUNC(VideoSettings, videoSource)
{
    if (!_videoSourceFact) {
        _videoSourceFact = _createSettingsFact(videoSourceName);
        //-- Check for sources no longer available
        if(!_videoSourceFact->enumValues().contains(_videoSourceFact->rawValue().toString())) {
            if (_noVideo) {
                _videoSourceFact->setRawValue(videoSourceNoVideo);
            } else {
                _videoSourceFact->setRawValue(videoDisabled);
            }
        }
        connect(_videoSourceFact, &Fact::valueChanged, this, &VideoSettings::_configChanged);
    }
    return _videoSourceFact;
}

DECLARE_SETTINGSFACT_NO_FUNC(VideoSettings, forceVideoDecoder)
{
    if (!_forceVideoDecoderFact) {
        _forceVideoDecoderFact = _createSettingsFact(forceVideoDecoderName);

        _forceVideoDecoderFact->setVisible(
#ifdef Q_OS_IOS
            false
#else
#ifdef Q_OS_ANDROID
            false
#else
            true
#endif
#endif
        );

        connect(_forceVideoDecoderFact, &Fact::valueChanged, this, &VideoSettings::_configChanged);
    }
    return _forceVideoDecoderFact;
}

DECLARE_SETTINGSFACT_NO_FUNC(VideoSettings, udpPort)
{
    if (!_udpPortFact) {
        _udpPortFact = _createSettingsFact(udpPortName);
        connect(_udpPortFact, &Fact::valueChanged, this, &VideoSettings::_configChanged);
    }
    return _udpPortFact;
}

DECLARE_SETTINGSFACT_NO_FUNC(VideoSettings, udpMulticastIP)
{
    if (!_udpMulticastIPFact)
    {
        _udpMulticastIPFact = _createSettingsFact(udpMulticastIPName);
        connect(_udpMulticastIPFact, &Fact::valueChanged, this, &VideoSettings::_configChanged);
    }

    return _udpMulticastIPFact;
}

DECLARE_SETTINGSFACT_NO_FUNC(VideoSettings, rtspUrl)
{
    if (!_rtspUrlFact) {
        _rtspUrlFact = _createSettingsFact(rtspUrlName);
        connect(_rtspUrlFact, &Fact::valueChanged, this, &VideoSettings::_configChanged);
    }
    return _rtspUrlFact;
}

DECLARE_SETTINGSFACT_NO_FUNC(VideoSettings, tcpUrl)
{
    if (!_tcpUrlFact) {
        _tcpUrlFact = _createSettingsFact(tcpUrlName);
        connect(_tcpUrlFact, &Fact::valueChanged, this, &VideoSettings::_configChanged);
    }
    return _tcpUrlFact;
}

bool VideoSettings::streamConfigured(void)
{
#if !defined(QGC_GST_STREAMING)
    return false;
#endif
    bool udpfwden;
    //-- First, check if it's autoconfigured
    if(qgcApp()->toolbox()->videoManager()->autoStreamConfigured()) {
        qCDebug(VideoManagerLog) << "Stream auto configured";
        return true;
    }

    /* disable video fwd if its not enabled */
    udpfwden = udpFwdEn()->rawValue().toBool();
    if (  udpfwden == false )
        _clean_udp_fwd();

    //-- Check if it's disabled
    QString vSource = videoSource()->rawValue().toString();
    if(vSource == videoSourceNoVideo || vSource == videoDisabled) {
        return false;
    }
    //-- If UDP, check if port is set
    if(vSource == videoSourceUDPH264 || vSource == videoSourceUDPH265) {    
        /* check if fwd is enabled */
        QHostAddress dst_address;

        /* check if fwd is enabled */
        if (  udpfwden == true )
        {
            /* validate IP address */
            if ( dst_address.setAddress(udpFwdDstIP()->rawValue().toString()) == true )
                _update_udp_fwd();
        }

        qCDebug(VideoManagerLog) << "Testing configuration for UDP Stream:" << udpPort()->rawValue().toInt();
        return udpPort()->rawValue().toInt() != 0;
    }
    //-- If RTSP, check for URL
    if(vSource == videoSourceRTSP) {
        qCDebug(VideoManagerLog) << "Testing configuration for RTSP Stream:" << rtspUrl()->rawValue().toString();
        return !rtspUrl()->rawValue().toString().isEmpty();
    }
    //-- If TCP, check for URL
    if(vSource == videoSourceTCP) {
        qCDebug(VideoManagerLog) << "Testing configuration for TCP Stream:" << tcpUrl()->rawValue().toString();
        return !tcpUrl()->rawValue().toString().isEmpty();
    }
    //-- If MPEG-TS, check if port is set
    if(vSource == videoSourceMPEGTS) {
        qCDebug(VideoManagerLog) << "Testing configuration for MPEG-TS Stream:" << udpPort()->rawValue().toInt();
        return udpPort()->rawValue().toInt() != 0;
    }

    return false;
}

void VideoSettings::_configChanged(QVariant)
{
    emit streamConfiguredChanged(streamConfigured());
}



void VideoSettings::_clean_udp_fwd()
{
    /* clean the socket */
    if ( _udp_socket )
    {
        qCDebug(VideoManagerLog) << "_clean_udp_fwd - purging udp fwd";
        disconnect(_udp_socket, &QUdpSocket::readyRead,this, &VideoSettings::_udp_packet_rx_cb);
        _udp_socket->close();
        delete _udp_socket;
        _udp_socket = nullptr;
    }
}

void VideoSettings::_update_udp_fwd()
{
    /* the IP/Port numbers */
    _udp_local_dst_port = udpPort()->rawValue().toInt();
    _udp_fwd_src_port = udpFwdSrcPort()->rawValue().toInt();
    _udp_fwd_dst_ip = udpFwdDstIP()->rawValue().toString();
    _udp_fwd_dst_port = udpFwdDstPort()->rawValue().toInt();

    /* check if first time */
    if (_udp_socket == nullptr)
    {
        qCDebug(VideoManagerLog) << "Setting Up UDP Video Forward To:" << _udp_fwd_dst_ip << ":" << _udp_fwd_dst_port;
    }
    else
    {
        disconnect(_udp_socket, &QUdpSocket::readyRead,this, &VideoSettings::_udp_packet_rx_cb);
        _udp_socket->close();
        delete _udp_socket;
        qCDebug(VideoManagerLog) << "Reconfigure UDP Video Forward To:" << _udp_fwd_dst_ip << ":" << _udp_fwd_dst_port;
    }

    _udp_socket = new QUdpSocket(this);
    _udp_socket->bind(QHostAddress::Any, _udp_fwd_src_port);

    if ([&]()
    {
        QStringList octets = _udp_fwd_dst_ip.split(".");
        if (octets.size() != 4 || octets[0].toInt() < 224 || octets[0].toInt() > 239
            || (octets[1].toInt() % 256 != octets[1].toInt())
            || (octets[2].toInt() % 256 != octets[2].toInt())
            || (octets[3].toInt() % 256 != octets[3].toInt()))
            return false;

        return true;
    }())
    {
        const int TTL = _udp_socket->socketOption(QAbstractSocket::MulticastTtlOption).toInt();

        // Required for multicast
        _udp_socket->setSocketOption(QAbstractSocket::MulticastTtlOption, std::max<int>(TTL, 64));
    }

    connect(_udp_socket, &QUdpSocket::readyRead,this, &VideoSettings::_udp_packet_rx_cb);
}


void VideoSettings::_udp_packet_rx_cb()
{
    while (_udp_socket->hasPendingDatagrams())
    {
        QNetworkDatagram datagram = _udp_socket->receiveDatagram();     
        _udp_socket->writeDatagram(datagram.data(), QHostAddress::LocalHost, _udp_local_dst_port);
        _udp_socket->writeDatagram(datagram.data(), QHostAddress(_udp_fwd_dst_ip), _udp_fwd_dst_port);
    }
}
