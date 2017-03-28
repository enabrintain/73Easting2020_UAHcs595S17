/*
 * receiver thread
 * now it receiving Espdus and update remote Espdus
 */

import java.net.*;
import java.util.*;

import edu.nps.moves.disutil.*;
import edu.nps.moves.dis7.*;



public class EspduReceiver extends Thread {

	 private DataRepository  dataObj; 
	 
	/** Max size of a PDU in binary format that we can receive. This is actually
     * somewhat outdated--PDUs can be larger--but this is a reasonable starting point
     */
    public static final int MAX_PDU_SIZE = 8192;
    
    public enum NetworkMode{UNICAST, MULTICAST, BROADCAST};
    
  
    
    public EspduReceiver(DataRepository  data) { //DataRepository  data
    	 dataObj = data; 
    } 
    
    public void run() {
    	/****** set up socket *****/   
	    MulticastSocket socket = null;

	    int port = demo.PORT;
	    //NetworkMode mode = NetworkMode.MULTICAST;
	    NetworkMode mode = NetworkMode.BROADCAST;
	    InetAddress destinationIp = null;
	    
	    try
	    {
	        
	    	destinationIp = InetAddress.getByName(demo.DEFAULT_MULTICAST_GROUP);
	        
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
	    
	    // Network mode: unicast, multicast, broadcast
	    String networkModeString = systemProperties.getProperty("networkMode"); // unicast or multicast or broadcast
	        

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
	            destinationIp = InetAddress.getByName(destinationIpString);
	        }

	        // Type of transport: unicast, broadcast, or multicast
	        if(networkModeString != null)
	        {
	            if(networkModeString.equalsIgnoreCase("unicast"))
	                mode = NetworkMode.UNICAST;
	            else if(networkModeString.equalsIgnoreCase("broadcast")) {
	                mode = NetworkMode.BROADCAST;
	                socket.joinGroup(destinationIp);
	            }
	            else if(networkModeString.equalsIgnoreCase("multicast"))
	            {
	                mode = NetworkMode.MULTICAST;
	                if(!destinationIp.isMulticastAddress())
	                {
	                    throw new RuntimeException("Sending to multicast address, but destination address " + destinationIp.toString() + "is not multicast");
	                }
	                
	                socket.joinGroup(destinationIp);
	                
	            }
	        } // end networkModeString
	    }
	    catch(Exception e)
	    {
	        System.out.println("Unable to initialize networking. Exiting.");
	        System.out.println(e);
	        System.exit(-1);
	    }
	  /********** END setup socket ***********/
	
	    DatagramPacket packet;
       // InetAddress address;
        Pdu7Factory pduFactory = new Pdu7Factory();
	    
        try {
            // Specify the socket to receive data
           // socket = new MulticastSocket(3000);
            //socket.setBroadcast(true);
       
            //address = InetAddress.getByName(T14Sender.DEFAULT_MULTICAST_GROUP);
            //socket.joinGroup(address);

            // Loop infinitely, receiving datagrams
           
            
            while (true) {
                byte buffer[] = new byte[MAX_PDU_SIZE];
                packet = new DatagramPacket(buffer, buffer.length);

                socket.receive(packet);

                List<Pdu> pduBundle = pduFactory.getPdusFromBundle(packet.getData());
               // System.out.println("Bundle size is " + pduBundle.size());
                
                Iterator it = pduBundle.iterator();

                
               
                while(it.hasNext())
                {
                	EntityID eid;
                	Pdu aPdu = (Pdu)it.next();
                    
                   
                    if(aPdu instanceof EntityStatePdu)
                    {
                    	EntityStatePdu Rpdu = (EntityStatePdu) aPdu;
                    	
                    	if(Rpdu.getEntityID().getApplicationID() != (int)Simulation.APPLICATION_ID) {
                    	   dataObj.update_remoteEsPdus(Rpdu);
                    	
                    	eid = ((EntityStatePdu)aPdu).getEntityID();
                    	System.out.print("got PDU of type: " + aPdu.getClass().getName());
                        Vector3Double position = ((EntityStatePdu)aPdu).getEntityLocation();
                        System.out.print(" EID:[" + eid.getSiteID() + ", " + eid.getApplicationID() + ", " + eid.getEntityID() + "] ");
                        System.out.print(" Location in DIS coordinates: [" + position.getX() + ", " + position.getY() + ", " + position.getZ() + "]");
                    	}
                    }
                    System.out.println();
                } // end trop through PDU bundle

            } // end while
        } // End try
        catch (Exception e) {

            System.out.println(e);
        }

    	
    	
    } // end run 

    
} // end class