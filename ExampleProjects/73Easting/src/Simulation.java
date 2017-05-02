import edu.nps.moves.dis7.*;
import edu.nps.moves.disutil.*;

/*
 * main logic 
 * now it's only create one tank and update local Espdu table
 */
public class Simulation extends Thread {
	public static final short EXERCISE_ID = 1;
	public static final short FORCE_ID = 2; // 2 for Iraqis
	public static final short APPLICATION_ID = 1;// 595;
	public static final short SITE_ID = 1;

	private DataRepository dataObj;

	public Simulation(DataRepository data) {
		dataObj = data;
	}

	public void run() {

		/******* create local entity *******/
		T14 t14_1 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID); // (short
																				// exerciseID,
																				// short
																				// forceID,
																				// short
																				// applicationID,
																				// short
																				// siteID)
		while(true)
			if(dataObj.isTerrainServerLive())
				break;
		
		//checkpoint
		//29.517024, 46.555961, 250, dataObj);//
		
		t14_1.setLocation(29.507035, 46.595540, 250, dataObj); // set tank location with
														// its position in (
														// lat, lon, alt )
		dataObj.addTank(t14_1);
		/******* END create local entity *******/

		DisTime dt = DisTime.getInstance();
		int timestamp = dt.getDisRelativeTimestamp();
		System.out.println("begin at " + timestamp);

		while (true) {
			for (T14 tank : dataObj.getTanks())
				tank.update(dataObj);

			
			timestamp = dt.getDisRelativeTimestamp();
			
		}

	} // end run

	public static void printLocation(EntityStatePdu e) {
		System.out.print(" EID=[" + e.getEntityID().getSiteID() + "," + e.getEntityID().getApplicationID() + ","
				+ e.getEntityID().getEntityID() + "]");
		System.out.print(" DIS coordinates location=[" + e.getEntityLocation().getX() + ","
				+ e.getEntityLocation().getY() + "," + e.getEntityLocation().getZ() + "]");
		double c[] = { e.getEntityLocation().getX(), e.getEntityLocation().getY(), e.getEntityLocation().getZ() };
		double lla[] = CoordinateConversions.xyzToLatLonDegrees(c);
		System.out.println(" Location (lat/lon/alt): [" + lla[0] + ", " + lla[1] + ", " + lla[2] + "]");
	}

}// end simulation class
