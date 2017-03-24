/**
 * 
 */
package edu.uah.cs595.tank_sim.events;

import edu.uah.cs595.tank_sim.*;

/**
 * @author Phil
 *
 */
public class EntityStateUpdateEvent extends Event {

	int interval = 0;
	SimulationEntity entity;
	
	public EntityStateUpdateEvent(int repeatInterval, double time, SimulationEntity se)
	{
		interval = repeatInterval;
		this.time = time;
		entity = se;
		setRealtime(true);
	}// constructor

	/**
	 * update model and send ES_PDU, then reschedule
	 */
	@Override
	public void execute(Simulation sim) 
	{
		//TODO: add update
		
		//send PDU
		sim.scheduleEntityStatePDU(entity);
		
		//reschedule event
		time += interval;
		sim.addEvent(time, this);
	}// execute
	
	
	
}// EntityStateUpdateEvent
