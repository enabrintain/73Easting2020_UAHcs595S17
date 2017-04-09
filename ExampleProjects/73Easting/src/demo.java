
/*
 * Using DIS6 now, still have problem with DIS7,  version configuration need to be done later 
 * This demo put 3 threads(sender, receiver and simulation) into execution pool and runs okay 
 * DataRepository class shall contain all the EntityState Pdus  and "Event" Pdus(FirePdu, DenotationPdu, at.el)
 * simulation class shall maintain the main simulation logic, handle event queue
 */

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.DatagramPacket;
import java.net.InetAddress;
import java.net.MulticastSocket;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class demo {

	public enum NetworkMode {
		UNICAST, MULTICAST, BROADCAST
	};

	/** default multicast group we send on */
	public static final String DEFAULT_MULTICAST_GROUP = "10.56.0.255";// "192.168.0.255";//"192.168.0.255";
																		// //"239.1.2.3";

	/** Port we send on */
	public static final int PORT = 3000;

	public static void main(String[] args) throws IOException {
		DataRepository dataRepository = new DataRepository();

		EspduReceiver e = new EspduReceiver(dataRepository);
		Simulation s = new Simulation(dataRepository);
		s.start(); // simulation
		e.start(); // receiver

		// goofy way of adding a enter
		BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
		System.out.println("Type enter to stop: \n\n\n");
		try {
			reader.readLine();
		} catch (IOException ex) {
			ex.printStackTrace();
		}
		System.exit(-1);
		System.out.println("Terminating..");
	}

}
