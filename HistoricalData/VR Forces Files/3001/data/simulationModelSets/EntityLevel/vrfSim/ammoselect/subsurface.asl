;; Copyright (c) 2003 MAK Technologies, Inc.
;; All rights reserved.
;;
;; $RCSfile: subsurface.asl,v $ $Revision: 1.1 $ $State: Exp $
;;
;; Ammo Select Table for the submarine
;; Configured to work for both US and CIS subs.
;; (for example only!)
;;

(ammo-select-table
   (anti-ship 
      (target-type 1 3 -1 -1 -1 -1 -1)
      (ammo
        (MK-48-torpedo    ;; these names need to match resource names
            (munition-type  2 7 225 1 2 1 0)  ;; torpedo type
            (warhead  0)
        )
        (USET-80-torpedo    ;; these names need to match resource names
            (munition-type  2 7 222 1 5 0 0)  ;; torpedo type
            (warhead  0)
        )
      )
   )
   (anti-sub 
      (target-type 1 4 -1 -1 -1 -1 -1)
      (ammo
        (MK-48-torpedo    ;; these names need to match resource names
            (munition-type  2 7 225 1 2 1 0)  ;; torpedo type
            (warhead  0)
        )
        (USET-80-torpedo    ;; these names need to match resource names
            (munition-type  2 7 222 1 5 0 0)  ;; torpedo type
            (warhead  0)
        )
      )
   )
)
