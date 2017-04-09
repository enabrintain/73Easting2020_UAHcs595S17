/*
 * Pdu database
 * shall contain remote  Espdu  table 
 * shall contain local  Espdu  table 
 * shall contain event pdu  table 
 */


import java.util.ArrayList;
import java.util.Dictionary;
import java.util.Hashtable;

import edu.nps.moves.dis7.* ;
import edu.nps.moves.disutil.DisTime;


/*
 * remore entiry database & local database 
 */

public class DataRepository {
	private  Dictionary<EntityID, EntityStatePdu> m_remoteEspdus;
	private Dictionary<EntityID, EntityStatePdu> m_localEspdus;
	// Dictionary<key, FirePdu> firePdus;
	// Dictionary<key, DetonationPdu  > detonationPdus;
	private ArrayList<T14> localTanks = new ArrayList<>();
	private T14Sender sender = null;
	
	
	/***************/
	public DataRepository() {
		m_remoteEspdus= new Hashtable<>();
		m_localEspdus = new Hashtable();
		sender = new T14Sender(this);
	}
	/***************/
	
	public void update_remoteEsPdus(EntityStatePdu Rpdu) {
		if (m_remoteEspdus.isEmpty()) {
			m_remoteEspdus.put(Rpdu.getEntityID(), Rpdu);
		} else { // remote localEsPdus not empty
			if (m_remoteEspdus.get(Rpdu.getEntityID()) == null){
				m_remoteEspdus.put(Rpdu.getEntityID(), Rpdu); // insert new entity
			} else {
				m_remoteEspdus.remove(Rpdu.getEntityID()); // delete old one
				m_remoteEspdus.put(Rpdu.getEntityID(), Rpdu); // update with new one
			} // end else 
		} // end else
	} 
	
	/***************/
	
	public void update_localEsPdus(EntityStatePdu Lpdu) {
		
		if (m_localEspdus.isEmpty()) {
			m_localEspdus.put(Lpdu.getEntityID(), Lpdu);
		} else { // local localEsPdus not empty
			if (m_localEspdus.get(Lpdu.getEntityID()) == null){
				m_localEspdus.put(Lpdu.getEntityID(), Lpdu); // insert new entity
			} else {
				m_localEspdus.remove(Lpdu.getEntityID()); // delete old one
				m_localEspdus.put(Lpdu.getEntityID(), Lpdu); // update with new one
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
	
	
	public Dictionary<EntityID, EntityStatePdu> getRemoteEspdus() {
		return m_remoteEspdus;
	}

	/***************/

	public Dictionary<EntityID, EntityStatePdu> getLocalEspdus() {
		return m_localEspdus;
	}
	/***************/
	public void notify_FirePdu(FirePdu fire) {
		System.out.println("DataRepository.notify_FirePdu()" + fire.getFiringEntityID().getEntityID() + " at " + fire.getTargetEntityID().getEntityID());
		EntityID id = fire.getTargetEntityID();
		for(T14 tank : localTanks)
			if(tank.getEntityID(null).equalsImpl(id))
			{
				tank.fireTarget(fire);
				return;
			}
	}
	
	public void notify_DetonationPdu(DetonationPdu detonation) {
		System.out.println("DataRepository.notify_DetonationPdu()" + detonation.getFiringEntityID().getEntityID() + " at " + detonation.getTargetEntityID().getEntityID());
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
	
} // end dataRepository class
