
/*
 * T14 Tank Class
 * @author Rui Wang
 * @author Phil Showers
 */

import java.io.ByteArrayOutputStream;
import java.io.UnsupportedEncodingException;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.Random;
import java.util.Vector;

import edu.nps.moves.deadreckoning.DIS_DeadReckoning;
import edu.nps.moves.dis7.*;
import edu.nps.moves.disutil.CoordinateConversions;
import edu.nps.moves.disutil.DisTime;

public class T14 {

	/******** T14 Field ********/
	public static long FUNCTIONAL_APPEARANCE = 400000;
	public static long KILLED_APPEARANCE = 408038;
	public static double MIN_FIRE_DISTANCE = 4000;
	public static double MAX_FIRE_DISTANCE = 20000;

	public static double FIRE_DELAY = 10; // 10 seconds

	private static int m_count = 302; // keep track on how many T14 has been
										// created
	private static int m_loads = 45;
	private int ID = -1;

	protected DisTime m_disTime; // time padding
	protected short ExerciseID;
	protected short ForceId;
	protected short ApplicationID;
	protected short SiteID;

	protected double CrewQualityMultiplier = 0.8; // range is 0 to 1, with 0
													// being absent and 1 being
													// the best.

	protected double m_disCoordinates[]; // tank's Coordinates in X, Y, Z
	protected Vector3Double m_location; // Tank's location in lan, lon, alt

	protected EulerAngles m_orientation;
	protected Vector3Float m_linearVelocity;

	protected FirePdu m_firepdu; // fire event
	protected DetonationPdu m_depdu; // been hit, report demage
	protected EntityStatePdu aimed_target = null;

	protected long m_appearance;

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

		m_appearance = FUNCTIONAL_APPEARANCE;
		m_disTime = DisTime.getInstance();
	} // end constructor

	private boolean sendFlag = true;
	private long lastTsent = -1;

	long lastUpdated = -1;
	private boolean firedFlag = false;
	private ArrayList<FirePdu> firePdus = new ArrayList<>();
	private boolean detonateFlag = false;
	private ArrayList<DetonationPdu> detonatePdus = new ArrayList<>();
	private long localClock = -1;
	private double fireTime = 0.0;
	private boolean fireWait = false;

	public void update(DataRepository dataObj) {

		// Does the Tank see something to shoot at?
		if (aimed_target == null) {
			findNearestTarget(dataObj);
			// calculate fire delay
			fireTime = System.currentTimeMillis();
		} else {
			// check if the target dead
			EntityID target = aimed_target.getEntityID();
			if (dataObj.getRemoteEspdus().get(dataObj.getkey(target)).getEntityAppearance() != FUNCTIONAL_APPEARANCE) {
				// target is dead
				aimed_target = null;
				fireWait = false;
			} else {
				// shoot at target if time>=firetime
				if (System.currentTimeMillis() >= fireTime)
					if (!fireWait) {
						// firewait is false - so shoot!
						shootAt(target, dataObj); // generates fire pdu and
													// xmits it
						fireWait = true;
						fireTime += 500; // wait half a second and then
											// calculate hit
					} else {
						// fire wait is true - so calculate pHit
						if (isTargetHit(getRange(dataObj.getDeadReckonings().get(dataObj.getkey(target))
								.getUpdatedPositionOrientation()))) {
							// Target was hit - send a detonate!
							detonateAt(target, dataObj);
							
							// decide to shoot at target again
							fireWait = false;
							
							 // as CrewQualityMultiplier -> 0, firedelay -> 15
							fireTime += (FIRE_DELAY + (5.0 - 5.0 * CrewQualityMultiplier)) * 1000;
						}
					}
			}
		}

		// Has the tank been shot at?
		if (firedFlag) {
			fireUpdate();

		}
		if (detonateFlag)
			detonateUpdate(dataObj);

		// if it's time to update Espdus
		if (shouldSendUpdate())
			dataObj.sendESPdu(this.getEntityStatePdu());

	}// update

	private void detonateAt(EntityID target, DataRepository dataObj) {
		DetonationPdu dPDU = new DetonationPdu();
		dPDU.setExerciseID(ExerciseID);
		EntityID firingId = dPDU.getFiringEntityID();
		firingId.setSiteID(SiteID);
		firingId.setApplicationID(ApplicationID);
		firingId.setEntityID(ID);
		EntityID targetId = dPDU.getTargetEntityID();
		targetId.setSiteID(target.getSiteID());
		targetId.setApplicationID(target.getApplicationID());
		firingId.setEntityID(target.getEntityID());

		EventIdentifier eventId = dPDU.getEventID();
		eventId.getSimulationAddress().setApplication(ApplicationID);
		eventId.getSimulationAddress().setSite(SiteID);
		eventId.setEventNumber(dataObj.getEventID());

		
		
		//STOPPED HERE
		
		double[] locAndOrientation = dataObj.getDeadReckonings().get(dataObj.getkey(target))
				.getUpdatedPositionOrientation();
		Vector3Double location = dPDU.getLocationInWorldCoordinates();
		location.setX(locAndOrientation[0]);
		location.setY(locAndOrientation[1]);
		location.setZ(locAndOrientation[2]);

		MunitionDescriptor descriptor = dPDU.getDescriptor();
		descriptor.setQuantity(4);
		EntityType munitionType = descriptor.getMunitionType();
		munitionType.setEntityKind((short) 2); // munition (vs platform,
												// lifeform, munition, sensor,
												// etc.)
		munitionType.setDomain((short) 1); // Land (vs air, surface, subsurface,
											// space)
		munitionType.setCountry(222); // 102 Iraq
		munitionType.setCategory((short) 2);
		munitionType.setSubcategory((short) 2);
		munitionType.setSpecific((short) 1);
		descriptor.setRate(600); // just 'cause

		dPDU.setRange(getRange(locAndOrientation));
		calculateVelocity(dPDU, locAndOrientation);

		dPDU.setTimestamp(DisTime.getInstance().getDisRelativeTimestamp());

		dataObj.sendDetonationPDU(dPDU);
		// isTargetHit
	}

	private void shootAt(EntityID target, DataRepository dataObj) {
		FirePdu fPDU = new FirePdu();
		fPDU.setExerciseID(ExerciseID);
		EntityID firingId = fPDU.getFiringEntityID();
		firingId.setSiteID(SiteID);
		firingId.setApplicationID(ApplicationID);
		firingId.setEntityID(ID);
		EntityID targetId = fPDU.getTargetEntityID();
		targetId.setSiteID(target.getSiteID());
		targetId.setApplicationID(target.getApplicationID());
		firingId.setEntityID(target.getEntityID());

		EventIdentifier eventId = fPDU.getEventID();
		eventId.getSimulationAddress().setApplication(ApplicationID);
		eventId.getSimulationAddress().setSite(SiteID);
		eventId.setEventNumber(dataObj.getEventID());

		double[] locAndOrientation = dataObj.getDeadReckonings().get(dataObj.getkey(target))
				.getUpdatedPositionOrientation();
		Vector3Double location = fPDU.getLocationInWorldCoordinates();
		location.setX(locAndOrientation[0]);
		location.setY(locAndOrientation[1]);
		location.setZ(locAndOrientation[2]);

		MunitionDescriptor descriptor = fPDU.getDescriptor();
		descriptor.setQuantity(4);
		EntityType munitionType = descriptor.getMunitionType();
		munitionType.setEntityKind((short) 2); // munition (vs platform,
												// lifeform, munition, sensor,
												// etc.)
		munitionType.setDomain((short) 1); // Land (vs air, surface, subsurface,
											// space)
		munitionType.setCountry(222); // 102 Iraq
		munitionType.setCategory((short) 2);
		munitionType.setSubcategory((short) 2);
		munitionType.setSpecific((short) 1);
		descriptor.setRate(600); // just 'cause

		fPDU.setRange(getRange(locAndOrientation));
		calculateVelocity(fPDU, locAndOrientation);

		fPDU.setTimestamp(DisTime.getInstance().getDisRelativeTimestamp());

		dataObj.sendFirePDU(fPDU);
		// isTargetHit
	}

	private void calculateVelocity(FirePdu fPDU, double[] locAndOrientation) {
		double x = locAndOrientation[0] - m_location.getX();
		double y = locAndOrientation[1] - m_location.getY();
		double z = locAndOrientation[2] - m_location.getZ();
		double vel = getRange(locAndOrientation) / fPDU.getDescriptor().getRate();
		fPDU.getVelocity().setX((float) (x / vel));
		fPDU.getVelocity().setY((float) (y / vel));
		fPDU.getVelocity().setZ((float) (z / vel));
	}

	private float getRange(double[] location) {
		double lx = m_disCoordinates[0];
		double ly = m_disCoordinates[1];
		double lz = m_disCoordinates[2];

		double rx = location[0];
		double ry = location[1];
		double rz = location[2];
		double distance = Math.sqrt(Math.pow((lx - rx), 2.0) + Math.pow((ly - ry), 2.0) + Math.pow((lz - rz), 2.0));

		return (float) distance;
	}

	private void detonateUpdate(DataRepository dataObj) {
		for (DetonationPdu d : detonatePdus) {

			System.out.println(d.getFiringEntityID().getEntityID() + " detonated " + this.ID);
			int a = d.getFiringEntityID().getSiteID();
			int b = d.getFiringEntityID().getApplicationID();
			int c = d.getFiringEntityID().getEntityID();
			String fire_tank_key = String.valueOf(a) + String.valueOf(b) + String.valueOf(c);
			double[] r = dataObj.getDeadReckonings().get(fire_tank_key).getUpdatedPositionOrientation();
			double rx = r[0];
			double ry = r[1];
			double rz = r[2];
			double lx = this.getM_location().getX();
			double ly = this.getM_location().getY();
			double lz = this.getM_location().getZ();

			double fire_distance = Math
					.sqrt(Math.pow((lx - rx), 2.0) + Math.pow((ly - ry), 2.0) + Math.pow((lz - rz), 2.0));

			if (isDead(fire_distance))
				m_appearance = KILLED_APPEARANCE;

		}
		detonatePdus.clear();
		detonateFlag = false;
	}

	private void fireUpdate() {
		for (FirePdu f : firePdus)
			System.out.println(f.getFiringEntityID().getEntityID() + " fired at " + this.ID);
		firePdus.clear();
		firedFlag = false;
	}

	// if the tank is moving then send a ES pdu when local dead reckoning
	// and actual sim location diverge
	// otherwise send "heartbeat" ES pdu once every 5 seconds.
	// TODO: this algorithm is not exactly right...
	private boolean shouldSendUpdate() {
		long num = 2; // send a ESPdu every num seconds

		long t = ((System.currentTimeMillis() - localClock) / 1000);
		// System.out.println("\t" + t);
		if (t % num == 0) // if the time since the sim started is divisable by
							// num then update ES PDU
		{
			if (sendFlag) {
				sendFlag = false; // send once and then set flag to false
				// System.out.println("\t" + t + "%" + num + " = " + (t % num));
				return true;
			} else {
				// System.out.println("not sending");
			}
		} else {
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

		espdu.setNumberOfVariableParameters((short) 4); // this selects the
														// symbol in VRForces

		// m_setEntityIDParameter(applicationID, siteID);
		EntityID eid = espdu.getEntityID();
		eid.setSiteID(SiteID);
		eid.setApplicationID(ApplicationID);
		eid.setEntityID(ID);

		// m_setEntityTypeParameter();
		EntityType entityType = espdu.getEntityType();
		entityType.setEntityKind((short) 1); // Platform (vs lifeform, munition,
												// sensor, etc.)
		entityType.setDomain((short) 1); // Land (vs air, surface, subsurface,
											// space)
		entityType.setCountry(222); // 102 Iraq
		entityType.setCategory((short) 1); // Tank
		entityType.setSubcategory((short) 2); // M1 Abrams
		entityType.setSpecific((short) 1); // M1A2 Abrams
		entityType.setExtra((short) 1);

		/*
		 * EntityType alternativeEntityType = espdu.getAlternativeEntityType();
		 * alternativeEntityType.setEntityKind((short) 1); // Platform (vs
		 * lifeform, munition, sensor, etc.)
		 * alternativeEntityType.setDomain((short) 1); // Land (vs air, surface,
		 * subsurface, space) alternativeEntityType.setCountry(222); //102 Iraq
		 * alternativeEntityType.setCategory((short) 1); // Tank
		 * alternativeEntityType.setSubcategory((short) 2); // M1 Abrams
		 * alternativeEntityType.setSpecific((short) 1); // M1A2 Abrams
		 * alternativeEntityType.setExtra((short) 1);
		 */

		espdu.setTimestamp(DisTime.getInstance().getDisRelativeTimestamp());

		espdu.getMarking().setCharacterSet((short) 1); // ascii
		try {
			espdu.getMarking().setCharacters("AAAAAAAAAAAAAAAAAAAAAAAAAAAA".getBytes("US-ASCII"));
		} catch (UnsupportedEncodingException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		espdu.setEntityAppearance(m_appearance);

		m_location = espdu.getEntityLocation();
		m_location.setX(m_disCoordinates[0]);
		m_location.setY(m_disCoordinates[1]);
		m_location.setZ(m_disCoordinates[2]);

		if (m_orientation != null)
			espdu.setEntityOrientation(m_orientation);
		if (m_linearVelocity != null)
			espdu.setEntityLinearVelocity(m_linearVelocity);

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
		detonateFlag = true;
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

	/***** orientation ********/
	public EulerAngles getM_orientation() {
		return m_orientation;
	}

	public void setM_orientation(float phi, float psi, float theta) {
		if (m_orientation == null)
			m_orientation = new EulerAngles();
		m_orientation.setPhi(phi);
		m_orientation.setPsi(psi);
		m_orientation.setTheta(theta);
	}

	/***** END orientation ********/

	/***** velocity ********/

	public Vector3Float getM_linearVelocity() {
		return m_linearVelocity;
	}

	public void setM_linearVelocity(float xValue, float yValue, float zValue) {
		if (m_linearVelocity == null)
			m_linearVelocity = new Vector3Float();
		m_linearVelocity.setX(xValue);
		m_linearVelocity.setY(yValue);
		m_linearVelocity.setZ(zValue);

	}

	/***** END velocity ********/

	/****** probability of hit function ***************/
	public boolean isTargetHit(double distance) {
		Random rng = null;
		double r1 = rng.nextDouble();
		double coefficient = 0;
		if (distance < 1000) { // unit is meter
			coefficient = 0.089;
			double final_probability = 0.9 * coefficient;
			if (r1 < final_probability) {
				return true;
			}

		} else if (distance < 2000) {
			coefficient = 0.05;
			double final_probability = 0.8 * coefficient;
			if (r1 < final_probability) {
				return true;
			}
		} else if (distance < 3000) {
			coefficient = 0.027;
			double final_probability = 0.75 * coefficient;
			if (r1 < final_probability) {
				return true;
			}
		} else if (distance < 4000) {
			coefficient = 0.014;
			double final_probability = 0.7 * coefficient;
			if (r1 < final_probability) {
				return true;
			}

		}

		return false;
	}

	/****** END PH function ***************/

	/****** probability of kill function ***************/
	public boolean isDead(double distance) {
		Random rng = null;
		double r1 = rng.nextDouble();
		double coefficient = 1;
		if (distance < 2000) { // unit is meter
			// coefficient = 0.089;
			double final_probability = 0.8 * coefficient;
			if (r1 < final_probability) {
				return true;
			}

		} else if (distance < 3000) {
			// coefficient = 0.05;
			double final_probability = 0.6 * coefficient;
			if (r1 < final_probability) {
				return true;
			}
		} else if (distance < 4000) {
			// coefficient = 0.027;
			double final_probability = 0.30 * coefficient;
			if (r1 < final_probability) {
				return true;
			}
		}

		return false;
	}

	/****** END PK function ***************/
	/****** isSeeTarget **********************/
	public boolean findNearestTarget(DataRepository dataObj) {
		double currentMax = MAX_FIRE_DISTANCE;

		for (Enumeration<EntityStatePdu> e = dataObj.getRemoteEspdus().elements(); e.hasMoreElements();) {
			EntityStatePdu temp = e.nextElement();

			if ((temp.getForceId() != this.ForceId) && (temp.getEntityAppearance() == FUNCTIONAL_APPEARANCE)) {

				double[] r = dataObj.getDeadReckonings().get(dataObj.getkey(temp.getEntityID()))
						.getUpdatedPositionOrientation();
				double distance = getRange(r);

				if ((distance > MIN_FIRE_DISTANCE) && (distance < MAX_FIRE_DISTANCE))
					if (distance < currentMax) {
						currentMax = distance;
						aimed_target = temp;
					}
			}
		}
		return aimed_target != null;
	}// seeTarget

	/****** END isSeeTarget **********************/

} // end T14 class
