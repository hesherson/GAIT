# GAIT 1.8.0-alpha30 settings

Open **Options → Addon Options → GAIT** in Arma or Eden.

| Setting | Default | Range |
| --- | --- | --- |
| Enable GAIT movement | On | On / off |
| Sprint release taper | 2.7 seconds on level ground | 2.3–2.9 seconds |
| Downhill trip frequency | 1× | 0–1.5× |
| Maximum brush slowdown | 18% | 0–25% |
| ACE heartbeat volume | 10% of original ACE volume | 0–100% |
| Movement debug HUD | Off | On / off |

Movement controls can be set by the mission or server. Heartbeat volume and the debug HUD are local preferences. Set trip frequency or brush slowdown to zero to turn off that effect. Terrain still adjusts the sprint release taper after you choose its base duration.

Alpha30 uses the previous Balanced defaults for internal movement, terrain, load and fatigue tuning. Old preset selections and retired setting values are ignored. Set **Enable GAIT movement** to off for the behavior previously provided by the Disabled compatibility mode. ACE continues to supply its fatigue feedback and exposes its own fatigue settings.
