;;
;; File - gatorMines.asl
;;
;;
;; Copyright (c) 2001 MaK Technologies, Inc.
;; All rights reserved.
;; 
;; $RCSfile: gatorMines.asl,Created:9/25/01 MEM Revision: 1.0
;; Updated:
;; Mine Select Table for a Gator FASCAM minefield
;; 
;;

(mine-select-table
   (BLU92B
		(mine-type "anti-personnel-mine")
		(munition
			(munition-type  2 2 225 3 3 0 0)
			(warhead  0)
		)
		(arming-time 120.000000 )			;;in seconds
		(self-destruct-time 4.000000)		;;in hours
		(trigger 6)								;;tripwire
  		(trigger-radius 12.000000)			;;in meters
		(failure-percentage 0.100000)
	)
	(BLU91B
		(mine-type "anti-tank-mine")
		(munition
			(munition-type  2 2 225 3 3 0 1)
			(warhead  0)
		)
		(arming-time 120.000000 )			;;in seconds
		(self-destruct-time 4.000000)		;;in hours
		(trigger 3)								;;magnetic
  		(trigger-radius 0.500000)			;;in meters
		(failure-percentage 0.100000)
	)
)