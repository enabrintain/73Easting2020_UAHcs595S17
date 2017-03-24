/**
 * 
 */
package edu.uah.cs595.tank_sim.io;

import java.net.*;
import java.util.*;

/**
 * 
 * @author DMcG
 */
public class Utils {

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
