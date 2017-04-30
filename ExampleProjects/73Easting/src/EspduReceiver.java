
/*
 * receiver thread
 * now it receiving Espdus and update remote Espdus
 */

import java.net.*;
import java.util.*;

import edu.nps.moves.disutil.*;
import edu.nps.moves.dis7.*;
import edu.nps.moves.deadreckoning.DIS_DR_FPW_02;
import edu.nps.moves.deadreckoning.DIS_DeadReckoning;
import edu.nps.moves.deadreckoning.utils.*;

public class EspduReceiver extends Thread {

	private DataRepository dataObj;

	/**
	 * Max size of a PDU in binary format that we can receive. This is actually
	 * somewhat outdated--PDUs can be larger--but this is a reasonable starting
	 * point
	 */
	public static final int MAX_PDU_SIZE = 8192;

	public enum NetworkMode {
		UNICAST, MULTICAST, BROADCAST
	};

	public EspduReceiver(DataRepository data) { // DataRepository data
		dataObj = data;
	}

	public void run() {
		/****** set up socket *****/
		MulticastSocket socket = null;
        // Default settings. These are used if no system properties are set. 
        // If system properties are passed in, these are over ridden.
        
        InetAddress address = null; // maybe not needed because of broadcast...
        
        try
        {
            address = InetAddress.getByName(demo.DEFAULT_MULTICAST_GROUP);
        }
        catch(Exception e)
        {
            System.out.println(e + " Cannot create multicast address");
            System.exit(0);
        }

        // All system properties, passed in on the command line via -Dattribute=value
        Properties systemProperties = System.getProperties();

        // IP address we send to
        String destinationIpString = systemProperties.getProperty("destinationIp");

        // Port we send to, and local port we open the socket on
        String portString = systemProperties.getProperty("port");

        // Set up a socket to send information
        try
        {
            socket = new MulticastSocket(demo.PORT);
            socket.setBroadcast(true);

            // Where we send packets to, the destination IP address
            if(destinationIpString != null)
            {
                address = InetAddress.getByName(destinationIpString);
            }
        }
        catch(Exception e)
        {
            System.out.println("Unable to initialize networking. Exiting.");
            System.out.println(e);
            //System.exit(-1);
        }
		/********** END setup socket ***********/

		DatagramPacket packet;
		// InetAddress address;
		Pdu7Factory pduFactory = new Pdu7Factory();

		try {
			// Loop infinitely, receiving datagrams
			while (true) {
				byte buffer[] = new byte[MAX_PDU_SIZE];
				packet = new DatagramPacket(buffer, buffer.length);

				socket.receive(packet);

				List<Pdu> pduBundle = pduFactory.getPdusFromBundle(packet.getData());

				Iterator it = pduBundle.iterator();

				while (it.hasNext()) {
					EntityID eid;
					Pdu aPdu = (Pdu) it.next();

					if (aPdu instanceof EntityStatePdu) {
						EntityStatePdu esPdu = (EntityStatePdu) aPdu;

						if (esPdu.getEntityID().getApplicationID() != (int) Simulation.APPLICATION_ID)
						{
							dataObj.update_remoteEsPdus(esPdu);
						    dataObj.update_dr(esPdu);
						}
					} else {
						String name = aPdu.getClass().getName();
						//if (!name.contains("DataPduReceived") && !name.contains("DataPdu"))
						//	System.out.println("Received " + name);
						if (aPdu instanceof FirePdu) {
							FirePdu fire = (FirePdu) aPdu;
							dataObj.notify_FirePdu(fire);
						}
						if (aPdu instanceof DetonationPdu) {
							DetonationPdu detonation = (DetonationPdu) aPdu;
							dataObj.notify_DetonationPdu(detonation);
						}
					}
					// System.out.println();
				} // end trop through PDU bundle

			} // end while
		} // End try
		catch (Exception e) {

			System.out.println(e);
		}

	} // end run
	
	

} // end class