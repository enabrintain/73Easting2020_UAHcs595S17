
import java.io.*;
import java.net.*;
import java.util.*;

import edu.nps.moves.dis7.*;

/**
 * Creates and sends ESPDUs in IEEE binary format.
 * @author phil showers
 */
public class T14Sender {

	private MulticastSocket socket = null;

	public enum NetworkMode {
		UNICAST, MULTICAST, BROADCAST
	};

	public T14Sender()
	{
		/****** set up socket *****/
		try {
			socket = new MulticastSocket(Demo.PORT);
			socket.setBroadcast(true);
		} catch (Exception e) {
			System.out.println(e + " Cannot create multicast address");
			System.exit(0);
		}
		/********** END setup socket ***********/
	}

	long lastSent = -1;
	public void send(Pdu pdu) {		
		Set<InetAddress> bcastAddresses = getBroadcastAddresses();
        Iterator<InetAddress> it = bcastAddresses.iterator();
		try {
			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			DataOutputStream dos = new DataOutputStream(baos);
			pdu.marshal(dos);
			
			// The byte array here is the packet in DIS format. We put
			// that into a datagram and send it.
			byte[] data = baos.toByteArray();

			while(it.hasNext())
	        {
	           InetAddress bcast = (InetAddress)it.next();
	           //System.out.println("Sending bcast to " + bcast);
	           DatagramPacket packet = new DatagramPacket(data, data.length, bcast, 3000);
	           try {
					socket.send(packet);
				} catch (IOException e) {
					e.printStackTrace(System.out);
				}
	        }
		} // end try
		catch (Exception e) {
			e.printStackTrace(System.out);
		}
	}


	 /**
	  * FROM edu.nps.moves.examples.EspduSender
	  * 
	  * A number of sites get all snippy about using 255.255.255.255 for a bcast
	  * address; it trips their security software and they kick you off their 
	  * network. (Comcast, NPS.) This determines the bcast address for all
	  * connected interfaces, based on the IP and subnet mask. If you have
	  * a dual-homed host it will return a bcast address for both. If you have
	  * some VMs running on your host this will pick up the addresses for those
	  * as well--eg running VMWare on your laptop with a local IP this will
	  * also pick up a 192.168 address assigned to the VM by the host OS.
	  * 
	  * @return set of all bcast addresses
	  */
	   public static Set<InetAddress> getBroadcastAddresses()
	   {
	       Set<InetAddress> bcastAddresses = new HashSet<InetAddress>();
	       Enumeration<NetworkInterface> interfaces;
	       
	       try
	       {
	           interfaces = NetworkInterface.getNetworkInterfaces();
	           
	           while(interfaces.hasMoreElements())
	           {
	               NetworkInterface anInterface = (NetworkInterface)interfaces.nextElement();
	               
	               if(anInterface.isUp())
	               {
	                   Iterator<InterfaceAddress> it = anInterface.getInterfaceAddresses().iterator();
	                   while(it.hasNext())
	                   {
	                       InterfaceAddress anAddress = (InterfaceAddress)it.next();
	                       if((anAddress == null || anAddress.getAddress().isLinkLocalAddress()))
	                           continue;
	                       
	                       //System.out.println("Getting bcast address for " + anAddress);
	                       InetAddress abcast = anAddress.getBroadcast();
	                       if(abcast != null)
	                        bcastAddresses.add(abcast);
	                   }
	               }
	           }
	           
	       }
	       catch(Exception e)
	       {
	           e.printStackTrace();
	           System.out.println(e);
	       }
	       
	       return bcastAddresses;   
	   }
}
