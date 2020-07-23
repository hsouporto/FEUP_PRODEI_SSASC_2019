## Crowd Evacuation Simulation

## How to run
* Run the setup to setup the arena and all agents
* Press go to issue one step
* Press go with recurrent for continuous simulation
* Press go until no survivors for simulating until no survivors

Agent will start to move to exits and escape from spreading fire

## Parameters
* Fire speed
* Number of fires
* Panic behaviour active
* Strategy to be used (agent behaviour)
* Random fire of fixed position
* max number survivors per patch
* threshold for survivor health control
* max vision for each agent (draw from normal distribution with max limit)

## Hardcoded parameters
* Male/Female distribution
* Child/Adult/Eldery distribution
* Child speed
* Adult Speed
* Eldery speed
* Panic speeds


## Notes

Some many other parameters can be easily set, but to avoid a cluttered GUI environment
only the most important were put on user direct control.

To speed things, change speed.

## ACKNOWLEDGES
Based on the work of shingkid with addons such as follow the leader, re-routing exit workload, multiple random fires, fire speed according material and formulation of agent healt