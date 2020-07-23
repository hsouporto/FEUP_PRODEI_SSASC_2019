# Crowd Evacuation Simulation
Current practices are not sufficient to prepare humans for crowd evacuations in reality as there is no real sense of danger when running fire drills. Multi-agent systems provide a way to model individual behaviours in an emergency setting more accurately and realistically. Panic levels can be encoded to simulate irrational and chaotic behaviours that result in deadly stampedes that have been observed in such situations historically. This project attempts to find out the significance of various factors on the human stampede effect using the unsafe layout of The Float @ Marina Bay as a simulation environment. Using the experiment results, this project hopes to provides some form of insights into likely causes of human stampede effects and seeks to provide informed recommendations to increase survivability in crowd evacuations in such settings.

## NetLogo Model
The NetLogo world is a 2-dimensional replication of The Float @ Marina Bay. Due to computational limitations, we halved the seating capacity from 30,000 to 14,178. The seating area can be divided into six sections, each with a distinct color. Lime-colored patches at the bottom of the staircases represent exits. The starting location of the fire can be set to a fixed or random location. Each tick represents a second, and each patch corresponds to a meter. The fire expands its reach every 10 ticks and consumes the entire stadium in approximately half an hour.

Agents are spawned on the seats (we assume a full house) and are colored according to their seat sections. Each agent is given a set of characteristics during setup such as age group, gender, weight, and vision. These parameters are used to calculate the individual’s panic level, speed, health, and force which we further elaborate upon in the next section.

## Parameters
### Age
Normal distribution following Singapore Age Structure 2017, grouped into three categories - child, adult, and elderly.
### Gender
961 males per 1000 females (Population Trends 2017, Singapore Department
of Statistics)
- Male: 48.05%
- Female: 51.95%
### Speed
Each agent has a base walking speed depending on their age category.
- Child: 0.3889m/s (1.4km/h)
- Adult: Uniform distribution between 1.4778m/s (5.32km/h) and 1.5083m/s (5.43km/h)
- Elderly: Uniform distribution between 1.2528m/s (4.51km/h) and 1.3194m/s (4.75km/h)
### Vision
Uniform distribution between 0 (vision can be extremely poor due to natural blindness or onset of smoke) and a maximum that can be set between 20 and 100.
### Panic (Levels 1-3)
1. All agents start with a base level of 1
2. If the fire is within the agent’s vision, panic rises to 2. The agent’s speed increases to average running pace (1.8056 m/s).
3. If the fire is nearer (within half the distance that the agent can see), panic rises to 3. The agent’s speed increases to a fast running speed (2.5 m/s).
### Mass (Body weight)
Each agent is given a mass (kg) drawn from a normal distribution depending
on their age category and gender. Standard deviation was set to 4 in all cases.
- Child
    - Female: mean=35
    - Male: mean=40
- Adult/Elderly: mean=57.7

## Strategies
### "Smart"
The “smart” strategy assumes that all survivors are equipped with the knowledge of the nearest exit location from where they are, and will try to proceed to the nearest possible exit with the use of the best-first search algorithm. In the event that the designated exit has been blocked by the fire, they will locate the next nearest exit.

### "Follow"
The “follow” strategy is used to model the ‘herding behaviour’ of survivors, as similar in the flocking library. In this strategy, survivors only have limited vision with no knowledge of the nearest exits, and they will follow the exact action of the other survivors 1 patch in front of them. If the fire is within their vision, they would run in the opposite direction from the fire. If they see an available exit, they will run straight for the exit.

## Agent Death
As our model does not take into account civil defence forces coming in to put out the fire or to rescue survivors, it is reasonable to assume that an agent dies once it comes in contact with fire.

According to Ngai et al (2009), “the vast majority of human stampede casualties result from traumatic asphyxia caused by external compression of the thorax and/or upper abdomen, resulting in complete or partial cessation of respiration." In situations leading to stampedes, crowds do not stop accumulating even with local densities up to 10 people per square meter. People who succumb typically die standing up and do not collapse to the floor until after the crowd density and pressure have been relieved (Gill & Landi, 2004). Further, forces of up to 4500 N can be generated by
just 6 to 7 people pushing in a single direction - large enough to bend steel railings.

In our model, we calculate force/pressure exerted in a patch *p* as

<img src="https://latex.codecogs.com/gif.latex?F_p=\sum&space;_{a\in&space;A}&space;mass_a&space;\times&space;speed_a" title="F_p=\sum _{a\in A} mass_a \times speed_a" />

where *A* is the set of agents on patch *p* and each patch has a limit of 10 agents at a time.

Each agent is given “health” which models the agent’s potential exertable force scaled by a global threshold specified during setup:

<img src="https://latex.codecogs.com/gif.latex?health_a&space;=&space;mass_a&space;\times&space;speed_a&space;\times&space;threshold" title="health_a = mass_a \times speed_a \times threshold" />

As the crowd scrambles towards the exits, overcrowding can occur as people push their way forward indiscriminately and the force exerted within a patch (which corresponds to a square meter) accumulates. A death from stampede occurs when the total patch force exceeds the “health” of an agent in the respective patch.

## Acknowledgements
Project team: Patrick Lim, Jane Seah, and Sim Li Jin

Supervisor: Dr Cheng Shih-Fen, School of Information Systems, Singapore Management University