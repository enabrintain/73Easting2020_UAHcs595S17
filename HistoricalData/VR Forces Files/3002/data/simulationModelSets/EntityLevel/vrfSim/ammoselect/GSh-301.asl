;;
;; File - GSh-301.asl
;;
;;
;; Copyright (c) 2014 MAK Technologies, Inc.
;; All rights reserved.
;;
;; Ammo Select Table for the GSh-301 cannon (for Ru attack aircraft.)
;; (for example only!)
;;
;; This gun cannot be loaded with different ammunition during a
;; mission; however this table is needed so that the gun controller
;; knows that it has a munition to fire on a given entity type.

(ammo-select-table
   (lifeform ;; matches any lifeform
      (target-type  3 -1 -1 -1 -1 -1 -1)
      (ammo
         (OFZ-HEI-30x165mm ;; these names need to match resource names
            (munition-type  2 2 222 2 2 1 0) ; This is AP-T (tracer)
            (tracer-type    2 2 222 2 2 1 0)
            (warhead  0)
         )
      )
   )
   (land-platform 
      (target-type  1 1 -1  -1 -1 -1 -1)
      (ammo
         (OFZ-HEI-30x165mm
            (munition-type  2 2 222 2 2 1 0) ; This is AP-T (tracer)
            (tracer-type    2 2 222 2 2 1 0)
            (warhead  0)
         )
      )
   )
   (air-platform 
      (target-type  1 2 -1  -1 -1 -1 -1)
      (ammo
         (OFZ-HEI-30x165mm
            (munition-type  2 2 222 2 2 1 0) ; This is AP-T (tracer)
            (tracer-type    2 2 222 2 2 1 0)
            (warhead  0)
         )
      )
   )
)
