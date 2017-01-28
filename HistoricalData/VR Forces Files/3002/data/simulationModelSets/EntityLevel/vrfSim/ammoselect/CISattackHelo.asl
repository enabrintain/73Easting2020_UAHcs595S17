;;
;; File - CISattackHelo.asl
;;
;;
;; Copyright (c) 2003 MAK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: CISattackHelo.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the attack helicopter launcher
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
        (spiral-missile  ;; these names need to match resource names
            (munition-type  2 2 222 1 8 0 0)  ;; AT-6 Spiral type
            (warhead  0)
         )
      )
   )
   (LCAC
      (target-type 1 3 -1 11 1 -1 -1)
      (ammo
        (spiral-missile  ;; these names need to match resource names
            (munition-type  2 2 222 1 8 0 0)  ;; AT-6 Spiral type
            (warhead  0)
         )
      )
   )
   (air-default ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
        (archer-missile  ;; these names need to match resource names
            (munition-type  2 1 222 1 11 0 0)  ;; AA-11 Archer
            (warhead  0)
         )
      )
   )
)
