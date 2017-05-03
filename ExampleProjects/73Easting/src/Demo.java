
/*
 * Using DIS7
 * This demo puts 3 threads(itself, receiver, and simulation) into execution pool and runs them. 
 * DataRepository class shall contain all the EntityState Pdus  and "Event" Pdus(FirePdu, DenotationPdu, at.el)
 * Simulation class shall maintain the main simulation logic, handle event queue
 * The 'main' thread simply listens for a keystroke to gracefully shut down the Application.
 */

import java.io.*;
import java.nio.charset.Charset;
import java.util.*;

import edu.nps.moves.dis7.*;

public class Demo {

	public enum NetworkMode {
		UNICAST, MULTICAST, BROADCAST
	};

	/** default multicast group we send on */
	public static final String DEFAULT_MULTICAST_GROUP = "10.56.0.255";// "192.168.0.255";//"192.168.0.255";
																		// //"239.1.2.3";

	/** Port we send on */
	public static final int PORT = 3000;

	public static void main(String[] args) throws IOException {
		DataRepository dataRepository = new DataRepository();

		EspduReceiver e = new EspduReceiver(dataRepository);
		Simulation s = new Simulation(dataRepository);
		s.start(); // simulation
		e.start(); // receiver

		// goofy way of adding a enter
		BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
		System.out.println("Type enter to stop: \n\n\n");
		try {
			reader.readLine();
		} catch (IOException ex) {
			ex.printStackTrace();
		}
		System.out.println("Terminating...");
		
		
		//Write Log
		/*try {
			File log = new File("73EastingData.txt");
			if(log.exists())
				log.delete();
			log.createNewFile();
			PrintWriter out = new PrintWriter(new FileWriter(log));
			writeLog(out, dataRepository);
			out.flush();
			out.close();
		} catch (Exception ex) {
			ex.printStackTrace();
		}//*/
		
		
		
		

		System.out.println("Finished");
		System.exit(-1);
	}

	private static void writeLog(PrintWriter out, DataRepository d) throws Exception {
		for(FirePdu f : d.shootList)
			out.println("\t" + getKey(f.getEventID()) + ": " + name(f.getFiringEntityID(),d) + " fired at " + name(f.getTargetEntityID(),d) + "["+typeFire(f)+"] @ "+time(f.getTimestamp()));
	
	}
	
	private static String getKey(EventIdentifier eventID) {
		return eventID.getSimulationAddress().getApplication() + ":" + eventID.getEventNumber();
	}
	private static String getKey(EntityID entityID) {
		return entityID.getApplicationID() + ":" + entityID.getEntityID();
	}
	private static String name(EntityID entityID, DataRepository d)
	{
		if(d.getRemoteEspdus().get(getKey(entityID))!=null)
			return new String(d.getRemoteEspdus().get(getKey(entityID)).getMarking().getCharacters(), Charset.forName("US-ASCII")).trim();
		else
			return "Nothing";
	}
	private static String typeFire(FirePdu f) {
		return f.getRange()+"."+f.getEventID().getSimulationAddress().getApplication()+":"+f.getEventID().getEventNumber()+"."+toString(f.getDescriptor().getMunitionType());
	}
	private static String toString(EntityType t) {
		return t.getEntityKind()+":"+t.getDomain()+":"+t.getCountry()+":"+t.getCategory()+":"+t.getSubcategory()+":"+t.getSpecific();
	}
	private static GregorianCalendar cal = new GregorianCalendar();
	private static String time(long timestamp)
	{
		long now = System.currentTimeMillis();
		/*int val = this.getDisTimeUnitsSinceTopOfHour();
         val = (val << 1) | ABSOLUTE_TIMESTAMP_MASK; // always flip the lsb to 1
         return val;
         */
		long val = (timestamp >> 1); // drops the lsb off the timestamp

        /*
        // It turns out that Integer.MAX_VALUE is 2^31-1, which is the time unit value, ie there are
        // 2^31-1 DIS time units in an hour. 3600 sec/hr X 1000 msec/sec divided into the number of
        // msec since the start of the hour gives the percentage of DIS time units in the hour, times
        // the number of DIS time units per hour, equals the time value
        double val = (((double) diff) / (3600.0 * 1000.0)) * Integer.MAX_VALUE;
        int ts = (int) val;*/
		
		double dval = (double)val;
		dval = dval/Integer.MAX_VALUE;
		dval = dval*(3600.0 * 1000.0);
		
		// set cal object to current time
        //long currentTime = System.currentTimeMillis(); // UTC milliseconds since 1970
        cal.setTimeInMillis(now);
        // Set cal to top of the hour, then compute what the cal object says was milliseconds since 1970
        // at the top of the hour
        cal.set(Calendar.MINUTE, 0);
        cal.set(Calendar.SECOND, 0);
        cal.set(Calendar.MILLISECOND, 0);
        long time = (long) (cal.getTimeInMillis()+dval); // top of hour + timestamp val
        
        
        cal.setTimeInMillis(time);

		return cal.get(Calendar.MINUTE)+":"+cal.get(Calendar.SECOND)+"."+cal.get(Calendar.MILLISECOND);
	}

}
