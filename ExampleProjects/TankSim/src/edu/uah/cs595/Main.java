/**
 * 
 */
package edu.uah.cs595;

import java.io.*;

import  edu.uah.cs595.tank_sim.*;

/**
 * Starts the sim
 * @author Phil
 *
 */
public class Main {

	public static void main(String args[])
	{
		System.out.println("Initializing..");
		Simulation sim = new Simulation();

		System.out.println("Starting...");
		sim.start();
		

        // goofy way of adding a enter 
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        System.out.println("Type enter to stop: \n\n\n");
        try {
            reader.readLine();
        } catch (IOException e) {
            e.printStackTrace();
        }
        System.exit(-1);
		System.out.println("Terminating..");
	}// main
	
}// Main
