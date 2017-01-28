;;
;; File - SA9.asl
;;
;;
;; Copyright (c) 1999-2000 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: SA9.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the SA9 launcher
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
         (SA-9-missile  ;; these names need to match resource names
            (munition-type  2 1 222 1 21 0 0)
            (warhead  0)
         )
      )
   )
)
