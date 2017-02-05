;;
;; File - AKA762.asl
;;
;;
;; Copyright (c) 1999 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: AKA762.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the AK-47(7.62 mm rifle)
;; (for example only!)
;;

(ammo-select-table
   (default ;; matches any lifeform
      (target-type  3 -1 -1 -1 -1 -1 -1)
      (ammo
         (AKA-762mm ;; these names need to match resource names
            (munition-type  2 8 222 2 2 3 0)
            (warhead  0)
         )
      )
   )
   (ground ;; matches any lifeform
      (target-type  1 -1 -1 -1 -1 -1 -1)
      (ammo
         (AKA-762mm ;; these names need to match resource names
            (munition-type  2 8 222 2 2 3 0)
            (warhead  0)
         )
      )
   )
)
