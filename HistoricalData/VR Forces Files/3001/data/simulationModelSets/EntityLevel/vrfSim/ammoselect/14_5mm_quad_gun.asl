;;
;; File - 14_5mm_quad_gun.asl
;;
;;
;; Copyright (c) 2009 MAK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: 14_5mm_quad_gun.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the ADA quad 14.5 mm machine gun)
;; (for example only!)
;;

(ammo-select-table
   (air ;; matches any air plateform
      (target-type  1 2 -1 -1 -1 -1 -1)
      (ammo
         (API-14.5mm ;; these names need to match resource names
            (munition-type  2 1 222 2 2 1 0)
            (tracer-type    2 1 222 2 2 2 0)
            (warhead  0)
         )
      )
   )
   (ground ;; matches any ground plateform
      (target-type  1 1 -1 -1 -1 -1 -1)
      (ammo
         (API-14.5mm ;; these names need to match resource names
            (munition-type  2 1 222 2 2 1 0)
            (tracer-type    2 1 222 2 2 2 0)
            (warhead  0)
         )
      )
   )
)
