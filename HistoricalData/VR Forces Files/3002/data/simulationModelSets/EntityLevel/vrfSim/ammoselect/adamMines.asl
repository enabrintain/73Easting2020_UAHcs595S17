;;
;; File - adamMines.asl
;;
;;
;; Copyright (c) 2001 MaK Technologies, Inc.
;; All rights reserved.
;; 
;; $RCSfile: adamMines.asl,Created:6/12/01 MEM Revision: 1.0
;; Updated:
;; Mine Select Table for a ADAM FASCAM minefield
;; 
;;

(mine-select-table
   (M67
		(mine-type "anti-personnel-mine")
		(munition
			(munition-type  2 8 225 3 11 0 0)
			(warhead  0)
		)
		(arming-time 120.000000 )			;;in seconds
		(self-destruct-time 0.010000)		;;in hours
		(trigger 1)								;;tripwire
  		(trigger-radius 6.000000)			;;in meters
		(failure-percentage 0.100000)
	)
	(M72
		(mine-type "anti-personnel-mine")
		(munition
			(munition-type  2 8 225 3 10 0 0)
			(warhead  0)
		)
		(arming-time 120.000000 )			;;in seconds
		(self-destruct-time 48.000000)		;;in hours
		(trigger 1)								;;tripwire
  		(trigger-radius 6.000000)			;;in meters
		(failure-percentage 0.100000)
	)
)