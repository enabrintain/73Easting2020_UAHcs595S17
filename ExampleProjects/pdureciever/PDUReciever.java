package pdureciever;

import edu.nps.moves.dis7.*;
import edu.nps.moves.disutil.*;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

import java.net.*;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;
/**
 *
 * @author Phil
 */
public class PDUReciever {

    private MulticastSocket socket = null;
    
    
    /** Max size of a PDU in binary format that we can receive. This is actually
     * somewhat outdated--PDUs can be larger--but this is a reasonable starting point
     */
    public static final int MAX_PDU_SIZE = 8192;
    
    /** always use BROADCAST */
    public enum NetworkMode{UNICAST, MULTICAST, BROADCAST};

    /** default multicast group we send on */
    public static final String DEFAULT_MULTICAST_GROUP="10.56.1.255";
   
    /** Port we send on */
    public static final int    DIS_DESTINATION_PORT = 3000;
    
    
    // configures the connection
    public PDUReciever()
    {
        
        // Default settings. These are used if no system properties are set. 
        // If system properties are passed in, these are over ridden.
        int port = DIS_DESTINATION_PORT;
        NetworkMode mode = NetworkMode.BROADCAST;
        
        DatagramPacket packet;
        InetAddress address = null;
        PduFactory pduFactory = new PduFactory();
        
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
                address = InetAddress.getByName(destinationIpString);
            }

            // Type of transport: unicast, broadcast, or multicast
            if(networkModeString != null)
            {
                if(networkModeString.equalsIgnoreCase("unicast"))
                    mode = NetworkMode.UNICAST;
                else if(networkModeString.equalsIgnoreCase("broadcast"))
                    mode = NetworkMode.BROADCAST;
                else if(networkModeString.equalsIgnoreCase("multicast"))
                {
                    mode = NetworkMode.MULTICAST;
                    if(!address.isMulticastAddress())
                        throw new RuntimeException("Sending to multicast address, but destination address " + address.toString() + "is not multicast");
                    socket.joinGroup(address);
                }
            } // end networkModeString
        }
        catch(Exception e)
        {
            System.out.println("Unable to initialize networking. Exiting.");
            System.out.println(e);
            System.exit(-1);
        }
    }// constructor
    
    public void startListener()
    {
        try{
            SocketListener sl = new SocketListener(socket);
            Thread t = new Thread(sl);
            t.start();
        } catch (Exception e) {
            e.printStackTrace(System.out);
            System.exit(-1);
        }
    }
    
    /**
     * Main driver
     * @param args the command line arguments
     */
    public static void main(String[] args) {
        PDUReciever receiver = new PDUReciever();
        SocketListener listener = new SocketListener(receiver.socket);
        //when necessary, this can be put in another thread by uncommenting the following lines
        Thread t = new Thread(listener);
        t.start();
        
        // goofy way of adding a enter 
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        System.out.println("Type enter to stop: \n\n\n");
        try {
            reader.readLine();
            listener.finalize();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }// main
    
}
