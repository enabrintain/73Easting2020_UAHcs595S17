;;
;; File - M136_AT4.asl
;;
;;
;; Copyright (c) 2007 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: M136_AT4.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the AT4 launcher
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
        (M84mm ;; these names need to match resource names
            (munition-type  2 2 225 2 8 1 0)  ;; AT4 84mm grenade
            (warhead  0)
         )
      )
   )
   (air ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
        (M84mm ;; these names need to match resource names
            (munition-type  2 2 225 2 8 1 0)  ;; AT4 84mm grenade
            (warhead  0)
         )
      )
   )
)
