package edu.uah.cs595.tank_sim;

/**
 * @author Phil
 *
 */
public abstract class Event {

	public double time = 0.0;
	private boolean realtime = false;
	
	public abstract void execute(Simulation sim);


	protected void setRealtime(boolean b) {
		realtime = b;
	}
	
	public boolean isRealTime() {
		return realtime;
	}
	
}
