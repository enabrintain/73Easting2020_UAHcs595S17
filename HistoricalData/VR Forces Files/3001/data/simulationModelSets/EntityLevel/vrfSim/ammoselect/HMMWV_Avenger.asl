;;
;; File - HMMWV_TOW.asl
;;
;;
;; Copyright (c) 1999 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: HMMWV_Avenger.asl,v $ $Revision: 1.1 $ $State: Exp $
;;

(ammo-select-table
   (default ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
         (Stinger-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 15 3 0) ;; Stinger RMP 
            (warhead  0)
         )
      )
   )
)
