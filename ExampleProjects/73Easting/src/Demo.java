
/*
 * Using DIS7
 * This demo puts 3 threads(itself, receiver, and simulation) into execution pool and runs them. 
 * DataRepository class shall contain all the EntityState Pdus  and "Event" Pdus(FirePdu, DenotationPdu, at.el)
 * Simulation class shall maintain the main simulation logic, handle event queue
 * The 'main' thread simply listens for a keystroke to gracefully shut down the Application.
 * @author Rui Wang and Phil Showers
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
	public static final String DEFAULT_MULTICAST_GROUP = "10.56.0.255"; //TODO: Change this to reflect your local reality

	/** Port we send on */
	public static final int PORT = 3000;

	public static void main(String[] args) throws IOException {
		DataRepository dataRepository = new DataRepository();

		EspduReceiver e = new EspduReceiver(dataRepository);
		Simulation s = new Simulation(dataRepository);
		s.start(); // simulation
		e.start(); // receiver

		// goofy way of adding a listen for enter key
		BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
		System.out.println("Type enter to stop: \n\n\n");
		try {
			reader.readLine();
		} catch (IOException ex) {
			ex.printStackTrace();
		}
		//System.out.println("Terminating...");
		
		System.out.println("Finished");
		System.exit(-1);
	}

}//Demo
