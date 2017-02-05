;;
;; File - M230.asl
;;
;;
;; Copyright (c) 2012 MAK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: M230.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the M230 chain gun (for AH-64)
;; (for example only!)
;;
;; This gun cannot be loaded with different ammunition during a
;; mission; however this table is needed so that the gun controller
;; knows that it has a munition to fire on a given entity type.

(ammo-select-table
   (lifeform ;; matches any lifeform
      (target-type  3 -1 -1 -1 -1 -1 -1)
      (ammo
         (M789-HEDP-30mm ;; these names need to match resource names
            (munition-type  2 9 225 2 3 1 0)
            (warhead  0)
         )
      )
   )
   (small-truck 
      (target-type  1 1 -1  6 -1 -1 -1)
      (ammo
         (M789-HEDP-30mm
            (munition-type  2 9 225 2 3 1 0)
            (warhead  0)
         )
      )
   )
   (large-truck 
      (target-type  1 1 -1  7 -1 -1 -1)
      (ammo
         (M789-HEDP-30mm
            (munition-type  2 9 225 2 3 1 0)
            (warhead  0)
         )
      )
   )
   (small-tracked-utility
      (target-type  1 1 -1  8 -1 -1 -1)
      (ammo
         (M789-HEDP-30mm
            (munition-type  2 9 225 2 3 1 0)
            (warhead  0)
         )
      )
   )
   (large-tracked-utility
      (target-type  1 1 -1  9 -1 -1 -1)
      (ammo
         (M789-HEDP-30mm
            (munition-type  2 9 225 2 3 1 0)
            (warhead  0)
         )
      )
   )
   (civilian-vehicle
      (target-type  1 1 -1  27 -1 -1 -1)
      (ammo
         (M789-HEDP-30mm
            (munition-type  2 9 225 2 3 1 0)
            (warhead  0)
         )
      )
   )
)
