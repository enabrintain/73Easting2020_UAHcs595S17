
import edu.nps.moves.dis7.EntityID;
import edu.nps.moves.dis7.EntityStatePdu;
import edu.nps.moves.dis7.EntityType;
import edu.nps.moves.dis7.Vector3Double;
import edu.nps.moves.disutil.CoordinateConversions;
import edu.nps.moves.disutil.DisTime;


public class T14 {
	EntityStatePdu m_espdu ; 
	DisTime m_disTime;
	EntityID m_eid; 
	EntityType m_entityType; 
	double m_disCoordinates[] ;
    Vector3Double m_location; 
   
	
	private static int m_count = 0; // keep track on how many T14 has been created
	
	/***constructor with ***/ 
	public T14(double lat, double lon, double alt) {
		m_espdu = new EntityStatePdu();
		m_disTime = DisTime.getInstance();
		m_location = m_espdu.getEntityLocation();
		m_espdu.setExerciseID((short) 1);
		m_espdu.setForceId((short)0);
		m_eid = m_espdu.getEntityID();
		m_eid.setSiteID(1);
	
	    m_eid.setApplicationID(1); 
	    m_eid.setEntityID(300); 
	    
	    m_entityType = m_espdu.getEntityType();
	    m_entityType.setEntityKind((short)1);      // Platform (vs lifeform, munition, sensor, etc.)
	    m_entityType.setCountry(222);   
	    m_entityType.setDomain((short)1);          // Land (vs air, surface, subsurface, space)
	    m_entityType.setCategory((short)1);        // Tank
	    m_entityType.setSubcategory((short)1);     // M1 Abrams
	    m_entityType.setSpecific((short)3);            // M1A2 Abrams
	    
	  /***position***/     
	  m_disCoordinates = CoordinateConversions.getXYZfromLatLonDegrees(lat, lon, alt);
	  m_location.setX(m_disCoordinates[0]);
	  m_location.setY(m_disCoordinates[1]);
	  m_location.setZ(m_disCoordinates[2]);   
	    
	  
	  m_count++;
		
	}
	
public int getT14Count() {
	return m_count;
}

	
public void getPosition() {
	 System.out.print( " EID=[" + m_eid.getSiteID() + "," + m_eid.getApplicationID() + "," + m_eid.getEntityID() + "]");
     System.out.print(" DIS coordinates location=[" + m_location.getX() + "," + m_location.getY() + "," + m_location.getZ() + "]");
     double c[] = {m_location.getX(), m_location.getY(), m_location.getZ()};
     double lla[] = CoordinateConversions.xyzToLatLonDegrees(c);
     System.out.println(" Location (lat/lon/alt): [" + lla[0] + ", " + lla[1] + ", " + lla[2] + "]");

}	
	

}
