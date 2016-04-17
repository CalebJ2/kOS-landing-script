ON AG1 {
	SET runMode TO runMode - 1.
	SET updateSettings TO true.
}
ON AG2 {
	SET runMode TO runMode + 1.
	SET updateSettings TO true.
}

CLEARSCREEN.
if addons:tr:available() = false {
	print "Trajectories mod is not installed or is the wrong version." at(0,8).
	print "Script will fail, but you may press 1 to launch anyway." at(0,9).
} else {
	print "Press 1 to launch." at(0,9).
}
print "Press 1 to launch." at(0,9).
RUN land_lib.ks. //Includes the function library

SET steeringDir TO 90. //0-360, 0=north, 90=east
SET steeringPitch TO 90. // 90 is up
LOCK STEERING TO HEADING(steeringDir,steeringPitch).

//see next comment
SET steeringArrow TO VECDRAW().
SET steeringArrow:VEC TO HEADING(steeringDir,steeringPitch):VECTOR.
SET steeringArrow:SCALE TO 7.
SET steeringArrow:COLOR TO RGB(1.0,0,0).
SET retroArrow TO VECDRAW().
SET retroArrow:VEC TO RETROGRADE:VECTOR.
SET retroArrow:SCALE TO 7.
SET retroArrow:COLOR TO RGB(0,1.0,0).
SET lpArrow TO VECDRAW().
SET lpArrow:VEC TO RETROGRADE:VECTOR.
SET lpArrow:SCALE TO 7.
SET lpArrow:COLOR TO RGB(0,0,1.0).

//uncomment these and lines 224 & 225 for some debug arrows
//SET steeringArrow:SHOW TO true.
//SET retroArrow:SHOW TO true.
//SET lpArrow:SHOW TO true.

if STAGE:NUMBER = 2 { STAGE. }
set ship:control:pilotmainthrottle to 0.
SET thrott TO 0.
LOCK THROTTLE TO thrott.
SAS OFF.
RCS OFF.

LOCK radar TO terrainDist().
SET radarOffset TO 8.//ship:altitude - radar. //rocket should be on ground at this point
SET launchPad TO SHIP:GEOPOSITION.//LATLNG(-0.0972077635067718, -74.5576726244574).
LOCK targetDist TO geoDistance(launchPad, ADDONS:TR:IMPACTPOS).
LOCK targetDir TO geoDir(ADDONS:TR:IMPACTPOS, launchPad).
SET cardVelCached TO cardVel().
SET targetDistOld TO 0.
//g in m/s^2 at sea level.
SET g TO constant:G * BODY:Mass / BODY:RADIUS^2.
LOCK maxVertAcc TO SHIP:AVAILABLETHRUST / SHIP:MASS - g. //max acceleration in up direction the engines can create
LOCK vertAcc TO scalarProj(SHIP:SENSORS:ACC, UP:VECTOR).
LOCK dragAcc TO g + vertAcc. //vertical acceleration due to drag. Same as g at terminal velocity
// Burn time to reach 0 vertical velocity
//LOCK sBurnTime TO -SHIP:VERTICALSPEED / maxVertAcc.
//Distance in vacuum = Vi*t + 1/2*a*t^2
LOCK sBurnDist TO SHIP:VERTICALSPEED^2 / (2 * (maxVertAcc + dragAcc/2)).//-SHIP:VERTICALSPEED * sBurnTime + 0.5 * -maxVertAcc * sBurnTime^2.//SHIP:VERTICALSPEED^2 / (2 * maxVertAcc). 

SET stopLoop TO false.
//0 = landed, 1 = final decent, 2 = hover/manouver, 3 = suicide burn, 4 = falling, 5 = boostback, 6 = launching, 7 = nothing
SET runMode TO 7.
SET updateSettings TO true.

SET climbPID TO PIDLOOP(0.4, 0.3, 0.005, 0, 1). //Controls vertical speed
SET hoverPID TO PIDLOOP(1, 0.01, 0.0, -15, 15). //Controls altitude by changing climbPID setpoint
SET hoverPID:SETPOINT TO 87. //87 is the altitude about 7 meters above launch pad
SET eastVelPID TO PIDLOOP(3, 0.01, 0.0, -35, 35). //Controls horizontal speed by tilting rocket
SET northVelPID TO PIDLOOP(3, 0.01, 0.0, -35, 35).
SET eastPosPID TO PIDLOOP(1700, 0, 100, -30, 30). //controls horizontal position by changing velPID setpoints
SET northPosPID TO PIDLOOP(1700, 0, 100, -30, 30).
SET eastPosPID:SETPOINT TO launchPad:LNG.
SET northPosPID:SETPOINT TO launchPad:LAT.

WHEN runMode = 6 THEN {
	SET thrott TO 1.
	GEAR OFF.
	SET updateSettings TO true.
	WHEN STAGE:LIQUIDFUEL < 110 AND STAGE:LIQUIDFUEL > 0 THEN {
		PRINT STAGE:LIQUIDFUEL AT(0,17).
		SET thrott TO 0.
		SET runMode TO 5.
		SET updateSettings TO true.
		WHEN runMode = 4 THEN { //When falling
			SET updateSettings TO true.
			SET thrott TO 0.
			WHEN sBurnDist > radar - radarOffset -15 AND SHIP:VERTICALSPEED < -5 THEN {//When there is barely enough time to stop before reaching altitude 90.
				//LOG "burn start alt: " + radar TO burn.txt.
				//LOG "burn est: " + sBurnDist TO burn.txt.
				SET runMode TO 3.
				SET updateSettings TO true.
				SET thrott to 1.
				WHEN SHIP:VERTICALSPEED > -1 THEN { //When it has stopped falling
					//LOG "burn end alt: " + radar TO burn.txt.
					SET runMode TO 2.
					GEAR ON.
					SET updateSettings TO true.
					WHEN geoDistance(SHIP:GEOPOSITION, launchPad) < 5 THEN { //When it is over the launch pad
						SET runMode TO 1.
						WHEN SHIP:STATUS = "LANDED" THEN {
							SET runMode TO 0.
							SET updateSettings TO true.
							SET thrott TO 0.
							RCS OFF.
						}
					}
				}
			}
		}
	}
}

UNTIL stopLoop = true { //Main loop
	if runMode = 7 {
		if updateSettings = true {
			UNLOCK THROTTLE.
			UNLOCK STEERING.
			SET updateSettings TO false.
		}
	}	
	if runMode = 6 {
		if updateSettings = true {
			LOCK STEERING TO HEADING(steeringDir,steeringPitch).
			LOCK THROTTLE TO thrott.
			SET updateSettings TO false.
			CLEARSCREEN.
		}
		SET steeringPitch TO 90 * (30000 - SHIP:ALTITUDE) / 30000.
	}
	if runMode = 5 { //boostback
		if updateSettings = true {
			RCS ON.
			SAS OFF.
			SET thrott TO 0.
			WAIT 0.1.
			STAGE.
			WAIT 2.
			SET updateSettings TO false.
		}
		if ADDONS:TR:HASIMPACT = true { //If ship will hit ground
			SET steeringDir TO targetDir - 180. //point towards launch pad
			SET steeringPitch TO 0.
			if VANG(HEADING(steeringDir,steeringPitch):VECTOR, SHIP:FACING:VECTOR) < 20 {  //wait until pointing in right direction
				SET thrott TO targetDist / 5000 + 0.2.
			} else {
				SET thrott TO 0.2.
			}
			if targetDist > targetDistOld AND targetDist < 300 {
				wait 0.2.
				SET thrott TO 0.
				SET runMode TO 4.
			}
			SET targetDistOld TO targetDist.
		}
	}
	if runMode = 4 { //Glide rocket back to launch pad.
		SET shipProVec TO (SHIP:VELOCITY:SURFACE * -1):NORMALIZED.
		if SHIP:VERTICALSPEED < -10 {
			SET launchPadVect TO (launchPad:POSITION - ADDONS:TR:IMPACTPOS:POSITION):NORMALIZED. //vector with magnitude 1 from impact to launchpad
			SET rotateBy TO MIN(targetDist*2, 15). //how many degrees to rotate the steeringVect
			PRINT "rotateBy: " + rotateBy at(0,7).
			SET steeringVect TO shipProVec * 40. //velocity vector lengthened
			SET loopCount TO 0.
			UNTIL (rotateBy - VANG(steeringVect, shipProVec)) < 3 { //until steeringVect gets close to desired angle
				PRINT "entered loop" at(0,9).
				if VANG(steeringVect, shipProVec) > rotateBy { //stop from overshooting
					PRINT "broke loop" at(0,9).
					BREAK.
				}
				SET loopCount TO loopCount + 1.
				if loopCount > 100 {
					PRINT "broke infinite loop" at(0,10).
					BREAK.
				}
				SET steeringVect TO steeringVect - launchPadVect. //essentially rotate steeringVect in small increments by subtracting the small vector.
			}
			PRINT "steeringAngle: " + VANG(steeringVect, shipProVec) at(0,8).
			SET steeringArrow:VEC TO steeringVect:NORMALIZED. //RED
			SET retroArrow:VEC TO shipProVec. //GREEN
			SET lpArrow:VEC TO launchPadVect:NORMALIZED. //BLUE
			LOCK STEERING TO steeringVect:DIRECTION.
		} else {
			LOCK STEERING TO (shipProVec):DIRECTION.
		}
	}
	if runMode = 3 {//Suicide burn. Mainly handled by WHEN on line ~38
		if updateSettings = true {
			SET eastVelPID:MINOUTPUT TO -5.
			SET eastVelPID:MAXOUTPUT TO 5.
			SET northVelPID:MINOUTPUT TO -5.
			SET northVelPID:MAXOUTPUT TO 5.
			SET steeringDir TO 0.
			SET steeringPitch TO 90.
			LOCK STEERING TO HEADING(steeringDir,steeringPitch).
			SET updateSettings TO false.
		}
		SET cardVelCached TO cardVel().
		steeringPIDs().
	}
	if runMode = 2 { //Powered flight to launch pad
		if updateSettings = true {
			SAS OFF.
			RCS OFF.
			SET eastVelPID:MINOUTPUT TO -35.
			SET eastVelPID:MAXOUTPUT TO 35.
			SET northVelPID:MINOUTPUT TO -35.
			SET northVelPID:MAXOUTPUT TO 35.
			SET updateSettings TO false.
		}
		SET cardVelCached TO cardVel().
		SET climbPID:SETPOINT TO hoverPID:UPDATE(TIME:SECONDS, SHIP:ALTITUDE). //lower ship down while flying to launch pad
		SET thrott TO climbPID:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).
		steeringPIDs().
	}
	if runMode = 1 { //Final landing
		SET cardVelCached TO cardVel().
		steeringPIDs().
		SET climbPID:SETPOINT TO MAX(radar - radarOffset, 1.5) * -1.
		PRINT "climbPID:SETPOINT: " + climbPID:SETPOINT at(0,8).
		SET thrott TO climbPID:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).
	}
	if runMode = 0 {
		SET thrott TO 0.
		SET updateSettings TO false.
	}

	printData2().
	//SET steeringArrow:VEC TO HEADING(steeringDir,steeringPitch):VECTOR.
	//SET steeringArrow:VEC TO launchPad:POSITION - ADDONS:TR:IMPACTPOS:POSITION.
	WAIT 0.01.
}
function printData2 {
	PRINT "runMode: " + runMode AT(0,1).
	PRINT "radar: " + ROUND(radar, 4) AT(0,2).

	PRINT "sBurnDist: " + ROUND(sBurnDist, 4) AT(0,3).
	PRINT "Vertical speed target: " + ROUND(climbPID:SETPOINT, 4) AT(0,4).
	PRINT "VERTICALSPEED: " + ROUND(SHIP:VERTICALSPEED, 4) AT(0,5).
	if ADDONS:TR:HASIMPACT = true { PRINT "Impact point dist from pad: " + ROUND(targetDist,4) at(0,6). }
}