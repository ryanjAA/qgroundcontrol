#include "NvExt_CameraManagement.h"
#include "../Joystick/JoystickManager.h"
#include "../Terrain/TerrainQuery.h"
#include "QGCApplication.h"
#include "TerrainQuery.h"
#include "SettingsManager.h"


Q_GLOBAL_STATIC(TerrainTileManager, _terrainTileManager)

CameraManagement::CameraManagement(QObject *parent,MultiVehicleManager *multiVehicleManager, JoystickManager *joystickManager) : QObject(parent),_multiVehicleManager(nullptr),activeVehicle(nullptr),_joystickManager(nullptr)
{
    this->_multiVehicleManager = multiVehicleManager;
    this->_joystickManager = joystickManager;
    activeVehicle = _multiVehicleManager->activeVehicle();
    connect(_multiVehicleManager, &MultiVehicleManager::activeVehicleChanged, this, &CameraManagement::_activeVehicleChanged);
    connect(this->_joystickManager, &JoystickManager::activeCamJoystickChanged, this, &CameraManagement::_activeCamJoystickChanged);

    /* connect the tile loaded signal to the cache worker */
    QGCMapEngine *map_engine = getQGCMapEngine();
    QGCCacheWorker *worker = &map_engine->_worker;
    connect(worker, &QGCCacheWorker::tileLoaded, this, &CameraManagement::addTileToCahce);
}

void CameraManagement::_activeVehicleChanged(Vehicle* activeVehicle)
{
    this->activeVehicle = activeVehicle;
    if(activeVehicle){
        float time = QDateTime::currentSecsSinceEpoch();
        /* Sending the system time to the vehicle */
        sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemTime,time,0,0,0,0,0);

        /* load all elevation tiles to cache when the Vehicle is connected */
        QGCLoadElevationTileSetsTask* taskSave = new QGCLoadElevationTileSetsTask();
        getQGCMapEngine()->addTask(taskSave);
    }
}

void CameraManagement::_activeCamJoystickChanged(Joystick* activeCamJoystick)
{
    if(activeCamJoystick){
        /* connect to joystick manual cam control message */
        connect(activeCamJoystick, &Joystick::manualControlCam, this, &CameraManagement::manualCamControl);
        this->_activeCamJoystick = activeCamJoystick;

        /* clear the camera button state machine vars */
        for ( int i = 0; i < 32;i++ ){
            _camButtonFuncState[i] = JoyBtnReleased;
            _camButtonFuncValue[i] = 0;
        }
    }
    else
    {
        if ( this->_activeCamJoystick )
            disconnect(this->_activeCamJoystick, &Joystick::manualControlCam, this, &CameraManagement::manualCamControl);
        this->_activeCamJoystick = activeCamJoystick;
    }
}

void CameraManagement::manualCamControl(float cam_roll_yaw, float cam_pitch,unsigned char* buttons)
{
    static int prev_zoom_value = -1;
    QList<AssignedButtonAction*> button_actions;
    if (!activeVehicle) {
        return;
    }

    WeakLinkInterfacePtr weakLink = activeVehicle->vehicleLinkManager()->primaryLink();
    if (weakLink.expired()) {
        return;
    }

    if (!_activeCamJoystick) {
        return;
    }

    /* read the current joystick configuration */
    button_actions = _activeCamJoystick->_buttonCamActionArray;

    /* call the button functions for each button */
    for (int buttonIndex=0; buttonIndex<_activeCamJoystick->totalButtonCount(); buttonIndex++)
    {
        //bool button_value = (buttons & (1 << buttonIndex)) ? true :false;
        AssignedButtonAction *button_action = button_actions.at(buttonIndex);
        if ( !button_action )
            continue;
        doCamAction(button_action->action,buttons[buttonIndex],buttonIndex);
    }

    /* call the button functions for each button */
   /* for (int buttonIndex=0; buttonIndex<activeJoystick->totalButtonCount(); buttonIndex++)
    {
        bool button_value = (buttons & (1 << buttonIndex)) ? true :false;
        doCamAction(_camButtonActionsMap[buttonIndex],button_value,buttonIndex);

    }*/

    /* Calculating the zoom value */
    int zoomValue = getZoomValue(buttons,button_actions);
    if ( prev_zoom_value != zoomValue )
    {
        prev_zoom_value = zoomValue;

        switch ( zoomValue )
        {
            case MavExtCmdArg_ZoomIn:
                setSysZoomInCommand();
            break;
            case MavExtCmdArg_ZoomOut:
                setSysZoomOutCommand();
            break;
            case MavExtCmdArg_ZoomStop:
                setSysZoomStopCommand();
            break;
        }
    }

    /* send the gimbal command to the system only when virtual joystick is disabled */
    if ( qgcApp()->toolbox()->settingsManager()->appSettings()->virtualJoystick()->rawValue().toBool() == false )
        sendGimbalCommand(cam_roll_yaw/ ( -32768),cam_pitch/ ( -32768));
}


bool CameraManagement::doBtnFuncToggle(bool pressed, int buttonIndex)
{
    switch ( _camButtonFuncState[buttonIndex] )
    {
        case JoyBtnReleased:
        {
            if ( pressed )
            {
                _camButtonFuncState[buttonIndex] = JoyBtnPressed;
            }
        }
        break;
        case JoyBtnPressed:
        {
            if ( !pressed )
            {
                _camButtonFuncValue[buttonIndex] ^= 1;
                _camButtonFuncState[buttonIndex] = JoyBtnReleased;
                return true;
            }
        }
        break;
    }
    return false;
}

void CameraManagement::doCamAction(QString buttonAction, bool pressed, int buttonIndex)
{
    bool doAction = doBtnFuncToggle(pressed,buttonIndex);

    if ( buttonAction.isEmpty() )
        return;

    if (!activeVehicle)
        return;

    if (!activeVehicle->joystickCamEnabled()) {
        return;
    }

    if (buttonAction == "Day / IR")
    {
        /* Day/IR toggle */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSensor,_camButtonFuncValue[buttonIndex],0,0,0,0,0);
    } else if (buttonAction == "White Hot / Black Hot")
    {
        /* Polarity Toggle */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetIrPolarity,_camButtonFuncValue[buttonIndex],0,0,0,0,0);
    }else if(buttonAction == "Image Capture"){
        /* Image Capture */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_TakeSnapShot,0,0,0,0,0,0);
    }else if(buttonAction == "Single Yaw"){
        /* Single Yaw */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSingleYawMode,_camButtonFuncValue[buttonIndex],0,0,0,0,0);
    }else if(buttonAction == "GRR"){
        /* GRR */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_GRR,0,0,0,0,0);
    }else if(buttonAction =="NUC"){
        /* NUC */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_DoNUC,0,0,0,0,0,0);
    }else if(buttonAction =="Stow"){
        /* Stow */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_Stow,0,0,0,0,0);
    }else if(buttonAction =="Pilot"){
        /* Pilot */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_Pilot,0,0,0,0,0);
    }else if(buttonAction =="Retract"){
         /* Retract */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_MOUNT_CONTROL,_camButtonFuncValue[buttonIndex],0,0,0,0,0,0);
    }else if(buttonAction =="Hold Coordinate"){
        /* Hold Coordinate */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_Hold,0,0,0,0,0);
    }else if(buttonAction =="Observation"){
        /* Observation */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_Observation,0,0,0,0,0);
    }else if(buttonAction =="Record"){
        /* Record */
        if (doAction)
            sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetRecordState,_camButtonFuncValue[buttonIndex],0,0,0,0,0);
    }
}

/* Returning the zoom value according to the buttons pressed */
CameraManagement::MavlinkExtSetGimbalArgs CameraManagement::getZoomValue(unsigned char* buttons,QList<AssignedButtonAction*> button_actions)
{
    if ( !_activeCamJoystick )
        return MavExtCmdArg_ZoomStop;

    int zoomInVal = 0;
    int zoomOutVal = 0;

    /* call the button functions for each button */
    for (int buttonIndex=0; buttonIndex<_activeCamJoystick->totalButtonCount(); buttonIndex++)
    {
        //bool button_value = (buttons & (1 << buttonIndex)) ? true :false;
        AssignedButtonAction *button_action = button_actions.at(buttonIndex);
        if ( !button_action )
            continue;
        if((button_action->action == "Zoom In") && (buttons[buttonIndex] != 0))
            zoomInVal = 1;
        else if((button_action->action == "Zoom Out") && (buttons[buttonIndex] != 0))
            zoomOutVal = 1;
    }

    if( (zoomInVal == 0 && zoomOutVal == 0) || (zoomInVal == 1 && zoomOutVal == 1) )
        return MavExtCmdArg_ZoomStop;
    else if(zoomInVal == 1)
        return MavExtCmdArg_ZoomIn;
    else
        return MavExtCmdArg_ZoomOut;
}

/* Sending gimbal Command Messages */
void CameraManagement::sendGimbalCommand(float cam_roll_yaw,float cam_pitch)
{
    if(!activeVehicle)
        return;

    WeakLinkInterfacePtr weakLink = activeVehicle->vehicleLinkManager()->primaryLink();
    if (weakLink.expired()) {
        return;
    }
    SharedLinkInterfacePtr sharedLink = weakLink.lock();

    /* check if joystick is enabled */
    if ( activeVehicle->joystickCamEnabled() )
    {
        mavlink_message_t message;
        mavlink_msg_command_long_pack_chan(1,
                                       0,
                                       sharedLink->mavlinkChannel(),
                                       &message,1,0,MAV_CMD_DO_DIGICAM_CONTROL,0,MavExtCmd_SetGimbal,cam_roll_yaw,cam_pitch,MavExtCmdArg_ZoomNoChange,(float)this->gndCrsAltitude,0,0);
        activeVehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
    }
}

/* Sending gimbal Command Messages */
void CameraManagement::sendGimbalVirtualCommand(float cam_roll_yaw,float cam_pitch)
{
    if(!activeVehicle)
        return;

    WeakLinkInterfacePtr weakLink = activeVehicle->vehicleLinkManager()->primaryLink();
    if (weakLink.expired()) {
        return;
    }
    SharedLinkInterfacePtr sharedLink = weakLink.lock();

    /* check if virtual joystick is enabled */
    if ( qgcApp()->toolbox()->settingsManager()->appSettings()->virtualJoystick()->rawValue().toBool() == true )
    {
        mavlink_message_t message;
        mavlink_msg_command_long_pack_chan(1,
                                       0,
                                       sharedLink->mavlinkChannel(),
                                       &message,1,0,MAV_CMD_DO_DIGICAM_CONTROL,0,MavExtCmd_SetGimbal,cam_roll_yaw,cam_pitch,MavExtCmdArg_ZoomNoChange,(float)this->gndCrsAltitude,0,0);

        activeVehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
    }
}

/* Sending Mavlink Command Long Messages */
void CameraManagement::sendMavCommandLong(MAV_CMD command,  float param1,   float param2,   float param3,
                                          float param4,     float param5,   float param6,   float param7)
{
    if(!activeVehicle)
        return;

    WeakLinkInterfacePtr weakLink = activeVehicle->vehicleLinkManager()->primaryLink();
    if (weakLink.expired()) {
        return;
    }

    activeVehicle->sendMavCommand(activeVehicle->defaultComponentId(),
                   command,
                   true,
                   param1, param2, param3, param4, param5, param6, param7);
}

void CameraManagement::addTileToCahce(QString tile_hash, QByteArray tile_data)
{
    _terrainTileManager->addTileToCahce(tile_data,tile_hash);
}

void CameraManagement::getAltAtCoord(float lat,float lon)
{
    double terrainAltitude;
    QGeoCoordinate coord;

    coord.setLatitude(lat);
    coord.setLongitude(lon);

    /* check if we have this data cached */
    if( _terrainTileManager->requestCahcedData(coord,terrainAltitude) )
        this->gndCrsAltitude = terrainAltitude;     /* save the value, will be transmitted to the TRIP2 in the next Gimbal or GndAlt message */

    if ( !activeVehicle )
        return;

    /* when the virtual joystick is disabled set gnd crs alt here */
    if ( qgcApp()->toolbox()->settingsManager()->appSettings()->virtualJoystick()->rawValue().toBool() == false ||
         activeVehicle->joystickCamEnabled() )
    {
        mavlink_message_t message;

        if(!activeVehicle)
            return;

        WeakLinkInterfacePtr weakLink = activeVehicle->vehicleLinkManager()->primaryLink();
        if (weakLink.expired()) {
            return;
        }
        SharedLinkInterfacePtr sharedLink = weakLink.lock();

        /* when the virtual joystick is disabled send the ground altitude from here instead */
        mavlink_msg_command_long_pack_chan(1,
                                           0,
                                           sharedLink->mavlinkChannel(),
                                           &message,1,0,MAV_CMD_DO_DIGICAM_CONTROL,0,MavExtCmd_SetGroundCrossingAlt,(float)this->gndCrsAltitude,0,0,0,0,0);
        activeVehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
    }
}

void CameraManagement::pointToCoordinate(float lat,float lon)
{
    double terrainAltitude;

    _coord.setLatitude(lat);
    _coord.setLongitude(lon);

    /* first check if we have this data cached */
    if ( _terrainTileManager->requestCahcedData(_coord,terrainAltitude) == false )
    {
        TerrainAtCoordinateQuery* terrain = new TerrainAtCoordinateQuery(true);
        connect(terrain, &TerrainAtCoordinateQuery::terrainDataReceived, this, &CameraManagement::_terrainDataReceived);
        QList<QGeoCoordinate> rgCoord;
        rgCoord.append(_coord);
        terrain->requestData(rgCoord);        
    }
    else
    {
        sendMavCommandLong(MAV_CMD_DO_SET_ROI_LOCATION,0.0,0.0,0.0,0.0,_coord.latitude(),_coord.longitude(),terrainAltitude);
        //qDebug() << "00 PTC On lat= " << (int)(_coord.latitude() * 10000000.0) << " lon = " << (int)(_coord.longitude() * 10000000.0 )<< " alt = " << terrainAltitude;
    }
}

void CameraManagement::_terrainDataReceived(bool success, QList<double> heights)
{
    double _terrainAltitude = success ? heights[0] : 0;
    sendMavCommandLong(MAV_CMD_DO_SET_ROI_LOCATION,0.0,0.0,0.0,0.0,_coord.latitude(),_coord.longitude(),_terrainAltitude);
    //qDebug() << "11 PTC On lat= " << (int)(_coord.latitude() * 10000000.0) << " lon = " << (int)(_coord.longitude() * 10000000.0 )<< " alt = " << _terrainAltitude;
    //sender()->deleteLater();
}

void CameraManagement::trackOnPosition(float posX,float posY, int chan)
{
    // qDebug() << "11 PTC On lat= " << chan <<"\n";
    /* Sending the track on position command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_TrackOnPosition,posX,posY,0,(float)chan,0);
}

void CameraManagement::setSysModeObsCommand()
{
    /* Sending the OBS command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_Observation,0,0,0,0,0);
}

void CameraManagement::setSysModeGrrCommand()
{
    /* Sending the GRR command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_GRR,0,0,0,0,0);
}

void CameraManagement::setSysModeEprCommand()
{
    /* Sending the EPR command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_EPR,0,0,0,0,0);
}

void CameraManagement::setSysModeHoldCommand()
{
    /* Sending the Hold command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_Hold,0,0,0,0,0);
}

void CameraManagement::setSysModePilotCommand()
{
    /* Sending the Pilot command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_Pilot,0,0,0,0,0);
}

void CameraManagement::setSysModeStowCommand()
{
    /* Sending the Stow command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_Stow,0,0,0,0,0);
}

void CameraManagement::setSysModeRetractCommand()
{
    /* Sending the Retract command */
    sendMavCommandLong(MAV_CMD_DO_MOUNT_CONTROL,0,0,0,0,0,0,0);
}

void CameraManagement::setSysModeRetractUnlockCommand()
{
    /* Sending retract release command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_ClearRetractLock,0,0,0,0,0,0);
}

void CameraManagement::setSysZoomStopCommand()
{
    /* Sending retract release command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetZoom,0,0,0,0,0,0);
}

void CameraManagement::setSysZoomInCommand()
{
    /* Sending retract release command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetZoom,1,0,0,0,0,0);
}

void CameraManagement::setSysZoomOutCommand()
{
    /* Sending retract release command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetZoom,2,0,0,0,0,0);
}

void CameraManagement::setSysSensorToggleCommand()
{
    /* Toggle the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSensor,MavExtCmdArg_ToggleSensor,0,0,0,0,0);
}

void CameraManagement::setSysSensorDayCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSensor,MavExtCmdArg_DaySensor,0,0,0,0,0);
}

void CameraManagement::setSysSensorIrCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSensor,MavExtCmdArg_IrSensor,0,0,0,0,0);
}

void CameraManagement::setSysIrPolarityToggleCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetIrPolarity,MavExtCmdArg_TogglePolarity,0,0,0,0,0);
}

void CameraManagement::setSysIrPolarityWHCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetIrPolarity,MavExtCmdArg_WhiteHot,0,0,0,0,0);
}

void CameraManagement::setSysIrPolarityBHCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetIrPolarity,MavExtCmdArg_BlackHot,0,0,0,0,0);
}

void CameraManagement::setSysIrColorPCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetIrColor,MavExtCmdArg_Color_P,0,0,0,0,0);
}

void CameraManagement::setSysIrBWPCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetIrColor,MavExtCmdArg_BW_P,0,0,0,0,0);
}

void CameraManagement::setSysIrNUCCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_DoNUC,0,0,0,0,0,0);
}

void CameraManagement::setSysIrGainLevelCommand(int cmd)
{
    /* Set the gain/level command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetIRGainLevel,cmd,0,0,0,0,0);
}

void CameraManagement::setSysRecToggleCommand(int chan)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetRecordState,MavExtCmdArg_Toggle,(float)chan,0,0,0,0);
}

void CameraManagement::setSysRecOnCommand(int chan)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetRecordState,MavExtCmdArg_Enable,(float)chan,0,0,0,0);
}

void CameraManagement::setSysRecOffCommand(int chan)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetRecordState,MavExtCmdArg_Disable,(float)chan,0,0,0,0);
}

void CameraManagement::setSysSnapshotCommand(int chan)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_TakeSnapShot,(float)chan,0,0,0,0,0);
}

void CameraManagement::setSysAutoSnapshotCommand(int interval, int count, bool inf, int chan)
{
    /* Set the system sensor */
    /* inf override */
    if ( inf )
        count = -1;

    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SnapShotInterval,(float)interval,(float)count,(float)chan,0,0,0);
}

void CameraManagement::setSysFOVCommand(float fov_value)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetFOV,fov_value,0,0,0,0,0);
}

void CameraManagement::setSysModeLocalPositionCommand(int pitch, int roll)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_LocalPosition,pitch,roll,0,0,0);
}

void CameraManagement::setSysModeGlobalPositionCommand( int elevation, int azimuth )
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_GlobalPosition,elevation,azimuth,0,0,0);
}

void CameraManagement::setSysSingleYawOnCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSingleYawMode,1,0,0,0,0,0);
}

void CameraManagement::setSysSingleYawOffCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSingleYawMode,0,0,0,0,0,0);
}
void CameraManagement::setSysFlyAboveOnCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetFlyAbove,1,0,0,0,0,0);
}

void CameraManagement::setSysFlyAboveOffCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetFlyAbove,0,0,0,0,0,0);
}

void CameraManagement::setSysFollowOnCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetFollowMode,1,0,0,0,0,0);
}

void CameraManagement::setSysFollowOffCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetFollowMode,0,0,0,0,0,0);
}

void CameraManagement::setSysNadirCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_Nadir,0,0,0,0,0);
}

void CameraManagement::setSysNadirScanCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_NadirScan,0,0,0,0,0);
}

void CameraManagement::setSysObjDetOnCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_DetectionControl,MavExtCmdArg_DetectorEnDis,1,0,0,0,0);
}
void CameraManagement::setSysObjDetOffCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_DetectionControl,MavExtCmdArg_DetectorEnDis,0,0,0,0,0);
}

void CameraManagement::setSysObjDetSetNetTypeCommand(int netType)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_DetectionControl,MavExtCmdArg_DetectorSelect,(float)netType,0,0,0,0);
}

void CameraManagement::setSysObjDetSetConfThresCommand(float confThres)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_DetectionControl,MavExtCmdArg_DetectorConfThres,confThres,0,0,0,0);
}

void CameraManagement::setSysObjDetSetFireThresCommand(float fireThres)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_DetectionControl,MavExtCmdArg_DetectorFireThres,fireThres,0,0,0,0);
}

void CameraManagement::setSysGeoAVGOnCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetGeoAvg,1,0,0,0,0,0);
}

void CameraManagement::setSysGeoAVGOffCommand(void)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetGeoAvg,0,0,0,0,0,0);
}

void CameraManagement::setSysVividEnabled(bool enabled)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetVividState, enabled ? 1 : 0,0,0,0,0,0);
}

void CameraManagement::setSysSetFocusState(bool IsNear, bool IsFar, bool IsInf)
{
    auto _state = MavExtCmdArg_Stop;

    if (IsNear)
        _state = MavExtCmdArg_Near;
    if (IsFar)
        _state = MavExtCmdArg_Far;
    if (IsInf)
        _state = MavExtCmdArg_Inf;

    /* Set Focus State */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetFocusState, (float)(int)_state,0,0,0,0,0);
}

void CameraManagement::doRescue()
{
    /* Set Focus State */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_DoRescue, 0,0,0,0,0,0);
}

void CameraManagement::setCameraMotorState(bool enabled)
{
    /* Set Focus State */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetCameraMotorState, enabled ? 1 : 0,0,0,0,0,0);
}
bool CameraManagement::getShouldUiEnabledRescueElement()
{
    /* Set Focus State */
    return m_should_enable_rescue_btn == 1;
}
void CameraManagement::setSysMode2DScanCommand()
{
    /* Sending the OBS command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_2DScan,0,0,0,0,0);
}

void CameraManagement::setSysStreamModeCommand(int chan0Mode, int chan1Mode)
{
    /* Sending the OBS command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_StreamControl,MavExtCmdArg_SetStreamMode,(float)chan0Mode,(float)chan1Mode,0,0,0);
}

void CameraManagement::setSysPIPModeCommand(int mode)
{
    /* Sending the OBS command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_StreamControl,MavExtCmdArg_SetPIPMode,(float)mode,0,0,0,0);
}

void CameraManagement::setSysSBSModeCommand(int mode)
{
    /* Sending the OBS command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_StreamControl,MavExtCmdArg_SetSBSMode,(float)mode,0,0,0,0);
}

void CameraManagement::setSysVMDOnCommand(void)
{
    /* Sending the OBS command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_VMDControl,MavExtCmdArg_VMDEnable,1,0,0,0,0);
}

void CameraManagement::setSysVMDOffCommand(void)
{
    /* Sending the OBS command */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_VMDControl,MavExtCmdArg_VMDEnable,0,0,0,0,0);
}

void CameraManagement::setSysModeUnstabilizedPositionCommand(int pitch, int roll)
{
    /* Set the system sensor */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetSystemMode,MavExtCmdArg_UnstabilizedPosition,pitch,roll,0,0,0);
}

void CameraManagement::setSysActiveTrackerCommand(int index)
{
    /* Set the active tracker */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_TrackControl,MavExtCmdArg_SetActiveTracker,index,0,0,0,0);
}

void CameraManagement::setSysPrimaryTrackerCommand(int index)
{
    /* Set the primary tracker */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_TrackControl,MavExtCmdArg_SetPrimaryTracker,index,0,0,0,0);
}

void CameraManagement::setSysTrackerROICommand(int index)
{
    /* Set the primary tracker */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_TrackControl,MavExtCmdArg_SetTrackerROI,index,0,0,0,0);
}

void CameraManagement::setSysSetIRNoiseReductionLevelCommand(int index)
{
    /* Set the IR Noise Reduction level */
    sendMavCommandLong(MAV_CMD_DO_DIGICAM_CONTROL,MavExtCmd_SetIRNoiseReductionLevel,index,0,0,0,0,0);
}
