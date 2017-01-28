;;
;; File - MIM-104.asl
;;
;;
;; Copyright (c) 1999-2000 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: MIM-104.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the MIM-104 launcher
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
         (PAC-3-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 16 2 0)
            (warhead  0)
         )
      )
   )
)
