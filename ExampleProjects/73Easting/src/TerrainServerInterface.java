import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.Socket;
import java.net.UnknownHostException;

/**
 * 
 */

/**
 * @author Phil Showers
 *
 */
public class TerrainServerInterface {

	public static String HOST = "10.56.1.167";
	public static int PORT = 8001;
	private Socket socket = null;
	private PrintWriter out = null;
	BufferedReader in = null;
	
	public TerrainServerInterface() {
		try{
			socket = new Socket(HOST, PORT);
			out = new PrintWriter(socket.getOutputStream(), true);
			in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
		} catch (UnknownHostException e) {
			System.err.println("Don't know about host " + HOST);
			System.exit(1);
		} catch (IOException e) {
			//System.err.println("Couldn't get I/O for the connection to " + hostName);
			e.printStackTrace(System.out);
			System.exit(1);
		}
	}// constructor
	
	public double getAltitude(double x, double y, double z) 
	{
		try {
			String message = "ELEVATION " + x + " " + y + " " + z;
			out.println(message);
			String reply = in.readLine();
			double elevation = Double.parseDouble(reply.trim());
			return elevation;
		} catch (NumberFormatException e) {
			// The first message that the Terrain server sends back is a bad number, like "﻿250.285759982316", so just throw it out.
			//e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace(System.out); // probably a bad thing...
		}
		return -1000;
	}
	
	public boolean canSee(double x1, double y1, double z1, double x2, double y2, double z2)
	{
		String message = "CANSEE " + x1 + " " + y1 + " " + z1 + " " + x2 + " " + y2 + " " + z2;
		try {
			out.println(message);
			String reply = in.readLine();
			boolean visible = Boolean.parseBoolean(reply);
			return visible;
		} catch (Exception e) {
			e.printStackTrace(System.out);
			System.exit(646464);
		}
		return false;
	}

}// TerrainServerInterface






	/*
	 * if (args.length != 2) { System.err.println(
	 * "Usage: 
	 * }// 
ELEVATION 3817940.9117024885 4036729.835147949 3123425.9327854933
CANSEE 817940.9117024885 4036729.835147949 3123425.9327854933 3817492.3980511194 4036255.6192080416 3123056.5349689415

Should  be blocked:
CANSEE 3819717.54686021 4031218.60673729 3126807.93341056 3818296.01076867 4032287.5276991 3127159.4084278
//DtPoint p1(3819717.54686021, 4031218.60673729, 3126807.93341056);
//DtPoint p2(3818296.01076867, 4032287.5276991, 3127159.4084278);

Should not be blocked
CANSEE 3817515.5630267 4037114.6118975 3121935 3817940.9117024885 4036729.835147949 3123425.9327854933
DtPoint p3(3817515.5630267, 4037114.6118975, 3121935);
DtPoint p4(3817940.9117024885, 4036729.835147949, 3123425.9327854933);


ELEVATION 3817940.9117024885 4036729.835147949 3123425.9327854933
Should  be blocked:
CANSEE 3819717.54686021 4031218.60673729 3126807.93341056 3818296.01076867 4032287.5276991 3127159.4084278
Should not be blocked
CANSEE 3817515.5630267 4037114.6118975 3121935 3817940.9117024885 4036729.835147949 3123425.9327854933



can see
CANSEE 3843366.1420419 4059677.0239505 3060878 3844310.0334652 4057316.3328563 3062809
p1 3843366.1420419, 4059677.0239505, 3060878
p2 3844310.0334652, 4057316.3328563, 3062809
can't see
CANSEE 3858262.1118657 4046355.3993365 3059685 3856349.3794404 4052194.2355176 3054530
p3 3858262.1118657, 4046355.3993365, 3059685
p4 3856349.3794404, 4052194.2355176, 3054530
	 */

	