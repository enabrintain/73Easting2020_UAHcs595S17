/**
 * 
 */
package edu.uah.cs595.tank_sim;

import java.util.*;

import edu.nps.moves.dis7.*;
import edu.uah.cs595.tank_sim.events.EntityStateUpdateEvent;
import edu.uah.cs595.tank_sim.events.LogEvent;
import edu.uah.cs595.tank_sim.io.*;

/**
 * @author Phil
 *
 */
public class Simulation implements Runnable {
	
	public static short EXERCISE_ID = 1;
	
	public double currentTime = 0.0;
	
	HashMap<Double, Event> eventQueue = new HashMap<>(); 
	HashMap<String, RemoteEntity> remoteEntityMap = new HashMap<>();
	ArrayList<T14> entities = new ArrayList<>();
	
	PDUTransceiver comm;
	Thread commThread;
	Thread eventQueueThread;
	
	/**
	 * This will initialize the Simulation, starting up the PDU IO class
	 */
	public Simulation()
	{
		// start transceiver
		comm = new PDUTransceiver(this);
		commThread = new Thread(comm);
		commThread.start();
		
		// initialize the tank model
		T14 t1 = new T14(304, 29.3318, 46.3748, 86);
		entities.add(t1);
		
		// add update event for t1
		eventQueue.put(0.0, new EntityStateUpdateEvent(1, 0, t1));
		
		// add logger event
		eventQueue.put(10.0, new LogEvent());
	}// constructor
	

	/**
	 * This method runs in a separate thread and handles the Event queue
	 */
	@Override
	public void run() {
		while(!eventQueue.isEmpty())
		{
			Event evt = eventQueue.remove(eventQueue.keySet().iterator().next());
			double delta = evt.time-currentTime;
			
			//wait until time has theoretically caught up to the actual time of the event?
			if(evt.isRealTime())
				try {
					Thread.sleep((long)(delta*1000));
				} catch (InterruptedException e) {
					e.printStackTrace(System.out);
				}
			
			evt.execute(this);
		}
	}// run
	
	
	public void start() {
		eventQueueThread = new Thread(this);
		eventQueueThread.start();
	}// start


	public void scheduleEntityStatePDU(SimulationEntity entity) {
		comm.sendES(entity.getEntityStatePDU(EXERCISE_ID));
	}// scheduleEntityStatePDU

	
	public void addEvent(double time, Event event) {
		double t = time;

		//make sure the time isnt conflicting by adding an arbitrarily small time to it
		if(eventQueue.containsKey(t))
			while(eventQueue.containsKey(t))
				t+=0.000001;
		
		// I am specifically not altering the time in the event so that the clock will not be arbitrary fractions
		//entityStateUpdateEvent.time = t;
		eventQueue.put(t, event);
	}// addEvent


	public synchronized void registerEntityStateUpdate(EntityStatePdu esp) {
        String id = esp.getEntityID().getEntityID()+"";
        if(remoteEntityMap.containsKey(id))
        {
        	RemoteEntity re = remoteEntityMap.get(id);
        	re.update(esp);
        }
	}// registerEntityStateUpdate


	public String getStatus() {
		return "Received "+comm.getReceivedCt() + "ES PDUs\nSent "+comm.getSentCt();
	}

}// Simulation
