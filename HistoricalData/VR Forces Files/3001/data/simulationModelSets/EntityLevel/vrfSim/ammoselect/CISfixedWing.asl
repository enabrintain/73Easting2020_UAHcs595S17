;;
;; File - CISfixedWing.asl
;;
;;
;; Copyright (c) 1999-2000 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: CISfixedWing.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for CIS fixed-wing launcher
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
        (Aphid-missile  ;; these names need to match resource names
            (munition-type  2 1 222 1 8 0 0)  ;; AA-8 Aphid
            (warhead  0)
         )
      )
   )
   (surface ;; matches any ground vehicle
      (target-type 1 1 -1 -1 -1 -1 -1)
      (ammo
         (Kedge-missile  ;; these names need to match resource names
            (munition-type  2 9 222 1 7 0 0)  ;; AS-14 Kedge Battlefield Support
            (warhead  0)
         )        
         (Kerry-missile  ;; these names need to match resource names
            (munition-type  2 9 222 1 4 0 0)  ;; AS-7 Kerry Battlefield Support
            (warhead  0)
         )        
         (Kegler-missile  ;; these names need to match resource names
            (munition-type  2 4 222 1 3 0 0)  ;; AS-12 Anti-radar
            (warhead  0)
         )
      )
   )
)
