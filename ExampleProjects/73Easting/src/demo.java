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
	
	
	
	public enum NetworkMode{UNICAST, MULTICAST, BROADCAST};

    /** default multicast group we send on */
    public static final String DEFAULT_MULTICAST_GROUP="10.56.0.255";//"192.168.0.255";//"192.168.0.255"; //"239.1.2.3";  // public static final String UNICAST_IP="10.56.1.171";
   //public static final String BROAD_CAST= "10.56.1.255";
   
    /** Port we send on */
    public static final int    PORT = 3000;
	
    
	
	
	public static void main(String[] args) throws IOException {
		
		
		/******* set up socket ********
	    MulticastSocket socket = null;
	   
	    int port = PORT;
	    //NetworkMode mode = NetworkMode.MULTICAST;
	    NetworkMode mode = NetworkMode.BROADCAST;
	    InetAddress destinationIp = null;
	    
	    try
	    {
	       
	    	destinationIp = InetAddress.getByName(DEFAULT_MULTICAST_GROUP);
	        
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
	    /******* END set up socket ***********/
	    
	   
		DataRepository dataRepository = new DataRepository();
	   
	   ExecutorService executor1 = Executors.newFixedThreadPool(3);
	   
	    
	    while (true) {
			//executor1.execute( new T14Sender(dataRepository)); // sender thread 	
			executor1.execute(new EspduReceiver(dataRepository)); // receiver thread 
			//executor1.execute(new Simulation(dataRepository)); // simulation thread 
			
								
			} 
			
	    
		
	}

}
