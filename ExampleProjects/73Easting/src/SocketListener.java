

import edu.nps.moves.dis.*;
import edu.nps.moves.disutil.*;
import java.net.*;
import java.util.*;

/**
 * This is a thread that listens for incoming PDUs
 * @author Phil
 */
public class SocketListener implements Runnable
{
    private MulticastSocket socket;
    private boolean running = true;

    /** Max size of a PDU in binary format that we can receive. This is actually
     * somewhat outdated--PDUs can be larger--but this is a reasonable starting point
     */
    public static final int MAX_PDU_SIZE = 8192;
    
    public SocketListener(MulticastSocket socket)
    {
        this.socket = socket;
    }// constructor
    

    @Override
    public void run() {
        try {
            DatagramPacket packet;
            PduFactory pduFactory = new PduFactory();
        
            // Loop infinitely, receiving datagrams
            while (running) {
                byte buffer[] = new byte[MAX_PDU_SIZE];
                packet = new DatagramPacket(buffer, buffer.length);

                socket.receive(packet);

                List<Pdu> pduBundle = pduFactory.getPdusFromBundle(packet.getData());
                System.out.println("Bundle size is " + pduBundle.size());
                
                Iterator it = pduBundle.iterator();

                while(it.hasNext())
                {
                    Pdu aPdu = (Pdu)it.next();
                
                    System.out.print("got PDU of type: " + aPdu.getClass().getName());
                    if(aPdu instanceof EntityStatePdu)
                    {
                        EntityID eid = ((EntityStatePdu)aPdu).getEntityID();
                        Vector3Double position = ((EntityStatePdu)aPdu).getEntityLocation();
                        System.out.print(" EID:[" + eid.getSite() + ", " + eid.getApplication() + ", " + eid.getEntity() + "] ");
                        System.out.print(" Location in DIS coordinates: [" + position.getX() + ", " + position.getY() + ", " + position.getZ() + "]");
                    }
                    System.out.println();
                } // end trop through PDU bundle
            }// end while
        }// End try
        catch (Exception e) {
            System.out.println(e);
        }
    }// run
    
    protected void finalize()
    {
        //Objects created in run method are finalized when
        //program terminates and thread exits
        try{
            running = false;
            socket.close();
        } catch (Exception e) {
            e.printStackTrace(System.out);
            //System.out.println("Could not close socket");
            System.exit(-1);
        }
    }
    
}// SocketListener
