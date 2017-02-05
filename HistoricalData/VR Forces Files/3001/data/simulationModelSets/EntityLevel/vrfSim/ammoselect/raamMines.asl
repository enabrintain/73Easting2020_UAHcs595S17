;;
;; File - raamMines.asl
;;
;;
;; Copyright (c) 2001 MaK Technologies, Inc.
;; All rights reserved.
;; 
;; $RCSfile: raamMines.asl,Created:9/26/01 MEM Revision: 1.0
;; Updated:
;; Mine Select Table for a RAAM FASCAM minefield
;; 
;;

(mine-select-table
   (M70
		(mine-type "anti-tank-mine")
		(munition
			(munition-type  2 8 225 3 6 0 0)
			(warhead  0)
		)
		(arming-time 120.000000 )			;;in seconds
		(self-destruct-time 4.000000)			;;in hours
		(trigger 3)								;;magnetic
  		(trigger-radius 0.500000)			;;in meters
		(failure-percentage 0.100000)
		(mines-per-rnd  9)
	)
	(M73
		(mine-type "anti-tank-mine")
		(munition
			(munition-type  2 8 225 3 7 0 0)
			(warhead  0)
		)
		(arming-time 120.000000 )			;;in seconds
		(self-destruct-time 48.000000)		;;in hours
		(trigger 3)								;;magnetic
  		(trigger-radius 0.500000)			;;in meters
		(failure-percentage 0.100000)
		(mines-per-rnd  9)
	)
)
