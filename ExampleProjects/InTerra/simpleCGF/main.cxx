/*******************************************************************************
** Copyright (c) 2004 MAK Technologies, Inc.
** All rights reserved.
*******************************************************************************/


//This example demonstrates how to use the DtCgf class to create objects
//and task entities, as you would if you were to embed VR-Forces in your own 
//application.

#ifdef WIN32
#include <winsock2.h>
#include <windows.h>
#endif

//VR-Forces Headers
#include "vrfcgf/cgf.h"
#include "vrfcgf/cgfDispatcher.h"
#include "vrfcore/simManager.h"
#include "vrftasks/moveToTask.h"
#include "vrfobjcore/vrfObject.h"
#include "terrainInterface\terrainInterface.h"

//VR-Link headers
#include <vl/exerciseConn.h>
#include <vl/exerciseConnInitializer.h>
#include <vlutil/vlPrint.h>
#include <vlutil/vlProcessControl.h>
#include <vl/hostStructs.h>

#include "vrfutil/vrfVlKeyboard.h"
#include "vrfutil\vrfCheckLicense.h"

#include "terrainInterface/terrainInterfaceDefines.h"
#include "terrainInterface/terrainImplementation.h"
#include "terrainInterface/terrainPagingGeometry.h"

#include "vrfutil/asyncJobServer.h"
#include "vrfutil/terrainInterfaceConfig.h"
#include "vrfutil/noArgumentCallbackList.h"

#include <features/feature.h>
#include <features/pathFeature.h>
#include <features/aStarGraph.h>
#include <features/areaFeature.h>
#include <features/sharedMemoryFeaturesDebugDrawer.h>
#include <features/attributeConfigParser.h>
#include <features/featureGeometry.h>


#include <boost/scoped_ptr.hpp>
#include <boost/ptr_container/ptr_list.hpp>


using namespace MAKVRinTerra;

//int main(int argc, char *argv[])
int main()
{
	{
		//DIS/RPR simulation address

		DtSimulationAddress simAddress(1, 3051);

		bool test = DtHaveVrfSimLicense();
		//Check to see if license pulled
		if (test == true)
		{
			//Create the CGF
			DtCgf* cgf = new DtCgf(simAddress);
			DtWarn << "License Checked Out."
				<< std::endl;
		}
		else
		{
			DtWarn << "Error checking out a VR-Forces back-end license."
				<< std::endl;
		}
	}
	DtTerrainInterface terrainInterface;

	terrainInterface.init();
	if (!terrainInterface.loadTerrain("73 Easting.mtf"))
	{
		DtInfo("Could not load terrain file %s", "terrainName");
		return 1;
	}
	system("Pause");
	return 0;
}



