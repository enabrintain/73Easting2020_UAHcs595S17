;;
;; File - BMP2MainGun.asl
;;
;;
;; Copyright (c) 1999 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: BMP2MainGun.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the BMP-2 Main Gun (30mm cannon)
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
         (AT-30mm ;; these names need to match resource names
            (munition-type  2 2 222 2 2 0 0) ; In the DIS enum this is AP-T, i.e. tracer
            (tracer-type    2 2 222 2 2 0 0)
            (warhead  0)
         )
      )
   )
)