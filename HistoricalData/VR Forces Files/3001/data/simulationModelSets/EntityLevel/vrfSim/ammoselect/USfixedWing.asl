;;
;; File - USfixedWing.asl
;;
;;
;; Copyright (c) 1999-2000 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: USfixedWing.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for US fixed-wing launcher
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
        (Sidewinder-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 1 3 0)  ;; AIM-9S Sidewinder type
            (warhead  0)
         )
      )
   )
   (surface ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
        (Maverick-missile  ;; these names need to match resource names
            (munition-type  2 2 225 1 4 0 0)  ;; AGM-65 Maverick type
            (warhead  0)
         )
      )
   )
)
