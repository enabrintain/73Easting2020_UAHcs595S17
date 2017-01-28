;;
;; File - T80MainGun.asl
;;
;;
;; Copyright (c) 1999 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: T80MainGun.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the T-80 Main Gun
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
         (BM-14m-HEAT-125mm ;; these names need to match resource names
            (munition-type  2 2 222 2 11 3 0)
            (warhead  0)
         )
         (BM-9-AP-125mm ;; these names need to match resource names
            (munition-type  2 2 222 2 11 1 0)
            (warhead  0)
         )
      )
   )
   (battle-tank ;; matches any tank
      (target-type 1 1 -1 1 -1 -1 -1)
      (ammo
         (BM-9-AP-125mm ;; these names need to match resource names
            (munition-type  2 2 222 2 11 1 0)
            (warhead  0)
         )
         (BM-14m-HEAT-125mm ;; these names need to match resource names
            (munition-type  2 2 222 2 11 3 0)
            (warhead  0)
         )
      )
   )
   (LCAC
      (target-type 1 3 -1 11 1 -1 -1)
      (ammo
         (BM-9-AP-125mm ;; these names need to match resource names
            (munition-type  2 2 222 2 11 1 0)
            (warhead  0)
         )
         (BM-14m-HEAT-125mm ;; these names need to match resource names
            (munition-type  2 2 222 2 11 3 0)
            (warhead  0)
         )
      )
   )
)
