globals[

  ; Map settings
  pedestrian-spawn-pcolor
  pedestrian-destination-pcolor
  car-spawn-pcolor
  car-destination-pcolor

  road-width

  ; Measurements
  pedestrian-total-stress
  pedestrian-total-stress-so-far
  pedestrian-current-average-stress
  pedestrian-average-stress-so-far

  car-total-stress
  car-total-stress-so-far
  car-current-average-stress
  car-average-stress-so-far

  num-accidents

  car-total-time-to-destination
  pedestrian-total-time-to-destination

  car-average-time-to-destination
  pedestrian-average-time-to-destination


  ; Used for spawning agents
  ticks-to-spawn_c
  ticks-to-spawn_p

  ; Other variable for caluculation
  total-cars-spawned
  total-pedestrians-spawned

  accumulated-pedestrian-to-car-ratio
  average-pedestrian-to-car-ratio
]

breed [cars car]
breed [pedestrians pedestrian]

cars-own [
  visibility-range
  cautiousness
  goal-patch
  actual-speed
  turtles-in-zone
  stress
  time-to-destination
  warning?
]

pedestrians-own[
  visibility-range
  walking-speed
  goal-patch
  cautiousness
  stress
  time-to-destination
]



to setup

  clear-all
  reset-ticks

  ;; resize-world min-pxcor max-pxcor min-pycor max-pycor
  resize-world -80 80 -80 80

  ;; define what colors represents what
  set pedestrian-spawn-pcolor 63 ;; green
  set pedestrian-destination-pcolor 63 ;; green, same as spawn patch

  set car-spawn-pcolor 94.9 ;; blue
  set car-destination-pcolor 94.9 ;; blue, same as spawn patch

  import-pcolors "Images/image1-5.jpg"
  import-drawing "Images/image1-5.jpg"

  set-default-shape cars "car top"
  set-default-shape pedestrians "person"

  set road-width 14

  set car-total-stress 0
  set pedestrian-total-stress 0
  set pedestrian-average-stress-so-far 0
  set car-average-stress-so-far 0
  set num-accidents 0
  set total-cars-spawned 0
  set total-pedestrians-spawned 0
  set accumulated-pedestrian-to-car-ratio 0

  initiate_cars
  initiate_pedestrians

  set ticks-to-spawn_c 1
  set ticks-to-spawn_p 1

end

to go

  ; Initialize agents
  if ticks = ticks-to-spawn_c [
    initiate_cars
    set ticks-to-spawn_c (ticks + 1 + round random-exponential cars-spawn-mean)
  ]
  if ticks = ticks-to-spawn_p [
    initiate_pedestrians
    set ticks-to-spawn_p (ticks + 1 + round random-exponential pedestrians-spawn-mean)
  ]

  move_cars


  ; Pedestrians checks for any cars nearby.
  ; If yes, they either stop or step back
  ; depending on how near the vehicle is.
  ; If no, they will make a move towards their goal.

  ask pedestrians [

    ifelse check_cars_danger_zone [

      ; if cars within stop zone, stop moving
      ifelse check_cars_stop_zone [

        set color green
        move_pedestrians
      ][
        set color orange
      ]
    ][
      set color red
      bk walking-speed
    ]
  ]

  ; Cars will have a tendency to stay slightly
  ; away from wall based on their cautiousness
  ask cars [stay_away_from_wall]

  ; Take measurements.
  count_stress
  check_accidents
  update_time_to_destination

  ; For estimating pedestrian spawn rate based on
  ; known vehicle spawn rate.
  if ticks > 0
  [
    let carCount 0
    ifelse count cars = 0
    [set carCount 1]
    [set carCount count cars]
    set accumulated-pedestrian-to-car-ratio accumulated-pedestrian-to-car-ratio + (count pedestrians / carCount)
    set average-pedestrian-to-car-ratio (accumulated-pedestrian-to-car-ratio / ticks)
  ]

  tick
end

to check_accidents

  ; At every tick, the pedestrian checks its surrounding.
  ; If any cars is within a radius of 0.2, it is recorded
  ; as an accident.
  ; The agents involved in the accident will die.
  ask pedestrians [

    let current-pedestrian self
    let crash-car cars with [distance current-pedestrian < 0.2]

    if crash-car != nobody and any? crash-car [
      set num-accidents (num-accidents + 1)
      ask crash-car [
        set car-total-time-to-destination car-total-time-to-destination + time-to-destination
        die
      ]
      set pedestrian-total-time-to-destination pedestrian-total-time-to-destination + time-to-destination
      die
    ]
  ]

  ; At every tick, the cars checks its surrounding for other cars.
  ; If there are cars within a radius of 1.2, it is recorded as an accident.
  ; Cars involved in the accident die.
  ask cars [

    let current-cars self
    let crash-car other cars with [distance current-cars < 1.2]

    if crash-car != nobody and any? crash-car [
      set num-accidents (num-accidents + 1)
      ask crash-car [
        set car-total-time-to-destination car-total-time-to-destination + time-to-destination
        die
      ]
      die
    ]
  ]

end

to count_stress

  set pedestrian-total-stress sum [stress] of pedestrians

  ifelse count pedestrians = 0
  [set pedestrian-current-average-stress 0]
  [set pedestrian-current-average-stress (pedestrian-total-stress / count pedestrians)]

  set car-total-stress sum [stress] of cars

  ifelse count cars = 0
  [set car-current-average-stress 0]
  [set car-current-average-stress (car-total-stress / count cars)]

  if ticks > 0
  [
    set car-total-stress-so-far car-total-stress-so-far + car-current-average-stress
    set car-average-stress-so-far car-total-stress-so-far / ticks
  ]

  if ticks > 0
  [
    set pedestrian-total-stress-so-far pedestrian-total-stress-so-far + pedestrian-current-average-stress
    set pedestrian-average-stress-so-far pedestrian-total-stress-so-far / ticks
  ]

end

to update_time_to_destination

  ask turtles [
    set time-to-destination time-to-destination + 1
  ]

  if ticks > 0 [
    set car-average-time-to-destination car-total-time-to-destination / total-cars-spawned
    set pedestrian-average-time-to-destination pedestrian-total-time-to-destination / total-pedestrians-spawned
  ]
end


to stay_away_from_wall

  let angle 5
  let current-car self

  let min-distance ((road-width * cautiousness * 0.4) / 2 )
  let wall-nearby patches in-cone min-distance 180 with [pcolor = black]

  if any? wall-nearby [

    let nearest-wall min-one-of wall-nearby [distance current-car]
    let initial-heading heading

    set heading towards nearest-wall

    ifelse floor (initial-heading / 90) != floor (heading / 90) [

      ; if C and W different quadrants:
      ifelse floor (initial-heading / 90) = 0 [
        ; if C = 0
        ifelse floor (heading / 90) = 3 [
          ; if C = 0, W = 3
          set heading initial-heading + angle
        ][
          ; if C = 0, W = 1
          set heading initial-heading - angle
        ]
      ][
        ; if C != 0
        ifelse floor (initial-heading / 90) > floor (heading / 90) [
          ; if C > W
          set heading initial-heading + angle
        ][
          ; if C < W
          set heading initial-heading - angle
        ]
      ]
    ][
      ; if C and W same quadrants:
      ifelse initial-heading > heading [
        set heading initial-heading + angle
      ][
        set heading initial-heading - angle
      ]

    ]
    if breed = cars [fd actual-speed / 2]
  ]


end

to move_cars

  ask cars[

    set actual-speed vehicle-speed-limit
    set color sky

    ; If goal reached, die.
    if distance goal-patch < actual-speed [
      set car-total-time-to-destination car-total-time-to-destination + time-to-destination
      die
    ]
    if distance goal-patch < 30 and [pcolor] of patch-here = car-destination-pcolor [
      set car-total-time-to-destination car-total-time-to-destination + time-to-destination
      die
    ]

    ; Cars move by determining the patch they want to move to.
    ; The patch they want to move to is the nearest patch to the goal,
    ; within their visbility range.
    ;
    ; If there is no such patch, they will look around.
    ;
    ; This patch then determines the car's heading.
    ; The car will attempt to move to this patch with its actual speed.

    ; needed to access goal-patch variable from patch perspective
    let goal-patch-temp goal-patch

    ; Attempt to move to where they can see, nearest to their goal-patch.
    ; Within human's natural vision of 114
    let can-see-patch min-one-of patches in-cone visibility-range 114 with [pcolor != black] [distance goal-patch-temp]

    ; If they cannot see any feasible patches to move to,
    ; they will look around
    ; until they find a feasible patch to move to
    let look-around-angle 114

    let countLoop 0 ; for infinite loop - prevents crashing

    while [can-see-patch = nobody or can-see-patch = patch-here] [

      set look-around-angle (look-around-angle + 1)
      set can-see-patch min-one-of patches in-cone visibility-range look-around-angle with [pcolor != black] [distance goal-patch-temp]

      if look-around-angle >= 360 [
        set look-around-angle 0
        set can-see-patch min-one-of patches in-cone visibility-range look-around-angle with [pcolor != black] [distance goal-patch-temp]
      ]

      set countLoop countLoop + 1

      if countLoop > 500 [
        set can-see-patch  min-one-of patches with [pcolor = white] [distance self]
      ]

      if (can-see-patch != nobody and distance can-see-patch <= 0.5) [
       ask patch-here [
          set can-see-patch min-one-of other patches with [pcolor = white] [distance self]
       ]
      ]
    ]

    set heading towards can-see-patch


    ; Before the actual movement, the car will lookout for any obstacles/agents in front,
    ; and it will try to navigate away from it.
    ; If there are any obstacles/agents in front of it,
    ; it will reassess its speed before moving.

    let warning-distance (car-size * cautiousness)
    let jam-break-distance (car-size * cautiousness * 0.3)
    set warning? false

    set turtles-in-zone other turtles in-cone jam-break-distance 114 with [pcolor != black]

    ;; if where they want to go is black, then go to a patch nearest to where they want to go that is not black
    ifelse not any? turtles-in-zone [

      ; If not in jam-break zone
      set turtles-in-zone other turtles in-cone warning-distance 114 with [pcolor != black]

      ifelse not any? turtles-in-zone [

        ; If not in warning zone, move.
        ifelse patch-at-heading-and-distance heading actual-speed = nobody or
        [pcolor] of patch-at-heading-and-distance heading actual-speed = black [

          after_assessment_speed ;; ASSESSMENT (change speed)

          let to-move-patch min-one-of patches in-radius actual-speed with [pcolor != black] [distance can-see-patch]
          if to-move-patch = nobody [set to-move-patch min-one-of patches with [pcolor != black] [distance can-see-patch]]
          face to-move-patch
          move-to to-move-patch
        ][

          after_assessment_speed ;; ASSESSMENT (change speed)
          fd actual-speed
        ]
      ][
        ; IF IN WARNING ZONE
        set warning? true
        set color orange
        stay_away_from_car
        set stress stress + 1
      ]
    ][
      ; If in jam break distance
      set color red
      set stress stress + 2

      ; In the situation where cars face head-on, and got stuck forever
      set heading heading + 10
      fd 2
    ]
  ]

end

to-report check_cars_stop_zone

  ; Returns a boolean.
  ; If true, continues to move.
  ; If false, stop.

  let stop-zone-distance (car-size * cautiousness)

  let car-in-front one-of cars in-cone 114 stop-zone-distance

  ifelse car-in-front = nobody [
    report true
  ][
    set stress stress + 1
    report false
  ]

end

to-report check_cars_danger_zone

  ; Returns a boolean.
  ; If true, continues to move.
  ; If false, stop.

  let danger-zone-distance (car-size * cautiousness * 0.3)

  let car-in-front one-of cars in-cone 30 danger-zone-distance

  ifelse car-in-front = nobody [
    ; True implies no car infront
    report true
  ][
    ; False implies there is car in front
    set stress stress + 2
    report false
  ]

end

to move_pedestrians

  ; If goal reached, die.
  if distance goal-patch < walking-speed [
    set pedestrian-total-time-to-destination pedestrian-total-time-to-destination + time-to-destination
    die
  ]
  if distance goal-patch < 30 and [pcolor] of patch-here = pedestrian-destination-pcolor [
    set pedestrian-total-time-to-destination pedestrian-total-time-to-destination + time-to-destination
    die
  ]

  ; Pedestrians move by determining the patch they want to move to.
  ; The patch they want to move to is the nearest patch to the goal,
  ; within their visbility range.
  ;
  ; If there is no such patch, they will look around.
  ;
  ; This patch then determines the pedestrian's heading.
  ; The pedestrian will attempt to move to this patch with its actual speed.

  let can-see-patch pedestrian_can_see_patch

  set heading towards can-see-patch


  ; If where they want to go is black or nobody, then go to a patch nearest to
  ; where they want to go that is not black
  ; else, move towards goal by staying near to wall

  ifelse patch-at-heading-and-distance heading walking-speed = nobody or
  [pcolor] of patch-at-heading-and-distance heading walking-speed = black [

    let to-move-patch min-one-of patches in-radius walking-speed with [pcolor = white or pcolor = pedestrian-destination-pcolor] [distance can-see-patch]
    if to-move-patch = nobody [set to-move-patch min-one-of patches with [pcolor != black] [distance can-see-patch]]

    ; Prevent stuck
    ifelse distance to-move-patch < 0.5 [
       face to-move-patch
       move-to to-move-patch
       fd 1
    ][
       face to-move-patch
       move-to to-move-patch
    ]
  ][
    let nearest-wall min-one-of patches with [pcolor = black] [distance can-see-patch]
    let nearest-wall-distance 0
    ask nearest-wall [set nearest-wall-distance distance can-see-patch]

    ifelse nearest-wall-distance > ((road-width / 2) * (1 - cautiousness)) [

      face min-one-of patches with [pcolor = white or pcolor = pedestrian-destination-pcolor] [distance nearest-wall]
      fd walking-speed
    ][
      fd walking-speed
    ]
  ]
end

to-report pedestrian_can_see_patch

  ;; needed to access goal-patch variable from patch perspective
  let goal-patch-temp goal-patch

  ;; pedestrians try to move to where they can see, nearest to their goal-patch
  ;; within human's natural vision of 114
  let can-see-patch min-one-of patches in-cone visibility-range 114 with [pcolor != black] [distance goal-patch-temp]

  ;; if they cannot see any feasible patches to move to, they will look around
  ;; until they find a feasible patch to move to
  let look-around-angle 114

  let countLoop 0
  while [can-see-patch = nobody or can-see-patch = patch-here] [

    set look-around-angle (look-around-angle + 1)

    ifelse look-around-angle <= 360 [
      set can-see-patch min-one-of patches in-cone visibility-range look-around-angle with [pcolor != black] [distance goal-patch-temp]
    ][
      set look-around-angle 0
      set can-see-patch min-one-of patches in-cone visibility-range look-around-angle with [pcolor != black] [distance goal-patch-temp]
    ]
    set countLoop countLoop + 1

    if countLoop >= 500 [
      set can-see-patch min-one-of other patches with [pcolor != black] [distance self]
    ]
  ]

  report can-see-patch
end

to initiate_cars

  ; Each agent will have their attributes vary according to the average value
  ; and the deviation level, distributed normally.

  let visibility-sd (average-driver-visibility-range * deviation-level)
  let cautiousness-sd (average-driver-cautiousness * deviation-level)

 repeat num-cars [

    let spawn-point one-of patches with [pcolor = car-spawn-pcolor and not any? other cars-here]
    if spawn-point != nobody [

      ask spawn-point [
        sprout-cars 1 [

          set size car-size
          set color sky

          set visibility-range random-normal average-driver-visibility-range visibility-sd
          set cautiousness random-normal average-driver-cautiousness cautiousness-sd
          set actual-speed vehicle-speed-limit
          set goal-patch one-of patches with [pcolor = car-destination-pcolor and distance myself > 10]

          set stress 0
          set time-to-destination 0

          ; Update global variable
          set total-cars-spawned total-cars-spawned + 1
        ]
      ]
    ]
  ]

end

to initiate_pedestrians

  ; Each agent will have their attributes vary according to the average value
  ; and the deviation level, distributed normally.

  let visibility-sd (average-pedestrian-visibility-range * deviation-level)
  let speed-sd (average-pedestrian-movespeed * deviation-level)
  let cautiousness-sd (average-pedestrian-cautiousness * deviation-level)

  repeat num-pedestrians [
    ask one-of patches with [pcolor = pedestrian-spawn-pcolor ][
      sprout-pedestrians 1 [

        set size pedestrian-size
        set color green

        set visibility-range random-normal average-pedestrian-visibility-range visibility-sd
        set walking-speed  random-normal average-pedestrian-movespeed speed-sd
        set cautiousness random-normal average-pedestrian-cautiousness cautiousness-sd
        set goal-patch one-of patches with [pcolor = pedestrian-destination-pcolor and distance myself > 10]

        set stress 0
        set time-to-destination 0

        ; Update global variable
        set total-pedestrians-spawned total-pedestrians-spawned + 1
      ]
    ]
  ]
end

to after_assessment_speed

  ; Check if there is a turtle in heading + visibility range
  let my-heading heading

  set turtles-in-zone other turtles in-cone visibility-range 30 with [pcolor != black]

  if count turtles-in-zone != 0 [
    set turtles-in-zone min-one-of turtles-in-zone [distance myself];; define nearest turtle-to-compare
  ]

  if turtles-in-zone != nobody [
    ifelse [breed] of turtles-in-zone = pedestrians [
      ifelse [walking-speed] of turtles-in-zone < actual-speed [

        set actual-speed (actual-speed / 1.2)
        if actual-speed < 0.5 [set actual-speed 0]
      ][
        set actual-speed vehicle-speed-limit
      ]
    ][
      if [breed] of turtles-in-zone = cars [
        ifelse [actual-speed] of turtles-in-zone < actual-speed [
          set actual-speed [actual-speed] of turtles-in-zone
        ][
          set actual-speed vehicle-speed-limit
        ]
      ]
    ]
  ]
end

to stay_away_from_car

  let warning-angle 30

  let r random 2

  if r = 0 [

    let current-car self

    let wall-nearby patches in-cone 10 180 with [pcolor = black]

    if any? wall-nearby [

      let nearest-wall min-one-of wall-nearby [distance current-car]
      let nearest-turtle min-one-of turtles-in-zone [distance self]
      let warning-heading towards nearest-turtle

      set heading towards nearest-wall

      ifelse floor (warning-heading / 90) != floor (heading / 90) [

        ; if C and W different quadrants:
        ifelse floor (warning-heading / 90) = 0 [

          ; if C = 0
          ifelse floor (heading / 90) = 3 [

            ; if C = 0, W = 3
            set heading warning-heading + warning-angle
          ][
            ; if C = 0, W = 1
            set heading warning-heading - warning-angle
          ]
        ][
          ; if C != 0
          ifelse floor (warning-heading / 90) > floor (heading / 90) [
            ; if C > W
            set heading warning-heading + warning-angle
          ][
            ; if C < W
            set heading warning-heading - warning-angle
          ]
        ]
      ][
        ; if C and W same quadrants:
        ifelse warning-heading > heading [
          set heading warning-heading + warning-angle
        ][
          set heading warning-heading - warning-angle
        ]
      ]

      ifelse warning? [fd actual-speed / 2][fd actual-speed / 4]
    ]
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
573
10
1236
674
-1
-1
4.07
1
14
1
1
1
0
0
0
1
-80
80
-80
80
1
1
1
ticks
30.0

BUTTON
14
11
84
51
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
7
585
181
618
vehicle-speed-limit
vehicle-speed-limit
1
20
9.0
0.1
1
NIL
HORIZONTAL

SLIDER
344
256
517
289
num-cars
num-cars
1
30
1.0
1
1
NIL
HORIZONTAL

SLIDER
343
299
516
332
num-pedestrians
num-pedestrians
1
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
14
312
261
345
average-driver-visibility-range
average-driver-visibility-range
1
20
20.0
1
1
NIL
HORIZONTAL

SLIDER
12
495
294
528
average-pedestrian-visibility-range
average-pedestrian-visibility-range
1
20
20.0
1
1
NIL
HORIZONTAL

SLIDER
6
630
250
663
average-pedestrian-movespeed
average-pedestrian-movespeed
0
2
1.3
0.05
1
NIL
HORIZONTAL

TEXTBOX
9
560
134
578
Speed Variables:
12
0.0
1

TEXTBOX
345
229
471
248
No. Agents:
12
0.0
1

SLIDER
14
272
249
305
average-driver-cautiousness
average-driver-cautiousness
0
1
1.0
0.05
1
NIL
HORIZONTAL

TEXTBOX
15
390
199
409
Pedestrians' Variables:
12
0.0
1

TEXTBOX
15
206
152
224
Drivers' Variables:
12
0.0
1

BUTTON
163
13
233
55
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
133
188
166
deviation-level
deviation-level
0
1
0.15
0.05
1
NIL
HORIZONTAL

TEXTBOX
16
108
153
126
Global Variables:
12
0.0
1

TEXTBOX
197
130
415
192
*deviation level is expressed as a percentage and it will be used to calculate standard deviation when initiating each agent's attributes
11
0.0
1

SLIDER
12
455
247
488
average-pedestrian-cautiousness
average-pedestrian-cautiousness
0
1
1.0
0.05
1
NIL
HORIZONTAL

MONITOR
1271
13
1469
70
Pedestrians Current Stress
pedestrian-current-average-stress
17
1
14

MONITOR
1659
15
1786
72
No. of Accidents
num-accidents
17
1
14

SLIDER
13
232
185
265
car-size
car-size
1
10
10.0
1
1
NIL
HORIZONTAL

SLIDER
13
413
185
446
pedestrian-size
pedestrian-size
1
3
2.4
0.1
1
NIL
HORIZONTAL

MONITOR
1480
14
1649
71
Drivers Current Stress
car-current-average-stress
17
1
14

MONITOR
1273
93
1468
150
Pedestrian Average Stress
pedestrian-average-stress-so-far
17
1
14

MONITOR
1552
96
1706
153
Cars Average Stress
car-average-stress-so-far
17
1
14

PLOT
1275
181
1475
331
Pedestrian Average Stress
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -13791810 true "" "plot pedestrian-average-stress-so-far"

PLOT
1558
185
1758
335
Car Average Stress
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -10899396 true "" "plot car-average-stress-so-far"

MONITOR
1558
351
1770
408
Car Avg Time-to-Destination
car-average-time-to-destination
17
1
14

MONITOR
1275
350
1536
407
Pedestrian Avg Time-to-Destination
pedestrian-average-time-to-destination
17
1
14

PLOT
1558
426
1758
576
Car Avg Time-to-Destination
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -11085214 true "" "plot car-average-time-to-destination"

PLOT
1274
424
1474
574
Pedestrian Avg Time-to-Destination
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -13791810 true "" "plot pedestrian-average-time-to-destination"

BUTTON
91
11
154
52
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
342
390
526
423
pedestrians-spawn-mean
pedestrians-spawn-mean
10
80
60.0
1
1
NIL
HORIZONTAL

SLIDER
341
345
513
378
cars-spawn-mean
cars-spawn-mean
1
20
9.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
true
0
Polygon -7500403 true true 180 0 164 21 144 39 135 60 132 74 106 87 84 97 63 115 50 141 50 165 60 225 150 300 165 300 225 300 225 0 180 0
Circle -16777216 true false 180 30 90
Circle -16777216 true false 180 180 90
Polygon -16777216 true false 80 138 78 168 135 166 135 91 105 106 96 111 89 120
Circle -7500403 true true 195 195 58
Circle -7500403 true true 195 47 58

car top
true
0
Polygon -7500403 true true 151 8 119 10 98 25 86 48 82 225 90 270 105 289 150 294 195 291 210 270 219 225 214 47 201 24 181 11
Polygon -16777216 true false 210 195 195 210 195 135 210 105
Polygon -16777216 true false 105 255 120 270 180 270 195 255 195 225 105 225
Polygon -16777216 true false 90 195 105 210 105 135 90 105
Polygon -1 true false 205 29 180 30 181 11
Line -7500403 true 210 165 195 165
Line -7500403 true 90 165 105 165
Polygon -16777216 true false 121 135 180 134 204 97 182 89 153 85 120 89 98 97
Line -16777216 false 210 90 195 30
Line -16777216 false 90 90 105 30
Polygon -1 true false 95 29 120 30 119 11

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person farmer
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 60 195 90 210 114 154 120 195 180 195 187 157 210 210 240 195 195 90 165 90 150 105 150 150 135 90 105 90
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -13345367 true false 120 90 120 180 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 180 90 172 89 165 135 135 135 127 90
Polygon -6459832 true false 116 4 113 21 71 33 71 40 109 48 117 34 144 27 180 26 188 36 224 23 222 14 178 16 167 0
Line -16777216 false 225 90 270 90
Line -16777216 false 225 15 225 90
Line -16777216 false 270 15 270 90
Line -16777216 false 247 15 247 90
Rectangle -6459832 true false 240 90 255 300

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>pedestrian-average-stress-so-far</metric>
    <metric>car-average-stress-so-far</metric>
    <metric>pedestrian-average-time-to-destination</metric>
    <metric>car-average-time-to-destination</metric>
    <enumeratedValueSet variable="num-pedestrians">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-patience">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-size">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-reaction-time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-visibility-range">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-reaction-time">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviation-level">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-movespeed">
      <value value="0.55"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-cautiousness">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vehicle-speed-limit">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-cautiousness">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-visibility-range">
      <value value="8"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Estimate Pedestrian Spawn Rate" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1800"/>
    <metric>average-pedestrian-to-car-ratio</metric>
    <enumeratedValueSet variable="average-pedestrian-movespeed">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-pedestrians">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-size">
      <value value="2.4"/>
    </enumeratedValueSet>
    <steppedValueSet variable="pedestrians-spawn-mean" first="10" step="5" last="80"/>
    <enumeratedValueSet variable="average-driver-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vehicle-speed-limit">
      <value value="5.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviation-level">
      <value value="0.15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Test Run" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1800"/>
    <metric>pedestrian-average-stress-so-far</metric>
    <metric>car-average-stress-so-far</metric>
    <metric>pedestrian-average-time-to-destination</metric>
    <metric>car-average-time-to-destination</metric>
    <metric>num-accidents</metric>
    <enumeratedValueSet variable="average-pedestrian-movespeed">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrians-spawn-mean">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-pedestrians">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-size">
      <value value="2.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cars-spawn-mean">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <steppedValueSet variable="vehicle-speed-limit" first="5" step="0.5" last="9"/>
    <enumeratedValueSet variable="num-cars">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviation-level">
      <value value="0.15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Find Out Pedestrian Spawn Rate" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7200"/>
    <metric>average-pedestrian-to-car-ratio</metric>
    <enumeratedValueSet variable="average-pedestrian-movespeed">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-size">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="pedestrians-spawn-mean" first="10" step="5" last="80"/>
    <enumeratedValueSet variable="num-pedestrians">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-size">
      <value value="2.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cars-spawn-mean">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vehicle-speed-limit">
      <value value="8.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviation-level">
      <value value="0.15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Singapore Setting" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7200"/>
    <metric>pedestrian-average-stress-so-far</metric>
    <metric>car-average-stress-so-far</metric>
    <metric>pedestrian-average-time-to-destination</metric>
    <metric>car-average-time-to-destination</metric>
    <metric>num-accidents</metric>
    <enumeratedValueSet variable="average-pedestrian-movespeed">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrians-spawn-mean">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-pedestrians">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-size">
      <value value="2.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cars-spawn-mean">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vehicle-speed-limit">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviation-level">
      <value value="0.15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Elwick Setting" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7200"/>
    <metric>pedestrian-average-stress-so-far</metric>
    <metric>car-average-stress-so-far</metric>
    <metric>pedestrian-average-time-to-destination</metric>
    <metric>car-average-time-to-destination</metric>
    <metric>num-accidents</metric>
    <enumeratedValueSet variable="average-pedestrian-movespeed">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrians-spawn-mean">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-pedestrians">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-size">
      <value value="2.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cars-spawn-mean">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vehicle-speed-limit">
      <value value="8.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviation-level">
      <value value="0.15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Elwick vs Singapore" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7200"/>
    <metric>pedestrian-average-stress-so-far</metric>
    <metric>car-average-stress-so-far</metric>
    <metric>pedestrian-average-time-to-destination</metric>
    <metric>car-average-time-to-destination</metric>
    <metric>num-accidents</metric>
    <enumeratedValueSet variable="average-pedestrian-movespeed">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrians-spawn-mean">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-pedestrians">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-size">
      <value value="2.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cars-spawn-mean">
      <value value="9"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vehicle-speed-limit">
      <value value="8.9"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cars">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-driver-cautiousness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-pedestrian-visibility-range">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviation-level">
      <value value="0.15"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
