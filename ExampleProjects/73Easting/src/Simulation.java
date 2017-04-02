/*
 * main logic 
 * now it's only create one tank and update local Espdu table
 */
public class Simulation extends Thread {
	public static final short EXERCISE_ID = 1;
	public static final short FORCE_ID = 0 ; // 
	public static final short APPLICATION_ID = 595;
	public static final short SITE_ID = 1;
	
	
	
	private DataRepository  dataObj; 
	
	public Simulation (DataRepository  data) {
		dataObj = data; 
	}
	
	
	
	public void run() {
		
		 /******* create local entity *******/ 
	    T14 t14_1 = new T14(EXERCISE_ID,FORCE_ID, APPLICATION_ID,SITE_ID ); //(short exerciseID, short forceID, short applicationID, short siteID)
	    t14_1.setLocation(29, 43, 240) ; // set tank location with its position in ( lat, lon, alt )
	    // t14_1.printLocation();
	    dataObj.addTank(t14_1);
	    /******* END create local entity *******/ 
	    
		
	    while(true)
	    {
	    	for(T14 tank : dataObj.getTanks())
	    		tank.update(dataObj);
	    }
	    
	    
	    
	} // end run 

}// end simulation class 
