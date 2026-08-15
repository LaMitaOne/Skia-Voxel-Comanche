
SkiaVoxelComanche    
A high-performance, CPU-based Voxel-Space rendering engine written in Delphi using Skia4Delphi. It simulates a Comanche-style helicopter flight experience over a procedurally generated voxel island at night.

**Skia Voxel Comanche v 0.1**   
       
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/Skia-Voxel-Comanche)    
     
<img width="360" height="202" alt="Unbenannt" src="https://github.com/user-attachments/assets/f14b4016-c651-4f3b-8bbe-7d096ca58112" />
<img width="360" height="202" alt="aywnmz" src="https://github.com/user-attachments/assets/afedf3d8-0af1-484a-a702-c8af67fbc2db" />   

Sample video: https://youtu.be/k75dcsOM_6A     
     
"Despite being just ~1200 lines of code, this is a complete all-in-one voxel sandbox. Unlike most traditional voxel-space demos that only render static heightmaps, this project combines dynamic heightmap destruction, a 3D-projected particle system, and flight physics into a single monolithic engine."
     
✨ Features

Rendering & Performance

     True Voxel-Space Raycasting: 1D heightmap lookups with a Y-Buffer for occlusion.
     Unbounded Terrain: Modulo-wrapped coordinates for an infinite flight grid.
     Heavy Optimizations: Trigonometry caching, dynamic Level of Detail (LOD) steps, pixel skipping in the far distance, and fast-math (multiplication instead of division).
     Volumetric Fog: Distance-based color blending into a black night horizon.

World & Environment

     Procedural Generation: Radial falloff island generation combined with noise and texture variations (water, sand, grass, rock).       
     Night Atmosphere: Custom dark palette designed for moonlight and fog blending.

Combat & Physics

     Destructible Voxel Towers: Enemy towers have HP, visually deteriorate (cracks/darkening) when damaged, and instantly collapse into rubble when destroyed. (the rockets are very cheap trash, so they not hit so often :P)
     Particle System: Gravity-affected explosions spawning fire, smoke, and debris.
     Helicopter Physics: Throttle-based forward speed (with inertia/damping) decoupled from independent vertical altitude control.
     Procedural Projectiles: Side-alternating rocket fire with trajectory arcs and timed explosions.

🎮 Controls

     Action   Key
     Turn	Mouse or A / D
     Throttle Up/Down	+ / - (or P / O)
     Forward / Backward	W / S (uses current throttle)
     Altitude Up / Down	E / Q
     Fire Rockets	R
   
🚀 How to Run

    Download the repository.
    Extract and run the included .exe file. (No installation required)
    Alternatively, open the .pas file in Delphi and compile it yourself using the Skia4Delphi framework.
    
More game repos:    
      
🎮 Skia4Delphi Games (each one file, no ext engine):    
   2D Platformer https://github.com/LaMitaOne/Skia_PlatformerGame    
   2D Lemmings/Worms/Portal/Touch hybrid https://github.com/LaMitaOne/SkiaLemmings       
   2D Side-scrolling space shooter https://github.com/LaMitaOne/SkiaStarPatrols    
   2.5D C&C style isometric rts https://github.com/LaMitaOne/Skia-RTS-Game   
   2.5D Isometric cat game https://github.com/LaMitaOne/Skia-A-Cats-Life    
   2.5D Raycasting doom base https://github.com/LaMitaOne/SkiaDoomBase     
   Tetris clone https://github.com/LaMitaOne/Skiatris    
     
🎮 Game components FMX:    
   MRX Gamepad Core https://github.com/LaMitaOne/MRX-Gamepad-Core   
