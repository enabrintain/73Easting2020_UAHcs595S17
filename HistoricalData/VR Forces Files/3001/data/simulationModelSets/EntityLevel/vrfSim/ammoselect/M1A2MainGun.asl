;;
;; File - M1A2MainGun.asl
;;
;;
;; Copyright (c) 1999 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: M1A2MainGun.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the M1A2 Main Gun
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
         (M830-HEAT-120mm ;; these names need to match resource names
            (munition-type  2 2 225 2 13 3 0)
            (warhead  0)
         )
         (M829A1-AP-120mm ;; these names need to match resource names
            (munition-type  2 2 225 2 13 2 0)
            (warhead  0)
         )
      )
   )
   (battle-tank ;; matches any tank
      (target-type 1 1 -1 1 -1 -1 -1)
      (ammo
         (M829A1-AP-120mm ;; these names need to match resource names
            (munition-type  2 2 225 2 13 2 0)
            (warhead  0)
         )
         (M830-HEAT-120mm ;; these names need to match resource names
            (munition-type  2 2 225 2 13 3 0)
            (warhead  0)
         )
      )
   )
)