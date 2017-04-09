
/*
 * T14 Tank Class
 * @author Rui Wang
 * @author Phil Showers
 */

import java.io.ByteArrayOutputStream;
import java.io.UnsupportedEncodingException;
import java.util.ArrayList;

import edu.nps.moves.dis7.*;
import edu.nps.moves.disutil.CoordinateConversions;
import edu.nps.moves.disutil.DisTime;

public class T14 {

	/******** T14 Field ********/
	private static int m_count = 302; // keep track on how many T14 has been
										// created
	private int ID = -1;

	// protected EntityStatePdu m_espdu;// Entity State
	protected DisTime m_disTime; // time padding
	protected short ExerciseID;
	protected short ForceId;
	protected short ApplicationID;
	protected short SiteID;

	protected double m_disCoordinates[]; // tank's Coordinates in X, Y, Z
	protected Vector3Double m_location; // Tank's location in lan, lon, alt
	// more like velocity, orientation

	//protected FirePdu m_firepdu; // fire event
	//protected DetonationPdu m_depdu; // been hit, report demage

	private long localClock;

	/********* End Field **************/

	/*** constructor with location ***/
	public T14(short exerciseID, short forceID, short applicationID, short siteID) {
		ExerciseID = exerciseID;
		ForceId = forceID;
		ApplicationID = applicationID;
		SiteID = siteID;
		localClock = System.currentTimeMillis();
		m_count++; // increment T14 count
		ID = m_count;

		m_disTime = DisTime.getInstance();
	} // end constructor

	private boolean sendFlag = true;
	private long lastTsent = -1;


	long lastUpdated = -1;
	private boolean firedFlag = false;
	private ArrayList<FirePdu> firePdus = new ArrayList<>();
	private boolean detonateFlag = false;
	private ArrayList<DetonationPdu> detonatePdus = new ArrayList<>();
	
	public void update(DataRepository dataObj) {

		/*if(lastUpdated!=-1){
			System.out.println("Update " + (System.currentTimeMillis()-lastUpdated));
		}
		lastUpdated = System.currentTimeMillis();*/
		
		// Does the Tank see something to shoot at?

		// Has the tank been shot at?
		if(firedFlag)
			fireUpdate();
		if(detonateFlag)
			detonateUpdate();

		
		if (shouldSendUpdate())
			dataObj.sendESPdu(this.getEntityStatePdu());

	}// update

	private void detonateUpdate() {
		for(DetonationPdu d : detonatePdus)
			System.out.println(d.getFiringEntityID().getEntityID() + " detonated " + this.ID);
		detonatePdus.clear();	
		detonateFlag = false;
	}

	private void fireUpdate() {
		for(FirePdu f : firePdus)
			System.out.println(f.getFiringEntityID().getEntityID() + " fired at " + this.ID);
		firePdus.clear();	
		firedFlag = false;
	}

	// if the tank is moving then send a ES pdu when local dead reckoning
	// and actual sim location diverge
	// otherwise send "heartbeat" ES pdu once every 5 seconds.
	//TODO: this algorithm is not exactly right...
	private boolean shouldSendUpdate() {
		long num = 2; // send a ESPdu every num seconds
		
		long t = ((System.currentTimeMillis() - localClock) / 1000);
		//System.out.println("\t" + t);
		if (t % num == 0) // if the time since the sim started is divisable by num then update ES PDU
		{
			if (sendFlag) {
				sendFlag = false; // send once and then set flag to false
				//System.out.println("\t" + t + "%" + num + " = " + (t % num));
				return true;
			} else {
				// System.out.println("not sending");
			}
		}
		else
		{
			sendFlag = true; // set flag to true once the time is past
		}
		
		if (t != lastTsent) {
			lastTsent = t;
			sendFlag = true;
		}
		
		return false;
	}// shouldSendUpdate

	/*****************************************************************/
	public EntityStatePdu getEntityStatePdu() {
		EntityStatePdu espdu = new EntityStatePdu();
		espdu.setExerciseID(ExerciseID);
		espdu.setForceId(ForceId);

		espdu.setNumberOfVariableParameters((short) 4); // this selects the symbol in VRForces
		
		// m_setEntityIDParameter(applicationID, siteID);
		EntityID eid = espdu.getEntityID();
		eid.setSiteID(SiteID);
		eid.setApplicationID(ApplicationID);
		eid.setEntityID(ID);

		// m_setEntityTypeParameter();
		EntityType entityType = espdu.getEntityType();
		entityType.setEntityKind((short) 1); // Platform (vs lifeform, munition, sensor, etc.)
		entityType.setDomain((short) 1); // Land (vs air, surface, subsurface, space)
		entityType.setCountry(222); //102 Iraq
		entityType.setCategory((short) 1); // Tank
		entityType.setSubcategory((short) 2); // M1 Abrams
		entityType.setSpecific((short) 1); // M1A2 Abrams
		entityType.setExtra((short) 1);
		
		/*EntityType alternativeEntityType = espdu.getAlternativeEntityType();
		alternativeEntityType.setEntityKind((short) 1); // Platform (vs lifeform, munition, sensor, etc.)
		alternativeEntityType.setDomain((short) 1); // Land (vs air, surface, subsurface, space)
		alternativeEntityType.setCountry(222); //102 Iraq
		alternativeEntityType.setCategory((short) 1); // Tank
		alternativeEntityType.setSubcategory((short) 2); // M1 Abrams
		alternativeEntityType.setSpecific((short) 1); // M1A2 Abrams
		alternativeEntityType.setExtra((short) 1);*/

		espdu.setTimestamp(DisTime.getInstance().getDisRelativeTimestamp());

		espdu.getMarking().setCharacterSet((short) 1); // ascii
		try {
			espdu.getMarking().setCharacters("AAAAAAAAAAAAAAAAAAAAAAAAAAAA".getBytes("US-ASCII"));
		} catch (UnsupportedEncodingException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		m_location = espdu.getEntityLocation();
		m_location.setX(m_disCoordinates[0]);
		m_location.setY(m_disCoordinates[1]);
		m_location.setZ(m_disCoordinates[2]);

		espdu.setLength(espdu.getMarshalledSize());
		return espdu;
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

	public EntityID getEntityID(EntityID eid) {
		if (eid == null)
			eid = new EntityID();
		eid.setApplicationID(this.ApplicationID);
		eid.setEntityID(this.ID);
		eid.setSiteID(this.SiteID);
		return eid;
	}

	/***** END EntityID ********/

	/***** END EntityType ********/

	/***** Location ********/
	public void setLocation(double lat, double lon, double alt) {
		m_disCoordinates = CoordinateConversions.getXYZfromLatLonDegrees(lat, lon, alt);
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

	public void fireTarget(FirePdu fire) {
		firedFlag = true;
		firePdus.add(fire);
	}

	public void detonationTarget(DetonationPdu detonation) {
		detonateFlag  = true;
		detonatePdus.add(detonation);
	}

	/*
	 * public void printLocation() { System.out .print(" EID=[" +
	 * m_eid.getSiteID() + "," + m_eid.getApplicationID() + "," +
	 * m_eid.getEntityID() + "]");
	 * System.out.print(" DIS coordinates location=[" + m_location.getX() + ","
	 * + m_location.getY() + "," + m_location.getZ() + "]"); double c[] = {
	 * m_location.getX(), m_location.getY(), m_location.getZ() }; double lla[] =
	 * CoordinateConversions.xyzToLatLonDegrees(c);
	 * System.out.println(" Location (lat/lon/alt): [" + lla[0] + ", " + lla[1]
	 * + ", " + lla[2] + "]"); }
	 */
	/***** END Location ********/

	/****** fire event ***************/
	/*
	 * when a Fire event happened, this function will instantiate a FirePdu
	 * according to the eventID
	 *
	 * public void fire(EventID pEventID) { // EventIdentifier m_firepdu = new
	 * FirePdu() ; m_firepdu.setEventID(pEventID);
	 * m_firepdu.setExerciseID(m_espdu.getExerciseID());
	 * //m_firepdu.setRangeToTarget(pRangeToTarget) // more tobe done
	 * 
	 * } //
	 */

	/*
	 * public boolean isTargetHit(EventID eventID) { // EventIdentifier
	 * 
	 * // more to be done return false; }//
	 */
	/****** END fire event ***************/

	/****** denotation ***************/

	// more to be done

	/****** END denotation ***************/

} // end T14 class
