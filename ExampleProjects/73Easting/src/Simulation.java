import edu.nps.moves.dis7.*;
import edu.nps.moves.disutil.*;

/*
 * main logic 
 * This is where the update loop lives
 * @author rui wang and phillip showers
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
		
		/******* Verify Connectivity to Terrain Server *******/
		while(true)
			if(dataObj.isTerrainServerLive())
				break;

		/******* create local entity *******/
		T14 t14_1 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID, "_AR 29_"); 
		t14_1.setLocation(29.515003, 46.600697, 249, dataObj);
		T14 t14_2 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID, "_AR 33_"); 
		t14_2.setLocation(29.514684, 46.602762, 249, dataObj);
		T14 t14_3 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID, "_AR 46_"); 
		t14_3.setLocation(29.514522, 46.603010, 249, dataObj);
		T14 t14_4 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID, "_AR 47_"); 
		t14_4.setLocation(29.514521, 46.602031, 249, dataObj); // set tank location with its position in (lat, lon, alt)
		T14 t14_5 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID, "_AR 48_"); 
		t14_5.setLocation(29.514702, 46.602278, 249, dataObj);
		T14 t14_6 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID, "_AR 49_"); 
		t14_6.setLocation(29.514522, 46.602515, 249, dataObj);
		T14 t14_7 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID, "_AR 50_"); 
		t14_7.setLocation(29.514999, 46.600476, 250, dataObj);
		T14 t14_8 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID, "_AR 51_"); 
		t14_8.setLocation(29.514993, 46.600259, 250, dataObj);
		T14 t14_9 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID, "_AR 72_"); 
		t14_9.setLocation(29.514299, 46.602272, 250, dataObj);
		T14 t14_10 = new T14(EXERCISE_ID, FORCE_ID, APPLICATION_ID, SITE_ID, "_AR 73_"); 
		t14_10.setLocation(29.514311, 46.602773, 250, dataObj);

		// old test checkpoint
		//29.517024, 46.555961, 250, dataObj);

		dataObj.addTank(t14_1);
		dataObj.addTank(t14_2);
		dataObj.addTank(t14_3);
		dataObj.addTank(t14_4);
		dataObj.addTank(t14_5);
		dataObj.addTank(t14_6);
		dataObj.addTank(t14_7);
		dataObj.addTank(t14_8);
		dataObj.addTank(t14_9);
		dataObj.addTank(t14_10);
		/******* END create local entity *******/

		DisTime dt = DisTime.getInstance();
		int timestamp = dt.getDisRelativeTimestamp();
		System.out.println("begin at " + timestamp);

		while (true) {
			for (T14 tank : dataObj.getTanks()){
				//System.out.println("Simulation.run() update " + tank.marking);
				tank.update(dataObj);
			}
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
