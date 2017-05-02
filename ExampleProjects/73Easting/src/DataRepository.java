/*
 * Pdu database
 * shall contain remote  Espdu  table 
 * shall contain local  Espdu  table 
 * shall contain event pdu  table 
 */


import java.util.ArrayList;
import java.util.Dictionary;
import java.util.Hashtable;

import edu.nps.moves.deadreckoning.DIS_DR_RVW_04;
import edu.nps.moves.deadreckoning.DIS_DeadReckoning;
import edu.nps.moves.dis7.* ;
import edu.nps.moves.disutil.DisTime;


/*
 * remove entry database & local database 
 */

public class DataRepository {
	
	private  Dictionary<String, EntityStatePdu> m_remoteEspdus;
	private  Dictionary<String, DIS_DeadReckoning> m_dr;
	private Dictionary<String, EntityStatePdu> m_localEspdus;
	// Dictionary<key, FirePdu> firePdus;
	// Dictionary<key, DetonationPdu  > detonationPdus;
	private ArrayList<T14> localTanks = new ArrayList<>();
	private T14Sender sender = null;
	private TerrainServerInterface terrainServer;
	private int eventUID = 4000;
	
	public ArrayList<FirePdu> shootList = new ArrayList<>();
	
	/***************/
	public DataRepository() {
		try {
			m_remoteEspdus= new Hashtable<>();
			m_localEspdus = new Hashtable<>();
			sender = new T14Sender();
			terrainServer = new TerrainServerInterface();
			m_localEspdus = new Hashtable<>();
			m_dr =  new Hashtable<>();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	
	public String getkey(EntityID id) {
		return ""+id.getApplicationID()+id.getEntityID();
	}
	
	/**
	 * @throws Exception *************/
	public void update_remoteEsPdus(EntityStatePdu Rpdu) throws Exception {
		String key = getkey(Rpdu.getEntityID());
		if (m_remoteEspdus.get(key) == null){
			m_remoteEspdus.put(key, Rpdu); // insert new entity
		} else {
			//m_remoteEspdus.remove(key); // delete old one
			m_remoteEspdus.put(key, Rpdu); // update with new one
		} // end else 
	}
	
	/***************/
	
	public void update_localEsPdus(EntityStatePdu Lpdu) {
		int a =Lpdu.getEntityID().getSiteID();
		int b =Lpdu.getEntityID().getApplicationID();
		int c =Lpdu.getEntityID().getEntityID();
		String key = String.valueOf(a)+String.valueOf(b)+String.valueOf(c);
		
		if (m_localEspdus.isEmpty()) {
			m_localEspdus.put(key, Lpdu);
		} else { // local localEsPdus not empty
			if (m_localEspdus.get(key) == null){
				m_localEspdus.put(key, Lpdu); // insert new entity
			} else {
				m_localEspdus.put(key, Lpdu); // update with new one
			} // end else 
			
		} // end else
		
	} 
	/***************/
	
	public void update_dr( EntityStatePdu Rpdu) throws Exception {
		String key = getkey(Rpdu.getEntityID());
 
		if (m_dr.isEmpty()) {
			DIS_DeadReckoning Rdr = getDR(Rpdu);
			m_dr.put(key, Rdr);
		} else { // 
			DIS_DeadReckoning dr = m_dr.get(key);
			if (dr == null){
				DIS_DeadReckoning Rdr = getDR(Rpdu);
				m_dr.put(key, Rdr); // insert new entity
				
			} else {
				
				double lx , ly, lz, ophi,opsi,otheta, lvx, lvy,lvz,Ax, Ay, Az, AVx, AVy, AVz = 0;
				
				lx = Rpdu.getEntityLocation().getX();
				ly =Rpdu.getEntityLocation().getY();
				lz = Rpdu.getEntityLocation().getZ();
				ophi = Rpdu.getEntityOrientation().getPhi();
				opsi=Rpdu.getEntityOrientation().getPsi();
				otheta = Rpdu.getEntityOrientation().getTheta();
				lvx = Rpdu.getEntityLinearVelocity().getX();
				lvy = Rpdu.getEntityLinearVelocity().getY();
				lvz = Rpdu.getEntityLinearVelocity().getZ();
				Ax = Rpdu.getDeadReckoningParameters().getEntityLinearAcceleration().getX();
				Ay = Rpdu.getDeadReckoningParameters().getEntityLinearAcceleration().getY();
				Az = Rpdu.getDeadReckoningParameters().getEntityLinearAcceleration().getZ();
				AVx = Rpdu.getDeadReckoningParameters().getEntityAngularVelocity().getX();
				AVy = Rpdu.getDeadReckoningParameters().getEntityAngularVelocity().getY();
				AVz = Rpdu.getDeadReckoningParameters().getEntityAngularVelocity().getZ();
				
				// make the arrays of location and other parameters
		        //                loc           orien               lin V          Accel         Ang V
		        double[] locOr = {lx, ly, lz,   ophi,opsi,otheta,   lvx, lvy,lvz,  Ax, Ay, Az,   AVx, AVy, AVz};
				dr.setNewAll(locOr);
			} // end else 
			
		} // end else
		
		
		
	}
	/***************/
	public void update_firePdus(FirePdu Fpdu) {
		// more to be done 
		
	} 
	
	/***************/
	public void update_detonationPdus (DetonationPdu dePdu) {
		
		// more to be done 
	}
	/***************/
	
	
	public Dictionary<String, EntityStatePdu> getRemoteEspdus() {
		return m_remoteEspdus;
	}

	/***************/

	public Dictionary<String, EntityStatePdu> getLocalEspdus() {
		return m_localEspdus;
	}
	/***************/
	
	public Dictionary<String, DIS_DeadReckoning> getDeadReckonings() {
		return m_dr;
	}
	/***************/
	
	public void notify_FirePdu(FirePdu fire) {
		//System.out.println("DataRepository.notify_FirePdu()" + fire.getFiringEntityID().getEntityID() + " at " + fire.getTargetEntityID().getEntityID());
		EntityID id = fire.getTargetEntityID();
		for(T14 tank : localTanks)
			if(tank.getEntityID(null).equalsImpl(id))
			{
				tank.fireTarget(fire);
				return;
			}
	}
	
	public void notify_DetonationPdu(DetonationPdu detonation) {
		//System.out.println("DataRepository.notify_DetonationPdu()" + detonation.getFiringEntityID().getEntityID() + " at " + detonation.getTargetEntityID().getEntityID());
		EntityID id = detonation.getTargetEntityID();
		for(T14 tank : localTanks)
			if(tank.getEntityID(null).equalsImpl(id))
			{
				tank.detonationTarget(detonation);
				return;
			}
	}
	
	public void addTank(T14 t14) {
		if(!localTanks.contains(t14))
			localTanks.add(t14);
	}
	public ArrayList<T14> getTanks() {
		return localTanks;
	}
	public void sendESPdu(EntityStatePdu entityStatePdu) {
		entityStatePdu.setTimestamp(DisTime.getInstance().getDisRelativeTimestamp());
		entityStatePdu.setLength(entityStatePdu.getMarshalledSize());
		sender.send(entityStatePdu);
	}
	
	
	public static DIS_DeadReckoning getDR( EntityStatePdu obj) throws Exception{
		
		//DIS_DeadReckoning dr = new DIS_DR_FPW_02();
		DIS_DeadReckoning dr = new DIS_DR_RVW_04();
		double lx , ly, lz, ophi,opsi,otheta, lvx, lvy,lvz,Ax, Ay, Az, AVx, AVy, AVz = 0;
		lx = obj.getEntityLocation().getX();
		ly =obj.getEntityLocation().getY();
		lz = obj.getEntityLocation().getZ();
		ophi = obj.getEntityOrientation().getPhi();
		opsi=obj.getEntityOrientation().getPsi();
		otheta = obj.getEntityOrientation().getTheta();
		lvx = obj.getEntityLinearVelocity().getX();
		lvy = obj.getEntityLinearVelocity().getY();
		lvz = obj.getEntityLinearVelocity().getZ();
		Ax = obj.getDeadReckoningParameters().getEntityLinearAcceleration().getX();
		Ay = obj.getDeadReckoningParameters().getEntityLinearAcceleration().getY();
		Az = obj.getDeadReckoningParameters().getEntityLinearAcceleration().getZ();
		AVx = obj.getDeadReckoningParameters().getEntityAngularVelocity().getX();
		AVy = obj.getDeadReckoningParameters().getEntityAngularVelocity().getY();
		AVz = obj.getDeadReckoningParameters().getEntityAngularVelocity().getZ();
		// make the arrays of location and other parameters
        //                loc           orien               lin V          Accel    Ang V
		double[] locOr = {lx, ly, lz,   ophi,opsi,otheta,   lvx, lvy,lvz,  Ax, Ay, Az,   AVx, AVy, AVz};
     // set the parameters
        dr.setNewAll(locOr);
        
        // Print out the current state
       // System.out.println(dr.toString());
        //System.out.println();
        
        return dr;

		
	}


	public void sendFirePDU(FirePdu fPDU) {
		fPDU.setTimestamp(DisTime.getInstance().getDisRelativeTimestamp());
		fPDU.setLength(fPDU.getMarshalledSize());
		shootList.add(fPDU);
		sender.send(fPDU);
	}


	public void sendDetonationPDU(DetonationPdu dPDU) {
		dPDU.setTimestamp(DisTime.getInstance().getDisRelativeTimestamp());
		dPDU.setLength(dPDU.getMarshalledSize());
		sender.send(dPDU);
	}
	
	public TerrainServerInterface getTerrainServer(){
		return terrainServer;
	}


	public int getEventID() {
		eventUID++;
		return eventUID;
	}


	public boolean isTerrainServerLive() {

		if(terrainServer==null)
			return false;
		else
			try{
				terrainServer.getAltitude(3817940.9117024885, 4036729.835147949, 3123425.9327854933);
				return true;
			}catch(Exception e){
				e.printStackTrace(System.out);
				return false;
			}
	}


	
	
} // end dataRepository class
