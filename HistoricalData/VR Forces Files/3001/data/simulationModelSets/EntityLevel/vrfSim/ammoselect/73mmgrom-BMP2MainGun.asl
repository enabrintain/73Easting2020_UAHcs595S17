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
         (OG-15V HE-Frag ;; these names need to match resource names
            (munition-type  2 2 222 2 2 0 0)
            (warhead  0)
         )
         (PG-15V HEAT ;; these names need to match resource names
            (munition-type  2 2 222 2 2 0 0)
            (warhead  0)
         )
      )
   )
      
)
