/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts  1.15
import QtQuick.Dialogs  1.3

import QGroundControl                   1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.Palette           1.0

// Self-contained, offline Albatross altitude / parameter calculator.
// Ported from the standalone HTML tool. Applied Aeronautics Albatross on
// PX4 v1.14 only. All physics runs locally - no internet required.
QGCPopupDialog {
    id:         root
    title:      qsTr("Albatross Altitude Parameter Calculator")
    buttons:    StandardButton.Close

    // Passed in via showPopupDialogFromComponent(properties)
    property var missionController: null

    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle
    property bool _haveFW:          _activeVehicle && _activeVehicle.fixedWing
    property bool _armed:           _activeVehicle ? _activeVehicle.armed : false

    readonly property real _fpw:        ScreenTools.defaultFontPixelWidth
    readonly property real _fph:        ScreenTools.defaultFontPixelHeight
    readonly property real _contentW:   _fpw * 60

    readonly property color _cAccent:   "#4fc3f7"
    readonly property color _cGood:     "#81c784"
    readonly property color _cWarn:     "#ffb74d"
    readonly property color _cDanger:   "#ef5350"
    readonly property color _cMuted:    "#888888"

    // ----- Albatross constants (mirror of the HTML tool) -----
    readonly property real _WING_AREA:              0.66
    readonly property real _CL_NO_FLAPS:            1.02
    readonly property real _CL_FLAPS:               1.2
    readonly property real _RHO_SL:                 1.225
    readonly property real _G:                      9.81
    readonly property real _BASELINE_WEIGHT:        8.1
    readonly property real _BASELINE_TRIM_AIRSPEED: 20.0
    readonly property real _MIN_AIRSPD_MIN:         18.5
    readonly property real _MOTOR_420_BASELINE:     0.367
    readonly property real _MOTOR_540_BASELINE:     0.276
    readonly property real _BATTERY_CAPACITY:       14000

    // ----- Inputs (kept in the user's selected display units) -----
    property string _altUnit:       "ft"        // "ft" | "m"
    property string _tempUnit:      "f"         // "f"  | "c"
    property string _weightUnit:    "kg"        // "kg" | "lb"
    property string _motor:         "420"       // "420"| "540"
    property string _climb:         "efficient" // "efficient" | "conservative"
    property int    _batteries:     1
    property real   _weightKg:      8.0          // physics always uses kg internally
    property real   _takeoffAltIn:  500
    property real   _maxAltIn:      1000
    property real   _tempIn:        59

    // Battery: capacity (mAh) actually used by the estimates. Pulled from the
    // connected aircraft when available, otherwise the manual pack selector.
    property real   _battCapacityMah:   14000
    property string _battSource:        qsTr("manual (1 x 14 Ah)")

    // ----- Result fields -----
    property string _densityRatioTxt:   "-"
    property string _densityAltTxt:     "-"
    property string _tasEasTxt:         "-"
    property string _stallNFTxt:        "-"
    property string _stallFTxt:         "-"
    property string _stallMargin1gTxt:  "-"
    property int    _stallMargin1gLvl:  0
    property string _thrToTxt:          "-"
    property int    _thrToLvl:          0
    property string _thrMaxTxt:         "-"
    property string _thrMarginTxt:      "-"
    property int    _thrMaxLvl:         0
    property string _enduranceTxt:      "-"
    property string _rangeTxt:          "-"
    property string _cruiseCurTxt:      "-"
    property int    _enduranceLvl:      0
    property string _tkoStallTxt:       "-"
    property string _tkoTrimTxt:        "-"
    property int    _tkoStallLvl:       0
    property int    _tkoTrimLvl:        0
    property string _altSuffix:         "ft"

    // levelColor: 0 good, 1 warn, 2 danger
    function levelColor(lvl) { return lvl === 2 ? _cDanger : (lvl === 1 ? _cWarn : _cGood) }

    // ----- Unit helpers -----
    function ftToM(ft)  { return ft * 0.3048 }
    function mToFt(m)   { return m / 0.3048 }
    function cToF(c)    { return (c * 9/5) + 32 }
    function fToC(f)    { return (f - 32) * 5/9 }
    function altToFeet(v)   { return _altUnit === "m" ? mToFt(v) : v }
    function feetToAlt(ft)  { return _altUnit === "m" ? ftToM(ft) : ft }
    function tempToC(v)     { return _tempUnit === "f" ? fToC(v) : v }
    function fmtAlt(ft)     { return Math.round(feetToAlt(ft)).toLocaleString() }
    function lbToKg(lb)     { return lb * 0.45359237 }
    function kgToLb(kg)     { return kg / 0.45359237 }
    // _weightKg is the source of truth; show it in the selected unit.
    function weightDisp()   { return _weightUnit === "lb" ? kgToLb(_weightKg) : _weightKg }
    function weightUnitStr() { return _weightUnit === "lb" ? "lb" : "kg" }

    // ----- Physics (identical to the HTML tool) -----
    function calcDensity(altFt, tempC) {
        var altM = altFt * 0.3048
        var tempK = tempC + 273.15
        var isaTempK = (15 - 0.0065 * altM) + 273.15
        var pressureRatio = Math.pow(1 - 0.0065 * altM / 288.15, 5.2561)
        return pressureRatio * (isaTempK / tempK)
    }
    function calcDensityAltitude(altFt, tempC) {
        var altM = altFt * 0.3048
        var isaTemp = 15 - 0.0065 * altM
        return altFt + (120 * (tempC - isaTemp))
    }
    function calcStallSpeed(weight, cl) {
        return Math.sqrt((2 * weight * _G) / (_RHO_SL * _WING_AREA * cl))
    }
    function calcThrottle(altFt, weight, baselineThrottle, tempC) {
        var densityRatio = calcDensity(altFt, tempC)
        var throttle = baselineThrottle * Math.pow(weight / _BASELINE_WEIGHT, 1.5) / Math.sqrt(densityRatio)
        return Math.min(1.0, throttle)
    }
    function getClimbParams(throttleMargin) {
        if (_climb === "efficient") {
            if (throttleMargin > 35) return { clmbMax: 5.5, clmbSp: 3.0 }
            if (throttleMargin > 25) return { clmbMax: 4.0, clmbSp: 2.5 }
            if (throttleMargin > 15) return { clmbMax: 3.0, clmbSp: 2.0 }
            if (throttleMargin > 10) return { clmbMax: 2.0, clmbSp: 1.5 }
            if (throttleMargin > 5)  return { clmbMax: 1.5, clmbSp: 1.0 }
            return { clmbMax: 1.0, clmbSp: 0.5 }
        } else {
            if (throttleMargin > 35) return { clmbMax: 3.0, clmbSp: 2.0 }
            if (throttleMargin > 25) return { clmbMax: 2.5, clmbSp: 1.5 }
            if (throttleMargin > 15) return { clmbMax: 2.0, clmbSp: 1.0 }
            if (throttleMargin > 10) return { clmbMax: 1.5, clmbSp: 1.0 }
            if (throttleMargin > 5)  return { clmbMax: 1.0, clmbSp: 0.5 }
            return { clmbMax: 0.5, clmbSp: 0.5 }
        }
    }
    function predictCurrent(throttlePct, altFt) {
        var thr = Math.min(100, Math.max(0, throttlePct))
        var m = (_motor === "540")
            ? { lowSlope:0.180, lowIntercept:1.8, highSlope:0.150, highIntercept:4.0, lowAlt:3000, highAlt:4000 }
            : { lowSlope:0.154, lowIntercept:1.5, highSlope:0.150, highIntercept:3.0, lowAlt:3000, highAlt:4000 }
        var minLow = 8.0, minHigh = 9.0
        var slope, intercept, minCur
        if (altFt <= m.lowAlt)       { slope = m.lowSlope;  intercept = m.lowIntercept;  minCur = minLow }
        else if (altFt >= m.highAlt) { slope = m.highSlope; intercept = m.highIntercept; minCur = minHigh }
        else {
            var f = (altFt - m.lowAlt) / (m.highAlt - m.lowAlt)
            slope     = m.lowSlope * (1-f)     + m.highSlope * f
            intercept = m.lowIntercept * (1-f) + m.highIntercept * f
            minCur    = minLow * (1-f)         + minHigh * f
        }
        return Math.max(minCur, slope * thr + intercept)
    }

    // ----- Parameter safety classification -----
    // GROUND ONLY params (red badge, disabled when armed)
    readonly property var _groundOnlyParams: ["FW_THR_TRIM", "FW_TKO_AIRSPD", "FW_TKO_PITCH_MIN"]
    function isGroundOnly(name) { return _groundOnlyParams.indexOf(name) !== -1 }

    // PX4 FW_THR_TRIM is normalized 0..1; the tool works in percent.
    function paramApplyValue(name, pct, raw) {
        if (name === "FW_THR_TRIM") return pct / 100.0
        return raw
    }

    function writeParam(name, value) {
        if (!_haveFW || !_activeVehicle.parameterManager) {
            mainWindow.showMessageDialog(qsTr("Alt Calc"), qsTr("No fixed-wing vehicle connected - parameters can only be applied to a connected fixed-wing vehicle."))
            return false
        }
        if (!_activeVehicle.parameterManager.parameterExists(-1, name)) {
            mainWindow.showMessageDialog(qsTr("Alt Calc"), qsTr("Parameter %1 does not exist on this vehicle.").arg(name))
            return false
        }
        if (isGroundOnly(name) && _armed) {
            mainWindow.showMessageDialog(qsTr("Alt Calc"), qsTr("%1 is GROUND ONLY and cannot be changed while armed.").arg(name))
            return false
        }
        _activeVehicle.parameterManager.getParameter(-1, name).value = value
        return true
    }

    function applyChangeRow(idx) {
        var c = paramChangesModel.get(idx)
        if (writeParam(c.paramName, c.applyValue)) {
            mainWindow.showMessageDialog(qsTr("Alt Calc"), qsTr("Applied %1 = %2").arg(c.paramName).arg(c.recText))
        }
    }

    function applyBulk() {
        // When armed (or always for safety) skip GROUND ONLY params.
        var skipGround = _armed
        var applied = [], skipped = []
        for (var i = 0; i < paramChangesModel.count; ++i) {
            var c = paramChangesModel.get(i)
            if (c.groundOnly && skipGround) { skipped.push(c.paramName); continue }
            if (writeParam(c.paramName, c.applyValue)) applied.push(c.paramName)
        }
        var msg = applied.length ? qsTr("Applied: %1").arg(applied.join(", ")) : qsTr("No parameters applied.")
        if (skipped.length) msg += "\n" + qsTr("Skipped (GROUND ONLY, armed): %1").arg(skipped.join(", "))
        mainWindow.showMessageDialog(qsTr("Alt Calc"), msg)
    }

    function applySteppedRow(idx) {
        var r = steppedModel.get(idx)
        var okMax = writeParam("FW_T_CLMB_MAX", r.clmbMaxVal)
        var okSp  = writeParam("FW_T_CLMB_R_SP", r.clmbSpVal)
        if (okMax || okSp) {
            mainWindow.showMessageDialog(qsTr("Alt Calc"),
                qsTr("Applied for %1:\nFW_T_CLMB_MAX = %2 m/s\nFW_T_CLMB_R_SP = %3 m/s")
                    .arg(r.altLabel).arg(r.clmbMaxVal.toFixed(1)).arg(r.clmbSpVal.toFixed(1)))
        }
    }

    // ----- Auto-populate helpers -----
    function fillFromGps() {
        if (!_activeVehicle || !_activeVehicle.altitudeAMSL) {
            mainWindow.showMessageDialog(qsTr("Alt Calc"), qsTr("No vehicle GPS altitude available."))
            return
        }
        var amslM = _activeVehicle.altitudeAMSL.rawValue
        _takeoffAltIn = Math.round(feetToAlt(mToFt(amslM)))
        recompute()
    }

    function itemAltMeters(item) {
        var a = item.altitude
        if (a === undefined || a === null) return 0
        if (typeof a === "object" && a.rawValue !== undefined) return a.rawValue
        if (typeof a === "number") return a
        return 0
    }

    function fillFromMission() {
        if (!missionController || !missionController.visualItems) {
            mainWindow.showMessageDialog(qsTr("Alt Calc"), qsTr("No mission available."))
            return
        }
        var items = missionController.visualItems
        var maxAglM = 0, found = false
        for (var i = 0; i < items.count; ++i) {
            var it = items.get(i)
            if (it && it.specifiesCoordinate) {
                var altM = itemAltMeters(it)
                if (altM > maxAglM) { maxAglM = altM; found = true }
            }
        }
        if (!found) {
            mainWindow.showMessageDialog(qsTr("Alt Calc"), qsTr("No waypoints with altitude found in the mission."))
            return
        }
        // Highest waypoint is above the takeoff point - add it to takeoff MSL.
        var takeoffFt = altToFeet(_takeoffAltIn)
        var newMaxFt  = takeoffFt + mToFt(maxAglM)
        _maxAltIn = Math.round(feetToAlt(newMaxFt))
        recompute()
    }

    // Total pack capacity (mAh) configured on the connected vehicle, or 0.
    function vehicleBatteryMah() {
        if (!_activeVehicle || !_activeVehicle.parameterManager) return 0
        var pm = _activeVehicle.parameterManager
        var names = ["BAT1_CAPACITY", "BAT_CAPACITY", "BATT_CAPACITY", "BAT2_CAPACITY"]
        for (var i = 0; i < names.length; ++i) {
            if (pm.parameterExists(-1, names[i])) {
                var v = pm.getParameter(-1, names[i]).rawValue
                if (v && v > 0) return v
            }
        }
        return 0
    }

    // Pull real battery capacity from the aircraft so endurance/range are
    // accurate. Returns true if a vehicle value was applied.
    function pullBatteryFromVehicle(showMsg) {
        var mah = vehicleBatteryMah()
        if (mah > 0) {
            _battCapacityMah = mah
            _battSource = qsTr("vehicle (%1 mAh)").arg(Math.round(mah).toLocaleString())
            recompute()
            return true
        }
        if (showMsg)
            mainWindow.showMessageDialog(qsTr("Alt Calc"),
                qsTr("No battery capacity available from the vehicle (BAT*_CAPACITY). Using the manual pack selection - estimates may be off if it does not match the actual battery."))
        return false
    }

    function setBatteriesManual(n) {
        _batteries = n
        _battCapacityMah = n * _BATTERY_CAPACITY
        _battSource = qsTr("manual (%1 x 14 Ah)").arg(n)
        recompute()
    }

    // ----- Core recompute: mirrors calculate() + buildSteppedTable() -----
    function recompute() {
        var weight      = _weightKg
        var takeoffAlt  = altToFeet(_takeoffAltIn)
        var maxAlt      = altToFeet(_maxAltIn)
        var temp        = tempToC(_tempIn)
        var baseline    = (_motor === "540") ? _MOTOR_540_BASELINE : _MOTOR_420_BASELINE
        _altSuffix      = _altUnit === "m" ? "m" : "ft"

        var densityRatioTO  = calcDensity(takeoffAlt, temp)
        var densityAltTO    = calcDensityAltitude(takeoffAlt, temp)
        var densityRatioMax = calcDensity(maxAlt, temp)
        var densityAltMax   = calcDensityAltitude(maxAlt, temp)
        var tasEasMax       = 1 / Math.sqrt(densityRatioMax)

        var stallNF = calcStallSpeed(weight, _CL_NO_FLAPS)
        var stallF  = calcStallSpeed(weight, _CL_FLAPS)

        var thrTO   = calcThrottle(takeoffAlt, weight, baseline, temp)
        var thrMax  = calcThrottle(maxAlt, weight, baseline, temp)
        var marginTO  = (1.0 - thrTO) * 100
        var marginMax = (1.0 - thrMax) * 100
        var throttleRequired = thrMax
        var throttleMargin   = marginMax

        var recStall = stallNF
        var recTrim  = _BASELINE_TRIM_AIRSPEED
        var recTko   = (throttleMargin < 15) ? recTrim : 19.0
        var recThrTrim = Math.min(95, throttleRequired * 100)
        var cp = getClimbParams(throttleMargin)

        // Atmospheric
        _densityRatioTxt = densityRatioTO.toFixed(3)
        _densityAltTxt   = fmtAlt(densityAltTO)
        _tasEasTxt       = tasEasMax.toFixed(2)

        // Stall
        _stallNFTxt = stallNF.toFixed(1) + " m/s"
        _stallFTxt  = stallF.toFixed(1) + " m/s"
        var m1g = recTrim - stallNF
        _stallMargin1gTxt = m1g.toFixed(1) + " m/s"
        _stallMargin1gLvl = m1g < 3 ? 2 : (m1g < 4 ? 1 : 0)

        // Throttle budget
        _thrToTxt     = Math.min(100, thrTO * 100).toFixed(0) + "%"
        _thrMaxTxt    = Math.min(100, thrMax * 100).toFixed(0) + "%"
        _thrMarginTxt = marginMax.toFixed(0) + "%"
        _thrToLvl  = marginTO  < 10 ? 2 : (marginTO  < 20 ? 1 : 0)
        _thrMaxLvl = marginMax < 10 ? 2 : (marginMax < 20 ? 1 : 0)

        // Endurance & range
        var totalCapacity = _battCapacityMah > 0 ? _battCapacityMah : (_batteries * _BATTERY_CAPACITY)
        var usable = totalCapacity * 0.80
        var cruiseThrPct = Math.min(100, thrMax * 100)
        var cruiseCur = predictCurrent(cruiseThrPct, maxAlt)
        var avgClimbAlt = (takeoffAlt + maxAlt) / 2
        var avgClimbThr = (thrTO + thrMax) / 2 * 100 + 8
        var avgClimbCur = predictCurrent(avgClimbThr, avgClimbAlt)
        var climbAltM = (maxAlt - takeoffAlt) * 0.3048
        var climbTimeSec = climbAltM / cp.clmbSp
        var climbMah = avgClimbCur * (climbTimeSec / 3600) * 1000
        var cruiseHrs = (usable - climbMah) / 1000 / cruiseCur
        var cruiseMin = cruiseHrs * 60
        var cruiseTAS = 20 / Math.sqrt(densityRatioMax)
        var rangeMi = cruiseTAS * cruiseHrs * 3.6 * 0.621371
        _enduranceTxt = (isFinite(cruiseMin) ? cruiseMin.toFixed(0) : "0") + " min"
        _rangeTxt     = (isFinite(rangeMi) ? rangeMi.toFixed(0) : "0") + " mi"
        _cruiseCurTxt = cruiseCur.toFixed(1) + " A"
        _enduranceLvl = cruiseMin < 30 ? 2 : (cruiseMin < 60 ? 1 : 0)

        // Safety margins
        var tkoStall = recTko - recStall
        var tkoTrim  = recTrim - recTko
        _tkoStallTxt = tkoStall.toFixed(1) + " m/s"
        _tkoTrimTxt  = tkoTrim.toFixed(1) + " m/s"
        _tkoStallLvl = tkoStall < 4 ? 1 : 0
        _tkoTrimLvl  = (tkoTrim > 0.5 && throttleMargin < 15) ? 2 : (tkoTrim > 0.5 ? 1 : 0)

        // ----- Recommended parameter changes -----
        paramChangesModel.clear()
        var DEFAULT_TKO = 19.0, DEFAULT_THR_TRIM = 60, DEFAULT_CLMB_MAX = 5.5, DEFAULT_CLMB_SP = 3.0
        var SENSIBLE_THR_TRIM = (_motor === "540") ? 50 : 60
        function push(name, defText, recText, applyVal, note) {
            paramChangesModel.append({
                paramName: name, defaultText: defText, recText: recText,
                applyValue: applyVal, note: note, groundOnly: isGroundOnly(name)
            })
        }
        if (throttleMargin < 15 && recTko > DEFAULT_TKO)
            push("FW_TKO_AIRSPD", DEFAULT_TKO.toFixed(1) + " m/s", recTko.toFixed(1) + " m/s", recTko,
                 qsTr("Increased to match trim (low throttle margin prevents acceleration during climb)"))
        if (recThrTrim > SENSIBLE_THR_TRIM + 5)
            push("FW_THR_TRIM", DEFAULT_THR_TRIM + "%", recThrTrim.toFixed(0) + "%", paramApplyValue("FW_THR_TRIM", recThrTrim, 0),
                 qsTr("Increased for high altitude cruise (set for max altitude, do not change in flight)"))
        else if (_motor === "540" && SENSIBLE_THR_TRIM < DEFAULT_THR_TRIM)
            push("FW_THR_TRIM", DEFAULT_THR_TRIM + "%", SENSIBLE_THR_TRIM + "%", paramApplyValue("FW_THR_TRIM", SENSIBLE_THR_TRIM, 0),
                 qsTr("Reduced for high-power motor (default 60% is excessive)"))
        if (cp.clmbMax < DEFAULT_CLMB_MAX - 0.1)
            push("FW_T_CLMB_MAX", DEFAULT_CLMB_MAX.toFixed(1) + " m/s", cp.clmbMax.toFixed(1) + " m/s", cp.clmbMax,
                 qsTr("Reduced for max altitude throttle margin (see stepped table for intermediate values)"))
        if (cp.clmbSp < DEFAULT_CLMB_SP - 0.1)
            push("FW_T_CLMB_R_SP", DEFAULT_CLMB_SP.toFixed(1) + " m/s", cp.clmbSp.toFixed(1) + " m/s", cp.clmbSp,
                 qsTr("Reduced for max altitude throttle margin (see stepped table for intermediate values)"))
        if (throttleMargin < 60)
            push("FW_TKO_PITCH_MIN", "10°", "2°", 2.0,
                 qsTr("Lower pitch = higher airspeed during climb (reduces stall risk at waypoint transition)"))
        var recFlTime = 2.2, recFlAlt = 1.0
        if (densityAltTO > 5000)      { recFlTime = 3.0; recFlAlt = 2.0 }
        else if (densityAltTO > 3000) { recFlTime = 2.5; recFlAlt = 1.5 }
        if (recFlTime > 2.3)
            push("FW_LND_FL_TIME", "2.2 s", recFlTime.toFixed(1) + " s", recFlTime,
                 qsTr("Increased for high density altitude (higher TAS/ground speed)"))
        if (recFlAlt > 1.1)
            push("FW_LND_FLALT", "1.0 m", recFlAlt.toFixed(1) + " m", recFlAlt,
                 qsTr("Increased for high density altitude"))

        // ----- Warnings -----
        warningsModel.clear()
        function warn(level, title, body) { warningsModel.append({ level: level, title: title, body: body }) }
        if (throttleMargin < 10)
            warn(2, qsTr("CRITICAL: Insufficient Throttle Margin at Max Altitude"),
                 qsTr("Throttle required at max altitude: %1%, only %2% margin for climb/maneuvering. With default parameters this condition caused a crash at 9.82kg / 5000ft runway. The changes below mitigate but see motor upgrade.")
                    .arg((throttleRequired*100).toFixed(0)).arg(throttleMargin.toFixed(0)))
        else if (throttleMargin < 15)
            warn(1, qsTr("Low Throttle Margin at Max Altitude"),
                 qsTr("Throttle required %1%, margin %2%. FW_TKO_AIRSPD matched to FW_AIRSPD_TRIM; climb rates reduced to %3 m/s max.")
                    .arg((throttleRequired*100).toFixed(0)).arg(throttleMargin.toFixed(0)).arg(cp.clmbMax.toFixed(1)))
        if (tkoTrim > 0.5 && throttleMargin < 15)
            warn(2, qsTr("Dangerous TKO -> TRIM Gap"),
                 qsTr("Gap of %1 m/s between takeoff and cruise airspeed with only %2% throttle margin - aircraft cannot accelerate during climb. FW_TKO_AIRSPD increased to match FW_AIRSPD_TRIM.")
                    .arg(tkoTrim.toFixed(1)).arg(throttleMargin.toFixed(0)))
        if (densityAltTO > 5000 || densityAltMax > 7000)
            warn(0, qsTr("High Density Altitude Operations"),
                 qsTr("Takeoff DA: %1 %3, max flight DA: %2 %3. TAS at max altitude is %4% above indicated. Landing flare parameters adjusted.")
                    .arg(fmtAlt(densityAltTO)).arg(fmtAlt(densityAltMax)).arg(_altSuffix).arg(((tasEasMax-1)*100).toFixed(0)))
        if (maxAlt > 15000)
            warn(1, qsTr("Beyond Tested Altitude"),
                 qsTr("Max altitude %1 %2 exceeds the tested limit of 15,000 ft MSL. Predictions above this are theoretical extrapolations - test incrementally with telemetry.")
                    .arg(fmtAlt(maxAlt)).arg(_altSuffix))
        if (_climb === "efficient")
            warn(0, qsTr("Efficient Climb Mode"),
                 qsTr("Maximum climb rates where throttle margin allows. Faster climb = less time at altitude = less battery. Switch to Conservative for thermal/motor concerns."))
        else
            warn(0, qsTr("Conservative Climb Mode"),
                 qsTr("Reduced climb rates for extra margin and lower sustained power draw. Trade-off: ~2x battery during climb phase."))
        var serviceCeiling = 0, absoluteCeiling = 0
        for (var ta = 5000; ta <= 35000; ta += 500) {
            var td = calcDensity(ta, temp)
            var tt = baseline * Math.pow(weight / _BASELINE_WEIGHT, 1.5) / Math.sqrt(td)
            if (tt < 0.90) serviceCeiling = ta
            if (tt < 0.95) absoluteCeiling = ta
        }
        var marginAtCeiling = serviceCeiling > maxAlt
            ? ((1 - (baseline * Math.pow(weight / _BASELINE_WEIGHT, 1.5) / Math.sqrt(calcDensity(maxAlt, temp)))) * 100).toFixed(0)
            : "0"
        warn(0, qsTr("Estimated Ceiling (theoretical)"),
             qsTr("Service ceiling (90%% thr): %1 %4 MSL. Absolute ceiling (95%% thr): %2 %4 MSL. Your max altitude: %3% throttle margin. Max tested altitude is 15,000 ft MSL.")
                .arg(fmtAlt(serviceCeiling)).arg(fmtAlt(absoluteCeiling)).arg(marginAtCeiling).arg(_altSuffix))

        // Motor upgrade
        if (throttleMargin <= 10 && _motor === "420")
            _motorUpgradeText = qsTr("SAFEST OPTION: Motor Upgrade. At %1 kg / %2 %3 max altitude with the standard motor there is <=%4%% throttle margin: no reserve for climb/maneuvering and vulnerable to stall. Parameter changes reduce but do not fix the power deficit. Try the High Power motor or contact Applied Aeronautics.")
                .arg(weight.toFixed(1)).arg(fmtAlt(maxAlt)).arg(_altSuffix).arg(throttleMargin.toFixed(0))
        else if (throttleMargin <= 10 && _motor === "540")
            _motorUpgradeText = qsTr("BEYOND SAFE ENVELOPE. Even with the high-power motor, %1 kg at %2 %3 has only %4%% throttle margin. Reduce weight or maximum altitude, or contact Applied Aeronautics.")
                .arg(weight.toFixed(1)).arg(fmtAlt(maxAlt)).arg(_altSuffix).arg(throttleMargin.toFixed(0))
        else
            _motorUpgradeText = ""

        rebuildStepped(takeoffAlt, maxAlt, temp, baseline, weight)
    }

    property string _motorUpgradeText: ""

    function rebuildStepped(takeoffAlt, maxAlt, temp, baseline, weight) {
        steppedModel.clear()
        var stepFt = 1000
        var altitudes = [takeoffAlt]
        var firstStep = Math.ceil(takeoffAlt / stepFt) * stepFt
        for (var a = firstStep; a <= maxAlt; a += stepFt)
            if (a > takeoffAlt && altitudes.indexOf(a) === -1) altitudes.push(a)
        if (altitudes.indexOf(maxAlt) === -1) altitudes.push(maxAlt)
        altitudes.sort(function(x, y) { return x - y })

        for (var i = 0; i < altitudes.length; ++i) {
            var alt = altitudes[i]
            var thrPct = calcThrottle(alt, weight, baseline, temp) * 100
            var margin = 100 - thrPct
            var p = getClimbParams(margin)
            var lvl = margin < 10 ? 2 : (margin < 20 ? 1 : 0)
            var label = fmtAlt(alt)
            if (alt === takeoffAlt) label += " " + qsTr("(TO)")
            if (alt === maxAlt)     label += " " + qsTr("(MAX)")
            steppedModel.append({
                altLabel: label,
                throttleTxt: thrPct.toFixed(0) + "%",
                marginTxt: margin.toFixed(0) + "%",
                clmbMaxVal: p.clmbMax,
                clmbSpVal: p.clmbSp,
                level: lvl,
                special: (alt === takeoffAlt || alt === maxAlt)
            })
        }
    }

    ListModel { id: paramChangesModel }
    ListModel { id: steppedModel }
    ListModel { id: warningsModel }

    Component.onCompleted: {
        // Two open paths:
        //  - showPopupDialogFromComponent(comp, props): the QGCPopupDialog
        //    Loader exposes a `dialogProperties` context object the component
        //    reads itself (QGC convention, e.g. simpleMessageDialog).
        //  - Component.createObject(parent, props).open(): props are assigned
        //    directly, so `missionController` is already set (this fork's path).
        // typeof guard keeps the dialogProperties reference safe when it does
        // not exist (the createObject path).
        if (!missionController && typeof dialogProperties !== "undefined" && dialogProperties)
            missionController = dialogProperties.missionController

        // Prefer the aircraft's real battery capacity when connected so the
        // endurance/range estimates are accurate; otherwise fall back to the
        // manual pack selector.
        if (!pullBatteryFromVehicle(false))
            recompute()
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    ColumnLayout {
        width:      _contentW
        spacing:    _fph * 0.6

        QGCLabel {
            text:       qsTr("Applied Aeronautics Albatross on PX4 v1.14 only. Offline - no internet required.")
            color:      _cMuted
            font.pointSize: ScreenTools.smallFontPointSize
            Layout.fillWidth: true
            wrapMode:   Text.WordWrap
        }

        // ---------------- Inputs ----------------
        Rectangle {
            Layout.fillWidth:   true
            color:              Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.04)
            radius:             _fpw * 0.5
            Layout.preferredHeight: inputCol.implicitHeight + _fph
            ColumnLayout {
                id:                 inputCol
                anchors.fill:       parent
                anchors.margins:    _fph * 0.5
                spacing:            _fph * 0.4

                SectionHeader { text: qsTr("Flight Conditions") }

                // toggle rows
                ToggleRow {
                    labelText: qsTr("Altitude")
                    options:   [ { t: qsTr("ft"), v: "ft" }, { t: qsTr("m"), v: "m" } ]
                    current:   _altUnit
                    onPicked:  { _altUnit = v; recompute() }
                }
                ToggleRow {
                    labelText: qsTr("Temperature")
                    options:   [ { t: qsTr("°F"), v: "f" }, { t: qsTr("°C"), v: "c" } ]
                    current:   _tempUnit
                    onPicked:  { _tempUnit = v; recompute() }
                }
                ToggleRow {
                    labelText: qsTr("Weight")
                    options:   [ { t: qsTr("kg"), v: "kg" }, { t: qsTr("lb"), v: "lb" } ]
                    current:   _weightUnit
                    onPicked:  { _weightUnit = v }   // display-only; _weightKg unchanged
                }
                ToggleRow {
                    labelText: qsTr("Motor")
                    options:   [ { t: qsTr("Standard"), v: "420" }, { t: qsTr("High Power"), v: "540" } ]
                    current:   _motor
                    onPicked:  { _motor = v; recompute() }
                }
                ToggleRow {
                    labelText: qsTr("Climb")
                    options:   [ { t: qsTr("Efficient"), v: "efficient" }, { t: qsTr("Conservative"), v: "conservative" } ]
                    current:   _climb
                    onPicked:  { _climb = v; recompute() }
                }
                ToggleRow {
                    labelText: qsTr("Packs (offline)")
                    options:   [ { t: "1", v: "1" }, { t: "2", v: "2" }, { t: "3", v: "3" } ]
                    current:   _batteries.toString()
                    onPicked:  setBatteriesManual(parseInt(v))
                }

                GridLayout {
                    columns:            2
                    columnSpacing:      _fpw * 2
                    rowSpacing:         _fph * 0.3
                    Layout.fillWidth:   true

                    QGCLabel { text: qsTr("Vehicle Weight (%1)").arg(weightUnitStr()) }
                    QGCTextField {
                        // bound to _weightKg/_weightUnit so it reformats on unit toggle
                        text:               (_weightUnit === "lb" ? kgToLb(_weightKg) : _weightKg).toFixed(1)
                        Layout.fillWidth:   true
                        onEditingFinished:  {
                            var n = parseFloat(text)
                            if (!isNaN(n)) { _weightKg = (_weightUnit === "lb" ? lbToKg(n) : n); recompute() }
                        }
                    }
                    QGCLabel { text: qsTr("Takeoff Alt MSL (%1)").arg(_altSuffix) }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCTextField {
                            text:               _takeoffAltIn.toString()
                            Layout.fillWidth:   true
                            onEditingFinished:  { var n = parseFloat(text); if (!isNaN(n)) { _takeoffAltIn = n; recompute() } }
                        }
                        QGCButton { text: qsTr("GPS");     onClicked: fillFromGps() }
                    }
                    QGCLabel { text: qsTr("Max Flight Alt MSL (%1)").arg(_altSuffix) }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCTextField {
                            text:               _maxAltIn.toString()
                            Layout.fillWidth:   true
                            onEditingFinished:  { var n = parseFloat(text); if (!isNaN(n)) { _maxAltIn = n; recompute() } }
                        }
                        QGCButton { text: qsTr("Mission"); onClicked: fillFromMission() }
                    }
                    QGCLabel { text: qsTr("Temperature (%1)").arg(_tempUnit === "f" ? "°F" : "°C") }
                    QGCTextField {
                        text:               _tempIn.toString()
                        Layout.fillWidth:   true
                        onEditingFinished:  { var n = parseFloat(text); if (!isNaN(n)) { _tempIn = n; recompute() } }
                    }

                    QGCLabel { text: qsTr("Battery (mAh)") }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCTextField {
                            text:               Math.round(_battCapacityMah).toString()
                            Layout.fillWidth:   true
                            onEditingFinished:  {
                                var n = parseFloat(text)
                                if (!isNaN(n) && n > 0) {
                                    _battCapacityMah = n
                                    _battSource = qsTr("manual entry")
                                    recompute()
                                }
                            }
                        }
                        QGCButton {
                            text:       qsTr("Pull from Vehicle")
                            enabled:    _activeVehicle !== null
                            onClicked:  pullBatteryFromVehicle(true)
                        }
                    }
                    QGCLabel { text: "" }
                    QGCLabel {
                        text:               qsTr("Source: %1").arg(_battSource)
                        color:              _cMuted
                        font.pointSize:     ScreenTools.smallFontPointSize
                        Layout.fillWidth:   true
                        wrapMode:           Text.WordWrap
                    }
                }
            }
        }

        // ---------------- Results: tiles ----------------
        SectionHeader { text: qsTr("Atmospheric Conditions") }
        GridLayout {
            columns: 3; Layout.fillWidth: true; columnSpacing: _fpw; rowSpacing: _fph * 0.4
            ResultTile { value: _densityRatioTxt;  label: qsTr("Density Ratio (σ)") }
            ResultTile { value: _densityAltTxt;    label: qsTr("Density Altitude (%1)").arg(_altSuffix) }
            ResultTile { value: _tasEasTxt;        label: qsTr("TAS/EAS Ratio") }
        }

        SectionHeader { text: qsTr("Stall Speeds (from aero)") }
        GridLayout {
            columns: 3; Layout.fillWidth: true; columnSpacing: _fpw; rowSpacing: _fph * 0.4
            ResultTile { value: _stallNFTxt;       label: qsTr("No Flaps (CAS)") }
            ResultTile { value: _stallFTxt;        label: qsTr("With Flaps (CAS)") }
            ResultTile { value: _stallMargin1gTxt; label: qsTr("Margin to Trim @1G"); valueColor: levelColor(_stallMargin1gLvl) }
        }

        SectionHeader { text: qsTr("Throttle Budget") }
        GridLayout {
            columns: 3; Layout.fillWidth: true; columnSpacing: _fpw; rowSpacing: _fph * 0.4
            ResultTile { value: _thrToTxt;     label: qsTr("Required @ Takeoff"); valueColor: levelColor(_thrToLvl) }
            ResultTile { value: _thrMaxTxt;    label: qsTr("Required @ Max Alt"); valueColor: levelColor(_thrMaxLvl) }
            ResultTile { value: _thrMarginTxt; label: qsTr("Margin @ Max Alt");   valueColor: levelColor(_thrMaxLvl) }
        }

        SectionHeader { text: qsTr("Endurance & Range (20% reserve)") }
        GridLayout {
            columns: 3; Layout.fillWidth: true; columnSpacing: _fpw; rowSpacing: _fph * 0.4
            ResultTile { value: _enduranceTxt; label: qsTr("Cruise Endurance"); valueColor: levelColor(_enduranceLvl) }
            ResultTile { value: _rangeTxt;     label: qsTr("Estimated Range");  valueColor: levelColor(_enduranceLvl) }
            ResultTile { value: _cruiseCurTxt; label: qsTr("Cruise Current") }
        }

        SectionHeader { text: qsTr("Safety Margins") }
        GridLayout {
            columns: 2; Layout.fillWidth: true; columnSpacing: _fpw; rowSpacing: _fph * 0.4
            ResultTile { value: _tkoStallTxt; label: qsTr("TKO -> Stall Margin"); valueColor: levelColor(_tkoStallLvl) }
            ResultTile { value: _tkoTrimTxt;  label: qsTr("TKO -> TRIM Gap");     valueColor: levelColor(_tkoTrimLvl) }
        }

        // ---------------- Warnings ----------------
        Repeater {
            model: warningsModel
            delegate: Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: wcol.implicitHeight + _fph * 0.6
                radius:                 _fpw * 0.4
                color:                  Qt.rgba((model.level===2?_cDanger:(model.level===1?_cWarn:_cAccent)).r,
                                                (model.level===2?_cDanger:(model.level===1?_cWarn:_cAccent)).g,
                                                (model.level===2?_cDanger:(model.level===1?_cWarn:_cAccent)).b, 0.15)
                border.color:           model.level===2?_cDanger:(model.level===1?_cWarn:_cAccent)
                border.width:           1
                ColumnLayout {
                    id:                 wcol
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    _fph * 0.3
                    spacing:            2
                    QGCLabel {
                        text:               model.title
                        font.bold:          true
                        color:              model.level===2?_cDanger:(model.level===1?_cWarn:_cAccent)
                        Layout.fillWidth:   true
                        wrapMode:           Text.WordWrap
                    }
                    QGCLabel {
                        text:               model.body
                        Layout.fillWidth:   true
                        wrapMode:           Text.WordWrap
                        font.pointSize:     ScreenTools.smallFontPointSize
                    }
                }
            }
        }

        // ---------------- Recommended parameter changes ----------------
        SectionHeader { text: qsTr("Recommended Parameter Changes") }
        QGCLabel {
            visible:            paramChangesModel.count === 0
            text:               qsTr("No parameter changes required - defaults are appropriate for this weight/altitude.")
            color:              _cGood
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
        }
        QGCLabel {
            visible:            !_haveFW
            text:               qsTr("Connect a fixed-wing vehicle to apply parameters. Calculations work offline regardless.")
            color:              _cWarn
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            font.pointSize:     ScreenTools.smallFontPointSize
        }

        Repeater {
            model: paramChangesModel
            delegate: Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: prow.implicitHeight + _fph * 0.5
                color:                  Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.04)
                radius:                 _fpw * 0.4
                ColumnLayout {
                    id:                 prow
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    _fph * 0.3
                    spacing:            3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          _fpw
                        Rectangle {
                            radius:         3
                            color:          model.groundOnly ? Qt.rgba(_cDanger.r,_cDanger.g,_cDanger.b,0.25)
                                                             : Qt.rgba(_cGood.r,_cGood.g,_cGood.b,0.25)
                            border.color:   model.groundOnly ? _cDanger : _cGood
                            border.width:   1
                            Layout.preferredWidth:  badge.implicitWidth + _fpw
                            Layout.preferredHeight: badge.implicitHeight + _fph * 0.2
                            QGCLabel {
                                id:             badge
                                anchors.centerIn: parent
                                text:           model.groundOnly ? qsTr("GROUND ONLY") : qsTr("IN-FLIGHT OK")
                                color:          model.groundOnly ? _cDanger : _cGood
                                font.bold:      true
                                font.pointSize: ScreenTools.smallFontPointSize
                            }
                        }
                        QGCLabel { text: model.paramName; font.family: ScreenTools.fixedFontFamily; color: _cWarn; Layout.fillWidth: true }
                        QGCLabel { text: model.defaultText; color: _cMuted; font.pointSize: ScreenTools.smallFontPointSize }
                        QGCLabel { text: "→"; color: _cMuted }
                        QGCLabel { text: model.recText; color: _cAccent; font.bold: true; font.family: ScreenTools.fixedFontFamily }
                        QGCButton {
                            text:       qsTr("Apply")
                            enabled:    _haveFW && !(model.groundOnly && _armed)
                            onClicked:  applyChangeRow(index)
                        }
                    }
                    QGCLabel {
                        text:               model.note + (model.groundOnly && _armed ? "  — " + qsTr("disabled while armed (ground only)") : "")
                        color:              _cMuted
                        font.pointSize:     ScreenTools.smallFontPointSize
                        Layout.fillWidth:   true
                        wrapMode:           Text.WordWrap
                    }
                }
            }
        }

        QGCButton {
            Layout.fillWidth:   true
            visible:            paramChangesModel.count > 0
            text:               _armed ? qsTr("Apply Flight-Safe Params") : qsTr("Apply All to Vehicle")
            enabled:            _haveFW
            onClicked:          applyBulk()
        }

        // ---------------- Stepped altitude table ----------------
        RowLayout {
            Layout.fillWidth: true
            QGCCheckBox {
                id:         steppedToggle
                text:       qsTr("Stepped Altitude Changes (per 1000 ft)")
                checked:    false
            }
        }
        QGCLabel {
            visible:            steppedToggle.checked
            text:               qsTr("FW_THR_TRIM is set for max altitude and must not be changed in flight (integrator wind-up). Only FW_T_CLMB_MAX / FW_T_CLMB_R_SP are adjusted here - both flight-safe.")
            color:              _cMuted
            font.pointSize:     ScreenTools.smallFontPointSize
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
        }
        Column {
            visible:            steppedToggle.checked
            Layout.fillWidth:   true
            spacing:            2

            RowLayout {
                width: _contentW
                QGCLabel { text: qsTr("Altitude (%1)").arg(_altSuffix); Layout.preferredWidth: _contentW*0.22; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize }
                QGCLabel { text: qsTr("Thr");      Layout.preferredWidth: _contentW*0.10; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize }
                QGCLabel { text: qsTr("Margin");   Layout.preferredWidth: _contentW*0.12; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize }
                QGCLabel { text: qsTr("CLMB_MAX"); Layout.preferredWidth: _contentW*0.16; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize }
                QGCLabel { text: qsTr("CLMB_R_SP");Layout.preferredWidth: _contentW*0.16; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize }
                Item      { Layout.fillWidth: true }
            }
            Repeater {
                model: steppedModel
                delegate: RowLayout {
                    width: _contentW
                    QGCLabel {
                        text:               model.altLabel
                        Layout.preferredWidth: _contentW*0.22
                        font.bold:          model.special
                        color:              model.special ? _cAccent : qgcPal.text
                        font.pointSize:     ScreenTools.smallFontPointSize
                    }
                    QGCLabel { text: model.throttleTxt; Layout.preferredWidth: _contentW*0.10; color: levelColor(model.level); font.pointSize: ScreenTools.smallFontPointSize }
                    QGCLabel { text: model.marginTxt;   Layout.preferredWidth: _contentW*0.12; color: levelColor(model.level); font.pointSize: ScreenTools.smallFontPointSize }
                    QGCLabel { text: model.clmbMaxVal.toFixed(1) + " m/s"; Layout.preferredWidth: _contentW*0.16; font.pointSize: ScreenTools.smallFontPointSize }
                    QGCLabel { text: model.clmbSpVal.toFixed(1) + " m/s";  Layout.preferredWidth: _contentW*0.16; font.pointSize: ScreenTools.smallFontPointSize }
                    QGCButton {
                        text:       qsTr("Apply")
                        enabled:    _haveFW   // CLMB_MAX/CLMB_R_SP are flight-safe -> always enabled when FW present
                        onClicked:  applySteppedRow(index)
                    }
                }
            }
        }

        // ---------------- Motor upgrade ----------------
        Rectangle {
            visible:                _motorUpgradeText !== ""
            Layout.fillWidth:       true
            Layout.preferredHeight: muLabel.implicitHeight + _fph * 0.6
            radius:                 _fpw * 0.4
            color:                  Qt.rgba(_cDanger.r, _cDanger.g, _cDanger.b, 0.15)
            border.color:           _cDanger
            border.width:           1
            QGCLabel {
                id:                 muLabel
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.top:        parent.top
                anchors.margins:    _fph * 0.3
                text:               _motorUpgradeText
                color:              _cDanger
                wrapMode:           Text.WordWrap
            }
        }

        QGCLabel {
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            color:              _cMuted
            font.pointSize:     ScreenTools.smallFontPointSize
            text:               qsTr("Model: baseline x (weight/8.1)^1.5 / sqrt(sigma). Wing 0.66 m2, Cl 1.02/1.2. Battery 14 Ah/pack, 20%% reserve, +/-15%% real-world variance. Defaults: FW_TKO_AIRSPD=19, FW_AIRSPD_TRIM=20, FW_THR_TRIM=0.60, FW_T_CLMB_MAX=5.5, FW_T_CLMB_R_SP=3.0, FW_TKO_PITCH_MIN=10.")
        }
    }

    // ===== Reusable inline components =====
    component SectionHeader: QGCLabel {
        Layout.fillWidth:   true
        font.bold:          true
        color:              _cGood
        Layout.topMargin:   _fph * 0.3
    }

    component ResultTile: Rectangle {
        property string value: "-"
        property string label: ""
        property color  valueColor: _cAccent
        Layout.fillWidth:       true
        Layout.preferredHeight: _fph * 3.2
        radius:                 _fpw * 0.4
        color:                  Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.06)
        ColumnLayout {
            anchors.centerIn:   parent
            spacing:            2
            QGCLabel {
                text:               value
                color:              valueColor
                font.bold:          true
                font.pointSize:     ScreenTools.mediumFontPointSize
                Layout.alignment:   Qt.AlignHCenter
            }
            QGCLabel {
                text:               label
                color:              _cMuted
                font.pointSize:     ScreenTools.smallFontPointSize
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment:   Qt.AlignHCenter
                Layout.maximumWidth: _contentW * 0.3
                wrapMode:           Text.WordWrap
            }
        }
    }

    component ToggleRow: RowLayout {
        id:                 toggleRow
        property string labelText: ""
        property var    options:   []
        property string current:   ""
        signal picked(string v)
        Layout.fillWidth:   true
        spacing:            _fpw
        QGCLabel { text: toggleRow.labelText; Layout.preferredWidth: _contentW * 0.22 }
        Repeater {
            model: toggleRow.options
            delegate: QGCButton {
                text:       modelData.t
                checkable:  true
                checked:    toggleRow.current === modelData.v
                onClicked:  toggleRow.picked(modelData.v)
            }
        }
        Item { Layout.fillWidth: true }
    }
}
