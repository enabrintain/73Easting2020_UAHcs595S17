;;
;; File - M2.asl
;;
;;
;; Copyright (c) 2003 MAK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: M2.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the M2(12.7 mm machine gun)
;; (for example only!)
;;

(ammo-select-table
   (lifeform ;; matches any lifeform
      (target-type  3 -1 -1 -1 -1 -1 -1)
      (ammo
         (M2-12.7mm ;; these names need to match resource names
            (munition-type  2 8 225 2 5 1 0) ;M33 ball
            (tracer-type    2 8 225 2 5 2 0) ; 4:1 mix of ball and tracer
            (warhead  0)
         )
      )
   )
   (small-truck 
      (target-type  1 1 -1  6 -1 -1 -1)
      (ammo
         (M2-12.7mm ;; these names need to match resource names
            (munition-type  2 8 225 2 5 1 0) ;M33 ball
            (tracer-type    2 8 225 2 5 2 0) ; 4:1 mix of ball and tracer
            (warhead  0)
         )
      )
   )
   (large-truck 
      (target-type  1 1 -1  7 -1 -1 -1)
      (ammo
         (M2-12.7mm ;; these names need to match resource names
            (munition-type  2 8 225 2 5 1 0) ;M33 ball
            (tracer-type    2 8 225 2 5 2 0) ; 4:1 mix of ball and tracer
            (warhead  0)
         )
      )
   )
   (civilian-vehicle
      (target-type  1 1 -1  27 -1 -1 -1)
      (ammo
         (M2-12.7mm ;; these names need to match resource names
            (munition-type  2 8 225 2 5 1 0) ;M33 ball
            (tracer-type    2 8 225 2 5 2 0) ; 4:1 mix of ball and tracer
            (warhead  0)
         )
      )
   )
)
