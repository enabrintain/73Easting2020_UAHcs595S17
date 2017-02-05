;;
;; File - M16.asl
;;
;;
;; Copyright (c) 2003 MAK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: M16.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the M16(5.56 mm rifle)
;; (for example only!)
;;

(ammo-select-table
   (lifeform ;; matches any lifeform
      (target-type  3 -1 -1 -1 -1 -1 -1)
      (ammo
         (M16A2-556mm ;; these names need to match resource names
            (munition-type  2 8 225 2 1 1 0)
            (tracer-type    2 8 225 2 1 2 0)
            (warhead  0)
         )
      )
   )
   (civilian-vehicle  ; "technical"
      (target-type  1 1 -1  27 -1 -1 -1)
      (ammo
         (M16A2-556mm ;; these names need to match resource names
            (munition-type  2 8 225 2 1 1 0)
            (tracer-type    2 8 225 2 1 2 0)
            (warhead  0)
         )
      )
   )
)
