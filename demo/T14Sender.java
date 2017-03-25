

import java.io.*;
import java.net.*;
import java.util.*;

import edu.nps.moves.dis.*;
import edu.nps.moves.disenum.ForceID;
import edu.nps.moves.disutil.CoordinateConversions;
import edu.nps.moves.disutil.DisTime;
//import edu.nps.moves.examples.EspduSender.NetworkMode;

/**
 * Creates and sends ESPDUs in IEEE binary format. 
 *
 * 
 */
public class T14Sender extends Thread
{
   
    private DataRepository  dataObj; 
    public enum NetworkMode{UNICAST, MULTICAST, BROADCAST};
    
    public T14Sender(  DataRepository  data  ) throws IOException {  
      
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
    	
    	
    	 // Loop through sending 100 ESPDUs
    	    try
    	    {
    	    	//InetAddress destinationIp = socket.getInetAddress();
    	    	//System.out.println("Sending 100 ESPDU packets to " + destinationIp.toString());
    	        while(true)
    	        {
    	            
    	        	Dictionary<EntityID, EntityStatePdu> localEspdus; 
    	        	localEspdus = dataObj.getLocalEspdus();
    	        	
    	        	 for (Enumeration<EntityStatePdu> e = localEspdus.elements(); e.hasMoreElements();) {
    	        		 
    	        		    EntityStatePdu t14EsPdu =  e.nextElement() ; 
    	        		    long ts = t14EsPdu.getTimestamp() ;//getDisAbsoluteTimestamp();
    	        		    t14EsPdu.setTimestamp(ts);
    	    	            
    	    	           
    	    	            ByteArrayOutputStream baos = new ByteArrayOutputStream();
    	    	            DataOutputStream dos = new DataOutputStream(baos);
    	    	            
    	    	            t14EsPdu.setPduLength(t14EsPdu.getMarshalledSize());
    	    	            t14EsPdu.marshal(dos);
    	    	            //t14Obj.printLocation(); // print out the position of a tank 
    	    	            System.out.println("sending local Espdu to: " + destinationIp.toString());
    	    	            EntityID eid = t14EsPdu.getEntityID();
    	    	            System.out.print( "EID=[" + eid.getSite() + "," + eid.getApplication() + "," + eid.getEntity() + "]");
    	    	           
    	    	            
    	    	            // The byte array here is the packet in DIS format. We put that into a 
    	    	            // datagram and send it.
    	    	            byte[] data = baos.toByteArray();

    	    	            DatagramPacket packet = new DatagramPacket(data, data.length, destinationIp, demo.PORT);

    	    	            socket.send(packet);
    	        		 
    	        		   
    	        		   } // end for: iterate local entity data base 
    	        	
    	        	
    	            
    	            // Send every 1 sec. Otherwise this will be all over in a fraction of a second.
    	            Thread.sleep(1000);
    	           

    	        }// end while 
    	    }// end try 
    	    catch(Exception e)
    	    {
    	        System.out.println(e);
    	    } // end sending espdu try and catch block 
    	        
    	   
    	    
    	   
    } // end run 
	
	

}










