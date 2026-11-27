# Skills: SU-34, FPV, AC-130 (owner; the friend does sounds)

Called from the SKILLS panel (points + cooldown, see economy.md). Numbers live in `ReplicatedStorage.WarConfig`
(`Bomber`, `FPV`, `AC130`). Aim rings are white; attack areas keep their colour. Esc or X cancels aiming.

## SU-34 bomber — `BomberInput` (client), `BomberCombat` (server), `WarShared.BomberPath`
- Aim: 1st click = target (white circle Ø40), move the mouse to turn the run, 2nd click = launch.
- Strike area 40 × 80 (outline only), stays on the ground until the last bomb lands.
- 5 bombs spread inside the area; damage 75 at the centre falling to 0 at radius 25 (server, `Damage.radial`).
- Speed 225 studs/s from 3500 studs out → bombs land ≈16 s after calling. Altitude 125 (min 14 above ground).
- Cost 2 points, cooldown 60 s from the call.

## FPV drone — `FPVInput` (client), `FPVCombat` (server)
- Aim like the SU-34: 1st click = start (white circle Ø40), mouse turns the 40 × 200 corridor, 2nd click = launch.
- Flies 12 studs above the ground at 50 studs/s (dive 70). Dives into the first enemy in the corridor, or into the
  ground at the end. Blast radius 10: damage 50 at the centre → 25 at the edge.
- Crashes into anything solid taller than 12 studs (walls, buildings); flies over lower ones.
- Cost 1 point, cooldown 30 s from the call.

## AC-130 — `AC130Input`, `AC130Combat`, `AC130Audio`, `WarShared.AC130Path`, `WarServer.AC130Targeting`
- Click the ground: the gunship flies in and orbits (radius 200) with the target on its LEFT (guns side), banking left.
- While active only the red attack circle (Ø200) shows, plus small rings where the guns aim.
- Attacks 40 s (leaves after 10 s with no enemies, or on RECALL). Guns: heavy (r25, 30 dmg / 1.5 s), secondary
  (r15, 15 dmg / 3 s), 2 machine guns (2 dmg / 0.2 s).
- Cost 3 points, cooldown 120 s after it has left.

All three can be shot down by enemies — see aircraft.md.
