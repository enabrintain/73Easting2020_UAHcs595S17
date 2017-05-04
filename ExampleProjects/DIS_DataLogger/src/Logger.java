import java.io.*;
import java.net.*;
import java.nio.charset.Charset;
import java.util.*;

import edu.nps.moves.dis7.*;
import edu.nps.moves.disutil.Pdu7Factory;

/**
 * 
 */

/**
 * @author Phil Showers
 *
 */
public class Logger implements Runnable{
	
	public static final int MAX_PDU_SIZE = 8192;
	public static final int PORT = 3000;
	public static final String DEFAULT_MULTICAST_GROUP = "10.56.0.255";
	public static final int APPLICATION_ID = 999;
	public static final short USA_FORCE_ID = 1;
	public static final short IRAQI_FORCE_ID = 2; // 2 for Iraqis

	public static long FUNCTIONAL_APPEARANCE_TANK_F = 6291456; //FROZEN 600000 in HEX
	public static long FUNCTIONAL_APPEARANCE_TANK_N = 4194304; //NOT FROZEN 400000 in HEX
	public static long FUNCTIONAL_APPEARANCE_INFANTRY_F = 39911424;//FROZEN  0x02610000
	public static long FUNCTIONAL_APPEARANCE_INFANTRY_N = 37814272;//NOT FROZEN  0x02410000

	private boolean loop = true;
	private boolean exit = false;
	private MulticastSocket socket = null;
	
	class KillLog
	{
		String marking;
		EntityStatePdu original;
		EntityStatePdu firstKilled;
		ArrayList<FirePdu> firePDUs = new ArrayList<>();
		ArrayList<DetonationPdu> detPDUs = new ArrayList<>();
		boolean isKilled = false;

		public KillLog(EntityStatePdu esPdu) {
			original = esPdu;
			marking = new String(esPdu.getMarking().getCharacters(), Charset.forName("US-ASCII")).trim();
		}

		public void kill(EntityStatePdu esPdu) {
			firstKilled = esPdu;
			isKilled = true;
		}

		public void log(FirePdu fire) {
			try{
				firePDUs.add(fire);
			}catch(Exception e)
			{
				e.printStackTrace(System.out);
			}
		}

		public void log(DetonationPdu detonation) {
			try{
				detPDUs.add(detonation);
			}catch(Exception e)
			{
				e.printStackTrace(System.out);
			}
		}
		
	}

	private long numES = 0;
	private long numDet = 0;
	private long numDetNothing = 0;
	private long numFire = 0;

	ArrayList<FirePdu> firePDUs = new ArrayList<>();
	ArrayList<DetonationPdu> detPDUs = new ArrayList<>();
	//ArrayList<EntityStatePdu> esPDUs = new ArrayList<>();
	ArrayList<KillLog> killLogs = new ArrayList<>();

	Hashtable<String, FirePdu> fireHash = new Hashtable<>();
	Hashtable<String, DetonationPdu> detHash = new Hashtable<>();
	Hashtable<String, EntityStatePdu> esHash = new Hashtable<>();
	Hashtable<String, KillLog> killLogHash = new Hashtable<>();

	private GregorianCalendar cal = new GregorianCalendar();
	
	public Logger()
	{
		/****** set up socket *****/
        // Default settings. These are used if no system properties are set. 
        // If system properties are passed in, these are over ridden.
        
        InetAddress address = null; // maybe not needed because of broadcast...
        
        try
        {
            address = InetAddress.getByName(DEFAULT_MULTICAST_GROUP);
        }
        catch(Exception e)
        {
            System.out.println(e + " Cannot create multicast address");
            System.exit(0);
        }

        // All system properties, passed in on the command line via -Dattribute=value
        Properties systemProperties = System.getProperties();

        // IP address we send to
        String destinationIpString = systemProperties.getProperty("destinationIp");

        // Port we send to, and local port we open the socket on
        String portString = systemProperties.getProperty("port");

        // Set up a socket to send information
        try
        {
            socket = new MulticastSocket(PORT);
            socket.setBroadcast(true);

            // Where we send packets to, the destination IP address
            if(destinationIpString != null)
            {
                address = InetAddress.getByName(destinationIpString);
            }
        }
        catch(Exception e)
        {
            System.out.println("Unable to initialize networking. Exiting.");
            System.out.println(e);
            //System.exit(-1);
        }
		/********** END setup socket ***********/
	}

	public static void main(String[] args) {
		Logger logger = new Logger();
		Thread t = new Thread(logger);
		t.start();
		

		// goofy way of adding a enter
		BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
		System.out.println("Type enter to stop: \n\n\n");
		try {
			reader.readLine();
		} catch (IOException ex) {
			ex.printStackTrace();
		}
		System.out.println("Terminating..");
		logger.loop = false;
		try {
			while(!logger.exit)
				Thread.sleep(1000);
		} catch (InterruptedException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

	@Override
	public void run() {
		try {
			DatagramPacket packet;
			// InetAddress address;
			Pdu7Factory pduFactory = new Pdu7Factory();

			// Loop infinitely, receiving datagrams
			while (loop) {
				byte buffer[] = new byte[MAX_PDU_SIZE];
				packet = new DatagramPacket(buffer, buffer.length);

				socket.receive(packet);

				List<Pdu> pduBundle = pduFactory.getPdusFromBundle(packet.getData());

				Iterator it = pduBundle.iterator();

				while (it.hasNext()) {
					EntityID eid;
					Pdu aPdu = (Pdu) it.next();

					if (aPdu instanceof EntityStatePdu) {
						EntityStatePdu esPdu = (EntityStatePdu) aPdu;

						if (esPdu.getEntityID().getApplicationID() != (int) APPLICATION_ID)
						{
						    log(esPdu);
						}
					} else {
						String name = aPdu.getClass().getName();
						/*if (!name.contains("DataPduReceived") && !name.contains("DataPdu"))
							System.out.println("Received " + name);*/
						if (aPdu instanceof FirePdu) {
							FirePdu fire = (FirePdu) aPdu;
							log(fire);
						}
						if (aPdu instanceof DetonationPdu) {
							DetonationPdu detonation = (DetonationPdu) aPdu;
							log(detonation);
						}
					}
					// System.out.println();
				} // end trop through PDU bundle

			} // end while
			
			//Write Log
			try {
				File log = new File("73EastingLog.txt");
				if(log.exists())
					log.delete();
				log.createNewFile();
				PrintWriter out = new PrintWriter(new FileWriter(log));
				writeLog(out);
				out.flush();
				out.close();
			} catch (Exception e) {
				e.printStackTrace();
			}
			exit = true; //done writing, exit.
		} // End try
		catch (Exception e) {
			System.out.println(e);
		}
	}

	private void log(DetonationPdu detonation) {
		try {
			numDet++;
			detPDUs.add(detonation);
			if(killLogHash.containsKey(getKey(detonation.getFiringEntityID())))
				killLogHash.get(getKey(detonation.getFiringEntityID())).log(detonation);
			if(killLogHash.containsKey(getKey(detonation.getTargetEntityID()))){
				killLogHash.get(getKey(detonation.getTargetEntityID())).log(detonation);
			}
			else
				numDetNothing++;
			detHash.put(getKey(detonation.getEventID()), detonation);
		} catch (Exception e) {
			// TODO Auto-generated catch block
			//System.out.println("Logger.log(detonation) " + getKey(detonation.getTargetEntityID()) + ((killLogHash.get(getKey(detonation.getTargetEntityID()))!=null)?"notNull":"Null"));
			//System.out.println("Logger.log(detonation) " + getKey(detonation.getExplodingEntityID()));
			e.printStackTrace();
			//System.out.println(detonation.getExplodingEntityID().getEntityID());
		}
	}

	private void log(FirePdu fire) {
		try {
			numFire++;
			firePDUs.add(fire);
			if(killLogHash.containsKey(getKey(fire.getTargetEntityID())))
				killLogHash.get(getKey(fire.getTargetEntityID())).log(fire);
			if(killLogHash.containsKey(getKey(fire.getFiringEntityID())))
				killLogHash.get(getKey(fire.getFiringEntityID())).log(fire);

			fireHash.put(getKey(fire.getEventID()), fire);
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

	private void log(EntityStatePdu esPdu) {
		try {
			numES++;
			//esPDUs.add(esPdu);
			if(!killLogHash.containsKey(getKey(esPdu.getEntityID()))){
				KillLog KL = new KillLog(esPdu);
				killLogHash.put(getKey(esPdu.getEntityID()), KL);
				killLogs.add(KL);
			}
			if(isKilled(esPdu))
				if(!killLogHash.get(getKey(esPdu.getEntityID())).isKilled)
					killLogHash.get(getKey(esPdu.getEntityID())).kill(esPdu);

			esHash.put(getKey(esPdu.getEntityID()), esPdu);
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

	private String getKey(EntityID entityID) {
		return entityID.getApplicationID() + ":" + entityID.getEntityID();
	}

	private String getKey(EntityType e) {
		return e.getEntityKind() + ":" + e.getDomain() + ":" +  e.getCountry() + ":" + e.getCategory() + ":" + e.getSubcategory() + ":" + e.getSpecific() + ":" + e.getExtra();
	}

	//check to see if the vehicle is 
	private boolean isKilled(EntityStatePdu esPdu) {
		
		long app = esPdu.getEntityAppearance();
		long tmp = app>>3;
	    tmp = tmp&3;
	    if(tmp!=3)
	    	System.out.println("Logger.isKilled() " + name(esPdu.getEntityID()) + " " + tmp);
		
		return !(esPdu.getEntityAppearance() == FUNCTIONAL_APPEARANCE_INFANTRY_F ||
				esPdu.getEntityAppearance() == FUNCTIONAL_APPEARANCE_INFANTRY_N ||
				esPdu.getEntityAppearance() == FUNCTIONAL_APPEARANCE_TANK_F ||
				esPdu.getEntityAppearance() == FUNCTIONAL_APPEARANCE_TANK_N); 
	}

	private String getKey(EventIdentifier eventID) {
		return eventID.getSimulationAddress().getApplication() + ":" + eventID.getEventNumber();
	}

	private void writeLog(PrintWriter out) {
		out.println("Number of ES PDUs: \t" + numES);
		out.println("Number of Fire PDUs: \t" + numFire);
		out.println("Number of Detonate PDUs: \t" + numDet);
		out.println("Number of Detonate PDUs containing null Targets: \t" + numDetNothing);

		processFires(out);
		
		out.println("\nAll Fire PDUs:");
		for(FirePdu f : firePDUs)
			out.println("\t" + getKey(f.getEventID()) + ": " + name(f.getFiringEntityID()) + " fired at " + name(f.getTargetEntityID()) + "["+typeFire(f)+"] @ "+time(f.getTimestamp()));

		out.println("\nAll Detonate PDUs:");
		for(DetonationPdu f : detPDUs)
			out.println("\t" + getKey(f.getEventID()) + ": " + name(f.getFiringEntityID()) + " fired at " + name(f.getTargetEntityID()) + "["+typeDet(f)+"] @ "+time(f.getTimestamp()));

		int numDead = 0;
		int deadRed = 0;
		int deadBlue = 0;
		for(KillLog kl : killLogs)
			if(kl.isKilled){
				numDead++;
				if(kl.original.getForceId()==1)
					deadBlue++;
				else
					deadRed++;
			}

		out.println("Number of Dead Entities: \t" + numDead);
		out.println("Number of Dead Blue: \t" + deadBlue);
		out.println("Number of Dead Red: \t" + deadRed);
		
		for(KillLog kl : killLogs)
			writeLog(out, kl);

		/*out.println("\nEntityStatePdu Log:");
		try {
		
			for(EntityStatePdu e : esPDUs)
			{
				out.println("\t" + getKey(e.getEntityID()) + "("+name(e.getEntityID())+"): " + e.getEntityAppearance());
			}

			//dos.close();
		} catch (Exception e1) {
			e1.printStackTrace();
		}//*/
	}

	private void processFires(PrintWriter out) {
		//num hits usa hits / misses
		//num hits iraqi hits / misses
		ArrayList<FirePdu> usaFires = new ArrayList<>();
		int usaHits=0, usaMisses = 0;
		double usaHitSumDist = 0, usaMissSumDist = 0;
		ArrayList<FirePdu> iraqiFires = new ArrayList<>();
		int iraqiHits=0, iraqiMisses = 0;
		double iraqiHitSumDist = 0, iraqiMissSumDist = 0;
		for(FirePdu f : firePDUs)
		{
			String eskey = getKey(f.getFiringEntityID());
			EntityStatePdu firingEntity = esHash.get(eskey);
			if(firingEntity==null)
				System.out.println("Logger.processFires() firingEntity==null for " + eskey + " : " + getKey(f.getEventID()));
			else
			{
				String evtKey = getKey(f.getEventID());
				DetonationPdu d = detHash.get(evtKey);
				if(firingEntity.getForceId()==USA_FORCE_ID){
					usaFires.add(f);
					if(d==null)
						System.out.println("Logger.processFires() no associated detonate with " + evtKey);
					else
						if(d.getDetonationResult()==1) //hit
						{
							usaHits++;
							usaHitSumDist += f.getRange();
						}
						else
						{
							usaMisses++;
							usaMissSumDist += f.getRange();
						}
				}// usa shooting
				else{
					iraqiFires.add(f);
					if(d==null)
						System.out.println("Logger.processFires() no associated detonate with " + evtKey);
					else
						if(d.getDetonationResult()==1) //hit
						{
							iraqiHits++;
							iraqiHitSumDist += f.getRange();
						}
						else
						{
							iraqiMisses++;
							iraqiMissSumDist += f.getRange();
						}
				}//else iraqi shooting
			}//if shooter field not null
		}// for every fire pdu

		out.println("USA forces fired \t" + (usaHits + usaMisses) + "\t times");
		out.println("USA forces hit \t" + usaHits + "\t times");
		out.println("USA forces missed \t" + usaMisses + "\t times");
		out.println("The mean distance of USA shots which hit was \t" + ((double)usaHitSumDist/(double)usaHits) + "\t ");
		out.println("The mean distance of USA shots which missed was \t" + ((double)usaMissSumDist/(double)usaMisses) + "\t ");
		
		out.println("Iraqi forces fired \t" + (iraqiHits + iraqiMisses) + "\t times");
		out.println("Iraqi forces hit \t" + iraqiHits + "\t times");
		out.println("Iraqi forces missed \t" + iraqiMisses + "\t times");
		out.println("The mean distance of Iraqi shots which hit was \t" + ((double)iraqiHitSumDist/(double)iraqiHits) + "\t ");
		out.println("The mean distance of Iraqi shots which missed was \t" + ((double)iraqiMissSumDist/(double)iraqiMisses) + "\t ");
		
		//sort weapon types used
		Hashtable<String, Integer> usaWeaponHash = new Hashtable<>();
		Hashtable<String, Integer> iraqiWeaponHash = new Hashtable<>();
		Hashtable<String, Integer> usaWeaponKillHash = new Hashtable<>();
		Hashtable<String, Integer> iraqiWeaponKillHash = new Hashtable<>();
		for(FirePdu f : usaFires)
		{
			DetonationPdu d = detHash.get(getKey(f.getEventID()));
			if(d!=null)
			{
				boolean hit = d.getDetonationResult()==1;
				String key = getKey(d.getDescriptor().getMunitionType());
				if(!usaWeaponHash.containsKey(key))
					usaWeaponHash.put(key, new Integer(0));
				usaWeaponHash.put(key, usaWeaponHash.get(key)+1);
				if(hit)
				{
					if(!usaWeaponKillHash.containsKey(key))
						usaWeaponKillHash.put(key, new Integer(0));
					usaWeaponKillHash.put(key, usaWeaponKillHash.get(key)+1);
				}
			}
		}//for each usa fires//*/
		for(FirePdu f : iraqiFires)
		{
			DetonationPdu d = detHash.get(getKey(f.getEventID()));
			if(d!=null)
			{
				boolean hit = d.getDetonationResult()==1;
				String key = getKey(d.getDescriptor().getMunitionType());
				if(!iraqiWeaponHash.containsKey(key))
					iraqiWeaponHash.put(key, new Integer(0));
				iraqiWeaponHash.put(key, iraqiWeaponHash.get(key)+1);
				if(hit)
				{
					if(!iraqiWeaponKillHash.containsKey(key))
						iraqiWeaponKillHash.put(key, new Integer(0));
					iraqiWeaponKillHash.put(key, iraqiWeaponKillHash.get(key)+1);
				}
			}
		}//for each iraqi fires//*/
		
		out.println("USA Weapon Table");
		for (Enumeration<String> e = usaWeaponHash.keys(); e.hasMoreElements();) {
			String key="";
		    try {
				key = e.nextElement();
				int numWeaponShots = usaWeaponHash.get(key);
				int kills = usaWeaponKillHash.get(key);
				out.println(key + "\t" + numWeaponShots + "\t" + kills + "\t"+(kills/numWeaponShots)+"");
			} catch (Exception e1) {
				out.println(key);
				e1.printStackTrace();
			}
		}
		
		out.println("\nIraqi Weapon Table");
		for (Enumeration<String> e = iraqiWeaponHash.keys(); e.hasMoreElements();) {
			String key="";
		    try {
				key = e.nextElement();
				int numWeaponShots = iraqiWeaponHash.get(key);
				int kills = iraqiWeaponKillHash.get(key);
				out.println(key + "\t" + numWeaponShots + "\t" + kills + "\t"+(kills/numWeaponShots)+"");
			} catch (Exception e1) {
				out.println(key);
				e1.printStackTrace();
			}
		}
	}

	private void writeLog(PrintWriter out, KillLog kl) {
		out.println();
		out.print ("["+getKey(kl.original.getEntityID())+"]"+name(kl.original.getEntityID()));
		out.println(kl.isKilled?"(@"+time(kl.original.getTimestamp())+") was Killed in sim at "+time(kl.firstKilled.getTimestamp()):" survived the sim.");
		if(kl.firePDUs.size()>0){
			out.println("\nFire Log:");
			for(FirePdu f : kl.firePDUs)
				out.println("\t" + getKey(f.getEventID()) + ": " + name(f.getFiringEntityID()) + " fired at " + name(f.getTargetEntityID()) + "["+typeFire(f)+"] @ "+time(f.getTimestamp()));
		}
		if(kl.detPDUs.size()>0){
			out.println("\nDetonate Log:");
			for(DetonationPdu d : kl.detPDUs)
				out.println("\t" + getKey(d.getEventID()) + ": " + name(d.getFiringEntityID()) + " detonate at " + name(d.getTargetEntityID()) + "["+typeDet(d)+"] @ "+time(d.getTimestamp()));
		}
		
	}
	
	private String typeDet(DetonationPdu d) {
		return d.getDetonationResult()+"."+d.getEventID().getSimulationAddress().getApplication()+":"+d.getEventID().getEventNumber()+"."+toString(d.getDescriptor().getMunitionType());
	}
	
	private String typeFire(FirePdu f) {
		return f.getRange()+"."+f.getEventID().getSimulationAddress().getApplication()+":"+f.getEventID().getEventNumber()+"."+toString(f.getDescriptor().getMunitionType());
	}

	private String toString(EntityType t) {
		return t.getEntityKind()+":"+t.getDomain()+":"+t.getCountry()+":"+t.getCategory()+":"+t.getSubcategory()+":"+t.getSpecific();
	}

	private String name(EntityID entityID)
	{
		if(esHash.get(getKey(entityID))!=null)
			return new String(esHash.get(getKey(entityID)).getMarking().getCharacters(), Charset.forName("US-ASCII")).trim();
		else
			return "Nothing";
	}
	
	private String time(long timestamp)
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
