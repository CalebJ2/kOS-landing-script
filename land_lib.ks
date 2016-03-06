CLEARSCREEN.
//LOCK airDensity TO (SHIP:SENSORS:PRES * 1000) / (287.058 * SHIP:SENSORS:TEMP). // estimate in kg/m^3
// LOCK vertAcc TO scalarProj(SHIP:SENSORS:ACC, UP:VECTOR).
// LOCK dragAcc TO g + vertAcc.
// LOCK dragForce TO SHIP:MASS * dragAcc.
// SET shipCrossSectionArea TO Constant:PI * 1.25^2.
// LOCK dynamicPres TO airDensity * SHIP:VERTICALSPEED^2 / 2.
// LOCK coeffD TO dragForce / (SHIP:DYNAMICPRESSURE * shipCrossSectionArea).
//2 * dragForce / airDensity * SHIP:VERTICALSPEED^2 * shipCrossSectionArea.
//SET dTargetDist TO 0.

function hasImpact { // ADDONS:TR:IMPACTPOS returns a vector(lat, bool hasImpact, lng)
	if ADDONS:TR:IMPACTPOS:y = 0 {
		return false.
	} else {
		return true.
	}
}
function geoImpact { //Get impact position. Check hasImpact() first.
	return LATLNG(ADDONS:TR:IMPACTPOS:x, ADDONS:TR:IMPACTPOS:z).
}
function cardVel {
	//Convert velocity vectors relative to SOI into easting and northing.
	local vect IS SHIP:VELOCITY:SURFACE.
	local eastVect is VCRS(UP:VECTOR, NORTH:VECTOR).
	local eastComp IS scalarProj(vect, eastVect).
	local northComp IS scalarProj(vect, NORTH:VECTOR).
	local upComp IS scalarProj(vect, UP:VECTOR).
	RETURN V(eastComp, upComp, northComp).
}
function velPitch { //angle of ship velocity relative to horizon
	LOCAL cardVelFlat IS V(cardVelCached:X, 0, cardVelCached:Z).
	RETURN VANG(cardVelCached, cardVelFlat).
}
function velDir { //compass angle of velocity
	return ARCTAN2(cardVelCached:X, cardVelCached:Y).
}
function scalarProj { //Scalar projection of two vectors. Find component of a along b. a(dot)b/||b||
	parameter a.
	parameter b.
	if b = 0 { PRINT "scalarProj: Tried to divide by 0. Returning 1". RETURN 1. } //error check
	RETURN VDOT(a, b) * (1/b:MAG).
}
function terrainHeight { //GEOPOSITION:TERRAINHEIGHT doesn't see water
	if SHIP:GEOPOSITION:TERRAINHEIGHT > 0{
		RETURN SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT.
	} else {
		RETURN SHIP:ALTITUDE.
	}
}
function geoDistance { //Approx in meters
	parameter geo1.
	parameter geo2.
	return SQRT((geo1:lng - geo2:lng)^2 + (geo1:lat - geo2:lat)^2) * 10472.
}
function geoDir {
	parameter geo1.
	parameter geo2.
	return ARCTAN2(geo1:LNG - geo2:LNG, geo1:LAT - geo2:LAT).
}
function steeringPIDs { //Sets global variables steeringDir and steeringPitch
	SET eastVelPID:SETPOINT TO eastPosPID:UPDATE(TIME:SECONDS, SHIP:GEOPOSITION:LNG).
	SET northVelPID:SETPOINT TO northPosPID:UPDATE(TIME:SECONDS,SHIP:GEOPOSITION:LAT).
	LOCAL eastVelPIDOut IS eastVelPID:UPDATE(TIME:SECONDS, cardVelCached:X).
	LOCAL northVelPIDOut IS northVelPID:UPDATE(TIME:SECONDS, cardVelCached:Z).
	
	LOCAL eastPlusNorth is MAX(ABS(eastVelPIDOut), ABS(northVelPIDOut)).//SQRT(eastVelPIDOut^2 + northVelPIDOut^2). 
	SET steeringPitch TO 90 - eastPlusNorth.
	LOCAL steeringDirNonNorm IS ARCTAN2(eastVelPID:OUTPUT, northVelPID:OUTPUT). //might be negative
	if steeringDirNonNorm >= 0 {
		SET steeringDir TO steeringDirNonNorm.
	} else {
		SET steeringDir TO 360 + steeringDirNonNorm.
	}
}