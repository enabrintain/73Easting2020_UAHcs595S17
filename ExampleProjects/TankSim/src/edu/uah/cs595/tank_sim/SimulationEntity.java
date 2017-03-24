/**
 * 
 */
package edu.uah.cs595.tank_sim;

import edu.nps.moves.dis7.*;
import edu.nps.moves.disutil.CoordinateConversions;
import edu.nps.moves.disutil.DisTime;

/**
 * @author Phil
 *
 */
public class SimulationEntity {

	public int entityId = 302;
	public double lat = 29.3318;//36.595517; 
	public double lon = 46.3748;//-121.877000;
	public double elev = 86;
	
	
	public EntityStatePdu getEntityStatePDU(short exerciseID) {
		EntityStatePdu esPdu = new EntityStatePdu();
		
		esPdu.setExerciseID(exerciseID);
		
		
		EntityID eid = esPdu.getEntityID();
	    eid.setSiteID(1);//setSite(1);  // 0 is apparently not a valid site number, per the spec
	    eid.setApplicationID(1);//setApplication(1); 
	    eid.setEntityID(entityId);
	    

	    EntityType entityType = esPdu.getEntityType();
	    entityType.setEntityKind((short)1);      // Platform (vs lifeform, munition, sensor, etc.)
	    entityType.setCountry(225);              // USA
	    entityType.setDomain((short)1);          // Land (vs air, surface, subsurface, space)
	    entityType.setCategory((short)1);        // Tank
	    entityType.setSubcategory((short)1);     // M1 Abrams
	    entityType.setSpecific((short)3); 
	    
	    
	    int ts = DisTime.getInstance().getDisRelativeTimestamp();
        esPdu.setTimestamp(ts);
        
        
        //lon = lon + (double)((double)idx / 100000.0); bad movement stuff
        //System.out.println("lla=" + lat + "," + lon + ", 0.0");
        //double direction = Math.pow((double)(-1.0), (double)(idx));
        //lon = lon + (direction * 0.00006);
        //System.out.println(lon);
        
        double disCoordinates[] = CoordinateConversions.getXYZfromLatLonDegrees(lat, lon, elev);
        Vector3Double location = esPdu.getEntityLocation();
        location.setX(disCoordinates[0]);
        location.setY(disCoordinates[1]);
        location.setZ(disCoordinates[2]);
        
        
        esPdu.setLength(esPdu.getMarshalledSize());
		return esPdu;
	}

}// SimulationEntity
