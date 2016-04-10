SET runLoop TO false.
SET updateSettings TO false.
SET steeringDir TO 90. //0-360, 0=north, 90=east
SET steeringPitch TO 90. // 90 is up

WHEN STAGE:NUMBER = 0 THEN {
	LOCK THROTTLE TO 0.
	SET updateSettings TO true.
	SET runLoop TO true.
	SET SHIP:SHIPNAME TO "kOS2Sat".
	WHEN SHIP:APOAPSIS > 80000 THEN {
		LOCK THROTTLE TO 0.
	}
}

UNTIL false {
	if runLoop = true {
		if updateSettings = true {
			WAIT 0.1.
			SAS ON.
			LOCK THROTTLE TO 1.
			//LOCK STEERING TO HEADING(steeringDir,steeringPitch).
			SET updateSettings TO false.
		}
		SET steeringPitch TO 45.//MIN(MAX(VANG(VCRS(UP:VECTOR, NORTH:VECTOR), SHIP:VELOCITY:SURFACE), 10) + 10, 80).
		PRINT "running" + steeringPitch.
		WAIT 1.
	}
	WAIT 0.05.
}