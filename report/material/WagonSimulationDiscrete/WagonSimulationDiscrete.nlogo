__includes ["stateMachines.nls"]
;;; Simulating a bus station


breed [passengers passenger]
breed [doors door]
breed [seats seat]
doors-own [open]
passengers-own [
  active-states ;; The current state of the world
  active-states-code ;; The code defined for the specific state.
  active-machines ;;
  active-machine-names ;;
  target
  beliefs intentions incoming-queue ]

;;; Creates stohastically a passenger on the platform.
;;; The latter is set by a slider on the simulation environment. 
;;; This give a model in which passengers appear at different execution times
to create-passengers-probability
if total-passengers > 0 
  [
  let p random max-passengers-in-terminal
  if p > total-passengers  [set p total-passengers ] ;; just not to get negative values.
  if (count patches with [pcolor = magenta and not any? other turtles-here] >= p) 
    [create-passengers p [
       set shape "passenger"
       set size 1.7
       set color red
       move-to one-of patches with [pcolor = magenta and not any? other turtles-here]
       initialise-state-machine
       if pen-on [pen-down]
       ]
     set total-passengers total-passengers - p   
    ]
  ]
end

to run-simulation
  create-passengers-probability
  ask passengers [execute-state-machine]
  tick
  if (not any? passengers) [stop]
end 


to movie-record
    movie-start "experiment1.mov"
    movie-grab-interface ;; show the initial state
    repeat 400 
    [ run-simulation
      movie-grab-interface ]
    movie-close
end



;;; Create the environment. Since the station layout is 
;;; imported from a image file, some adjustment to the colors had to be done.
to setup
  ca 
  ca import-pcolors layout-of-wagon
  reset-ticks 
  ask patches [set pcolor round pcolor] ; normalise colors so we can use yellow and blue.
  ask patches with [pcolor = 63] [set pcolor green] ;hack to be changed later
  ask patches with [pcolor = 98] [set pcolor sky] ; hack as above.
  ask patches with [pcolor = yellow] [sprout-seats 1 [set shape "seat" set color black set size 2]]  ;; seat creation
  ask patches with [pcolor = blue and not any? neighbors with [pcolor = sky] ] [sprout-doors 1 [set shape "cylinder" set size 0.7 set color blue set pcolor cyan set open false]]  ;; doors
  ask patches with [pcolor = blue] [sprout-doors 1 [set shape "cylinder" set size 0.7 set color blue set pcolor cyan set open false]] 
  ask patches with [pcolor = blue] [set pcolor cyan] ; hack to remove last two door spots
  ask patches with [pcolor = 10] [set pcolor black]
  ;; Draw some lines for visuallization 
  ask patch 21 25 [sprout 1 [set color black set pen-size 2 pendown set heading 90 while [can-move? 1] [fd 1] die]]
  ask patch 21 32 [sprout 1 [set color black set pen-size 2 pendown set heading 90 while [can-move? 1] [fd 1] die]]
  ask patch -67 25 [sprout 1 [set color black set pen-size 2 pendown set heading -90 while [can-move? 1] [fd 1] die]]
  ask patch -67 32 [sprout 1 [set color black set pen-size 2 pendown set heading -90 while [can-move? 1] [fd 1] die]]
  ;;set total-passengers 40 ;; a value not to set the val at each experiment.
end 

;;; The following presents the definition of the "main" state machine that passengers "execute".
;;; Note that this is actually a reporter that returns the list of state definitions (see TSTATES manual for details).

to-report state-def-of-passengers 
  report (list
      
   state "enter station"
   # on-success "walk-toward close-to 80" do "set color blue" goto "waiting"
   # on-failure "walk-toward close-to 80" do "select-an-empty-door" activate-machine "walk-toward close-to 80"
   # otherwise do "select-the-closest-door" activate-machine "walk-toward close-to 80"
   end-state 
 
   state "waiting" 
    # when "passenger-close" do "move-to-a-clear-spot" goto "waiting" ;; and this allows us to arrange ourselves nicely.
    # when "on-wagon" do "set color violet" goto "passenger"
    # on-failure "walk-toward near 10" do "select-spot-in-wagon" activate-machine "walk-toward near 10"
    # on-success "goto-door-area" do "select-spot-in-wagon" activate-machine "walk-toward near 10" 
    # when "doors-open" do "nothing" activate-machine "goto-door-area"
    # otherwise do "nothing" goto "waiting"   
   end-state
   
   
   state "passenger"
   # after-n-ticks (random 100 + travel-time) do "set color brown" goto "get-off"
   # when "outside" do "set color blue" goto "waiting"
   # when "passenger-close" do "move-to-a-clear-spot" goto "passenger"
   # on-success "walk-toward near 10" do "nothing" goto "get-seated"
   # when "seat-near-available" do "select-a-seat" activate-machine "walk-toward near 10"
   # otherwise do "nothing" goto "passenger"  
   end-state
 
   state "get-seated"
    # when "seat-clear" do "move-to target set color white" goto "seated" 
    # otherwise do "nothing" goto "passenger"
   end-state

   state "seated"
    # after-n-ticks (random 100 + travel-time) do "set color brown" goto "get-off"
    # otherwise do "nothing" goto "seated"
   end-state

   state "get-off"
     # on-success "goto-door-area" do "nothing" goto "exiting"
     # otherwise do "nothing" activate-machine "goto-door-area"
   end-state  
  
  state "exiting"
     # on-success "walk-toward near 300" do "die" goto "exiting"
     # on-failure "walk-toward near 300" do "nothing" goto "get-off"
     # when "doors-open" do "select-an-exit" activate-machine "walk-toward near 300"
     # otherwise do "nothing" goto "exiting"
  end-state
  
  )

end

;;; A definition of a state machine to be invoked. 
to-report state-def-of-goto-door-area
  report (list
    state "select-door-area"
    # when "invoked-from \"waiting\" and any? passengers-decenting" do "step-back" goto "select-door-area"
    # when "at-door" do "nothing" success 
    # when "any? entry-points" do "select-entry-point" activate-machine "walk-toward near 15" 
    # otherwise do "face closest-door" goto "select-door-area" 
    end-state   
    )
end

;;; Definition of a state machine to be activbated when the passenger, wants to move somewhere in the station.
;;; Note that since this is a reporter, we can have machines that take arguments.

to-report state-def-of-walk-toward [proximity-val time]
  report (list
   state "moving"
    # after-n-ticks time do "face target" failure ;;; time out here. Then decide what to do.  
    # when "closed-doors" do "nothing" goto "moving"
    # when "in-queue" do "face target" goto "moving"
    # when  (word "target-is " proximity-val)  do "face target" success
    # when "any? free-positions" do "move-closer-to target face target" goto "moving" 
    # otherwise do "nothing" goto "moving"
   end-state
    )
end


;;; Doors ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Open the door
to open-door
  set open true
  set color cyan ;;; this make door invisible
end

;;; Close the door
to close-door
  set open false
  set color blue
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Reporters Concering doors
;;; We assume that when doors open there is a sound alarm that informs 
;;; everybody in the station. This can be changed easily to include cone-of-vision 
;;; and vision-distance parameters.
to-report doors-open
  report [open] of one-of doors
end 

;;; Can I sense a closed door? (No alrm in this case, you have to see it).
;;; Why not cone-of-vision etc?  Because simply when I see a closed door in an wagon, 
;;; I move closer to it until a certain "influence distance".
to-report closed-doors
  report any? doors in-cone influence-distance cone-of-influence with [not open] 
end

;;; Passenger Actions 
to move-closer-to [t]
  let tloc min-one-of free-positions [distance t]
  if (tloc != nobody) [move-to tloc] ;;min-one-of free-positions [distance t]]
end

;;; Select a door with the fewer passengers. Any door!
to select-an-empty-door
  set target min-one-of doors in-cone vision-distance cone-of-vision [count passengers in-radius 3] 
end

;;; Select a door that is near.
to select-the-closest-door 
  set target closest-door
end

;;; Report a door that is near.
to-report closest-door 
  report min-one-of doors [distance myself]
end

to select-an-exit-point
  set target [one-of patches in-radius 9 with [pcolor = red]] of closest-door
end

to select-entry-point
  set target one-of entry-points
end 

to-report entry-points
  report patches in-cone vision-distance cone-of-vision with [pcolor = red]
end


;;; Check space to see if there is any empty location.
to select-spot-in-wagon
  set target one-of patches in-radius 16 with [pcolor = green and not any? passengers-on self]
end

;;; Selects an end point in the simulation. It actually selects an exit of the station.
to select-an-exit
  set target one-of patches with [pcolor = magenta]
end

to step-back
  rt 180
  walk-a-step 
  lt 180
end


to walk-a-step
  if not any? other turtles-on patch-ahead 1 and [pcolor != sky] of patch-ahead 1 [move-to patch-ahead 1]
end

;;;; Reporters

to-report at-door
  report pcolor = red
end

to-report passengers-decenting 
  report passengers in-cone influence-distance cone-of-vision with [color = brown]
end

to-report passenger-ahead
  report any? other passengers-on patch-ahead 1
end

;;; I am well on the wagon.
to-report on-wagon
  report pcolor = green 
  ;;report not any? neighbors with [pcolor != green] 
end 

to-report outside
  report pcolor = black
end


to-report seats-ahead  ;; Other seats not the one I am heading.
  let m target
  ifelse is-turtle? target  
     [report any? seats  with [who != [who] of m] in-cone 1 180]
     [report any? seats  in-cone 1 180] 
end

to change-direction
  set heading heading + round random-normal 0 10
end 


;;; my Area is my area. 
to-report passenger-close
  report any? other passengers-on neighbors ;;closest-passenger != nobody and [distance myself] of closest-passenger < 1
end

to-report free-spot
  let p closest-passenger
  report max-one-of free-positions [distance p]
end

;;; This is the list of free neighborgs
to-report free-positions
  report neighbors with [
    not any? other passengers-here ;on self 
    and not any? seats-here ;;on self 
    and not any? doors-here with [not open] 
    and pcolor != sky 
    and pcolor != yellow]
end


to move-to-a-clear-spot
  let fs free-spot
  if fs != nobody [move-to fs]
  if target != nobody [face target]
end

to-report closest-passenger
  report min-one-of other passengers in-radius 2 [distance myself]
end

;;; too many people ahead cannot do anything, but wait.
to-report in-queue 
  report count passengers-on neighbors in-cone influence-distance cone-of-influence > 3 ;; All three places ahead are occupied. 
end
  
;;;;
;;; Select a near-by seat
to select-a-seat
  set target min-one-of seats-near-by [distance myself]
end

to-report seat-near-available
  report any? seats-near-by
end

to-report seats-near-by
  report seats in-cone vision-distance cone-of-vision with [not any? other passengers-here]
end

to-report seat-clear
  report not any? other passengers-on target
end 

;;; Am I near a seat?
to-report near-seat
  report distance target = near
end

to-report seated
  report any? seats-here
end

to-report target-is [dis]
  report distance target < dis
end
@#$#@#$#@
GRAPHICS-WINDOW
343
10
1158
446
80
40
5.0
1
10
1
1
1
0
0
0
1
-80
80
-40
40
1
1
1
ticks
30.0

SLIDER
13
152
269
185
total-passengers
total-passengers
0
200
40
10
1
NIL
HORIZONTAL

BUTTON
90
10
153
43
Run
run-simulation
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
12
191
268
224
max-passengers-in-terminal
max-passengers-in-terminal
0
50
22
1
1
NIL
HORIZONTAL

BUTTON
12
10
85
43
NIL
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

BUTTON
14
268
153
301
Open all doors
ask doors [open-door]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
13
304
154
337
Close all Doors
ask doors [close-door]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
160
10
245
43
Run Once
run-simulation
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
13
230
269
263
travel-time
travel-time
50
500
90
10
1
NIL
HORIZONTAL

SLIDER
13
354
185
387
near
near
0
5
2
1
1
NIL
HORIZONTAL

SLIDER
13
389
185
422
close-to
close-to
0
20
8
1
1
NIL
HORIZONTAL

SLIDER
15
464
187
497
cone-of-vision
cone-of-vision
0
370
180
1
1
NIL
HORIZONTAL

SLIDER
15
501
187
534
vision-distance
vision-distance
15
30
20
1
1
NIL
HORIZONTAL

SLIDER
194
501
385
534
influence-distance
influence-distance
0
10
1
1
1
NIL
HORIZONTAL

SWITCH
13
114
121
147
pen-on
pen-on
1
1
-1000

SLIDER
193
464
385
497
cone-of-influence
cone-of-influence
0
360
180
1
1
NIL
HORIZONTAL

CHOOSER
12
64
258
109
layout-of-wagon
layout-of-wagon
"wagonDrawingDouble1.png" "wagonDrawingDouble2.png" "wagonDrawingDouble3.png"
2

BUTTON
978
518
1145
551
Record Experiment
movie-record
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This is a model of an underground station drawn from [3], where authors use the Situated Cellular Agent model to simulate crowd behaviour while boarding and descending a metro wagon in an underground station.

The model was developed with the purpose of demonstrating/investigating the expressive power of the TSTATES library[1],[2] and is described in more detail in [1].

## HOW IT WORKS

The simulation concerns a complete passenger cycle, in the sense that the simulation models not only the boarding but also the descending of passengers in the wagon. This was done, since we wanted to investigate how boarding passengers affect the behaviour of passengers descending the wagon, and in order to have a richer state machine to encode.  
 
Passenger behaviour is specified by a state machine, encoded in the TSTATES Library. Informally and rather briefly, each passenger:

* Upon entering the station, selects its closest door and walks towards that target.
* When close to the door and doors open, boards the wagon by selecting a door area (coloured red) to walk towards. If there are any passengers descending the passenger steps back to facilitate their exit. 
* When in the door area, selects a clear spot in the wagon to move to. Upon arriving at the spot, the passenger has completed boarding.
* If the passenger "sees" an empty seat, he/she tries top get seated. 
* After a while (determined differently for each passenger), begins to descend from the wagon. This involves selecting the nearest door area for un-boarding and walks towards that door.
* When at the door area, the passenger selects an exit, walks towards this new target and "leaves" the simulation.

## HOW TO USE IT

1. Choose a underground station setup from the layout-of-wagon drop down list.
2. Select the number of passengers you wish to simulate (total-passengers NetLogo slider) 
3. Select the number of passengers that can be at any time at the entrance (max-passengers-in-terminal NetLogo slider) 
4. Select the total travel time, i.e the time each passenger stays on the wagon (travel-time NetLogo slider). This value defines the minimum number of ticks that each passenger will stay on the wagon, before trying to get off. In order to have a more realistic simulation, this value is added to a random 100 value in order that each passenger has an different time he/she decides to get off.  

Agents have two sets of parameters that control how they perceive the environment: 
* Cone-of-influence and influence distance that determines the area lying in "front" of the agent (towards its heading), which the agent considers when assessing whether it is in a "crowded" situation
* cone-of-vision and vision-distance, that determines the area an agent can "see" to spot empty seats, detect passengers descending and determining whether a door is closed or not. NOTE: If you set a veyr low value to distance, your agents will not be able to see the doors!

The experiment also has two other parameters, i.e. close-to and near, which are spatial proximity values used to describe success conditions on agent goals. For instance when moving close to a door, the value close-to sets the distance from the selected door, and at the point when the agent is in a distance less than that value the "goal" is considered successful. 

Finaly, there are two buttons that control opening/closing of wagon doors. 

## THINGS TO NOTICE

Notice the passenger patterns when boarding. 

## THINGS TO TRY

Vary the number of passengers, to see how the boarding/descending takes place.  

## EXTENDING THE MODEL

There are a number of variations that could be implemented:
* Stations: Instead of having passengers descending depending on the travel-time value, passengers could simply be assigned a destination station, which will be announced (a netLogo reporter?) and initiate their descent.
* Variations in the population, in the sense that there could be passengers that walk faster, have different cone of vision etc. 
* ... emotions, evacuation scenarios (fire, smoke, etc)...

## NETLOGO FEATURES

Model uses the TSTATES library (file stateMachines.nls) for encoding the finite state machine model. Please check [1] and [3] for a reference and a manual for the library.

## RELATED MODELS

Models using the TSTATES library found at http://users.uom.gr/~iliass/projects/NetLogo/TSTATES/index.html

A similar model has been developed using Population P-Systems. 

## CREDITS AND REFERENCES

[1] Sakellariou, I. (2012) Agent Based Modelling and Simulation using State Machines, SIMULTECH 2012, Rome Italy.

[2] Sakellariou, I. (2012). Turtles as state machines - agent programming
in netlogo using state machines. ICAART 2012 February, 2012.

[3] Bandini, S., Federici, M. L., and Vizzari, G. (2007). Situated cellular agents approach to crowd modeling and simulation. Cybernetics and Systems, 38(7):729–753.

[4] TSTATES libary and examples, manula can be found at  http://users.uom.gr/~iliass/projects/NetLogo/TSTATES/index.html
(or http://users.uom.gr/~iliass/ and follow the corresponding link).
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
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

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

passenger
true
0
Circle -7500403 true true 30 30 240
Rectangle -10899396 true false 120 15 180 210

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

seat
false
0
Rectangle -7500403 true true 0 15 45 285
Rectangle -7500403 true true 0 255 285 300
Rectangle -7500403 true true 255 15 300 300
Rectangle -7500403 true true 0 0 300 45
Line -7500403 true 0 0 0 300
Line -7500403 true 0 0 300 0

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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
Polygon -7500403 true true 135 285 195 285 270 90 30 90 105 285
Polygon -7500403 true true 270 90 225 15 180 90
Polygon -7500403 true true 30 90 75 15 120 90
Circle -1 true false 183 138 24
Circle -1 true false 93 138 24

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="3" runMetricsEveryStep="true">
    <setup>setup
ask doors [open-door]</setup>
    <go>run-simulation</go>
    <timeLimit steps="3000"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="close-to">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-passengers">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cone-of-influence">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-passengers-in-terminal">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-distance">
      <value value="27"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-of-wagon">
      <value value="&quot;wagonDrawingDouble3.png&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pen-on">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cone-of-vision">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="influence-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="near">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="travel-time">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
