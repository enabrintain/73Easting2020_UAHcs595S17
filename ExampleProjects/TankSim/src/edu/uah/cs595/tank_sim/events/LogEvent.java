package edu.uah.cs595.tank_sim.events;

import edu.uah.cs595.tank_sim.Event;
import edu.uah.cs595.tank_sim.Simulation;

public class LogEvent extends Event {

	public LogEvent()
	{
		setRealtime(false);
	}
	
	@Override
	public void execute(Simulation sim) {
		
		System.out.println("Logging Event: \n"+sim.getStatus());
		
		time += 10;
		sim.addEvent(time, this);
	}

}
