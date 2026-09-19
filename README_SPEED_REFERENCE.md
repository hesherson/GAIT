# GAIT 1.8.0-alpha10 sprint speed reference

Balanced defaults, fresh reserve, weapon out, fully developed sprint/downhill momentum, no vegetation/injury penalty. Speed scales continuously within each gear tier.

| Gear tier | GAIT load | Flat sprint multiplier | Peak downhill multiplier |
| --- | --- | --- | --- |
| Light | 0–35 lb | 1.3824–1.3440 | 1.6312–1.5089 |
| Medium | >35–55 lb | <1.3440–1.3120 | <1.5089–1.4482 |
| Moderate | >55–75 lb | <1.3120–1.2800 | <1.4482–1.4083 |
| Heavy | >75 lb | Below 1.2800 | Below 1.4083 |
| Heavy example | 100 lb | 1.1743 | 1.2899 |
| Heavy example | 125 lb | 1.0847 | 1.1896 |

These are animation speed coefficients relative to the active sprint clip at 1.0. They are not km/h. The theoretical upper targets assume full reserve and full momentum simultaneously; fatigue and ramping can keep actual output below them. Heavier loads above 75 lb keep reducing speed instead of reaching a fixed heavy-tier value.

Peak downhill gain occurs at 18–35 degrees of descent with default settings, then tapers. GAIT's displayed pounds use its configurable load conversion rather than literal engine SI mass.

For default fresh armed sprint:

```
flat coefficient = 1.28 * loadMultiplier
peak downhill coefficient = flat * (1 + 0.18 / (1 + bonusLoad / 75))
bonusLoad = loadLb when loadLb <= 55
otherwise: extra = loadLb - 55
           bonusLoad = 55 + 0.10 * extra + 2.70 * (1 - exp(-extra / 3))
above 75 lb: loadMultiplier = 1 / (1 + 0.18 * (loadLb - 75) / 50)
```

Alpha9 softens only the downhill bonus penalty above 55 lb. At 100 lb this adds about 2% to the peak downhill target; at 150 lb it adds about 3.3%. The bonus still decreases with load, and extreme slopes still taper it.

The continuous load multiplier interpolates 1.08 at zero load, 1.05 at 35 lb, 1.025 at 55 lb and 1.0 at 75 lb. These values and thresholds come from the original defaults.

There is currently no fixed physical top-speed cap. Native animation root motion, weapon family, terrain, fatigue and other active constraints affect actual speed. No measured clip-speed profiles are bundled, so assigning exact km/h values would be unsupported. The in-game GAIT HUD and acceptance recorder show observed km/h/horizontal m/s for calibration.

Unarmed sprint uses a separate normalizer and the existing walk-relative floor, so it cannot be calculated by simply multiplying this table by 0.725. Other presets and server-forced Addon Options change these figures. Alpha10 preserves the original brace tuning and alpha9's pace targets and sprint access for every gear tier. Its short W-held release samples actual velocity and the applied coefficient together, finishes a finite deceleration in the current running clip, then requests the ordinary jog/walk blend. That local sample does not calibrate physical speed across different animation clips.
