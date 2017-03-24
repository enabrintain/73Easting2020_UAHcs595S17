package edu.uah.cs595.tank_sim;

import edu.nps.moves.dis7.*;
import edu.nps.moves.disutil.CoordinateConversions;

/**
 * @author Phil
 *
 */
public class RemoteEntity {


	public int entityId = -1;
	public double lat = 0; 
	public double lon = 0;
	public double elev = 0;
	
	public RemoteEntity(EntityStatePdu esp)
	{
		entityId = esp.getEntityID().getEntityID();
		update(esp);
	}// constructor
	
	public void update(EntityStatePdu esp) {
		Vector3Double location = esp.getEntityLocation();
		double disCoordinates[] = new double[3];
		disCoordinates[0] = location.getX();
		disCoordinates[1] = location.getY();
		disCoordinates[2] = location.getZ();
		double latLonCoordinates[] = CoordinateConversions.xyzToLatLonDegrees(disCoordinates);
		lat = latLonCoordinates[0];
		lon = latLonCoordinates[1];
		elev = latLonCoordinates[2];
        //System.out.println(" EID:[" + eid.getSiteID() + ", " + eid.getApplicationID() + ", " + eid.getEntityID()+ "] ");
        //System.out.println(" Location in DIS coordinates: [" + position.getX() + ", " + position.getY() + ", " + position.getZ() + "]");
        
	}// update

}
