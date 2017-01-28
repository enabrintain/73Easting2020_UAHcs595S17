;;
;; File - sm-2.asl
;;
;;
;; Copyright (c) 1999-2000 MaK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: sm-2.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the SM2 launcher
;; (for example only!)
;;

(ammo-select-table
   (aircraft ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
         (sm-2-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 27 1 0)
            (warhead  0)
         )
      )
   )
   (harpoon
      (target-type 2 6 225 1 1 -1 -1)
      (ammo
         (sm-2-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 27 1 0)
            (warhead  0)
         )
      )
   )
   (tomahawk
      (target-type 2 6 225 1 12 -1 -1)
      (ammo
         (sm-2-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 27 1 0)
            (warhead  0)
         )
      )
   )
   (styx
      (target-type 2 6 222 1 8 -1 -1)
      (ammo
         (sm-2-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 27 1 0)
            (warhead  0)
         )
      )
   )
   (exocet
      (target-type 2 6 71 1 1 -1 -1)
      (ammo
         (sm-2-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 27 1 0)
            (warhead  0)
         )
      )
   )
   (gabriel
      (target-type 2 6 105 1 1 -1 -1)
      (ammo
         (sm-2-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 27 1 0)
            (warhead  0)
         )
      )
   )
   (silkworm
      (target-type 2 6 45 1 8 -1 -1)
      (ammo
         (sm-2-missile  ;; these names need to match resource names
            (munition-type  2 1 225 1 27 1 0)
            (warhead  0)
         )
      )
   )
)
