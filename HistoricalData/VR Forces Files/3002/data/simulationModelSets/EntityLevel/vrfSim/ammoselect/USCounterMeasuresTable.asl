;;
;; File - USCounterMeasuresTable.asl
;;
;;
;; Copyright (c) 2011 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: USCounterMeasuresTable,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Counter Measures Select Table for US automatic counter measures launcher
;; (for example only!)
;;

(counter-measures-select-table
   (ir-guided-aphid
      (target-type 2 1 222 1 8 -1 -1)
      (ammo
        (m206-flare ;; these names need to match resource names
            (munition-type  8 2 225 2 1 0 0)
            (warhead  0)
         )
      )
   )
   (ir-guided-archer 
      (target-type 2 1 222 1 11 -1 -1)
      (ammo
        (m206-flare ;; these names need to match resource names
            (munition-type  8 2 225 2 1 0 0)
            (warhead  0)
         )
      )
   )
   (ir-guided-sa-9 
      (target-type 2 1 222 1 21 -1 -1)
      (ammo
        (m206-flare ;; these names need to match resource names
            (munition-type  8 2 225 2 1 0 0)
            (warhead  0)
         )
      )
   )
   (radar-guided-SA-9 
      (target-type 2 6 71 1 1 -1 -1)
      (ammo
        (chaff ;; these names need to match resource names
            (munition-type  8 2 225 1 1 1 0)
            (warhead  0)
         )
      )
   )
   (ir-guided-sidewinder
      (target-type 2 1 225 1 1 3 -1)
      (ammo
        (m206-flare ;; these names need to match resource names
            (munition-type  8 2 225 2 1 0 0)
            (warhead  0)
         )
      )
   )
   (ir-guided-stinger 
      (target-type 2 1 225 1 15 -1 -1)
      (ammo
        (m206-flare ;; these names need to match resource names
            (munition-type  8 2 225 2 1 0 0)
            (warhead  0)
         )
      )
   )
   (radar-guided-patriot 
      (target-type 2 1 225 1 16 2 -1)
      (ammo
        (chaff ;; these names need to match resource names
            (munition-type  8 2 225 1 1 1 0)
            (warhead  0)
         )
      )
   )
   (radar-guided-sm-2 
      (target-type 2 1 225 1 27 1 -1)
      (ammo
        (chaff ;; these names need to match resource names
            (munition-type  8 2 225 1 1 1 0)
            (warhead  0)
         )
      )
   )
)
