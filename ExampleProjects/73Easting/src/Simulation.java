import java.util.Enumeration;

import edu.nps.moves.deadreckoning.DIS_DR_FPW_02;
import edu.nps.moves.deadreckoning.DIS_DeadReckoning;
import edu.nps.moves.dis7.EntityStatePdu;
import edu.nps.moves.disutil.CoordinateConversions;
import edu.nps.moves.disutil.DisTime;

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
		t14_1.setLocation(29.507035, 46.595540, 250); // set tank location with
														// its position in (
														// lat, lon, alt )
		// t14_1.printLocation();
		dataObj.addTank(t14_1);
		/******* END create local entity *******/

		// DIS_DeadReckoning dr = new DIS_DR_FPW_02();
		DisTime dt = DisTime.getInstance();
		int timestamp = dt.getDisRelativeTimestamp();
		int preTs = timestamp;
		System.out.println("begin at " + timestamp);
		int t = 0;
		EntityStatePdu temp = null;

		while (true) {
			for (T14 tank : dataObj.getTanks())
				tank.update(dataObj);

			
			timestamp = dt.getDisRelativeTimestamp();
			int delta = Math.abs(timestamp - preTs);

			/*
			 * for (Enumeration<EntityStatePdu> e =
			 * dataObj.getRemoteEspdus().elements(); e.hasMoreElements();) {
			 * 
			 * EntityStatePdu temp = e.nextElement() ;
			 * System.out.println("tank's updatetime"+temp.getTimestamp());
			 * System.out.println("time now : "+ timestamp);
			 * printLocation(temp);
			 * System.out.println(temp.getDeadReckoningParameters().
			 * getDeadReckoningAlgorithm()); double[] r =
			 * dataObj.getM_dr().get("1300246").
			 * getUpdatedPositionOrientation();
			 * System.out.println(dataObj.getM_dr().get("1300246").toString( ));
			 * //System.out.println("dr: "); //getDR(timestamp, temp);
			 * 
			 * }
			 */

			/***********************************************************
			// This is where actually needed code probably
			if ((!dataObj.getRemoteEspdus().isEmpty())) {
				temp = dataObj.getRemoteEspdus().get("1300246"); // get
																	// ESpdu
																	// with
																	// EID[1,3002,46]
																	// EID[siteID,
																	// applicationID,EntityID]
				System.out.println("tank's updatetime" + temp.getTimestamp());
				System.out.println("time now : " + timestamp);
				printLocation(temp);
				double[] r = dataObj.getM_dr().get("1300246").getUpdatedPositionOrientation();// get
																								// dead
																								// reckoning
																								// data
																								// of
																								// EID[1,3002,46]
																								// ESpdu
				// location x value: r[0],location y value: r[1], location z
				// value: r[2]
				System.out.println(dataObj.getM_dr().get("1300246").toString());// print
																				// out
																				// all
																				// dead
																				// reckoning
																				// data

			}
			***********************************************************

			if (temp != null) {
				System.out.println("tank's updatetime" + temp.getTimestamp());
				System.out.println("delta: " + delta);
				printLocation(temp);
			}

			t++;
			Thread.sleep(1000);
			System.out.println(t + " times.");
			System.out.println("delta: " + delta);
			preTs = timestamp;
			*/
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
