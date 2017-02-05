;;
;; File - M240.asl
;;
;;
;; Copyright (c) 2012 MAK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: M240.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the M240(7.62 mm machine gun)
;; (for example only!)
;;

(ammo-select-table
   (lifeform ;; matches any lifeform
      (target-type  3 -1 -1 -1 -1 -1 -1)
      (ammo
         (NATO-7.62x51mm ;; these names need to match resource names
            (munition-type  2 8 225 2 2 5 0)
            (tracer-type    2 8 225 2 2 4 0) ; Ball/tracer mix, 4:1
            (warhead  0)
         )
      )
   )
   (small-truck 
      (target-type  1 1 -1  6 -1 -1 -1)
      (ammo
         (NATO-7.62x51mm ;; these names need to match resource names
            (munition-type  2 8 225 2 2 5 0)
            (tracer-type    2 8 225 2 2 4 0) ; Ball/tracer mix, 4:1
            (warhead  0)
         )
      )
   )
   (large-truck 
      (target-type  1 1 -1  7 -1 -1 -1)
      (ammo
         (NATO-7.62x51mm ;; these names need to match resource names
            (munition-type  2 8 225 2 2 5 0)
            (tracer-type    2 8 225 2 2 4 0) ; Ball/tracer mix, 4:1
            (warhead  0)
         )
      )
   )
   (civilian-vehicle
      (target-type  1 1 -1  27 -1 -1 -1)
      (ammo
         (NATO-7.62x51mm ;; these names need to match resource names
            (munition-type  2 8 225 2 2 5 0)
            (tracer-type    2 8 225 2 2 4 0) ; Ball/tracer mix, 4:1
            (warhead  0)
         )
      )
   )
)
