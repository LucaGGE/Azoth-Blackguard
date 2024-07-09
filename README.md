# Rogue24 Game System
_CS50's Introduction to Game Development 2024, Final Project by Luca Giovani_

## A word (or two) on Videogames and Life

What constitutes video games - probably the most complex form of art conceived by man to date - is the combination of a massive amount of disciplines, variables in quantity, form, and even presence based on the specific product. Think of the cutscenes, the music and sounds, the next-gen graphics of AAA games, or the 8x8 pixel sprites.\
And that's not all: there are also ethical considerations. Marketing, visibility (if a tree falls in a forest, and there’s no one around to hear it, does it make a sound?). The cultural impact. The platform, which will determine who, when, and how will consume our product.\
It is not an easy or grateful job: we have all gritted our teeth in front of the trash asset-flip money-generating games kindly encouraged by Unity and indiscriminately distributed by Steam. We have all experienced the moment when our poorly organized Kickstarter closed the crowdfunding period by barely raising $15.\
What not everyone can do is reach the next stage: understanding that it's okay. Video games are art. And art is a thing, which can be good or bad, ordinary or exceptional, sell or never see the light of day. Art is a thing, indeed.\
A transcendental, divine thing - as it is ideal and perfect - something that is beauty for the sake of beauty. The video game, in its form, is a game for the pleasure of playing.\
And games teach. Games influence. Games shape.\
That's why a good game is so powerful when it satisfies a fantasy (original or not), that's why it touches so deeply when it tells a profoundly human story, and that's why it is essential that it contains essential truths. Lies and propaganda jar like broken strings, but the most insidious ones are able to hide behind powerful notes so well as to be diabolical.\
It is our responsibility as developers to care about the ethics and quality of our products. Only we can choose our path and decide to produce something that truly brings value to the user rather than doping them with sounds and colors or hiding the mediocrity of our product behind overwhelming special effects (which, by the way, works particularly well).\
At the very least, we should care about dignity and self-love - however rare they may be nowadays. What twisted soul desires to sell low-quality products? What pettiness can deprive us of the highest aspirations, even if they are very modest? Perhaps it is the fear of the quintessential human act - sacrifice, of course - that deprives us of the priceless joys it brings?\
We are nothing if we try to be everything. Sacrificing what we could be for what we decide to be is the steep path that leads to the top, which we must find groping in the dark. The night is long but not eternal, and soon our feet find the path we have been heading towards, a bit trampled and open, and a bit to clean up. Sometimes, it is almost night again when we realize that we have advanced a long way just a few steps from our path.\
I sacrificed my being a mediocre-of-all-trades and gave everything I could to embark on my journey, so close yet found so laboriously. I sweated for years, worked beyond exhaustion, failed beyond belief, destroyed my ego, attended exceptional courses, and read books of knowledge rarer than useless diamonds. My prize is to be able to put my creatures on the cross, without pain or fear.

## The idea

The idea for the _system_ that I have, with little imagination (I've never been strong with names), baptized _Rogue24_, is that of one capable of bringing the best elements of OSR tabletop RPGs to the computer.

Several games and genres have already succeeded in this endeavor, but always focusing on specific aspects. Perhaps the easiest way to imagine what I have in mind is to think of Rogue (without significant graphical limitations) meeting Colossal Cave Adventure with the customization capabilities of Dungeons & Dragons.

Therefore, I am thinking of an experience that contains the following elements:

1. Essential but pleasing graphics, whose main purpose is to provide spatial information
2. Game world organized within a grid, for simplicity of space and interaction
3. Modular and dynamic game physics. For this, I referred to MUDs and used an OOP system by aggregation. At the end of the text there are specific acknowledgments for this.
4. Multiplayer. Playable in _local-coop_ (currently the only way to play multiplayer that I have managed to recognize as healthy) or by a single player, if desired.
5. Heavily customizable game. Once the tools are created to facilitate modding, the system will almost seem like an engine.

**Cos'è questa storia del _sistema_? Non si tratta di un _videogame_?**

Well, I didn't create so much as _a game_ but a _game system_ instead.\
Don't get confused thinking this has something to do with game frameworks or engines. Instead, think of Tabletop RPGs (such as _Advanced Dungeons & Dragons_).
Or, well, think of LEGO or Minecraft. These are all incredibly successful "games", and for a good reason. But most of all, I want you to notice how much they have in common, so much that I would dare to say they're basically all different forms of the same thing: a _game system_.

Think about these common qualities:
1. They are all built with simple elements, based on imagination and defined by rules.
    - You act in a world created by imagination, defined by dice rolls and abstract rules
    - You act in a world created by imagination, defined by plastic modules obeying real-world physics
    - You act in a world created by imagination, defined by a simple structure of blocks and virtual physics
1. You excercise creativity interacting with its elements, and can even _make things_.
    - Creating a new character, forcing a trapdoor before the mutant finds you
    - Building a dinosaur, creating stop-motion animation, playing with a premade set
    - Building a cottage to host your next weekly LAN party, mine for diamonds
1. They are all _highly_ customizable.
    - Tweak rules to fit your campaign, change dice system, create roll tables
    - Mix sets, build without following instructions, mix character parts
    - Creating a texture-pack, a character skin, a mod
1. They're all about unleashing your creativity and enabling you to share your creation.
    - Inviting your friends to play your new, oh-so-full-of-surprises campaign
    - Hey Instagram people, watch this crazy thing I made with plastic bricks!
    - Creating YouTube content to teach people how to build the most incredible skyscraper
1. They are primarily meant for interaction with a community.
    - Your friday evening game session, with friends, snacks and jokes
    - Playing with your sister, making up imaginary scenarios
    - Hosting a server for fantasy role-players, giving them space to build a medieval town together

Interestingly enough, these tend to be what we generally see as _educational_ characteristics, as we easily recognise them as positive qualities.

**What's this talk about the _system_? Isn't this a _videogame_?**

Basically, _game systems_ allow you to create _games_. Think of a LEGO set to build Hogwarts. LEGO is the _game system_, the castle a predefined setting to play in, with a clear fantasy and suggested scenarios to play (since we could play Harry as a cyborg and Hermione as an alien from outer space), supported by specific graphics (think of a colorful set of bricks - probably not very helpful for your gothic cathedral project).

Or try taking in consideration the most abstract and therefore flexible of the examples given - since it's mostly played with pen, paper and dices - D&D.\
Anyone who has ever played it knows there are all these books full of rules. Well, that's the _game system_. You can use all of that to create absolutely any interactive story you want. But when you play a premade or homemade campaign, well, that's the _game_ that someone made for you to play.

## A word about monetization

Creating a _game_ using your own _game system_ helps you develop not only more robustly, but also to test the fun your system can provide, and helps you showcase magnificently what can be done with said system.\
That's why all of the above-mentioned _systems_ always come with at least one "premade" _game_.\
 
Players will see what can be done and will jump right in to start making their own content.\
It's like selling an ice cream cup that instead of just containing your ice cream and then becoming junk, provides you with all the ice cream you want.\
And maybe, the next version of that cup will let you have tastier ice cream. And the next will let you have an affogato ice cream. Or sprinkles. Or will add new flavours. How does that sound to you?\
Actually, creators of _game systems_ have a tendency to create many _games_ as possible, with some of them focusing more on merch and community-created mods, trying to have all players converge to a single product (Minecraft) and some focusing on providing new, improved versions of their _system_ (Dungeons & Dragons). The choice is driven by many complex factors that include personal taste and vision.

## About ethics

And here's where we should, in my opinion, start to think about _ethics_, and maybe how to make them go hand-in-hand with business (I may be dumb or naive, but I honestly think that's perfectly possible).

To start, here are some ideas that come to mind to avoid selling unethical products. You'll see these are very common techniques not at all exclusive to videogames. Our products:

1. Should not come out each year with minimal, mostly useless upgrades so that next year you can do the same thing easily (smartphones)
1. Should not be obsolete the day they come out by design (lots of tech)
1. Should not be produced exploiting workers and destroying environments/communities (fast fashion)
1. Should not be wolves in sheep's skin. If you want to create fancy advertisement, good for you; but don't tell people they're going to have a game experience when you are going to bombard them with unskippable advertising (masked as a game or not) and steal their phone data. I have seen people brag about how they were making exactly that and how that was cool and revolutionary and good for people as it was "bridging game and advertisment experience". How do I even comment this?
1. Should always keep community in mind, even if you are a badly asocial bear like me (social media)

At this point, it seems appropriate to propose my solutions to the above points. My product:

1. Will be released as a new version when it has something new to offer. Otherwise, I may propose a game created with it. If it becomes economically unsustainable, perhaps I am not working hard enough, or perhaps I am biting off more than I can chew.
1. I promise that it will represent the best of the best that my abilities and dedication can produce. No fixes/improvements will be shelved to save time.
1. It is being developed with my own hands, and those who created the sources for the sounds have been regularly paid.
1. It does not contain advertisements or propaganda, nor does it seek to deceive or misinform people. It is a genuine product.
1. It is being developed with portability and lightness in mind. My goal is to create something as compatible as possible with older operating systems and machines, and it will be sold for a few dollars. In fact, I am considering releasing it under an OS MPLv2 license.

## So, this "system" of yours, how is it?

Now that we discussed about what a _game system_ is and some ideas on _ethics_, I thinking I can share with you details about my project making sense.

Here I list and briefly explain my project's main characteristics:
1. The system is structured in such a way that it is easy for the player to use custom graphics and to add/modify/remove content.
    - Everything that the system uses for game content - the graphics, the creatures, weapons, even the player character - is loaded at launch from external files. Changing game graphics is easy as swapping tileset inside a folder. Changing the tile of an object means opening a CSV file and replacing a number. Adding content is slightly more complex, but not much. Thanks do detailed manuals and tools, players will be able to "build" custom entities with these simple steps:
        - Imagine what you would like to add to your game
        - Open the dedicated CSV in the source folder
        - Consult Game Manual to understand which components you'd like and how to input them in the _game system_
        - Write something like: "Entity name|Tile Index|Component,Argument|Component". For example:
            - "Blood Crab|66|npc,hostile|movable,walk,swim|attack,grab,pierce". But also:
            - "Death Cap|11|eatable|special,poison." Or even:
            - "Carrot Crop|62|eatable,+15hp|sprouting,ground".\
    All that is achieved thanks to objects built by aggregation. I will go in detail about it in a couple of sections.
1. The player is able to easily and freely share their custom game content, and to make a profit with it.
    - Since the system works with externalised, open game content, it will extremely easy for players to pack their creations and share them with friends/community. It won't be harder than moving a folder's content from A to B. Also, I don't see why people should be unable to _sell_ the content they created: after all, it's _their_ craft!\
    The only limitations imposed to players will be redistribution of the _game system_ and the fact that all the components used to build game entities need to be implemented in the system's code. That means, players will be limited by number and functionality of such components. What I'd like to offer, as a business model, is newer, improved, rich and more powerful systems; each version, clearly, will need to bring real innovation and value to players. This will be a great challenge, since the better the product offered, the harder it will be for me to improve it. Of course players will also be offered "Official" games built on these systems and old systems will be fixed and mantained.
1. Player gets Game Manuals (a cool way to present documentation, think of D&D's Players Handbook) to unleash their full creativity.
    - Each version of the _game system_ will have useful manuals. My idea is to give players two manuals. One will be there for the _game_ included with the system, with hints and tips and general cool content showcase, mostly for beauty and inspiration.\
    The other will be a "Modders Guide" that will give practical examples to explain how to create your very own game or mod. It will contain pretty illustrations, detailed explanations, lists of components and how to use them... it may sound slightly complex, but actually, modding is so easy that it will be a rather thin booklet.\
    I'd really like to highlight the fact that these manuals should feel like illustrated, antique tomes; making the player excited to have and read them, and why not, creating their own for their mod.
1. Players will have access to helpful developer tools and a full premade _game_ that values replayability, local coop and sharing.
    - To make players life even easier, they will have access to some developer tools. For example, to create a map, I used Tiled (and players will too, if they choose to). It is a very useful tool to create 2D maps using tilesets. But I think specific tools should be offered, to make things even easier for players and to give them a "batteries included" experience and also to avoid confusion since, for example, Tiled exports CSV files with commas as a standard while I use pipes. Another idea could be to change the text-based approach to entities creation and to use a visual tool. Also, maybe they should have a small tool to number tilesets tiles to choose them with more ease.\
    For what regards the _game_ included with system, I think it is of vital importance. It does several essential things such as:
        - Letting players understand if they like what they can do with the system.
        - Allowing me to develop a solid, rich _game system_ instead of an abstract, mock-up one.
        - Inspiring the players and making them want to create their own thing.
        - Giving them solid examples on how to make simple and complex things (remember that they will have full access to game content).
        - Having fun by themselves or with friends, sharing their experience and crazy game over screens with others.
    Also, I can, through time, develop different games with the same system, to enforce the above points. Just think of all D&D premade adventures that players still love today, and how much they have taught about campaign making to DMs.
1. The system is built to create interactions between game entities, and very diverse games can be created with it.
    - It's of little surprise that such a flexible game system is able to offer drastically different gaming experiences, since what the _game system_ does is foundamentally allowing turn-based interactions between game entities. These interactions can be things like collision, combat, dialogue, triggers or powerups. This means we can, for example, create a farming game, where the player has to defend their crops from noctural hordes of pests. We can create intelligent entities that can move but at the same time can be collected by the player. Multiplayer is not yet fully implemented, but the game is structured in such a way that it is perfectly possible for players to play together, maybe with NPCs with rich dialogues written by them.

## How much of that has been actually developed?

Now let's get a little pragmatic, and let's check out the actual code.\
So the first question is: how much of all that is already developed and working?
Being not all-that-easy-or-small of a project, and considering I am a commuter with a full-time, highly stressing job and that while I am writing this I am more than 15 days late, you can imagine I didn't have all the time I would have wanted.\
Still, I worked very hard and took time off work to build a convincing, solid base to show the system's functionality.

As of today, my _Rogue24_ (called this way to because it's my 2024 version of Rogue and I'd like to program it 24 hours a day) can:
- Translate CSV files in custom maps of any size, built by cells that make up a grid, representing the game world. There are currently two maps and you can check yourself how banal it is to insert data and link levels, even by writing text.
- Use any tileset to draw graphics. The tileset can have 20x20 cells (as the default one) or of any custom square size.
- Let the player manipulate tiles physics through another CSV, changing which tiles (using indexes) are solid, liquid, and so on.
- Create entity blueprints to spawn in game from yet another CSV - weapons, creatures, potions, etc. Right now it contains few example entities, built by a handful of components I had time to implement.
- Use a simple yet optimized camera system with static objects being drawn just once, able to center any needed subject.
- Demonstrate dynamic interaction between objects made of pure aggregation.
- Move an input-ready entity around, preventing it from exiting the grid that constitutes the world and allowing it to move only on terrain it can traverse (e.g. crabs can swim, player can't). All of that with the magic of turn-based movement.
- Showcase high-tech, pixel-perfect graphics with (wow!) dynamic UI (try resizing the screen).
- Amaze player with insane, next-gen camera tweening.
- Allow the player to choose between 1 to 4 characters (enabling local multiplayer).
- Provide a Game Over screen that will show the character's name, how and where it died, and how much gold it could loot. From there, players can jump back to the menu and start a new game.
- Provide horrible Credits screen, that I still like since I was able to have an image that resizes with the game window.
- Prove beyond any reasonable doubt that I spend too much time on the computer.

There's much; **much** more to come; but still, I hope I was able to showcase effectively the main concepts behind the project.

## The Development

To help you better understand the my _Rogue24_, I will quickly illustrate all the files found in this project's folder. Please note I was quite generous with comments while developing this and I think it might be useful to use this overview documentation in conjunction with simply reading the code.

### map_1/map_2.csv

Just a simple CSV with pipe character separations. The system reads it and transforms each index in a cell containing a tile, that has properties and few capabilities. All these cells form a grid structure. The grid size is dictated by the size of the map contained in the CSV file and nothing exists outside of the grid.\
Each cell can accept three arguments:
1. Tile index, mandatory
1. Entity, optional. Its id must exist as a blueprint.
1. Entity name, optional. This is used to give generic blueprint entities unique names (i.e. "Crab" becomes "Crabby") and also for special purposes such as telling an Exit component where to teleport the player (using the map's name).

### tiles_features.csv

Contains a list of physical features such as liquid, ground, solid, etc; and a list of tiles that belong to that specific group. Player can easily modify this file, and the system checks if all the features are valid and implemented in its code, otherwise they simply get rejected and a warning is printed on the console.

### entities.csv

This is were a player can get really creative. Each entity is created as a simple set of values, with the only rule that the first two values must represent "Entity Name" and "Entity Tile Index". For the rest, components can be added in any order. Some components accept optional arguments: for example "movable", that accepts different inputs for the type of movement (walking, flying, swimming).\
I intentionally added for demonstration purposes an invalid_feature_test, to show how the system recognizes when a component is not implemented and prints a warning on the console.

### mods.lua

Here I exposed all the game settings that could be easily changed by players.\
These are all optional and failing to assign valid values (or values at all) to this variables will mean that the program will simply ignore them.

### conf.lua

This is an extremely simple file, and all it does basically is enabling/disabling LOVE2D's console for printing and debugging. This can be enabled or disabled inside mods.lua, allowing modders to retrieve more important info about game events and mechanisms (even if to date, prints in code aren't organized to provice such utility).

### classic.lua

This one is RXI's class module for Lua. It is light, simple and saves tons of time.

### event.lua and timer.lua

These great libs are part of the Knife library from Airstruck and provide advanced functions I wouldn't have been able to implement myself, such as timers and tweening.

### components.lua

As the name suggests, this file contains all the implemented components do date.\
With the term component, I mean the single classes that compose an Entity. Think of a player character as something that is _composed_ by stats, moving abilities and die sets for things like attacking. As you may have guessed, this is where the most preliminary thinking and abstraction are required.\
This is also where most of the game content will go, and with time it will probably reach a length of thousands of lines. Unfortunately, being the juicy meat of the _system_ and not its backbone, this has received a lot less polish, and there are even some extremely crude examples of code that is "not good nor well designed, but working". With time, code will be fixed and optimized.

### constants.lua

All of the game constants are here. Most of them are taken from mods.lua.

### globals.lua

A simple table containing all the variables that need a global scope. There's not much stuff here and I always try to shrink it; still, I think it's a good way to handle global variables.

### definitions.lua

Definitions for modular elements like grid Cells, Entities and Game States. 

### main.lua

As the name suggests, this is the backbone of the software. It's what starts _Rogue24_ and tells Game States to do essential things like update() and draw().

### util.lua

This is by far the biggest and most complex file. It contains all of the useful game's functions, from reading CSV files to screen resizing and turn management. Explaining all of the material contained in this lua file would make this already extremely long text to unbearable.\
For all of the poor souls interested in a deeper delve, I recommend you simply jump in and read the code with its comments. I really tried to be as clear as possible to make life easier to me and others, so I have hope it won't be too hard to make sense of the code.

### states folder

The folder accomodating all of the Game States. These are nothing particularly advanced, and they only need few improvements before they are virtually finished.

## OOP by aggregation

This was not my original idea by any means, and all I did by myself was taking the abstract idea and give it a practical application. I recommend you check last section, "Acknowledgments", and check out Cowboy Programming's article "Evolve your hierarchy" where I originally took the idea. I also consulted other material scattered on the web but I honestly had a hard time finding anything that gave practical examples. Despite that, I must say I am quite satisfied with the results.\
You probably have already heard of OOP by aggregation (sometimes slightly different terms are used) or you may even be more familiar with it than I am. It's an extremely interesting topic and I hope to illustrate here my understanding of the subject.
 
Basically, the strongest arguments in favour of this approach are two:
1. On one side, when you use inheritance to create your classes, you're not only being extremely abstract and philosophical (is this a _tool_ or a _weapon_? Should it be _both_?) but you're creating big, bloated classes full of useless data and functions (just think about a platypus class, inheriting from mammals class, birds class etc and only needing a small part of each).\
A practical example may be: pretend you're creating a game about birds.\
You create a base class that has beak, feathers, legs, and flying capabilities. Now imagine from this class, you're creating chickens. But chickens cannot fly! Then you have a function that is useless, but it still is there, bloating your code and making it heavier. Now imagine you're creating ostrich class. They can run really fast! Shouldn't it be included in the class? And what about penguins, that cannot fly, are extremely slow to walk, can slide and swim swiftly? Now imagine you have forgotten something in the base bird class - they can lay eggs too! Well, that's _not_ going to be funny.\
Truth is, all this time wasted on flights of fancy and patching ultra complex code is in itself enough to abandon the idea of a system based on just hierarchy. No wonder it tends to be the most criticized concept by people who dislike OOP in general. Hierarchy is useful in my opinion, but I also happen to dislike the approach described above, since it is very easy at first and then becomes more and more hard to manage and optimize.
1. On the other side, making an object from just its features is as concrete, flexible and simple as it gets. It takes more forethought than inheritance, but it's totally worth it.\
For example, think of building objects (some prefer the term entities, or actors, or GOs, that's your choice) in your game in the following way.
I need to implement a hammer. Which features compose a hammer? It can be picked up, used as a blunt object, has a weight, is made of some material, it is visible. Aggregate this components, tag this union "hammer" - since this is just a word describing an object that can assume very different forms - and voilà! You just implemented a hammer.\
Need to make a game about birds? Just create all the components that may be needed to form a bird entity - swim, run, fly, eggs, beak, legs, feathers, etc - and compose all the crazy exotic winged creatures you can think of!\
This also happend to be great for interaction, since components just check for other components they can interact with.

I love how this system just pushes toward creation and imaginative composition. In itself, it already looks and feels like a game, and makes it so easy to give access to players to build their own thing.\
If you are really clever about your components, you may not have the perfect system, but you will surely have a very flexible, powerful system capable of building many diverse objects and making them interact with one another. A good hint you've done a great job is when your system is so rich and unpredictable that people do or create things with it that you would have never thought of.

### Extra Content

The project was born as a game, and even if it has evolved into a system, it still is shipped with a game, of which I already explained the importance.\
This means the project would have had little sense without at least some game graphics.\
The stuff you will found included on GitHub is not there just for test purposes nor it was copied or bought anywhere. Everything was especially developed for this final project. This material is to be considered a finished first alpha that needs to be tested, modified and polished. I also have Game design docs that still have some incogruences and need to be merged, updated and improved until they become the final, official version. Along the Krita files for the graphics, they weren't included in the repo.\
I like how the tileset came out but it will undergo some changes anyway, especially background tiles that are too little and rough (since they are the one that suffered the most when I decided to change tile resolution from 32x32 pixels to 20x20).\
Of course it would have been extremely cool to include at least a first draft of the "Modders Manual", but with the time at my disposal that was absolutely out of question.

## Acknowledgments

Cowboy Programming's article "Evolve your hierarchy" gave the original idea and theoretical basis for developing the objects as pure aggregation.\
Link to the article: https://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/

The one video I have to cite, since it gave me a huge insight on what a good _game systems_ should be capable of and how that's even possible, is Richard Bartle's GDC talk.\
Link to the video: https://www.youtube.com/watch?v=YfX8Z8W9JCE&list=PLOzz0QMrGbpYWly6j9UqPvVZabXrWqqZC&index=313

Simple class module for Lua by RXI was used to create empty entities and all of their components.\
Link to the GitHub page: https://github.com/rxi/classic

Useful micro-modules for Lua by Airstruck were used for timers and tweening.\
Link to the GitHub page: https://github.com/alexshi126/lua-knife 

Florentine24 by Haboo - a 24 colors palette I used for my pixelart graphics.\
Link to Lospec: https://lospec.com/palette-list/florentine24

Special thanks to Martina Del Giudice, my loved girlfriend, for supporting me first during CS50 and then during CS50's Intoduction to Game Development. And also for sacrificing her mental health listening to me rambling about code and the courses all the time.\
Also, I'd like to thank her for being my first tester, for trying so hard to help and for being extremely understanding in regards of all the time I sacrificed for this program.

And lastly, thanks to anybody who went through this chunky document. I really appreciate you spending some of your time to read this, and I'd be glad to hear you out if you have any questions.

Well, that's all for now! I wish you the best of luck for your own projects. I'm sure you'll deliver!\
This was CS50... again!
Cheers,\
Luca