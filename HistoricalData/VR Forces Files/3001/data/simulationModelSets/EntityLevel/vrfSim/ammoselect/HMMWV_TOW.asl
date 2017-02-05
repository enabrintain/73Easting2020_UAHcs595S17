;;
;; File - HMMWV_TOW.asl
;;
;;
;; Copyright (c) 1999 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: HMMWV_TOW.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the HMMWV TOW launcher
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
         (TOW-missile  ;; these names need to match resource names
            (munition-type  2 2 225 1 1 3 0)  ;; BGM-71D TOW 2
            (warhead  0)
         )
      )
   )
)
