{*******************************************************************************
  SkiaVoxelComanche (Voxel-Space Engine v0.2)
********************************************************************************
  A high-performance, CPU-based Voxel-Space rendering engine written in Delphi
  using Skia4Delphi. It simulates a Comanche-style helicopter flight experience
  over a procedurally generated voxel island at night.
  Author:  Lara Miriam Tamy Reschke
  License: MIT

  Latest Changes:
    v0.2:
      - Fixed Stars not showing

*******************************************************************************
  TECHNICAL FEATURES & IMPLEMENTATIONS:
*******************************************************************************
  [ Rendering Pipeline ]
  - True Voxel-Space Raycasting : 1D heightmap lookup for O(1) terrain sampling.
  - Unbounded Terrain           : Modulo-wrapped coordinates for infinite grid.
  - Z-Buffer (Y-Buffer)        : Painter's algorithm sorting for occlusion.
  - Volumetric Fog              : Distance-based linear interpolation (Lerp)
                                  mixing terrain colors with a black horizon fog.
  [ Performance Optimizations ]
  - Cached Skia Objects         : Reuses ISkPaint instances to prevent memory
                                  allocation overhead during frame drawing.
  - Trigonometry Caching        : Cos/Sin values for camera rays are calculated
                                  once per distance step, not per pixel.
  - Level of Detail (LOD) Steps : Raycasting distance steps dynamically increase
                                  (1 -> 2 -> 5 -> 10 -> 20) in the far distance.
  - Pixel Skipping (LOD Pixels) : Skips rendering every 2nd pixel in the far
                                  distance, drawing thicker voxels to compensate.
  - Fast Math                   : Pre-calculated inverse screen width and tile
                                  scale to replace slow division with fast
                                  multiplication inside the main loop.
  [ Procedural World Generation ]
  - Radial Island Generation    : Hypotenuse-based falloff for natural island
                                  shapes, combined with sine/cosine noise.
  - Texture Variation           : Randomized detail map for platformer-style
                                  color variations (grass, sand, rock, water).
  - Procedural 3D Structures    : Generation of massive enemy towers integrated
                                  directly into the voxel heightmap.
  [ Destructible Environment & Combat ]
  - Entity Health System        : Voxel structures (like towers) have HP.
                                  Projectiles apply damage on impact.
  - Sphere Collision            : Projectiles use 2D distance checks to ensure
                                  reliable hits even at close range or high speed.
  - Dynamic Damage States       : Structures visually deteriorate (color darkens,
                                  cracks appear) as HP decreases.
  - Structural Collapse         : Destroyed structures instantly flatten to the
                                  ground level in the heightmap.
  - Advanced Particle System    : Explosions spawn dynamic particles (fire, smoke,
                                  and massive rotating angular voxel debris)
                                  affected by gravity.
  [ Atmospheric & Environmental ]
  - 3D Spherical Star Field     : True 3D spherical projection (Azimuth/Altitude)
                                  for stars. Correctly occluded by terrain.
  - Night Sky & Lighting        : Custom dark palette for moonlight visibility
                                  and seamless blending with the black fog wall.
  [ Physics & Controls ]
  - Independent Flight Physics  : Throttle-based forward speed (+ / - keys)
                                  decoupled from precise vertical altitude
                                  control (Q / E keys).
  - Flight Inertia (Damping)    : Smooth acceleration and gliding physics using
                                  velocity interpolation.
  - Terrain Collision           : Real-time altitude clamping based on 1D
                                  heightmap sampling to prevent underground
                                  clipping.
  - Procedural Projectiles      : Independent rocket physics with side-alternating
                                  fire points, trajectory arcs, and timed
                                  explosion sequences.
*******************************************************************************}

unit SkiaVoxelComanche;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math, System.UITypes,
  System.SyncObjs, FMX.Types, FMX.Controls, FMX.Forms, FMX.Skia, System.Skia,
  Winapi.Windows;

const
  FOV = 70 * (Pi / 180);
  MOUSE_SENS = 0.0025;
  MAP_SIZE = 128;
  TILE_SCALE = 10.0;
  CAMERA_UP = 5.0;
  CAMERA_PITCH = 0.15;
  MAX_FLIGHT_HEIGHT = 120.0;
  MAX_SPEED = 30.0;
  VERT_SPEED = 3.0;
  ROT_SPEED = 1.5;
  MAX_RENDER_DIST = 1500;
  ROCKET_DAMAGE = 50;
  TOWER_HEIGHT = 100;

type
  TRocket = record
    X, Y, Z: Single;
    DirX, DirY: Single;
    Active: Boolean;
    ExplosionTimer: Single;
  end;

  TStar = record
    Azimuth, Altitude: Single;
  end;

  TParticleType = (ptFire, ptDebris);

  TParticle = record
    X, Y, Z: Single;
    VelX, VelY, VelZ: Single;
    Life: Single;
    Color: TAlphaColor;
    Size: Single;
    Rotation: Single;
    RotSpeed: Single;
    PType: TParticleType;
  end;

  TTower = record
    CenterX, CenterY: Integer;
    Health: Single;
    Destroyed: Boolean;
  end;

  TVoxelGame = class(TSkCustomControl)
  private
    FThread: TThread;
    FActive: Boolean;
    FLock: TCriticalSection;

    FPlayerX: Single;
    FPlayerY: Single;
    FPlayerAngle: Single;
    FPlayerHeight: Single;
    FThrottle: Single;
    FRocketSide: Integer;

    FCurrentVelX: Single;
    FCurrentVelY: Single;
    FCurrentVelZ: Single;

    FLastMouseX: Single;
    FMouseInit: Boolean;
    FAnimPhase: Single;

    FRockets: array[0..3] of TRocket;
    FFireCooldown: Single;
    FStars: array[0..199] of TStar;
    FTowers: array of TTower;
    FParticles: array of TParticle;

    FHeightMap: array[0..MAP_SIZE - 1, 0..MAP_SIZE - 1] of Byte;
    FColorMap: array[0..MAP_SIZE - 1, 0..MAP_SIZE - 1] of TAlphaColor;
    FDetailMap: array[0..MAP_SIZE - 1, 0..MAP_SIZE - 1] of Byte;

    FYBuffer: array of Single;
    FPaintCache: ISkPaint;

    procedure DoPhysicsUpdate(DeltaSec: Double);
    procedure SafeInvalidate;
    procedure StartThread;
    procedure StopThread;

    procedure GenerateVoxelIsland;
    procedure GenerateStars;
    function IsKeyDown(Key: Integer): Boolean;
    procedure FireRocket;
    procedure SpawnExplosion(X, Y, Z: Single; IsTower: Boolean = False);

    procedure DrawVoxelTerrain(const ACanvas: ISkCanvas; const ADest: TRectF);
    procedure DrawStars(const ACanvas: ISkCanvas; const ADest: TRectF);
    procedure DrawCockpit(const ACanvas: ISkCanvas; const ADest: TRectF);
    procedure DrawRockets(const ACanvas: ISkCanvas; const ADest: TRectF);
    procedure DrawParticles(const ACanvas: ISkCanvas; const ADest: TRectF);
    function GetHeightAt(X, Y: Single): Single;
    function GetTowerAt(MapX, MapY: Integer): Integer;
    function SafeHypot(X, Y: Single): Single;
  protected
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

function TVoxelGame.IsKeyDown(Key: Integer): Boolean;
begin
  Result := (GetAsyncKeyState(Key) and $8000) <> 0;
end;

function TVoxelGame.SafeHypot(X, Y: Single): Single;
begin
  // Prevents Range Check errors if coordinates become NaN or Infinite
  if IsNaN(X) or IsNaN(Y) or IsInfinite(X) or IsInfinite(Y) then
    Result := 1.0
  else
    Result := Hypot(X, Y);
end;
{ =============================================================================
  WORLD GENERATION
============================================================================= }
procedure TVoxelGame.GenerateVoxelIsland;
var
  X, Y: Integer;
  DistToCenter, MaxDist: Single;
  HeightVal: Single;

  procedure AddTower(TX, TY: Integer);
  var
    BX, BY, Idx: Integer;
  begin
    for BY := TY - 1 to TY + 1 do
      for BX := TX - 1 to TX + 1 do
      begin
        FHeightMap[BX, BY] := TOWER_HEIGHT;
        FColorMap[BX, BY] := $FF404048;
      end;

    Idx := Length(FTowers);
    SetLength(FTowers, Idx + 1);
    FTowers[Idx].CenterX := TX;
    FTowers[Idx].CenterY := TY;
    FTowers[Idx].Health := 100.0;
    FTowers[Idx].Destroyed := False;
  end;

begin
  MaxDist := MAP_SIZE / 2.0;
  Randomize;

  for Y := 0 to MAP_SIZE - 1 do
  begin
    for X := 0 to MAP_SIZE - 1 do
    begin
      DistToCenter := Hypot(X - MaxDist, Y - MaxDist) / MaxDist;

      HeightVal := (1.0 - DistToCenter) * 80.0;
      HeightVal := HeightVal + (Sin(X / 8.0) * Cos(Y / 8.0) * 10.0);

      if HeightVal < 0 then
        HeightVal := 0;
      FHeightMap[X, Y] := Trunc(EnsureRange(HeightVal, 0, 255));

      FDetailMap[X, Y] := Random(4);

      if FHeightMap[X, Y] <= 10 then
      begin
        FHeightMap[X, Y] := 10;
        FColorMap[X, Y] := $FF1133AA;
      end
      else if FHeightMap[X, Y] < 35 then
      begin
        if FDetailMap[X, Y] = 0 then
          FColorMap[X, Y] := $FFE0C060
        else if FDetailMap[X, Y] = 1 then
          FColorMap[X, Y] := $FFF0D080
        else
          FColorMap[X, Y] := $FFD0A040;
      end
      else if FHeightMap[X, Y] < 100 then
      begin
        if FDetailMap[X, Y] = 0 then
          FColorMap[X, Y] := $FF20A030
        else if FDetailMap[X, Y] = 1 then
          FColorMap[X, Y] := $FF30B040
        else if FDetailMap[X, Y] = 2 then
          FColorMap[X, Y] := $FF108020
        else
          FColorMap[X, Y] := $FF189030;
      end
      else
      begin
        if FDetailMap[X, Y] < 2 then
          FColorMap[X, Y] := $FF808080
        else
          FColorMap[X, Y] := $FFFFFFFF;
      end;
    end;
  end;

  AddTower(60, 40);
  AddTower(80, 80);
  AddTower(40, 70);
end;

procedure TVoxelGame.GenerateStars;
var
  I: Integer;
begin
  Randomize;
  for I := 0 to High(FStars) do
  begin
    FStars[I].Azimuth := Random * 2 * Pi;
    FStars[I].Altitude := Random * (Pi / 2);
  end;
end;

function TVoxelGame.GetHeightAt(X, Y: Single): Single;
var
  MapX, MapY: Integer;
begin
  MapX := Trunc(EnsureRange(X / TILE_SCALE, 0, MAP_SIZE - 1));
  MapY := Trunc(EnsureRange(Y / TILE_SCALE, 0, MAP_SIZE - 1));
  Result := FHeightMap[MapX, MapY];
end;

function TVoxelGame.GetTowerAt(MapX, MapY: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FTowers) do
  begin
    if not FTowers[I].Destroyed then
    begin
      if (MapX >= FTowers[I].CenterX - 1) and (MapX <= FTowers[I].CenterX + 1) and (MapY >= FTowers[I].CenterY - 1) and (MapY <= FTowers[I].CenterY + 1) then
      begin
        Result := I;
        Break;
      end;
    end;
  end;
end;
{ =============================================================================
  PARTICLE SYSTEM
============================================================================= }
procedure TVoxelGame.SpawnExplosion(X, Y, Z: Single; IsTower: Boolean = False);
var
  I, Count: Integer;
  P: TParticle;
begin
  // Spawn standard fire/smoke for all explosions
  Count := 30;
  SetLength(FParticles, Length(FParticles) + Count);

  for I := 1 to Count do
  begin
    P.X := X;
    P.Y := Y;
    P.Z := Z;

    P.VelX := (Random - 0.5) * 80.0;
    P.VelY := (Random - 0.5) * 80.0;
    P.VelZ := (Random - 0.5) * 80.0 + 40.0;

    P.Life := 1.0 + Random * 0.5;
    P.PType := ptFire;

    case Random(3) of
      0:
        P.Color := $FFFF8800;
      1:
        P.Color := $FFFFDD00;
      2:
        P.Color := $FF505050;
    end;

    P.Size := 3.0 + Random * 5.0;
    P.Rotation := 0;
    P.RotSpeed := 0;

    FParticles[High(FParticles) - I + 1] := P;
  end;

  // Spawn massive angular Voxel debris if a tower was destroyed
  if IsTower then
  begin
    Count := 15;
    SetLength(FParticles, Length(FParticles) + Count);

    for I := 1 to Count do
    begin
      P.X := X + (Random - 0.5) * 20.0;
      P.Y := Y + (Random - 0.5) * 20.0;
      P.Z := Z + Random * 40.0; // Spawn higher up

      // Strong outward and upward velocity
      P.VelX := (Random - 0.5) * 150.0;
      P.VelY := (Random - 0.5) * 150.0;
      P.VelZ := 80.0 + Random * 80.0;

      P.Life := 2.0 + Random * 1.0;
      P.PType := ptDebris;

      // Dark gray angular blocks
      P.Color := $FF303030 + (Random(4) * $080808);
      P.Size := 6.0 + Random * 10.0;

      // Add spin to the debris
      P.Rotation := Random * Pi * 2.0;
      P.RotSpeed := (Random - 0.5) * 10.0;

      FParticles[High(FParticles) - I + 1] := P;
    end;
  end;
end;
{ =============================================================================
  LOGIC & PHYSICS
============================================================================= }
procedure TVoxelGame.FireRocket;
var
  I: Integer;
  SideOffset: Single;
begin
  if FFireCooldown > 0 then
    Exit;

  for I := 0 to High(FRockets) do
  begin
    if not FRockets[I].Active then
    begin
      // Alternate firing side (left/right wing)
      if FRocketSide = -1 then
      begin
        SideOffset := -15.0;
        FRocketSide := 1;
      end
      else
      begin
        SideOffset := 15.0;
        FRocketSide := -1;
      end;

      // Calculate spawn position slightly in front and to the side
      FRockets[I].X := FPlayerX + (Cos(FPlayerAngle) * 10.0) + (Cos(FPlayerAngle + Pi / 2) * SideOffset);
      FRockets[I].Y := FPlayerY + (Sin(FPlayerAngle) * 10.0) + (Sin(FPlayerAngle + Pi / 2) * SideOffset);
      FRockets[I].Z := FPlayerHeight - 15.0;

      FRockets[I].DirX := Cos(FPlayerAngle);
      FRockets[I].DirY := Sin(FPlayerAngle);

      FRockets[I].Active := True;
      FRockets[I].ExplosionTimer := 0;
      FFireCooldown := 0.5;
      Break;
    end;
  end;
end;

procedure TVoxelGame.DoPhysicsUpdate(DeltaSec: Double);
var
  MoveFwd, MoveBwd, TurnL, TurnR, MoveUp, MoveDown, Fire: Boolean;
  IncThrottle, DecThrottle: Boolean;
  NewX, NewY, NewHeight, CurrentSpeed: Single;
  TargetVelX, TargetVelY, TargetVelZ: Single;
  I, J, HitMapX, HitMapY, RubbleX, RubbleY: Integer;
  P: TParticle;
  GroundZ, DistToTower: Single;
  HitTowerIdx: Integer;
begin
  if not FActive then
    Exit;

  FAnimPhase := FAnimPhase + DeltaSec;

  // Read Inputs
  MoveFwd := IsKeyDown(VK_UP) or IsKeyDown(Ord('W'));
  MoveBwd := IsKeyDown(VK_DOWN) or IsKeyDown(Ord('S'));
  TurnL := IsKeyDown(VK_LEFT) or IsKeyDown(Ord('A'));
  TurnR := IsKeyDown(VK_RIGHT) or IsKeyDown(Ord('D'));
  MoveUp := IsKeyDown(Ord('E'));
  MoveDown := IsKeyDown(Ord('Q'));
  Fire := IsKeyDown(Ord('R'));

  IncThrottle := IsKeyDown(VK_OEM_PLUS) or IsKeyDown(Ord('P'));
  DecThrottle := IsKeyDown(VK_OEM_MINUS) or IsKeyDown(Ord('O'));

  if IncThrottle then
    FThrottle := EnsureRange(FThrottle + 0.5 * DeltaSec, 0, 1);
  if DecThrottle then
    FThrottle := EnsureRange(FThrottle - 0.5 * DeltaSec, 0, 1);

  if TurnL then
    FPlayerAngle := FPlayerAngle - ROT_SPEED * DeltaSec;
  if TurnR then
    FPlayerAngle := FPlayerAngle + ROT_SPEED * DeltaSec;
  while FPlayerAngle < 0 do
    FPlayerAngle := FPlayerAngle + 2 * Pi;
  while FPlayerAngle >= 2 * Pi do
    FPlayerAngle := FPlayerAngle - 2 * Pi;

  CurrentSpeed := MAX_SPEED * FThrottle;
  TargetVelX := 0;
  TargetVelY := 0;
  TargetVelZ := 0;

  if MoveFwd then
  begin
    TargetVelX := Cos(FPlayerAngle) * CurrentSpeed * 10.0;
    TargetVelY := Sin(FPlayerAngle) * CurrentSpeed * 10.0;
  end;
  if MoveBwd then
  begin
    TargetVelX := -Cos(FPlayerAngle) * CurrentSpeed * 5.0;
    TargetVelY := -Sin(FPlayerAngle) * CurrentSpeed * 5.0;
  end;

  if MoveUp then
    TargetVelZ := VERT_SPEED * 10.0;
  if MoveDown then
    TargetVelZ := -VERT_SPEED * 10.0;

  // Apply Inertia (Damping)
  FCurrentVelX := FCurrentVelX + (TargetVelX - FCurrentVelX) * 1.5 * DeltaSec;
  FCurrentVelY := FCurrentVelY + (TargetVelY - FCurrentVelY) * 1.5 * DeltaSec;
  FCurrentVelZ := FCurrentVelZ + (TargetVelZ - FCurrentVelZ) * 1.5 * DeltaSec;

  NewX := FPlayerX + (FCurrentVelX * DeltaSec);
  NewY := FPlayerY + (FCurrentVelY * DeltaSec);
  NewHeight := FPlayerHeight + (FCurrentVelZ * DeltaSec);

  // Terrain Collision
  if NewHeight < GetHeightAt(NewX, NewY) + 1.0 then
  begin
    NewHeight := GetHeightAt(NewX, NewY) + 1.0;
    FCurrentVelZ := 0;
  end;
  if NewHeight > MAX_FLIGHT_HEIGHT then
  begin
    NewHeight := MAX_FLIGHT_HEIGHT;
    FCurrentVelZ := 0;
  end;

  FPlayerX := NewX;
  FPlayerY := NewY;
  FPlayerHeight := NewHeight;

  if Fire then
    FireRocket;
  if FFireCooldown > 0 then
    FFireCooldown := FFireCooldown - DeltaSec;

  // Update Rockets
  for I := 0 to High(FRockets) do
  begin
    if FRockets[I].Active then
    begin
      if FRockets[I].ExplosionTimer > 0 then
      begin
        FRockets[I].ExplosionTimer := FRockets[I].ExplosionTimer - DeltaSec;
        if FRockets[I].ExplosionTimer <= 0 then
          FRockets[I].Active := False;
      end
      else
      begin
        // Move Rocket
        FRockets[I].X := FRockets[I].X + FRockets[I].DirX * 100.0 * DeltaSec;
        FRockets[I].Y := FRockets[I].Y + FRockets[I].DirY * 100.0 * DeltaSec;
        FRockets[I].Z := FRockets[I].Z - (10.0 * DeltaSec);

        HitMapX := Trunc(EnsureRange(FRockets[I].X / TILE_SCALE, 0, MAP_SIZE - 1));
        HitMapY := Trunc(EnsureRange(FRockets[I].Y / TILE_SCALE, 0, MAP_SIZE - 1));
        GroundZ := FHeightMap[HitMapX, HitMapY];

        HitTowerIdx := -1;

        // 2D Sphere Collision check for towers
        for J := 0 to High(FTowers) do
        begin
          if not FTowers[J].Destroyed then
          begin
            DistToTower := SafeHypot(FRockets[I].X - (FTowers[J].CenterX * TILE_SCALE), FRockets[I].Y - (FTowers[J].CenterY * TILE_SCALE));

            // If within 2.5 blocks (25 units) and below tower height
            if (DistToTower < 25.0) and (FRockets[I].Z <= TOWER_HEIGHT) then
            begin
              HitTowerIdx := J;
              Break;
            end;
          end;
        end;

        // Process Collision
        if HitTowerIdx <> -1 then
        begin
          // Hit a tower!
          FRockets[I].ExplosionTimer := 0.5;
          SpawnExplosion(FRockets[I].X, FRockets[I].Y, FRockets[I].Z, False);

          FTowers[HitTowerIdx].Health := FTowers[HitTowerIdx].Health - ROCKET_DAMAGE;

          // If destroyed, flatten the tower in the heightmap and spawn massive debris
          if FTowers[HitTowerIdx].Health <= 0 then
          begin
            FTowers[HitTowerIdx].Destroyed := True;

            // Spawn Voxel Debris Explosion at the tower's center
            SpawnExplosion(FTowers[HitTowerIdx].CenterX * TILE_SCALE, FTowers[HitTowerIdx].CenterY * TILE_SCALE, TOWER_HEIGHT / 2.0, True);

            for RubbleY := FTowers[HitTowerIdx].CenterY - 1 to FTowers[HitTowerIdx].CenterY + 1 do
              for RubbleX := FTowers[HitTowerIdx].CenterX - 1 to FTowers[HitTowerIdx].CenterX + 1 do
                FHeightMap[RubbleX, RubbleY] := 15;
          end;
        end
        else if FRockets[I].Z <= GroundZ then
        begin
          // Hit the ground
          FRockets[I].ExplosionTimer := 0.5;
          SpawnExplosion(FRockets[I].X, FRockets[I].Y, FRockets[I].Z, False);
        end;
      end;
    end;
  end;

  // Update Particles
  for I := High(FParticles) downto 0 do
  begin
    P := FParticles[I];
    P.X := P.X + P.VelX * DeltaSec;
    P.Y := P.Y + P.VelY * DeltaSec;
    P.Z := P.Z + P.VelZ * DeltaSec;
    P.VelZ := P.VelZ - 80.0 * DeltaSec; // Apply Gravity

    // Add air resistance to debris
    if P.PType = ptDebris then
    begin
      P.VelX := P.VelX * 0.98;
      P.VelY := P.VelY * 0.98;
      P.Rotation := P.Rotation + P.RotSpeed * DeltaSec;
    end;

    P.Life := P.Life - DeltaSec;

    HitMapX := Trunc(EnsureRange(P.X / TILE_SCALE, 0, MAP_SIZE - 1));
    HitMapY := Trunc(EnsureRange(P.Y / TILE_SCALE, 0, MAP_SIZE - 1));
    GroundZ := FHeightMap[HitMapX, HitMapY];

    // Simple ground collision for particles
    if P.Z <= GroundZ then
    begin
      P.Z := GroundZ;
      P.VelZ := -P.VelZ * 0.3; // Bounce
      P.VelX := P.VelX * 0.5;  // Friction
      P.VelY := P.VelY * 0.5;
      if P.PType = ptDebris then
      begin
        P.RotSpeed := P.RotSpeed * 0.5; // Slow down spin
      end;
    end;

    // Remove dead particles
    if P.Life <= 0 then
    begin
      FParticles[I] := FParticles[High(FParticles)];
      SetLength(FParticles, Length(FParticles) - 1);
    end
    else
    begin
      FParticles[I] := P;
    end;
  end;
end;
{ =============================================================================
  RENDERING: STARS
============================================================================= }
procedure TVoxelGame.DrawStars(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  I: Integer;
  Paint: ISkPaint;
  StarSize: Single;
  RelAz, ProjX, ProjY: Single;
  HalfW, HorizonY: Single;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;

  HalfW := ADest.Width / 2.0;
  HorizonY := ADest.Height * (0.5 - CAMERA_PITCH);

  // Render the night sky background above the horizon.
  // This must be done before drawing the stars to provide a clean canvas,
  // and prevents the terrain renderer from overwriting the stars with a black box.
  Paint.Color := $FF020205; // Slightly bluish-black for a realistic night sky
  ACanvas.DrawRect(RectF(0, 0, ADest.Width, HorizonY), Paint);

  // Render the 3D spherical star field
  for I := 0 to High(FStars) do
  begin
    // Calculate relative azimuth to the player's view direction
    RelAz := FStars[I].Azimuth - FPlayerAngle;
    while RelAz > Pi do
      RelAz := RelAz - 2 * Pi;
    while RelAz < -Pi do
      RelAz := RelAz + 2 * Pi;

    // Check if the star is within the Field of View (FOV)
    if Abs(RelAz) < (FOV / 2) then
    begin
      // Project star coordinates to 2D screen space
      ProjX := HalfW + (RelAz / (FOV / 2)) * HalfW;
      ProjY := HorizonY - (ADest.Height * 0.5) * (FStars[I].Altitude / (Pi / 2));

      // Calculate twinkle effect using a sine wave
      StarSize := 1.5 + (Sin(FAnimPhase * 5 + I) * 0.5);

      Paint.Color := $FFFFFFFF;
      ACanvas.DrawCircle(PointF(ProjX, ProjY), StarSize, Paint);
    end;
  end;
end;

{ =============================================================================
  RENDERING: VOXEL TERRAIN
============================================================================= }
procedure TVoxelGame.DrawVoxelTerrain(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  ScreenW, ScreenH, Z, ScreenX, MapX, MapY, TowerIdx, I, J: Integer;
  HeightOnScreen, YPos: Single;
  DrawHeight, PrevHeight, CamHeight: Single;
  Color: TAlphaColor;
  HorizonY: Single;
  LeftX, LeftY, RightX, RightY: Single;
  RayDirX, RayDirY: Single;
  Shade, R, G, B, FogFactor: Single;
  FogR, FogG, FogB: Single;
  CosL, SinL, CosR, SinR, DeltaX, DeltaY: Single;
  StepZ, StepX, MaxScreenX: Integer;
  InvScreenW, InvTILE_SCALE: Single;
  DrawWidth: Single;
begin
  ScreenW := Trunc(ADest.Width);
  ScreenH := Trunc(ADest.Height);
  HorizonY := ScreenH * (0.5 - CAMERA_PITCH);

  if Length(FYBuffer) <> ScreenW then
    SetLength(FYBuffer, ScreenW);

  if FPaintCache = nil then
    FPaintCache := TSkPaint.Create(TSkPaintStyle.Fill);
  FPaintCache.AntiAlias := False;

  // Fill the area below the horizon with base fog color.
  // The sky area above the horizon is intentionally skipped here to preserve
  // the stars and night sky drawn in the previous render step.
  FPaintCache.Color := $FF050505;
  ACanvas.DrawRect(RectF(0, HorizonY, ScreenW, ScreenH), FPaintCache);

  // Initialize Z-Buffer (Y-Buffer) for occlusion culling
  for ScreenX := 0 to ScreenW - 1 do
    FYBuffer[ScreenX] := ScreenH;

  CamHeight := FPlayerHeight + CAMERA_UP;

  FogR := 0;
  FogG := 0;
  FogB := 0;
  InvScreenW := 1.0 / ScreenW;
  InvTILE_SCALE := 1.0 / TILE_SCALE;

  // Update tower colors based on health before rendering
  for I := 0 to High(FTowers) do
  begin
    if not FTowers[I].Destroyed then
    begin
      for J := FTowers[I].CenterY - 1 to FTowers[I].CenterY + 1 do
        for TowerIdx := FTowers[I].CenterX - 1 to FTowers[I].CenterX + 1 do
        begin
          if FTowers[I].Health > 50 then
            FColorMap[TowerIdx, J] := $FF404048 // Healthy
          else
            FColorMap[TowerIdx, J] := $FF202028; // Damaged
        end;
    end;
  end;

  // Main Raycasting Loop
  Z := 1;
  while Z <= MAX_RENDER_DIST do
  begin
    // Level of Detail (LOD): Increase step size in the far distance
    if Z < 200 then
      StepZ := 1
    else if Z < 400 then
      StepZ := 2
    else if Z < 800 then
      StepZ := 5
    else if Z < 1200 then
      StepZ := 10
    else
      StepZ := 20;

    // Cache Trigonometry for current ray slice
    CosL := Cos(FPlayerAngle - FOV / 2);
    SinL := Sin(FPlayerAngle - FOV / 2);
    CosR := Cos(FPlayerAngle + FOV / 2);
    SinR := Sin(FPlayerAngle + FOV / 2);

    LeftX := FPlayerX + CosL * Z;
    LeftY := FPlayerY + SinL * Z;
    RightX := FPlayerX + CosR * Z;
    RightY := FPlayerY + SinR * Z;

    PrevHeight := HorizonY;

    // LOD: Skip pixels in the far distance to save performance
    if Z > 600 then
      StepX := 2
    else
      StepX := 1;
    MaxScreenX := ScreenW - 1;
    DrawWidth := StepX;

    ScreenX := 0;
    while ScreenX <= MaxScreenX do
    begin
      DeltaX := (RightX - LeftX) * (ScreenX * InvScreenW);
      DeltaY := (RightY - LeftY) * (ScreenX * InvScreenW);
      RayDirX := LeftX + DeltaX;
      RayDirY := LeftY + DeltaY;

      // Modulo wrapping for infinite terrain
      MapX := Trunc(RayDirX * InvTILE_SCALE) mod MAP_SIZE;
      MapY := Trunc(RayDirY * InvTILE_SCALE) mod MAP_SIZE;
      if MapX < 0 then
        MapX := MapX + MAP_SIZE;
      if MapY < 0 then
        MapY := MapY + MAP_SIZE;

      DrawHeight := FHeightMap[MapX, MapY];
      HeightOnScreen := HorizonY - ((DrawHeight - CamHeight) * 800.0) / Z;

      // Painter's algorithm: Only draw if the voxel is closer to the camera
      // than what has been drawn in this column so far.
      if HeightOnScreen < FYBuffer[ScreenX] then
      begin
        YPos := HeightOnScreen;
        Color := FColorMap[MapX, MapY];

        // Draw cracks on damaged towers
        TowerIdx := GetTowerAt(MapX, MapY);
        if (TowerIdx <> -1) and (FTowers[TowerIdx].Health <= 50) and (DrawHeight > 20) then
        begin
          if (MapX + MapY) mod 2 = 0 then
            Color := $FF000000; // Black cracks
        end;

        // Calculate distance shading
        Shade := EnsureRange(1.0 - (Z / MAX_RENDER_DIST), 0.4, 1.0);
        R := (Color and $00FF0000) shr 16;
        G := (Color and $0000FF00) shr 8;
        B := Color and $000000FF;

        // Mix terrain color with volumetric fog (Linear Interpolation)
        R := (R * Shade) * (1 - FogFactor) + (FogR * FogFactor);
        G := (G * Shade) * (1 - FogFactor) + (FogG * FogFactor);
        B := (B * Shade) * (1 - FogFactor) + (FogB * FogFactor);

        FPaintCache.Color := $FF000000 or (Trunc(R) shl 16) or (Trunc(G) shl 8) or Trunc(B);

        // Draw the vertical voxel slice
        ACanvas.DrawRect(RectF(ScreenX, YPos, ScreenX + DrawWidth, FYBuffer[ScreenX]), FPaintCache);

        // Draw a small shadow line to emphasize height differences (edges)
        if (ScreenX > 0) and (Abs(HeightOnScreen - PrevHeight) > 1.0) and (FogFactor < 0.8) then
        begin
          FPaintCache.Color := $88000000;
          ACanvas.DrawRect(RectF(ScreenX, YPos, ScreenX + DrawWidth, YPos + 2.0), FPaintCache);
        end;

        // Update the Y-Buffer for occlusion
        FYBuffer[ScreenX] := YPos;
      end;

      PrevHeight := HeightOnScreen;
      Inc(ScreenX, StepX);
    end;

    Inc(Z, StepZ);
  end;
end;

{ =============================================================================
  RENDERING: ROCKETS
============================================================================= }
procedure TVoxelGame.DrawRockets(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  I: Integer;
  RocketScreenX, RocketScreenY: Single;
  DistZ, AngleToRocket: Single;
  Paint: ISkPaint;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;

  for I := 0 to High(FRockets) do
  begin
    if FRockets[I].Active then
    begin
      DistZ := SafeHypot(FRockets[I].X - FPlayerX, FRockets[I].Y - FPlayerY);

      if DistZ > 1 then
      begin
        AngleToRocket := ArcTan2(FRockets[I].Y - FPlayerY, FRockets[I].X - FPlayerX) - FPlayerAngle;
        while AngleToRocket > Pi do
          AngleToRocket := AngleToRocket - 2 * Pi;
        while AngleToRocket < -Pi do
          AngleToRocket := AngleToRocket + 2 * Pi;

        if Abs(AngleToRocket) < (FOV / 2) + 0.2 then
        begin
          RocketScreenX := ADest.CenterPoint.X + (Sin(AngleToRocket) / Sin(FOV / 2)) * (ADest.Width / 2);
          RocketScreenY := (ADest.Height * (0.5 - CAMERA_PITCH)) - ((FRockets[I].Z - (FPlayerHeight + CAMERA_UP)) * 800.0) / DistZ;

          if FRockets[I].ExplosionTimer > 0 then
          begin
            Paint.Color := $FFFF8800;
            ACanvas.DrawCircle(PointF(RocketScreenX, RocketScreenY), 20 + (0.5 - FRockets[I].ExplosionTimer) * 40, Paint);
            Paint.Color := $FFFFDD00;
            ACanvas.DrawCircle(PointF(RocketScreenX, RocketScreenY), 10, Paint);
          end
          else
          begin
            Paint.Color := $88AAAAAA;
            ACanvas.DrawCircle(PointF(RocketScreenX, RocketScreenY + 5), 3, Paint);
            ACanvas.DrawCircle(PointF(RocketScreenX, RocketScreenY + 15), 5, Paint);

            Paint.Color := $FFDDDDDD;
            ACanvas.DrawCircle(PointF(RocketScreenX, RocketScreenY), 4, Paint);
          end;
        end;
      end;
    end;
  end;
end;
{ =============================================================================
  RENDERING: PARTICLES
============================================================================= }
procedure TVoxelGame.DrawParticles(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  I: Integer;
  PScreenX, PScreenY, DistZ, AngleToP: Single;
  Paint: ISkPaint;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;

  for I := 0 to High(FParticles) do
  begin
    DistZ := SafeHypot(FParticles[I].X - FPlayerX, FParticles[I].Y - FPlayerY);

    if DistZ > 1 then
    begin
      AngleToP := ArcTan2(FParticles[I].Y - FPlayerY, FParticles[I].X - FPlayerX) - FPlayerAngle;
      while AngleToP > Pi do
        AngleToP := AngleToP - 2 * Pi;
      while AngleToP < -Pi do
        AngleToP := AngleToP + 2 * Pi;

      if Abs(AngleToP) < (FOV / 2) + 0.2 then
      begin
        PScreenX := ADest.CenterPoint.X + (Sin(AngleToP) / Sin(FOV / 2)) * (ADest.Width / 2);
        PScreenY := (ADest.Height * (0.5 - CAMERA_PITCH)) - ((FParticles[I].Z - (FPlayerHeight + CAMERA_UP)) * 800.0) / DistZ;

        Paint.Color := FParticles[I].Color;
        Paint.Alpha := Trunc(EnsureRange(FParticles[I].Life * 255, 0, 255));

        // Draw angular debris vs circular fire
        if FParticles[I].PType = ptDebris then
        begin
          ACanvas.Save;
          ACanvas.Translate(PScreenX, PScreenY);
          ACanvas.Rotate(FParticles[I].Rotation * 180 / Pi);
          ACanvas.DrawRect(RectF(-FParticles[I].Size, -FParticles[I].Size, FParticles[I].Size, FParticles[I].Size), Paint);
          ACanvas.Restore;
        end
        else
        begin
          ACanvas.DrawCircle(PointF(PScreenX, PScreenY), FParticles[I].Size, Paint);
        end;
      end;
    end;
  end;
end;
{ =============================================================================
  RENDERING: COCKPIT OVERLAY
============================================================================= }
procedure TVoxelGame.DrawCockpit(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  Paint: ISkPaint;
  CenterX, BottomY: Single;
  HeightRatio: Single;
begin
  CenterX := ADest.CenterPoint.X;
  BottomY := ADest.Bottom;

  Paint := TSkPaint.Create(TSkPaintStyle.Stroke);
  Paint.AntiAlias := True;
  Paint.StrokeCap := TSkStrokeCap.Round;
  Paint.Color := $FF2A2A2A;

  Paint.StrokeWidth := 8.0;
  ACanvas.DrawLine(PointF(0, 20), PointF(ADest.Width * 0.2, 45), Paint);
  ACanvas.DrawLine(PointF(ADest.Width * 0.2, 45), PointF(CenterX, 35), Paint);
  ACanvas.DrawLine(PointF(CenterX, 35), PointF(ADest.Width * 0.8, 45), Paint);
  ACanvas.DrawLine(PointF(ADest.Width * 0.8, 45), PointF(ADest.Width, 20), Paint);
  ACanvas.DrawLine(PointF(ADest.Width * 0.15, 40), PointF(ADest.Width * 0.85, 40), Paint);

  Paint.StrokeWidth := 24.0;
  ACanvas.DrawLine(PointF(0, BottomY - 100), PointF(ADest.Width * 0.15, BottomY - 110), Paint);
  ACanvas.DrawLine(PointF(ADest.Width * 0.15, BottomY - 110), PointF(CenterX - 120, BottomY - 60), Paint);
  ACanvas.DrawLine(PointF(CenterX - 120, BottomY - 60), PointF(CenterX + 120, BottomY - 60), Paint);
  ACanvas.DrawLine(PointF(CenterX + 120, BottomY - 60), PointF(ADest.Width * 0.85, BottomY - 110), Paint);
  ACanvas.DrawLine(PointF(ADest.Width * 0.85, BottomY - 110), PointF(ADest.Width, BottomY - 100), Paint);

  Paint.StrokeWidth := 16.0;
  ACanvas.DrawLine(PointF(ADest.Width * 0.3, BottomY - 110), PointF(ADest.Width * 0.3, BottomY - 50), Paint);
  ACanvas.DrawLine(PointF(ADest.Width * 0.7, BottomY - 110), PointF(ADest.Width * 0.7, BottomY - 50), Paint);
  ACanvas.DrawLine(PointF(CenterX - 60, BottomY - 60), PointF(CenterX - 60, BottomY), Paint);
  ACanvas.DrawLine(PointF(CenterX + 60, BottomY - 60), PointF(CenterX + 60, BottomY), Paint);

  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 1.5;
  Paint.Color := $6400FF00;
  ACanvas.DrawLine(PointF(CenterX - 20, ADest.CenterPoint.Y), PointF(CenterX + 20, ADest.CenterPoint.Y), Paint);
  ACanvas.DrawLine(PointF(CenterX, ADest.CenterPoint.Y - 20), PointF(CenterX, ADest.CenterPoint.Y + 20), Paint);

  Paint.Style := TSkPaintStyle.Fill;
  HeightRatio := EnsureRange(FPlayerHeight / MAX_FLIGHT_HEIGHT, 0, 1);

  Paint.Color := $64008800;
  ACanvas.DrawRect(RectF(20, ADest.CenterPoint.Y, 35, ADest.CenterPoint.Y + 50), Paint);
  Paint.Color := $6400FF00;
  ACanvas.DrawRect(RectF(20, ADest.CenterPoint.Y - (HeightRatio * 50), 35, ADest.CenterPoint.Y), Paint);
  Paint.AntiAlias := False;
  Paint.Color := $6400FF00;
  ACanvas.DrawRect(RectF(15, ADest.CenterPoint.Y - 2, 40, ADest.CenterPoint.Y + 2), Paint);

  Paint.Color := $64222222;
  ACanvas.DrawRect(RectF(ADest.Width - 35, ADest.CenterPoint.Y - 25, ADest.Width - 20, ADest.CenterPoint.Y + 25), Paint);
  Paint.Color := $64008800;
  ACanvas.DrawRect(RectF(ADest.Width - 35, ADest.CenterPoint.Y + (25 - FThrottle * 50), ADest.Width - 20, ADest.CenterPoint.Y + 25), Paint);
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 1.0;
  Paint.Color := $6400FF00;
  ACanvas.DrawRect(RectF(ADest.Width - 35, ADest.CenterPoint.Y - 25, ADest.Width - 20, ADest.CenterPoint.Y + 25), Paint);
end;
{ =============================================================================
  MAIN DRAW & THREADING
============================================================================= }
procedure TVoxelGame.Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
begin
  FLock.Acquire;
  try
    DrawStars(ACanvas, ADest);
    DrawVoxelTerrain(ACanvas, ADest);
    DrawRockets(ACanvas, ADest);
    DrawParticles(ACanvas, ADest);
    DrawCockpit(ACanvas, ADest);
  finally
    FLock.Release;
  end;
end;

procedure TVoxelGame.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  FMouseInit := False;
end;

procedure TVoxelGame.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if not FMouseInit then
  begin
    FLastMouseX := X;
    FMouseInit := True;
    Exit;
  end;
  FPlayerAngle := FPlayerAngle + (X - FLastMouseX) * MOUSE_SENS;
  FLastMouseX := X;
end;

procedure TVoxelGame.SafeInvalidate;
begin
  if csDestroying in ComponentState then
    Exit;
  TThread.Queue(nil,
    procedure
    begin
      if not (csDestroying in ComponentState) and Assigned(Self) then
      begin
        Redraw;
        Repaint;
      end;
    end);
end;

procedure TVoxelGame.StartThread;
begin
  if Assigned(FThread) then
    Exit;
  FThread := TThread.CreateAnonymousThread(
    procedure
    var
      LastTime, NowTime, DeltaMS: Cardinal;
    begin
      LastTime := TThread.GetTickCount;
      while not TThread.CheckTerminated do
      begin
        NowTime := TThread.GetTickCount;
        DeltaMS := NowTime - LastTime;
        if DeltaMS = 0 then
          DeltaMS := 1;
        LastTime := NowTime;

        if FActive then
        begin
          DoPhysicsUpdate(DeltaMS / 1000);
          SafeInvalidate;
        end;
        Sleep(12);
      end;
    end);
  FThread.FreeOnTerminate := True;
  FThread.Start;
end;

procedure TVoxelGame.StopThread;
begin
  FActive := False;
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    Sleep(50);
  end;
end;

constructor TVoxelGame.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited Create(AOwner);
  FLock := TCriticalSection.Create;
  Align := TAlignLayout.Client;
  HitTest := True;
  CanFocus := True;
  TabStop := True;

  FActive := True;
  FPlayerX := 700.0;
  FPlayerY := 800.0;
  FPlayerAngle := -Pi / 2;
  FMouseInit := True;
  FPlayerHeight := 60.0;
  FFireCooldown := 0;
  FThrottle := 0.0;
  FRocketSide := -1;
  FCurrentVelX := 0;
  FCurrentVelY := 0;
  FCurrentVelZ := 0;
  FAnimPhase := 0;

  for I := 0 to High(FRockets) do
    FRockets[I].Active := False;

  GenerateVoxelIsland;
  GenerateStars;
  StartThread;
end;

destructor TVoxelGame.Destroy;
begin
  StopThread;
  FreeAndNil(FLock);
  inherited;
end;

end.

