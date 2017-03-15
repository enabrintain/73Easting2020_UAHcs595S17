package pdureciever;

import edu.nps.moves.dis7.*;
import edu.nps.moves.disutil.*;
import edu.nps.moves.sql.DatabaseConfiguration;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

import java.net.*;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

import org.hibernate.*;
import org.hibernate.cfg.*;

/**
 *
 * @author Phil
 */
public class PDUReciever {

    private MulticastSocket socket = null;
    private SessionFactory factory = null;
    
    private SessionFactory sessionFactory = null;
    
    /** Three popular database types. MySql requires a bit more setup, while hsqldb
     * and derby can be used as embedded databases, though possibly with lower performance
     * under load. */
    public enum DatabaseType{MYSQL, HSQLDB, DERBY};
    
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
        /***********************************************************************
         * Multicast socket configuration section
         **********************************************************************/
        
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
        
        /***********************************************************************
         * MySQL configuration section
         **********************************************************************/
        factory = getSessionFactory(DatabaseType.MYSQL);
        
    }// constructor
    
    public void startListener()
    {
        try{
            SocketListener sl = new SocketListener(socket, factory);
            Thread t = new Thread(sl);
            t.start();
        } catch (Exception e) {
            e.printStackTrace(System.out);
            System.exit(-1);
        }
    }// startListener
    
    /**
     * Main driver
     * @param args the command line arguments
     */
    public static void main(String[] args) {
        PDUReciever receiver = new PDUReciever();
        receiver.startListener();
        
        // goofy way of adding a enter 
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        System.out.println("Type enter to stop: \n\n\n");
        try {
            reader.readLine();
        } catch (IOException e) {
            e.printStackTrace();
        }
        System.exit(-1);
    }// main
    
    

    public SessionFactory getSessionFactory(DatabaseType db)
    {
        // Already been created? Then return that.
        if(sessionFactory != null)
            return sessionFactory;


        AnnotationConfiguration config = new AnnotationConfiguration();

        try
        {
            switch(db)
            {
                case MYSQL:
                    config = config.setProperty(org.hibernate.cfg.Environment.URL,"jdbc:mysql://localhost:3306/opendis")
                            .setProperty(org.hibernate.cfg.Environment.DRIVER,"com.mysql.jdbc.Driver")
                            .setProperty(org.hibernate.cfg.Environment.DIALECT, "org.hibernate.dialect.MySQLDialect")
                            .setProperty("hibernate.connection.username","logger")
                            .setProperty("hibernate.connection.password", "")
                            .setProperty("hibernate.hbm2ddl.auto", "create")
                            .setProperty("hibernate.connection.pool_size", "10")
                            .setProperty("hibernate.connection.autocommit", "true")
                            .setProperty("hibernate.hbm2ddl.auto", "create-drop")// When using this, the OLD TABLES WILL BE DROPPED each run
                            .setProperty("hibernate.transaction.factory_class", "org.hibernate.transaction.JDBCTransactionFactory")
                            .setProperty("hibernate.current_session_context_class", "thread")
                            .setProperty("hibernate.cache.provider_class", "org.hibernate.cache.NoCacheProvider");
                    /*
                       config.setProperty("hibernate.connection.driver_class", "com.mysql.jdbc.Driver");
                       config.setProperty("hibernate.connection.url", "jdbc:mysql://localhost:3306/opendis");
                      
                       config.setProperty("hibernate.connection.username", "logger");
                       config.setProperty("hibernate.connection.password", "");
                       config.setProperty("hibernate.dialect", "org.hibernate.dialect.MySQLDialect");
                       config.setProperty("hibernate.hbm2ddl.auto", "create"); // create tables when not exist

                       config.setProperty("hibernate.connection.pool_size", "10");
                       config.setProperty("hibernate.connection.autocommit", "true");
                       config.setProperty("hibernate.cache.provider_class", "org.hibernate.cache.NoCacheProvider");

                       // When using this, the OLD TABLES WILL BE DROPPED each run
                       config.setProperty("hibernate.hbm2ddl.auto", "create-drop");

                       // When using this, the OLD TABLES WILL BE BE RETAINED each run
                       //config.setProperty("hibernate.hbm2ddl.auto", "validate");

                       //config.setProperty("hibernate.show_sql", "true");
                       config.setProperty("hibernate.transaction.factory_class", "org.hibernate.transaction.JDBCTransactionFactory");
                       config.setProperty("hibernate.current_session_context_class", "thread");

*/
                    break;

                case HSQLDB:
                        config.setProperty("hibernate.dialect", "org.hibernate.dialect.HSQLDialect");
                        config.setProperty("hibernate.connection.driver_class", "org.hsqldb.jdbcDriver");
                        //config.setProperty("hibernate.connection.url", "jdbc:hsqldb:mem:demodb");
                        config.setProperty("hibernate.connection.url", "jdbc:hsqldb:file:/tmp/hsqldb");

                        config.setProperty("hibernate.connection.username", "sa");
                        config.setProperty("hibernate.connection.password", "");
                        config.setProperty("hibernate.connection.pool_size", "1");
                        config.setProperty("hibernate.connection.autocommit", "true");
                        config.setProperty("hibernate.cache.provider_class", "org.hibernate.cache.NoCacheProvider");
                        config.setProperty("hibernate.hbm2ddl.auto", "create-drop");
                        //config.setProperty("hibernate.hbm2ddl.auto", "validate");
                        //config.setProperty("hibernate.show_sql", "true");
                        config.setProperty("hibernate.transaction.factory_class", "org.hibernate.transaction.JDBCTransactionFactory");
                        config.setProperty("hibernate.current_session_context_class", "thread");
                    break;

                case DERBY:
                       config.setProperty("hibernate.dialect", "org.hibernate.dialect.DerbyDialect");
                       //config.setProperty("hibernate.connection.driver.class", "org.apache.derby.jdbc.CLientDriver");
                       config.setProperty("hibernate.connection.driver.class", "org.apache.derby.jdbc.EmbeddedDriver");
                       //config.setProperty("hibernate.connection.url", "jdbc:derby://localhost:1527/sample");
                       config.setProperty("hibernate.connection.url", "jdbc:derby:/tmp/opendis;create=true");
                       config.setProperty("hibernate.connection.username", "app");
                       config.setProperty("hibernate.connection.password", "app");

                       config.setProperty("hibernate.hbm2ddl.auto", "create"); // create tables when not exist

                       config.setProperty("hibernate.connection.pool_size", "10");
                       config.setProperty("hibernate.connection.autocommit", "true");
                       config.setProperty("hibernate.cache.provider_class", "org.hibernate.cache.NoCacheProvider");
                       // When using this, the OLD TABLES WILL BE DROPPED each run
                       config.setProperty("hibernate.hbm2ddl.auto", "create-drop");

                       // When using this, the OLD TABLES WILL BE BE RETAINED each run
                       //config.setProperty("hibernate.hbm2ddl.auto", "validate");

                       //config.setProperty("hibernate.show_sql", "true");
                       config.setProperty("hibernate.show_sql", "false");
                       config.setProperty("hibernate.transaction.factory_class", "org.hibernate.transaction.JDBCTransactionFactory");
                       config.setProperty("hibernate.current_session_context_class", "thread");
                    break;

                default:
                    return null;
            }

            // Add  mapped classes here. Ideally this should be done via introspection, but
            // not all classes may be loaded by the classloader at runtime, which may result
            // in some classes being missed. So copy & paste from ls and some text manipulation it
            // is. The array is just a handy way to deal with the copy & paste.
            Class classArray[] = {
                AcknowledgePdu.class,
                AcknowledgeReliablePdu.class,
                AcousticEmitter.class,
                ActionRequestPdu.class,
                ActionRequestReliablePdu.class,
                ActionResponsePdu.class,
                ActionResponseReliablePdu.class,
                AggregateIdentifier.class,
                AggregateMarking.class,
                AggregateType.class,
                AngleDeception.class,
                AngularVelocityVector.class,
                AntennaLocation.class,
                ArealObjectStatePdu.class,
                ArticulatedParts.class,
                Association.class,
                AttachedParts.class,
                Attribute.class,
                AttributePdu.class,
                BeamAntennaPattern.class,
                BeamData.class,
                BeamStatus.class,
                BlankingSector.class,
                ChangeOptions.class,
                ClockTime.class,
                CollisionElasticPdu.class,
                CollisionPdu.class,
                CommentPdu.class,
                CommentReliablePdu.class,
                CommunicationsNodeID.class,
                CreateEntityPdu.class,
                CreateEntityReliablePdu.class,
                DataFilterRecord.class,
                DataPdu.class,
                DataQueryDatumSpecification.class,
                DataQueryPdu.class,
                DataQueryReliablePdu.class,
                DataReliablePdu.class,
                DatumSpecification.class,
                DeadReckoningParameters.class,
                DesignatorPdu.class,
                DetonationPdu.class,
                DirectedEnergyAreaAimpoint.class,
                DirectedEnergyDamage.class,
                DirectedEnergyFirePdu.class,
                DirectedEnergyPrecisionAimpoint.class,
                DirectedEnergyTargetEnergyDeposition.class,
                DistributedEmissionsFamilyPdu.class,
                EEFundamentalParameterData.class,
                EightByteChunk.class,
                ElectronicEmissionsPdu.class,
                EmitterSystem.class,
                EngineFuel.class,
                EngineFuelReload.class,
                EntityStatePdu.class,
                EntityDamageStatusPdu.class,
                EntityID.class,
                EntityIdentifier.class,
                EntityInformationFamilyPdu.class,
                EntityManagementFamilyPdu.class,
                EntityMarking.class,
                EntityStatePdu.class,
                EntityStateUpdatePdu.class,
                EntityType.class,
                EntityTypeVP.class,
                edu.nps.moves.dis7.Environment.class,
                EnvironmentGeneral.class,
                EnvironmentType.class,
                EulerAngles.class,
                EventIdentifier.class,
                EventIdentifierLiveEntity.class,
                EventReportPdu.class,
                EventReportReliablePdu.class,
                Expendable.class,
                ExpendableDescriptor.class,
                ExpendableReload.class,
                ExplosionDescriptor.class,
                FalseTargetsAttribute.class,
                FastEntityStatePdu.class,
                FirePdu.class,
                FixedDatum.class,
                FourByteChunk.class,
                FundamentalOperationalData.class,
                GridAxis.class,
                GridAxisDescriptorVariable.class,
                GroupID.class,
                GroupIdentifier.class,
                IFFData.class,
                IFFFundamentalParameterData.class,
                IOCommunicationsNode.class,
                IOEffect.class,
                IffDataSpecification.class,
                IntercomCommunicationsParameters.class,
                IntercomControlPdu.class,
                IntercomIdentifier.class,
                IntercomSignalPdu.class,
                IsPartOfPdu.class,
                JammingTechnique.class,
                LaunchedMunitionRecord.class,
                LayerHeader.class,
                LinearObjectStatePdu.class,
                LinearSegmentParameter.class,
                LiveEntityIdentifier.class,
                LiveEntityPdu.class,
                LiveSimulationAddress.class,
                LogisticsFamilyPdu.class,
                MineEntityIdentifier.class,
                MinefieldFamilyPdu.class,
                MinefieldIdentifier.class,
                MinefieldResponseNackPdu.class,
                MinefieldSensorType.class,
                MinefieldStatePdu.class,
                ModulationType.class,
                Munition.class,
                MunitionDescriptor.class,
                MunitionReload.class,
                NamedLocationIdentification.class,
                ObjectIdentifier.class,
                ObjectType.class,
                OneByteChunk.class,
                OwnershipStatus.class,
                Pdu.class,
                PduContainer.class,
                PduHeader.class,
                PduStatus.class,
                PduStream.class,
                PduSuperclass.class,
                PointObjectStatePdu.class,
                PropulsionSystemData.class,
                ProtocolMode.class,
                RadioCommunicationsFamilyPdu.class,
                RadioIdentifier.class,
                RadioType.class,
                ReceiverPdu.class,
                RecordQueryReliablePdu.class,
                RecordQuerySpecification.class,
                RecordSpecification.class,
                RecordSpecificationElement.class,
                Relationship.class,
                RemoveEntityPdu.class,
                RemoveEntityReliablePdu.class,
                RepairCompletePdu.class,
                RepairResponsePdu.class,
                RequestID.class,
                ResupplyOfferPdu.class,
                ResupplyReceivedPdu.class,
                SecondaryOperationalData.class,
                SeesPdu.class,
                Sensor.class,
                SeparationVP.class,
                ServiceRequestPdu.class,
                SetDataPdu.class,
                SetDataReliablePdu.class,
                SignalPdu.class,
                SilentEntitySystem.class,
                SimulationAddress.class,
                SimulationIdentifier.class,
                SimulationManagementFamilyPdu.class,
                SimulationManagementPduHeader.class,
                SimulationManagementWithReliabilityFamilyPdu.class,
                StandardVariableSpecification.class,
                StartResumePdu.class,
                StartResumeReliablePdu.class,
                StopFreezePdu.class,
                StopFreezeReliablePdu.class,
                StorageFuel.class,
                StorageFuelReload.class,
                SupplyQuantity.class,
                SyntheticEnvironmentFamilyPdu.class,
                SystemIdentifier.class,
                TotalRecordSets.class,
                TrackJamData.class,
                TransmitterPdu.class,
                TwoByteChunk.class,
                UAFundamentalParameter.class,
                UaPdu.class,
                UnattachedIdentifier.class,
                UnsignedDISInteger.class,
                UnsignedIntegerWrapper.class,
                VariableDatum.class,
                VariableParameter.class,
                VariableTransmitterParameters.class,
                Vector2Float.class,
                Vector3Double.class,
                Vector3Float.class,
                VectoringNozzleSystem.class,
                WarfareFamilyPdu.class
            };

            for(int idx = 0; idx < classArray.length; idx++)
                config.addAnnotatedClass(classArray[idx]);

            return config.buildSessionFactory();
        }
        catch(Exception e)
        {
          System.err.println("++++++++++++ Exception "+e.getClass().getSimpleName()+" in DatabaseSetup.getSessionFactory(db,cntx): "+e.getLocalizedMessage());
          return null;
        }
    }// getSessionFactory

    
}
