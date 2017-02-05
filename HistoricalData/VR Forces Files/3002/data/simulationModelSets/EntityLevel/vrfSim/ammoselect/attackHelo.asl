;;
;; File - attackHelo.asl
;;
;;
;; Copyright (c) 1999 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: attackHelo.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the attack helicopter launcher
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
        (Hellfire-missile  ;; these names need to match resource names
            (munition-type  2 2 225 1 3 4 0)  ;; Hellfire type
            (warhead  0)
         )
         (TOW-missile  ;; these names need to match resource names
            (munition-type  2 2 225 1 1 3 0)  ;; TOW type
            (warhead  0)
         )
      )
   )
   (air ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
        (Sidewinder-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 1 3 0)  ;; AIM-9S Sidewinder type
            (warhead  0)
         )
      )
   )
)
