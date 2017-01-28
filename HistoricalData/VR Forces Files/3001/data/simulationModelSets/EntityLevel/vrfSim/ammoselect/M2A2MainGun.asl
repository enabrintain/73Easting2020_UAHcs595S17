;;
;; File - M2A2MainGun.asl
;;
;;
;; Copyright (c) 1999 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: M2A2MainGun.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the M2A2 Main Gun (25mm cannon)
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
         (M791-AP-25mm ;; these names need to match resource names
            (munition-type  2 2 225 2 3 2 0) ; APDS-T (tracer)
            (tracer-type    2 2 225 2 3 2 0)
            (warhead  0)
         )
      )
   )
(lifeform ;; matches any ground vehicle
      (target-type 3 1 -1 -1 -1 -1 -1)
      (ammo
         (M791-AP-25mm ;; these names need to match resource names
            (munition-type  2 2 225 2 3 2 0) ; APDS-T (tracer)
            (tracer-type    2 2 225 2 3 2 0)
            (warhead  0)
         )
      )
   )
)