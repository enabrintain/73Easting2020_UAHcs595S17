/**
 * 
 */
package edu.uah.cs595.tank_sim.io;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.net.*;
import java.util.*;

import edu.nps.moves.dis7.*;
import edu.nps.moves.disutil.Pdu7Factory;

import edu.uah.cs595.tank_sim.Simulation;

/**
 * Handles receiving PDUs and sending them
 * @author Phil & DMcG
 *
 */
public class PDUTransceiver implements Runnable {

    /** Port we send on */
    public static final int DIS_DESTINATION_PORT = 3000;

    /** default multicast group we send on */
    public static final String DEFAULT_MULTICAST_GROUP="10.56.1.255";

    /** Max size of a PDU in binary format that we can receive. This is actually
     * somewhat outdated--PDUs can be larger--but this is a reasonable starting point
     */
    public static final int MAX_PDU_SIZE = 1024*8;
	
	
	
	private Simulation simulation;
	private MulticastSocket socket;
    private boolean running = true;
	private int receivedCt = 0;
	private int sentCt = 0;
	
	Thread t;
	
    /**
     * 
     */
	public PDUTransceiver(Simulation sim)
	{
		simulation = sim;
		initSocket();
		
		t = new Thread(this);
		t.start();
	}// constructor

	private void initSocket()
    {
        /***********************************************************************
         * Multicast socket configuration 
         **********************************************************************/
        
        // Default settings. These are used if no system properties are set. 
        // If system properties are passed in, these are over ridden.
        int port = DIS_DESTINATION_PORT;
        
        InetAddress address = null; // maybe not needed because of broadcast...
        
        try
        {
            address = InetAddress.getByName(DEFAULT_MULTICAST_GROUP);
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
            // Port we send to
            if(portString != null)
                port = Integer.parseInt(portString);

            socket = new MulticastSocket(port);
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
        
    }// constructor

	/**
	 * listen loop in another thread
	 */
	@Override
	public void run() {
		try {
            DatagramPacket packet;
            Pdu7Factory pduFactory = new Pdu7Factory();
            
            // Loop infinitely, receiving datagrams
            while (running) {
                byte buffer[] = new byte[MAX_PDU_SIZE];
                packet = new DatagramPacket(buffer, buffer.length);

                socket.receive(packet);

                List<Pdu> pduBundle = pduFactory.getPdusFromBundle(packet.getData());
                //System.out.println("Bundle size is " + pduBundle.size());
                
                Iterator<Pdu> it = pduBundle.iterator();

                while(it.hasNext())
                {
                    Pdu aPdu = (Pdu)it.next();
                    receivedCt++;
                    
                    //System.out.println("got PDU of type: " + aPdu.getClass().getName());
                    if(aPdu instanceof EntityStatePdu)
                    {
                    	EntityStatePdu esp = (EntityStatePdu)aPdu;
                        simulation.registerEntityStateUpdate(esp);
                    }
                } // end trop through PDU bundle
            }// end while
        }// End try
        catch (Exception e) {
            System.out.println(e);
            //System.exit(-1);
        }
	}// run

	/**
	 * Ive read that sockets have their own internal synchronization, so as long as we have only
	 * one thread sending, and one thread receiving, we should be fine.
	 */
	public void sendES(EntityStatePdu entityStatePDU) {
		ByteArrayOutputStream baos = new ByteArrayOutputStream();
        DataOutputStream dos = new DataOutputStream(baos);
        entityStatePDU.marshal(dos);
        byte[] data = baos.toByteArray();
        
        Set<InetAddress> bcastAddresses = Utils.getBroadcastAddresses();
        Iterator<InetAddress> it = bcastAddresses.iterator();
        while(it.hasNext())
        {
           InetAddress bcast = (InetAddress)it.next();
           //System.out.println("Sending bcast to " + bcast);
           DatagramPacket packet = new DatagramPacket(data, data.length, bcast, 3000);
           try {
				socket.send(packet);
				sentCt++;
			} catch (IOException e) {
				e.printStackTrace(System.out);
			}
        }
	}// sendES

	

	public synchronized int getReceivedCt() {
		return receivedCt;
	}
	public synchronized int getSentCt() {
		return sentCt;
	}
	
	

}// PDUTransceiver
