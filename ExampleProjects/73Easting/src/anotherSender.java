

import java.io.*;
import java.net.*;
import java.util.*;

import edu.nps.moves.dis7.Vector3Double;
import edu.nps.moves.dis7.Vector3Float;
import edu.nps.moves.disutil.CoordinateConversions;
import edu.nps.moves.disutil.DisTime;



/**
 * Creates and sends ESPDUs in IEEE binary format. 
 *
 * 
 */
public class anotherSender 
{
    
	
	
	public enum NetworkMode{UNICAST, MULTICAST, BROADCAST};

    /** default multicast group we send on */
    public static final String DEFAULT_MULTICAST_GROUP="10.56.0.255";//"192.168.0.255";//"10.56.0.255"; //"239.1.2.3";
    public static final String UNICAST_IP="10.56.1.171";
    public static final String BROAD_CAST= "10.56.1.255";
   
    /** Port we send on */
    public static final int    PORT = 3000;
    
/** Possible system properties, passed in via -Dattr=val
     * networkMode: unicast, broadcast, multicast
     * destinationIp: where to send the packet. If in multicast mode, this can be mcast.
     *                To determine bcast destination IP, use an online bcast address
     *                caclulator, for example http://www.remotemonitoringsystems.ca/broadcast.php
     *                If in mcast mode, a join() will be done on the mcast address.
     * port: port used for both source and destination.
     * @param args 
     */
public static void main(String args[])
{
    /** an entity state pdu */
   
    MulticastSocket socket = null;
    //DisTime disTime = DisTime.  getInstance();
        
    // Default settings. These are used if no system properties are set. 
    // If system properties are passed in, these are over ridden.
    int port = PORT;
    //NetworkMode mode = NetworkMode.MULTICAST;
    NetworkMode mode = NetworkMode.BROADCAST;
    InetAddress destinationIp = null;
    
    try
    {
        //destinationIp = InetAddress.getByName(DEFAULT_MULTICAST_GROUP);
       // destinationIp = InetAddress.getByName(UNICAST_IP);
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
    
    
    // create a new T14 tank with its position in ( lat, lon, alt )
    T14 t14_1 = new T14((short)1,(short) 0, (short)1,(short) 1 ); //(short exerciseID, short forceID, short applicationID, short siteID)
    t14_1.setLocation(29.3318,46.3748,0) ; 
    t14_1.setM_orientation(150.0f, -0.01f, 0.01f);
    t14_1.setM_linearVelocity(0, 1f, 0);
    

    // Loop through sending 100 ESPDUs
    try
    {
        System.out.println("from another sender : Sending 100 ESPDU packets to " + destinationIp.toString());
        while (true)
        {
            
        	moving(t14_1);
           // int ts = t14_1.getM_disTime().getDisRelativeTimestamp();//getDisAbsoluteTimestamp();
           int ts =  DisTime.getInstance().getDisRelativeTimestamp();
           System.out.println(ts);
        	t14_1.getEntityStatePdu().setTimestamp(ts);
            
           
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            DataOutputStream dos = new DataOutputStream(baos);
            
            t14_1.getEntityStatePdu().setLength(t14_1.getEntityStatePdu().getMarshalledSize());
            t14_1.getEntityStatePdu().marshal(dos);
            //t14_1.printLocation(); // print out the position of a tank 
            
            // The byte array here is the packet in DIS format. We put that into a 
            // datagram and send it.
            byte[] data = baos.toByteArray();

            DatagramPacket packet = new DatagramPacket(data, data.length, destinationIp, PORT);

            socket.send(packet);
            
            // Send every 1 sec. Otherwise this will be all over in a fraction of a second.
            Thread.sleep(5000);
           

        }// end for
    }// end try 
    catch(Exception e)
    {
        System.out.println(e);
    }
        
}

public static void moving(T14 t) {
	double x, y, z;
	//double lat, lon, alt;
	
	//Vector3Float v = t.getM_linearVelocity();
	//Vector3Double l =t.getM_location();
	//x = v.getX();
	//y = v.getY();
    //z = v.getZ();
	x = t.getM_location().getX();
	y = t.getM_location().getY();
	z = t.getM_location().getZ();
	
	y = y+5;
	
	t.getM_location().setX(x);
	t.getM_location().setY(y);
	t.getM_location().setZ(z);
	
	
	
	//xyz = CoordinateConversions.xyzToLatLonDegrees(xyz);
	
	//xyz[1]+=  0.00005;
	
	//xyz = CoordinateConversions.getXYZfromLatLonDegrees(xyz[0], xyz[1], xyz[2]);
	
	//t.setLocation(xyz[0], xyz[1], xyz[2]);
	
}

}












