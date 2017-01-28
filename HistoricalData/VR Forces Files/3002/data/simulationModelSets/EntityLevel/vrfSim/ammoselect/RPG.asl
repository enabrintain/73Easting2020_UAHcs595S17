;;
;; File - RPG.asl
;;
;;
;; Copyright (c) 1999 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: RPG.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the RPG launcher
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
        (PG-7 ;; these names need to match resource names
            (munition-type  2 2 222 2 8 1 0)  ;; RPG grenade
            (warhead  0)
         )
      )
   )
   (air ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
        (PG-7 ;; these names need to match resource names
            (munition-type  2 2 222 2 8 1 0)  ;; RPG grenade
            (warhead  0)
         )
      )
   )
)
