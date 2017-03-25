/*
 * T14 Tank Class
 * @author Rui Wang
 * 
 * 
 * 
 * 
 * 
 * 
 */

import edu.nps.moves.dis.*;
import edu.nps.moves.disutil.CoordinateConversions;
import edu.nps.moves.disutil.DisTime;


public class T14 {
	
	/********T14 Field********/ 
	private static int m_count = 0; // keep track on how many T14 has been created
	
	protected EntityStatePdu m_espdu ;// Entity State 	
	protected DisTime m_disTime; // time padding	
	protected EntityID m_eid; // this can be used to identify an object
	
	protected double m_disCoordinates[] ; // tank's Coordinates in X, Y, Z 
	protected Vector3Double m_location; // Tank's location in lan, lon, alt
    // more like velocity, orientation
	
	protected FirePdu m_firepdu ; //fire event 
	protected DetonationPdu m_depdu; // been hit, report demage
	
	
	
	/*********End Field**************/ 
	
	/***constructor with location ***/ 
	public T14(short exerciseID, short forceID, short applicationID, short siteID) {
		m_count++; // increment T14 count
		// double lat, double lon, double alt
		m_espdu = new EntityStatePdu();
		m_espdu.setExerciseID(exerciseID);
		m_espdu.setForceId(forceID);
		
		m_disTime = DisTime.getInstance();
		
		m_setEntityIDParameter(applicationID, siteID); 
		
		m_setEntityTypeParameter() ; 
		
	  
	    
		
	} // end constructor
	/********End Constructor**********/ 
	
/*****************************************************************/	
public EntityStatePdu getEntityStatePdu(){
	return m_espdu;
}
	
		
public DisTime getM_disTime() {
	return m_disTime;
}

public void setM_disTime(DisTime m_disTime) {
	this.m_disTime = m_disTime;
}

public int getT14Count() {
	return m_count;
}

	/***** EntityID ********/ 
/*
 * set identifier [siteID, applicationID, Entity]
 * should not be used when a tank has been created
 */
	private void m_setEntityIDParameter( short applicationID, short siteID) {
		m_eid = m_espdu.getEntityID();
		m_eid.setSite(siteID);
	    m_eid.setApplication(applicationID); 
	    m_eid.setEntity(m_count); 
	} 

	public EntityID getEntityID() {
		return m_eid;
	} 
	
	public void printEntityID() {
		System.out.print( " EID=[" + m_eid.getSite() + "," + m_eid.getApplication() + "," + m_eid.getEntity() + "]");
	} 
/*****END  EntityID ********/ 

	
	
/***** EntityTpye ********/ 	
	/*
	 * set Tank's basic feature: country, domain, Category
	 * Tanks's basic feature should not change when it's been created
	 */
  private void m_setEntityTypeParameter() {
	 EntityType m_entityType = m_espdu.getEntityType();
	    m_entityType.setEntityKind((short)1);      // Platform (vs lifeform, munition, sensor, etc.)
	    m_entityType.setCountry(222);   
	    m_entityType.setDomain((short)1);          // Land (vs air, surface, subsurface, space)
	    m_entityType.setCategory((short)1);        // Tank
	    m_entityType.setSubcategory((short)1);     // M1 Abrams
	    m_entityType.setSpec((short)3);            // M1A2 Abrams
	    
	
} 
/*****END EntityType ********/ 

/***** Location ********/ 
public void setLocation(double lat, double lon, double alt) {
	 
	  m_location = m_espdu.getEntityLocation();	    
	  m_disCoordinates = CoordinateConversions.getXYZfromLatLonDegrees(lat, lon, alt);
	  m_location.setX(m_disCoordinates[0]);
	  m_location.setY(m_disCoordinates[1]);
	  m_location.setZ(m_disCoordinates[2]); 
	
} 

public double[] getM_disCoordinates() {
	return m_disCoordinates;
}

public void setM_disCoordinates(double[] m_disCoordinates) {
	this.m_disCoordinates = m_disCoordinates;
}

public Vector3Double getM_location() {
	return m_location;
}

public void setM_location(Vector3Double m_location) {
	this.m_location = m_location;
}


public double getLat() {
	return m_location.getX();
} 

public double getLon() {
	return m_location.getY();
} 

public double getAlt() {
	return m_location.getZ();
} 

public void printLocation() {
	 System.out.print( " EID=[" + m_eid.getSite() + "," + m_eid.getApplication() + "," + m_eid.getEntity() + "]");
    System.out.print(" DIS coordinates location=[" + m_location.getX() + "," + m_location.getY() + "," + m_location.getZ() + "]");
    double c[] = {m_location.getX(), m_location.getY(), m_location.getZ()};
    double lla[] = CoordinateConversions.xyzToLatLonDegrees(c);
    System.out.println(" Location (lat/lon/alt): [" + lla[0] + ", " + lla[1] + ", " + lla[2] + "]");

}	

/*****END  Location ********/ 

/****** fire event ***************/ 
/*
 * when a Fire event happened, this function will instantiate a FirePdu according to the eventID
 */
public void fire(EventID  pEventID) { // EventIdentifier 
	m_firepdu = new FirePdu() ; 
	m_firepdu.setEventID(pEventID);
	m_firepdu.setExerciseID(m_espdu.getExerciseID());
	//m_firepdu.setRangeToTarget(pRangeToTarget)
	// more tobe done 
	
} 

public boolean isTargetHit(EventID  eventID) { // EventIdentifier
	
	// more to be done 
	return false;
}
/******END  fire event ***************/ 

/******denotation  ***************/


// more to be done

/****** END denotation ***************/ 

} // end T14 class
