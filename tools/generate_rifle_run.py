"""Build the GAIT upper-body dead-sprint gestures from extracted vanilla Arma 3 BMTR v5 files.

Pass the directory of extracted native movement references, including the
lowered-rifle forward, left and right walks. Only this authoring
tool requires NumPy and lzokay.
"""
import argparse
from bisect import bisect_right
from dataclasses import dataclass
from math import sqrt
from pathlib import Path
import struct

import lzokay
import numpy as np


@dataclass
class Clip:
    bones: list
    phases: tuple
    frames: list

    def sample(self, bone, phase):
        phase %= 1
        hi = min(bisect_right(self.phases, phase), len(self.phases) - 1)
        lo = hi - 1
        mix = (phase - self.phases[lo]) / (self.phases[hi] - self.phases[lo])
        a, b = self.frames[lo][bone], self.frames[hi][bone]
        sign = 1 if sum(x*y for x, y in zip(a[:4], b[:4])) >= 0 else -1
        quat = [(1-mix)*x + mix*sign*y for x, y in zip(a[:4], b[:4])]
        scale = 16384 / sqrt(sum(x*x for x in quat))
        return tuple(round(x*scale) for x in quat) + tuple(
            (1-mix)*x + mix*y for x, y in zip(a[4:], b[4:]))


def read_block(data, pos, size, packed):
    if not packed:
        return data[pos:pos+size], pos+size
    end = pos
    while True:
        # BMTR omits the compressed size. A literal can resemble the end marker.
        end = data.index(b'\x11\0\0',end)+3
        try:
            raw = lzokay.decompress(data[pos:end],size)
        except lzokay.LzokayError:
            continue
        if len(raw) == size:
            return raw,end


def read_clip(path):
    data = path.read_bytes()
    if data[:8] != b'BMTR\x05\0\0\0':
        raise ValueError(f'{path}: expected BMTR v5')
    frames, _, bones, repeated = struct.unpack_from('<4I', data, 21)
    assert bones == repeated
    names = data[37:].split(b'\0', bones)
    pos = len(data) - len(names.pop())
    names = [name.decode('ascii') for name in names]
    _, props = struct.unpack_from('<2I', data, pos)
    pos += 8
    for _ in range(props):
        # Native walks carry timed footstep annotations before the phase table.
        pos = data.index(b'\0',pos+4)+1
        pos = data.index(b'\0',pos+4)+1
    repeated, packed = struct.unpack_from('<IB',data,pos)
    assert repeated == frames
    raw,pos = read_block(data,pos+5,4*frames,packed)
    phases = struct.unpack(f'<{frames}f',raw)
    assert phases[0] == 0 and phases[-1] == 1 and all(a < b for a,b in zip(phases, phases[1:]))
    result = []
    for _ in phases:
        count, packed = struct.unpack_from('<IB', data, pos)
        pos += 5
        assert count == bones
        raw,pos = read_block(data,pos,count*14,packed)
        result.append(list(struct.iter_unpack('<4h3e', raw)))
    assert pos == len(data)
    return Clip(names, phases, result)


def align(base, donor):
    # Some Arma jog loops span two footsteps per side; others span one.
    # Fit both hips over the entire cycle, including their phase offset.
    hips = ['leftupleg', 'rightupleg']
    samples = [(base.bones.index(h), donor.bones.index(h)) for h in hips]
    def error(cycles, offset):
        total = 0
        for frame, phase in zip(base.frames[:-1], base.phases):
            for src, dest in samples:
                a = frame[src][:4]
                b = donor.sample(dest, cycles*phase + offset)[:4]
                total += 1 - abs(sum(x*y for x,y in zip(a,b))) / 16384**2
        return total
    _, cycles, phase = min((error(c, i/96), c, i/96) for c in (1, 2) for i in range(96))
    return cycles, phase


def matrix(track):
    # BMTR stores the inverse rotation quaternion and a parent-local offset.
    x, y, z, w = np.array(track[:4]) / np.linalg.norm(track[:4])
    result = np.eye(4)
    result[:3, :3] = np.array([
        [1-2*(y*y+z*z), 2*(x*y+z*w), 2*(x*z-y*w)],
        [2*(x*y-z*w), 1-2*(x*x+z*z), 2*(y*z+x*w)],
        [2*(x*z+y*w), 2*(y*z-x*w), 1-2*(x*x+y*y)]])
    result[:3, 3] = track[4:]
    return result


def track_from_matrix(m):
    r = m[:3,:3].T
    w = np.sqrt(max(0,1+np.trace(r)))/2
    if w > .05:
        xyz = np.array([r[2,1]-r[1,2],r[0,2]-r[2,0],r[1,0]-r[0,1]])/(4*w)
    else:
        # Use the largest vector component for near-half-turn palm rotations.
        i = int(np.argmax(np.diag(r)))
        j,k = (i+1)%3,(i+2)%3
        xyz = np.zeros(3)
        xyz[i] = np.sqrt(1+r[i,i]-r[j,j]-r[k,k])/2
        xyz[j] = (r[j,i]+r[i,j])/(4*xyz[i])
        xyz[k] = (r[k,i]+r[i,k])/(4*xyz[i])
        w = (r[k,j]-r[j,k])/(4*xyz[i])
    return (*np.rint(np.r_[xyz,w]*16384).astype(int), *m[:3,3])


def unit(v):
    return v / np.linalg.norm(v)


def align_segment(start, end, goal_start, goal_end):
    a, b = unit(end-start), unit(goal_end-goal_start)
    x,y,z = np.cross(a,b)
    k = np.array([[0,-z,y],[z,0,-x],[-y,x,0]])
    m = np.eye(4)
    m[:3,:3] += k + k@k / (1 + a@b)
    m[:3,3] = goal_start - m[:3,:3]@start
    return m


def check_stock_clearance(rotation, wrist, shoulder, elbow):
    # Conservative stock centreline and clothed arm volumes, in metres.
    # These are authoring checks, not collision meshes for individual weapons.
    points = np.array([wrist + rotation @ [0, .095, rear]
                       for rear in np.linspace(-.33, -.10, 13)])
    def segment_gap(start, end, radius):
        axis = end - start
        t = np.clip((points - start) @ axis / (axis @ axis), 0, 1)
        nearest = start + t[:, None] * axis
        return np.min(np.linalg.norm(points - nearest, axis=1)) - radius
    arm = elbow - shoulder
    rear = points[:6]
    station = ((rear - shoulder) @ arm / (arm @ arm)).clip(0,1)
    nearest = shoulder + station[:,None]*arm
    separation = np.linalg.norm(nearest-rear,axis=1)
    i = separation.argmin()
    # The butt, not the receiver, must touch the inside of the upper arm.
    # Allow the stock envelope a few mm of compression against clothing.
    if (separation[i]-.083 > .025 or nearest[i,0]-rear[i,0] < .028 or
        not .33 < station[i] < .97 or segment_gap(shoulder,elbow,.083) < -.009 or
        segment_gap(elbow,wrist,.065) < -.006 or points[:,0].min() < .19):
        raise ValueError(f'Stock outside upper-arm pocket: gap={separation[i]-.083:.4f}, inside={nearest[i,0]-rear[i,0]:.4f}, station={station[i]:.3f}, upper={segment_gap(shoulder,elbow,.083):.4f}, lower={segment_gap(elbow,wrist,.065):.4f}, torso={points[:,0].min():.4f}')



# The roomy fit is also the fallback for equipment with unknown dimensions.
# Each offset is measured from the reference stock pocket in chest space.
FITS = {"standard": (0,0,0), "compact": (-.005,0,-.014), "roomy": (.016,-.005,.004)}
# Chest pitch, free-arm excursion, rifle pitch adjustment (degrees).
MOTION = {"travel": (0,1,0), "drive": (5,1,2), "descent": (-4,.83,2),
          "tired": (8,1,15), "turn": (1,.66,-1)}
# Playback rates relative to the native sprint loop. Variants share RTM files.
CADENCES = {"slow": .62, "tired": .84, "run": 1.00, "climb": 1.06, "cruise": 1.15,
            "fast": 1.27, "dash": 1.41, "descent": 1.56, "gravity": 1.72}
LOWER_STRIDES = 4
# Neck joint in the native skeleton bind space, in metres.
NECK_SOCKET = np.array([0,.555,-.0246,1])


def rifle_drop(phase):
    # The upper arm gives way slowly, then takes the load again as the stock
    # settles. Hold the landing for the remaining portion of the last stride.
    t = min(1, phase/.88)**1.18
    return t*t*(3-2*t)


def pitch_about(pivot, degrees):
    angle = np.deg2rad(degrees)
    c, s = np.cos(angle), np.sin(angle)
    transform = np.eye(4)
    transform[:3,:3] = [[1,0,0],[0,c,-s],[0,s,c]]
    transform[:3,3] = pivot - transform[:3,:3] @ pivot
    return transform


def sway_about(pivot, yaw, roll):
    y,z = np.radians([yaw,roll])
    cy,sy,cz,sz = np.cos(y),np.sin(y),np.cos(z),np.sin(z)
    transform = np.eye(4)
    transform[:3,:3] = [[cy*cz,-cy*sz,sy],[sz,cz,0],[-sy*cz,sy*sz,cy]]
    transform[:3,3] = pivot - transform[:3,:3] @ pivot
    return transform


def arm_pose(bone, side):
    sign = 1 if side == 'right' else -1
    shoulder = bone(side+'shoulder')
    arm = shoulder @ bone(side+'arm')
    roll = arm @ bone(side+'armroll')
    forearm = roll @ bone(side+'forearm')
    forearm_roll = forearm @ bone(side+'forearmroll')
    hand = forearm_roll @ bone(side+'hand')
    points = [(m @ [sign*x,y,z,1])[:3] for m,(x,y,z) in zip(
        (arm,forearm,hand),((.203,.477,-.05),(.378,.283,-.07),(.587,.066,-.074)))]
    return shoulder,arm,roll,forearm,forearm_roll,hand,*points


def carried_arm(bone, side, delta):
    shoulder,arm,roll,forearm,forearm_roll,hand,origin,elbow,wrist = arm_pose(bone,side)
    goal = (delta @ np.r_[wrist,1])[:3]
    axis = unit(goal-origin)
    a,b = np.linalg.norm(elbow-origin),np.linalg.norm(wrist-elbow)
    d = np.linalg.norm(goal-origin)
    if not abs(a-b) < d < a+b:
        raise ValueError(f'{side} hand outside reachable space')
    along = (a*a-b*b+d*d)/(2*d)
    pole = elbow-origin
    target_elbow = origin + axis*along + unit(pole-axis*(axis@pole))*np.sqrt(a*a-along*along)
    upper = align_segment(origin,elbow,origin,target_elbow)
    lower = align_segment(elbow,wrist,target_elbow,goal)
    return {side+'arm':np.linalg.solve(shoulder,upper@arm),
            side+'forearm':np.linalg.solve(upper@roll,lower@forearm),
            side+'hand':np.linalg.solve(lower@forearm_roll,delta@hand)}


def fatigue_mix(motion, phase):
    if motion not in ('fatigue_blend','fatigue_return'):
        return float(motion == 'tired')
    # The controller enters and leaves only on the plateaus. In either
    # direction the shoulders, weapon and free hand keep their stride phase.
    if phase <= .25:
        return 0.
    if phase <= .62:
        t = (phase-.25)/.37
    elif phase <= .80:
        return 1.
    else:
        t = (1.-phase)/.20
    return t*t*(3.-2.*t)


def running_arm(reference, side, upper_direction, lower_direction):
    """Place an arm in chest space without borrowing a pole from a different stride."""
    bone = lambda name: matrix(reference[name])
    shoulder, arm, roll, forearm, forearm_roll, hand, origin, elbow, wrist = arm_pose(bone, side)
    new_elbow = origin + unit(upper_direction) * np.linalg.norm(elbow - origin)
    new_wrist = new_elbow + unit(lower_direction) * np.linalg.norm(wrist - elbow)
    upper = align_segment(origin, elbow, origin, new_elbow)
    lower = align_segment(elbow, wrist, new_elbow, new_wrist)
    tracks = {name:reference[name] for name in reference if name.startswith(side+'hand')}
    tracks.update({side+'shoulder':reference[side+'shoulder'],
                   side+'arm':track_from_matrix(np.linalg.solve(shoulder, upper @ arm)),
                   side+'armroll':reference[side+'armroll'],
                   side+'forearm':track_from_matrix(np.linalg.solve(upper @ roll, lower @ forearm)),
                   side+'forearmroll':reference[side+'forearmroll'],
                   side+'hand':reference[side+'hand']})
    return tracks


def sagittal_direction(degrees, lateral):
    angle = np.deg2rad(degrees)
    return np.array([lateral, -np.cos(angle), np.sin(angle)])


# Wrist-to-middle-knuckle axis and inward palm normal from the Arma left-hand
# bind pose. The cross-knuckle direction runs from pinky to index.
LEFT_HAND_AXIS = unit(np.array([-.0691,-.0657,.0122]))
LEFT_PALM = unit(np.cross([-.0101,.0007,.0680],LEFT_HAND_AXIS))


def joint_twist(pivot, axis, radians):
    x,y,z = unit(axis)
    cross = np.array([[0,-z,y],[z,0,-x],[-y,x,0]])
    twist = np.eye(4)
    twist[:3,:3] += np.sin(radians)*cross + (1-np.cos(radians))*(cross@cross)
    twist[:3,3] = pivot - twist[:3,:3] @ pivot
    return twist


def roll_free_arm(tracks, chest, medial, pronation, wrist_flex):
    bone = lambda name: matrix(tracks[name])
    shoulder,arm,_,_,_,_,origin,elbow,_ = arm_pose(bone,'left')
    # Turn the humerus about its own shaft. Its bent elbow carries the
    # forearm inwards while the shoulder and elbow pivots stay in place.
    turn_in = joint_twist(origin,elbow-origin,-np.deg2rad(medial))
    tracks['leftarm'] = track_from_matrix(np.linalg.solve(shoulder,turn_in @ arm))
    _,_,_,forearm,roll,hand,_,elbow,wrist = arm_pose(bone,'left')
    axis = unit(wrist-elbow)
    inward = chest[:3,:3].T @ [1,0,0]
    palm = unit(inward - axis*(axis @ inward))
    bind = np.column_stack((LEFT_HAND_AXIS,LEFT_PALM,np.cross(LEFT_HAND_AXIS,LEFT_PALM)))
    palm = joint_twist(wrist,axis,-np.deg2rad(pronation))[:3,:3] @ palm
    fingers = joint_twist(wrist,palm,-np.deg2rad(wrist_flex))[:3,:3] @ axis
    rotation = np.column_stack((fingers,palm,np.cross(fingers,palm))) @ bind.T
    # Twist the forearm with the glove. Rotate about the arm axis, keeping
    # the wrist joint fixed while the palm turns towards the runner.
    old_palm = hand[:3,:3] @ LEFT_PALM
    old_palm = unit(old_palm-axis*(axis @ old_palm))
    turn = .78*np.arctan2(axis @ np.cross(old_palm,palm),old_palm @ palm)
    new_roll = joint_twist(wrist,axis,turn) @ roll
    new_hand = np.eye(4)
    new_hand[:3,:3] = rotation
    new_hand[:3,3] = wrist - rotation @ np.linalg.solve(hand,np.r_[wrist,1])[:3]
    tracks['leftforearmroll'] = track_from_matrix(np.linalg.solve(forearm,new_roll))
    tracks['lefthand'] = track_from_matrix(np.linalg.solve(new_roll,new_hand))


def forearm_frame(phase, fit):
    # Effective yaw of the equipped forearm on the in-game rig. A fixed
    # chest-local lane cuts across the vest on the rifle's rear contact.
    # Fit the low harmonics to elbow-to-glove directions over a full stride.
    step = 2*np.pi*phase
    yaw = (7 - 1.6*np.sin(step) if fit == 'pistol' else
           15 + 18*np.sin(step+.18) - 4*np.cos(2*step))
    return sway_about(np.zeros(3),yaw,0)[:3,:3]


# Approximate sagittal angles (degrees from downward) at eight equally
# spaced instants in the side-view reference. The forearm trails the elbow at
# the hip and folds during recovery. A periodic cubic keeps the seam smooth.
RUN_ARM_KEYS = np.array([
    [31,147], [29,129], [7,60], [-36,9],
    [-75,10], [-74,20], [-51,43], [-5,87]
],dtype=float)


def swing_phase(phase, fit):
    # Calibrated against the opposite boot in the equipped game stride.
    # The rifle shoulder frame delays the glove more than the pistol frame.
    return (phase + (.010 if fit == 'pistol' else .523) - .25) % 1


def runner_arm_angles(phase):
    position = phase * len(RUN_ARM_KEYS)
    index = int(np.floor(position))
    t = position - index
    prev, start, end, following = RUN_ARM_KEYS[(index + np.arange(-1,3)) % len(RUN_ARM_KEYS)]
    m0, m1 = .5*(end-prev), .5*(following-start)
    return start + t*(m0 + t*(3*(end-start)-2*m0-m1 + t*(2*(start-end)+m0+m1)))


def free_arm_tracks(rest, chest, phase, fit, fatigue, excursion):
    step = swing_phase(phase,fit)
    # A small lead at the shoulder and delayed forearm recovery preserve
    # the measured shapes while letting the joints reverse in sequence.
    shoulder_key = runner_arm_angles(step+.03)[0]
    forearm_key = runner_arm_angles(step-.025)[1]
    hand_key = runner_arm_angles(step-.065)[1]
    # Scale the measured excursion for equipment and fatigue. Keep the rear
    # elbow drive and forward fold distinct even as the stride shortens.
    travel = excursion*(1-.23*fatigue)
    upper = (-8 if fit == 'pistol' else -2) + .73*travel*(shoulder_key+10)
    lower = (74 if fit == 'pistol' else 79) - 8*fatigue + .74*travel*(forearm_key-70)
    lateral = -.29 if fit == 'roomy' else -.25
    # The glove rounds in toward the lower chest during the forward fold,
    # then clears the vest on the way back past the hip.
    fold = np.clip((forearm_key-42)/95,0,1)
    lower -= 6*(1-fold)**2
    inward = -.065 + .12*fold*fold*(3-2*fold)
    effort = excursion*(1-.2*fatigue)
    medial = effort*(1+8.5*(.5+.5*np.cos(2*np.pi*(step+.02))))
    pronation = 2 + 13*effort*(.5+.5*np.cos(2*np.pi*(step-.055)))
    wrist_flex = np.clip(.24*travel*(hand_key-forearm_key),-4,4)
    to_chest = chest[:3,:3].T
    forearm_basis = forearm_frame(phase,fit)
    tracks = running_arm(rest, 'left', to_chest @ sagittal_direction(upper,lateral),
                         to_chest @ forearm_basis.T @ sagittal_direction(lower,inward))
    wrist_frame = chest.copy()
    wrist_frame[:3,:3] = forearm_basis @ chest[:3,:3]
    roll_free_arm(tracks,wrist_frame,medial,pronation,wrist_flex)
    return tracks


def native_upper_body(bone):
    lower = bone('pelvis') @ bone('spine') @ bone('spine1') @ bone('spine2')
    chest = lower @ bone('spine3')
    skull = chest @ bone('neck') @ bone('neck1') @ bone('head')
    return lower, chest, skull


def locomotion_bone(base, phase, fit):
    # The equipped forward rifle evasion plays the opposite half of the
    # reference sprint at the same engine phase. The pistol loop is aligned.
    # Calibrated against the in-game fore/aft and vertical right-boot tracks.
    phase = (phase + (.5 if fit in FITS else 0)) % 1
    return lambda n: matrix(base.sample(base.bones.index(n),phase))


def masked_chest_parent(body, gesture, fit):
    spine2 = gesture('spine2') if fit in FITS else body('spine2')
    return body('pelvis') @ body('spine') @ body('spine1') @ spine2


def damp_rotation(current, target, weight):
    a, b = np.eye(4), np.eye(4)
    a[:3,:3], b[:3,:3] = current, target
    return matrix(blend_track(track_from_matrix(a),track_from_matrix(b),weight))[:3,:3]


def neutral_upper_body(base):
    samples = [native_upper_body(lambda n: matrix(row[base.bones.index(n)]))
               for row in base.frames[:-1]]
    # Mean native shoulder and head orientation at this weapon's sprint pace.
    # Polar decomposition gives an orthonormal mean for these small rotations.
    def rotation(i):
        u, _, vt = np.linalg.svd(np.mean([s[i][:3,:3] for s in samples],axis=0))
        return u @ vt
    pelvis = [matrix(row[base.bones.index('pelvis')]) for row in base.frames[:-1]]
    heights = [m[1,3] for m in pelvis]
    yaw = np.mean([np.arctan2(m[0,2],m[2,2]) for m in pelvis])
    return rotation(1),rotation(2),(min(heights),max(heights)),yaw


def pistol_arm_tracks(grip, rifle, phase, motion):
    # Match the ordinary underarm rifle carry at the same footfall. The pistol
    # proxy follows RightHand, and its native finger curl stays on the grip.
    stride = (phase + swing_phase(0,'pistol') - swing_phase(0,'standard')) % 1
    bone = lambda n: matrix(rifle.sample(rifle.bones.index(n),stride))
    chest = bone('spine2') @ bone('spine3')
    fatigue = fatigue_mix(motion,phase)
    pitch = (1-fatigue)*MOTION.get(motion,MOTION['travel'])[2]+fatigue*MOTION['tired'][2]
    carry = rifle_tracks(bone,chest,chest,stride,'standard',pitch)
    tracks = {n:t for n,t in grip.items() if n.startswith('righthand')}
    for name in ('rightshoulder','rightarm','rightarmroll','rightforearm','rightforearmroll','righthand'):
        tracks[name] = track_from_matrix(carry[name] if name in carry else bone(name))
    return tracks


def upper_tracks(base, frame, phase, fit, motion, inhale, neutral):
    bone = lambda name: matrix(frame[base.bones.index(name)])
    native_chest = bone('spine2') @ bone('spine3')
    tired = fatigue_mix(motion,phase)
    posture = MOTION.get(motion,MOTION['travel'])
    lean = (1-tired)*posture[0]+tired*MOTION['tired'][0]
    # Work in the sample skeleton's right/up/forward coordinates. The upper
    # chest lifts on inspiration. The legs and lower spine belong to locomotion.
    lift = (1+1.8*tired) if inhale else 0
    stride = 2*np.pi*phase
    chest_pivot = np.array([0,.438,-.033])
    neck_pivot = NECK_SOCKET[:3]
    if fit == 'launcher':
        # Let the upper chest unwind between footfalls. The neck follows the
        # shoulders slightly late and counter-rotates so the gaze stays readable.
        twist = (3.2 + .8*tired)*np.sin(stride)
        roll = (1.9 + .6*tired)*np.sin(stride-.35)
        bend = pitch_about(chest_pivot, .7*lean+6-lift+1.7*np.sin(2*stride-.4))
        bend = bend @ sway_about(chest_pivot,twist,roll)
        bend[1,3] += lift*.003
        # The launcher's native clip contains two pairs of steps.
        side_plant = .65*(-np.cos(2*stride)+.18*np.cos(stride))
        neck_roll = 2.6*np.sin(2*stride-.15)
        bend = sway_about(chest_pivot,0,6.3*side_plant) @ bend
        bend[0,3] -= .013*side_plant
        spine = bone('spine3') @ bend
        chest = bone('spine2') @ spine
        # Keep the native head orientation through the added chest swing, allowing
        # a little of the sustained forward lean through to the gaze.
        live_neck = chest @ bone('neck')
        rest_neck = native_chest @ bone('neck') @ pitch_about(neck_pivot,2.0)
        # Counter the remaining ear-to-shoulder roll around the gaze axis. The
        # neck still pitches through the stride and the player retains free look.
        rest_neck = rest_neck @ sway_about(neck_pivot,0,neck_roll)
        relative = np.eye(4)
        relative[:3,:3] = live_neck[:3,:3].T @ rest_neck[:3,:3]
        relative[:3,3] = neck_pivot-relative[:3,:3]@neck_pivot
        neck = bone('neck') @ relative
    else:
        body = locomotion_bone(base,phase,fit)
        lower = masked_chest_parent(body,bone,fit)
        _, original_chest, skull = native_upper_body(body)
        shoulder_rotation, head_rotation, height_range, rest_yaw = neutral
        # Keep a small amount of shoulder drive; broad oscillations show up
        # particularly strongly head-on with a one-handed carry.
        step = 2*np.pi*swing_phase(phase,fit)
        launch_pitch = 3 if motion == 'drive' else 0
        lean_pose = pitch_about(chest_pivot,2+.48*lean+launch_pitch-lift)
        pelvis = body('pelvis')
        hip_turn = np.degrees(np.arctan2(pelvis[0,2],pelvis[2,2])-rest_yaw)
        chest_turn = (1.5-.35*tired)*np.cos(step+.18) - .18*np.clip(hip_turn,-12,12)
        lean_pose = lean_pose @ sway_about(chest_pivot,chest_turn,0)
        # Let the equipped stride set the timing for both feet, including its
        # natural asymmetry. Add a few millimetres of give above the pelvis.
        low, high = height_range
        rebound = .006*(np.clip((pelvis[1,3]-low)/max(high-low,.001),0,1)-.5)
        chest_model = original_chest @ lean_pose
        anchor = (chest_model @ np.r_[chest_pivot,1])[:3]
        chest_model[:3,:3] = damp_rotation(original_chest[:3,:3],shoulder_rotation,.73) @ lean_pose[:3,:3]
        chest_model[:3,3] = anchor - chest_model[:3,:3] @ chest_pivot
        chest_model[1,3] += lift*.003 + rebound
        spine = np.linalg.solve(lower,chest_model)
        chest = bone('spine2') @ spine
        # Stabilize eye orientation about the native neck socket. Its position
        # follows the animated chest through contact, rebound and breathing.
        tip = body('neck1') @ body('head')
        gaze = damp_rotation(skull[:3,:3],head_rotation,.82) @ pitch_about(neck_pivot,2)[:3,:3]
        neck = np.eye(4)
        neck[:3,:3] = chest_model[:3,:3].T @ gaze @ tip[:3,:3].T
        neck[:3,3] = (body('neck') @ NECK_SOCKET)[:3] - neck[:3,:3] @ neck_pivot
    edited = {'spine3':spine,'neck':neck}
    if fit == 'launcher':
        # The tube has its own Spine1 proxy. Move both native hand contacts
        # with the same rigid transform around the right shoulder.
        shoulder = arm_pose(bone,'right')[-3]
        delta = pitch_about(shoulder,(-5+10*tired)+1.8*np.sin(2*np.pi*phase))
        delta[:3,3] += [.007,-.012,-.017]
        for side in ('right','left'):
            edited.update(carried_arm(bone,side,delta))
        edited['launcher'] = chest @ delta @ np.linalg.solve(native_chest,bone('launcher'))
    elif fit in FITS:
        pitch = (1-tired)*posture[2]+tired*MOTION['tired'][2]
        if motion == 'upright':
            pitch = -69.1
        edited.update(rifle_tracks(bone,native_chest,chest,phase,fit,pitch))
    return {name:track_from_matrix(m) for name,m in edited.items()}


def rifle_tracks(bone,native_chest,chest,phase,fit,pitch_adjustment):
    shoulder,arm,arm_roll,forearm,forearm_roll,hand,shoulder_pos,elbow_pos,wrist = arm_pose(bone,'right')
    rifle = np.linalg.solve(native_chest, bone('weapon'))
    grip = np.linalg.solve(rifle, np.r_[wrist,1])[:3]
    # Wrist placement and elbow pole fitted to the inner upper arm. The
    # upright stock sits forward of the shoulder so it can tip into the catch.
    angles = [-129.1,-61,-60,-43]
    poses = [[.01552,-.08749,.20141,-9.1,57.7121,-2.86022,-8.0],
             [.01619,-.18077,.04687,5.534,41.347,.2154,-1.2622],
             [.0161,-.1819,.0447,5.40,41.21,.236,-1.187],
             [.0255,-.1677,.0432,7.91,41.95,1.707,-3.140]]
    degrees = np.clip(-60 + pitch_adjustment,-129.1,-43)
    x,y,z,yaw,roll,px,py = [np.interp(degrees,angles,column) for column in zip(*poses)]
    pitch = np.deg2rad(degrees + 1.2*np.sin(2*np.pi*phase))
    c, s = np.cos(pitch), np.sin(pitch)
    tucked = np.eye(4)
    yaw, roll = np.deg2rad([yaw,roll])
    cy, sy = np.cos(yaw), np.sin(yaw)
    cr, sr = np.cos(roll), np.sin(roll)
    tucked[:3,:3] = (np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]]) @
                     np.array([[1,0,0],[0,c,-s],[0,s,c]]) @
                     np.array([[cr,-sr,0],[sr,cr,0],[0,0,1]]))
    stock_from_wrist = np.array([0, .085, -.215])
    stock_pocket = shoulder_pos + np.array([x,y,z]) + np.asarray(FITS[fit])*(.42 if degrees == -129.1 else 1)
    goal = stock_pocket - tucked[:3,:3] @ stock_from_wrist
    # Preserve both arm lengths, with the elbow pointing behind the chest.
    axis = unit(goal - shoulder_pos)
    pole = np.array([px,py,-1.0])
    length = np.linalg.norm(goal - shoulder_pos)
    upper = np.linalg.norm(elbow_pos-shoulder_pos)
    lower = np.linalg.norm(wrist-elbow_pos)
    along = (upper**2 - lower**2 + length**2)/(2*length)
    elbow = shoulder_pos + axis*along + unit(pole-axis*(axis@pole))*np.sqrt(upper**2-along**2)
    try:
        check_stock_clearance(tucked[:3,:3], goal, shoulder_pos, elbow)
    except ValueError as error:
        raise ValueError(f"{fit} at {degrees} degrees, phase {phase}: {error}") from error
    upper_edit = align_segment(shoulder_pos,elbow_pos,shoulder_pos,elbow)
    lower_edit = align_segment(elbow_pos,wrist,elbow,goal)
    tucked[:3,3] = goal - tucked[:3,:3]@grip
    # Preserve the actual native rifle-to-palm transform at every frame.
    new_hand = tucked @ np.linalg.solve(rifle, hand)
    # Let the forearm share the rotation required by the grip. Twist around
    # the elbow-wrist line so neither end of the forearm changes position.
    axis = unit(goal-elbow)
    residual = new_hand[:3,:3] @ (lower_edit[:3,:3] @ hand[:3,:3]).T
    skew = np.array([residual[2,1]-residual[1,2],residual[0,2]-residual[2,0],residual[1,0]-residual[0,1]])
    angle = .70*np.clip(np.arctan2(axis@skew,np.trace(residual)-axis@residual@axis),-np.pi/3,np.pi/3)
    x,y,z = axis
    cross = np.array([[0,-z,y],[z,0,-x],[-y,x,0]])
    twist = np.eye(4)
    twist[:3,:3] += np.sin(angle)*cross+(1-np.cos(angle))*(cross@cross)
    twist[:3,3] = goal-twist[:3,:3]@goal
    rolled = twist @ lower_edit @ forearm_roll
    # Bind-pose wrist to middle knuckle, measured on the Arma sample rig.
    palm = unit(new_hand[:3,:3] @ np.array([.0687,-.0655,.0133]))
    if elbow[0]-shoulder_pos[0] > .14 or palm@axis < np.cos(np.deg2rad(34)):
        raise ValueError("Rifle elbow or wrist outside the clamped carry envelope")
    return {'rightarm': np.linalg.solve(shoulder,upper_edit@arm),
        'rightforearm': np.linalg.solve(upper_edit@arm_roll,lower_edit@forearm),
        'rightforearmroll': np.linalg.solve(lower_edit@forearm,rolled),
        'righthand': np.linalg.solve(rolled,new_hand),
        'weapon': chest@tucked}


def blend_track(a, b, amount):
    if amount == 0: return a
    if amount == 1: return b
    qa,qb = np.asarray(a[:4]),np.asarray(b[:4])
    if qa @ qb < 0: qb = -qb
    quat = np.rint(unit((1-amount)*qa + amount*qb)*16384).astype(int)
    return (*quat,*((1-amount)*np.asarray(a[4:]) + amount*np.asarray(b[4:])))


def transport_arm(pose, side, elbow_hint, wrist_goal, palm_rotation):
    bone = lambda name: matrix(pose[name])
    shoulder,arm,roll,forearm,forearm_roll,hand,origin,elbow,wrist = arm_pose(bone,side)
    axis = unit(wrist_goal-origin)
    a,b = np.linalg.norm(elbow-origin),np.linalg.norm(wrist-elbow)
    d = np.clip(np.linalg.norm(wrist_goal-origin),abs(a-b)+.0001,a+b-.0001)
    along = (a*a-b*b+d*d)/(2*d)
    pole = elbow_hint-origin
    target_elbow = origin+axis*along+unit(pole-axis*(axis@pole))*np.sqrt(max(0,a*a-along*along))
    goal = origin+d*axis
    upper = align_segment(origin,elbow,origin,target_elbow)
    lower = align_segment(elbow,wrist,target_elbow,goal)
    corrected = np.eye(4)
    corrected[:3,:3] = palm_rotation
    corrected[:3,3] = goal - palm_rotation @ (np.linalg.solve(hand,np.r_[wrist,1])[:3])
    pose.update({side+'arm':track_from_matrix(np.linalg.solve(shoulder,upper@arm)),
                 side+'forearm':track_from_matrix(np.linalg.solve(upper@roll,lower@forearm)),
                 side+'hand':track_from_matrix(np.linalg.solve(lower@forearm_roll,corrected))})
    return goal


def blend_rifle_pose(start, finish, chest_a, chest_b, u, gather=False):
    if u <= 0: return start
    if u >= 1: return finish
    pose = {n:blend_track(value,finish[n],u) for n,value in start.items()}
    ch = matrix(pose['spine2']) @ matrix(pose['spine3'])
    guns = [np.linalg.solve(c,matrix(p['weapon'])) for c,p in ((chest_a,start),(chest_b,finish))]
    weapon = matrix(blend_track(*(track_from_matrix(g) for g in guns),u))
    for side in ('right','left') if gather else ('right',):
        arms = [arm_pose(lambda n:matrix(p[n]),side) for p in (start,finish)]
        h0,h1 = [arm[5] for arm in arms]
        e0,e1 = [arm[-2] for arm in arms]
        w0,w1 = [arm[-1] for arm in arms]
        if side == 'right':
            # Interpolate at the pistol grip. The RTM weapon bone rotates about
            # a distant bind origin; interpolating its translation throws it up.
            grip0,grip1 = [np.linalg.solve(g,np.r_[w,1])[:3] for g,w in zip(guns,(w0,w1))]
            grip = (1-u)*grip0+u*grip1
            wr = (1-u)*w0+u*w1
            wr += np.sin(np.pi*u)*np.array([.015,-.025,0])
            rel0,rel1 = [np.linalg.solve(g,h) for g,h in zip(guns,(h0,h1))]
            palm = weapon @ matrix(blend_track(track_from_matrix(rel0),track_from_matrix(rel1),u))
            wrist = transport_arm(pose,side,(1-u)*e0+u*e1,wr,palm[:3,:3])
            weapon[:3,3] = wrist - weapon[:3,:3] @ grip
            pose['weapon'] = track_from_matrix(ch@weapon)
        else:
            contact = weapon @ np.linalg.solve(guns[1],np.r_[w1,1])
            reach = min(1,u/.85)
            reach = reach*reach*(3-2*reach)
            wr = (1-reach)*w0+reach*contact[:3]
            target = weapon @ np.linalg.solve(guns[1],h1)
            palm = matrix(blend_track(track_from_matrix(h0),track_from_matrix(target),reach))
            transport_arm(pose,side,(1-reach)*e0+reach*e1,wr,palm[:3,:3])
    return pose


def soft_fist(donor, idle, name, phase):
    # Keep the thumb near the index finger and ease the four knuckles away
    # from the fully curled donor. The separate rifle catch opens the hand.
    amount = .10 if name.startswith('lefthandthumb') else .20
    return blend_track(donor.sample(donor.bones.index(name),phase),idle[name],amount)


def render(base, donor, cycles, offset, idle, grip, fit, motion, inhale, rifle):
    proxy = {"pistol":None, "launcher":"launcher"}.get(fit,"weapon")
    names = [n for n in base.bones if n in (proxy,'spine3','neck') or (fit in FITS and n == 'spine2') or n.startswith(
        ('leftshoulder','leftarm','leftforearm','lefthand','rightshoulder','rightarm','rightforearm','righthand'))]
    levels = range(1) if fit == 'launcher' or motion in ('upright','lower') else range(7)
    frames = {level:[] for level in levels}
    strides = LOWER_STRIDES if motion == 'lower' else 1
    keys = [(i,(stride+p)/strides) for stride in range(strides)
            for i,p in enumerate(base.phases[:-1])] + [(0,1.)]
    neutral = neutral_upper_body(base) if fit != 'launcher' else None
    for index, progress in keys:
        phase = base.phases[index]
        # Arma can briefly sample the first key when acquiring a gesture.
        # The tired landing and reverse bridge start at the same stride contact.
        if motion in ('tired','fatigue_return'):
            phase = (phase + .75) % 1
            frame = [base.sample(i,phase) for i in range(len(base.bones))]
        else:
            frame = base.frames[0 if phase == 1 else index]
        phase %= 1
        edits = upper_tracks(base,frame,phase,fit,motion,inhale,neutral)
        if motion == 'lower':
            original = dict(zip(base.bones,frame))
            source = original | upper_tracks(base,frame,phase,fit,'upright',inhale,neutral)
            target = original | edits
            spine = matrix(original['spine2'])
            edits = blend_rifle_pose(source,target,spine@matrix(source['spine3']),
                                     spine@matrix(target['spine3']),rifle_drop(progress))
        if fit != 'launcher':
            # Effective forward plant of the opposite foot, measured on the
            # equipped rifle/pistol sprint. Their native clips start on different feet.
            lead = -.14 if fit == 'pistol' else .35
            excursion = MOTION.get(motion,MOTION['travel'])[1]
            local = lambda n: matrix(frame[base.bones.index(n)])
            chest_model = masked_chest_parent(locomotion_bone(base,phase,fit),local,fit) @ matrix(edits['spine3'])
            fresh = free_arm_tracks(idle,chest_model,phase,fit,0,excursion)
            relaxed = free_arm_tracks(idle,chest_model,phase,fit,1,excursion)
            for n in fresh:
                if n.startswith('lefthand') and n != 'lefthand':
                    fresh[n] = soft_fist(donor,idle,n,cycles*phase+offset+lead)
                    relaxed[n] = fresh[n]
            if fit == 'pistol':
                edits.update(pistol_arm_tracks(grip,rifle,phase,motion))
        for level in levels:
            tracks = dict(edits)
            if fit != 'launcher':
                for n in fresh:
                    tracks[n] = blend_track(fresh[n],relaxed[n],level/6)
            frames[level].append([tracks.get(n,frame[base.bones.index(n)]) for n in names])
    phases = tuple(progress for _,progress in keys)
    return {level:Clip(names,phases,rows) for level,rows in frames.items()}


def normal_brace(idle, sprint):
    names = ['spine1','neck']
    phases = tuple(i/20 for i in range(21))
    frames = []
    for t in phases:
        # A single load-and-release pulse, with a quicker weight transfer
        # and a longer recovery into the moving pose. Neck follows the trunk.
        row = []
        for name,peak,degrees,pivot in (
                ('spine1',.34,8,[-.0025,.1558,-.0123]),
                ('neck',.42,9,[0,.5551,-.0246])):
            u = t/peak if t <= peak else (1-t)/(1-peak)
            amount = u*u*(3-2*u)
            target = sprint.sample(sprint.bones.index(name),.58*t)
            neutral = blend_track(idle[name],target,t*t*(3-2*t))
            row.append(track_from_matrix(matrix(neutral) @ pitch_about(np.array(pivot),degrees*amount)))
        frames.append(row)
    return Clip(names,phases,frames)


def encode(clip):
    count = len(clip.bones)
    size = len(clip.phases)
    data = bytearray(struct.pack('<4sIB3f4I', b'BMTR',5,1,0,0,0,size,0,count,count))
    for n in clip.bones: data.extend(n.encode('ascii') + b'\0')
    data.extend(struct.pack('<3IB',0,0,size,0))
    data.extend(struct.pack(f'<{size}f',*clip.phases))
    for row in clip.frames:
        data.extend(struct.pack('<IB',count,0))
        for track in row: data.extend(struct.pack('<4h3e',*track))
    return data


def catch_clip(source, native, start_phase, strides=1, held=False, leg_phase=0):
    steps = 32 if held else 16
    phases = tuple(i/steps for i in range(steps+1))
    rows = []
    for t in phases:
        a_phase,b_phase = ((start_phase+1.35*t/strides,leg_phase+1.35*t) if held else
                           (start_phase+.53*t/strides,.45+.50*t))
        a = {n:source.sample(i,a_phase) for i,n in enumerate(source.bones)}
        b = {n:native.sample(native.bones.index(n),b_phase) for n in source.bones}
        spine_a = matrix(a['spine2']) @ matrix(a['spine3'])
        spine_b = matrix(native.sample(native.bones.index('spine2'),b_phase)) @ matrix(b['spine3'])
        u = min(1,t/.94)
        tracks = blend_rifle_pose(a,b,spine_a,spine_b,u*u*(3-2*u),gather=True)
        rows.append([tracks[n] for n in source.bones])
    return Clip(source.bones,phases,rows)


def downhill_shuffle(forward, lateral, side, band):
    # Lowered walks contain four strides, except the right strafe which has
    # five. Average their local tracks at matching contacts for a seamless loop.
    cycles,first = (4,.076) if side == 'left' else (5,.057)
    def stride(clip, name, phase, count, first):
        samples = [clip.sample(clip.bones.index(name),first+(k+phase)/count) for k in range(count)]
        track = samples[0]
        for k,value in enumerate(samples[1:],2):
            track = blend_track(track,value,1/k)
        return track
    leg_bones = {side+part for side in ('left','right')
                 for part in ('upleg','uplegroll','leg','legroll','foot','toebase')}
    bones = ['pelvis']+[n for n in forward.bones if n in leg_bones]
    mix,second,settle = [(.43,.39,.012),(.60,.36,.018),(.77,.33,.025)][band]
    turn = sway_about(np.zeros(3),90 if side=='left' else -90,0)
    phases = tuple(i/64 for i in range(65))
    rows = []
    for p in phases:
        t = p % 1
        # Bring the second foot in early, then give the planted pair a longer
        # weight transfer. The speed curve is positive and periodic at the seam.
        q = t + (.5-second)*(1-np.cos(2*np.pi*t))/(1-np.cos(2*np.pi*second))
        row = []
        for name in bones:
            a = stride(forward,name,q,4,.083)
            b = stride(lateral,name,q,cycles,first)
            if name=='pelvis':
                # Rotate native lateral travel into the downhill path. The hips,
                # chest and lowered weapon turn together around the pelvis.
                m = turn @ matrix(b)
                b = track_from_matrix(m)
            track = blend_track(a,b,mix)
            if name=='pelvis':
                m = matrix(track)
                m[1,3] -= settle*(.5+.5*np.cos(2*np.pi*(t-second)))
                track = track_from_matrix(m)
            row.append(track)
        rows.append(row)
    return Clip(bones,phases,rows)


def check_shuffle_footfalls(clip, band):
    # Measure the exported boot positions independently of the timing curve.
    reach = []
    for row in clip.frames[:-1]:
        feet = []
        for side,x in [('left',-.1),('right',.1)]:
            m = matrix(row[clip.bones.index('pelvis')])
            for part in ('upleg','uplegroll','leg','legroll','foot'):
                m = m @ matrix(row[clip.bones.index(side+part)])
            feet.append((m @ [x,-.91,0,1])[2])
        reach.append(feet[1]-feet[0])
    width = abs(clip.phases[np.argmax(reach)]-clip.phases[np.argmin(reach)])
    if abs(min(width,1-width)-[.39,.36,.33][band]) > .025 or np.ptp(reach) < .35:
        raise ValueError('Downhill boots do not alternate through the expected quick step and longer transfer')


def check_free_hand(clips, donor, cycles, offset, fit, base, idle):
    # Check the free-hand curl, roll at both joints, and clearance through the stride.
    fresh = clips[0]
    hand_paths = {level:[] for level in clips}
    _,rest_arm,_,_,_,_,rest_origin,rest_elbow,_ = arm_pose(lambda n: matrix(idle[n]),'left')
    for index, phase in enumerate(fresh.phases):
        for track, name in enumerate(fresh.bones):
            if not name.startswith('lefthand') or name == 'lefthand':
                continue
            lead = -.14 if fit == 'pistol' else .35
            expected = soft_fist(donor,idle,name,cycles*(phase%1)+offset+lead)
            for clip in clips.values():
                q = unit(np.array(clip.frames[index][track][:4],dtype=float))
                if abs(q @ unit(np.array(expected[:4],dtype=float))) < .99999:
                    raise ValueError(f'{name} loses its relaxed curl during the sprint')
        body = locomotion_bone(base,phase,fit)
        lower = masked_chest_parent(body,lambda n: matrix(base.sample(base.bones.index(n),phase)),fit)
        for level,clip in clips.items():
            bone = lambda name: matrix(clip.frames[index][clip.bones.index(name)])
            chest = lower @ bone('spine3')
            _,arm,_,_,_,hand,origin,bend,tip = arm_pose(bone,'left')
            # Remove the shortest swing to this elbow. The residual is axial
            # rotation of the humerus, independent of the hand's position.
            aligned = align_segment(rest_origin,rest_elbow,origin,bend) @ rest_arm
            delta = arm[:3,:3] @ aligned[:3,:3].T
            skew = np.array([delta[2,1]-delta[1,2],delta[0,2]-delta[2,0],delta[1,0]-delta[0,1]])
            medial = -np.degrees(np.arctan2(unit(bend-origin) @ skew,np.trace(delta)-1))
            shoulder,elbow,wrist = [(chest @ np.r_[p,1])[:3] for p in (origin,bend,tip)]
            forearm_basis = forearm_frame(phase,fit)
            wrist = elbow + forearm_basis @ (wrist-elbow)
            palm = forearm_basis @ (chest @ hand)[:3,:3] @ LEFT_PALM
            if palm[0] < .91 or wrist[0] >= 0:
                raise ValueError(f'Free palm turns away from torso at {phase}')
            axis = unit(wrist-elbow)
            inward = unit(np.array([1,0,0])-axis*axis[0])
            roll = np.degrees(np.arctan2(axis @ np.cross(palm,inward),palm @ inward))
            hand_paths[level].append((wrist,wrist-shoulder,roll,medial))
            if not -.13 < elbow[0]-shoulder[0] < -.035 or not -.15 < wrist[0]-shoulder[0] < .012:
                raise ValueError(f'Free arm leaves its swing plane at {phase}')

    for path in hand_paths.values():
        world, relative, rolls, medials = map(np.asarray,zip(*path))
        phase = np.array([swing_phase(p,fit) for p in fresh.phases])
        front = relative[(phase < .08) | (phase > .94)].mean(axis=0)
        rear = relative[(phase > .46) & (phase < .60)].mean(axis=0)
        forward_roll = rolls[(phase < .12) | (phase > .98)].mean()
        rear_roll = rolls[(phase > .44) & (phase < .64)].mean()
        if not 7 < forward_roll-rear_roll < 17:
            raise ValueError('Free forearm must pronate on the forward swing')
        if not 5 < medials[(phase < .08) | (phase > .94)].mean()-medials[(phase > .46) & (phase < .60)].mean() < 11:
            raise ValueError('The forward swing must include a small medial shoulder rotation')
        inward, lift, _ = front-rear
        if not .03 < inward < .10 or lift < .20:
            raise ValueError('The forward fist must rise and round gently inward')
        width, _, reach = np.ptp(world,axis=0)
        if width > .12 or reach < .19 or width > reach*.37:
            raise ValueError('Dead-sprint hand path must principally follow the direction of travel')


def check_rifle_grip(clip, side='right', last_frames=None):
    # Evaluate the exported upper body alone, as the engine does under the
    # rifle mask. Missing Spine2 allows the legs to rotate the hand off its grip.
    points = []
    frames = clip.frames[-last_frames:] if last_frames else clip.frames
    for frame in frames:
        bone = lambda name: matrix(frame[clip.bones.index(name)])
        wrist = arm_pose(bone,side)[-1]
        chest = bone('spine2') @ bone('spine3')
        points.append(np.linalg.solve(bone('weapon'),chest @ np.r_[wrist,1])[:3])
    if np.linalg.norm(np.ptp(points,axis=0)) > .003:
        raise ValueError(f'{side} wrist moves more than 3 mm relative to its rifle contact')


def check_sprint_gaze(clip, native, fit, motion):
    _, neutral, _, _ = neutral_upper_body(native)
    forward = (neutral @ pitch_about(np.zeros(3),2)[:3,:3])[:,2]
    for phase,row in zip(clip.phases[:-1],clip.frames[:-1]):
        stride = (phase*(LOWER_STRIDES if motion == 'lower' else 1) +
                  (.75 if motion in ('tired','fatigue_return') else 0)) % 1
        body = locomotion_bone(native,stride,fit)
        def bone(name):
            if name in clip.bones:
                return matrix(row[clip.bones.index(name)])
            return body(name)
        skull = native_upper_body(bone)[2]
        if np.linalg.norm((bone('neck') - body('neck')) @ NECK_SOCKET) > .001:
            raise ValueError(f'{fit}/{motion} neck slides relative to chest at {phase:.3f}')
        if fit == 'launcher':
            continue
        if np.degrees(np.arccos(np.clip(skull[:3,2] @ forward,-1,1))) > 1.5:
            raise ValueError('Excessive variation in dead-sprint gaze')


def check_rifle_drop(clip, base):
    # Compare the weapon at the same foot contact each stride. This removes
    # the ordinary running bob from the measurement of how the rifle falls.
    stride = len(base.phases)-1
    assert len(clip.frames) == LOWER_STRIDES*stride+1
    weapon = clip.bones.index('weapon')
    rotations = [unit(np.array(row[weapon][:4],dtype=float)) for row in clip.frames[::stride]]
    angles = np.degrees(2*np.arccos(np.clip(np.abs(np.array(rotations) @ rotations[0]),0,1)))
    if angles[-1] < 45 or not np.all(np.diff(angles) > 0):
        raise ValueError(f'Rifle must lower progressively through the run: {angles}')
    if max(np.diff(angles)) > .55*angles[-1] or angles[1] > .25*angles[-1]:
        raise ValueError(f'Rifle drops too abruptly in one stride: {angles}')


def check_pistol_carry(pistol, rifle):
    offset = swing_phase(0,'pistol') - swing_phase(0,'standard')
    for phase,row in zip(pistol.phases,pistol.frames):
        actual = arm_pose(lambda n: matrix(row[pistol.bones.index(n)]),'right')
        target = arm_pose(lambda n: matrix(rifle.sample(rifle.bones.index(n),phase+offset)),'right')
        if max(np.linalg.norm(actual[i]-target[i]) for i in (-1,-2)) > .002:
            raise ValueError("Pistol elbow or wrist leaves the rifle carry by more than 2 mm")
        if np.trace(actual[5][:3,:3].T @ target[5][:3,:3]) < 1+2*np.cos(np.deg2rad(1)):
            raise ValueError("Pistol palm roll differs from the rifle carry")


def check_pistol_grip(clip, reference):
    fingers = [(i, reference[name]) for i,name in enumerate(clip.bones)
               if name.startswith('righthand') and name != 'righthand']
    for frame in clip.frames:
        if any(frame[i] != expected for i,expected in fingers):
            raise ValueError("Pistol finger pose differs from the native closed grip")
        bone = lambda name: matrix(frame[clip.bones.index(name)])
        *_, hand, shoulder, elbow, wrist = arm_pose(bone,'right')
        palm = unit(hand[:3,:3] @ [.0687,-.0655,.0133])
        if palm @ unit(wrist-elbow) < np.cos(np.deg2rad(34)) or elbow[0]-shoulder[0] > .14:
            raise ValueError("Pistol wrist or elbow leaves the underarm rifle carry")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('--check', action='store_true', help='verify the checked-in RTMs without writing them')
    args = parser.parse_args()
    out = Path(__file__).resolve().parents[1] / 'addons/gait/data'
    forward = read_clip(args.reference/'amovpercmwlkslowwrfldf.rtm')
    for side,suffix in [('left','l'),('right','r')]:
        lateral = read_clip(args.reference/f'amovpercmwlkslowwrfld{suffix}.rtm')
        for band,grade in enumerate(['','_medium','_steep']):
            shuffle = downhill_shuffle(forward,lateral,side,band)
            path = out/f'downhill_shuffle_{side}{grade}.rtm'
            if args.check:
                assert shuffle.frames[0] == shuffle.frames[-1] and len(shuffle.bones) == 13
                if path.read_bytes()!=encode(shuffle): raise SystemExit(f'{path.name} differs from bake')
                check_shuffle_footfalls(read_clip(path),band)
            else: path.write_bytes(encode(shuffle))
    donor = read_clip(args.reference / 'amovpercmsprsnonwnondf.rtm')
    rest = read_clip(args.reference / 'amovpercmstpsnonwnondnon.rtm')
    idle = dict(zip(rest.bones,rest.frames[0]))
    brace_path = out/'normal_brace.rtm'
    brace = encode(normal_brace(idle,donor))
    if args.check:
        if brace_path.read_bytes() != brace: raise SystemExit('Normal brace differs from bake')
    else:
        brace_path.write_bytes(brace)
    pistol_idle = read_clip(args.reference / 'amovpercmstpslowwpstdnon.rtm')
    grip = dict(zip(pistol_idle.bones,pistol_idle.frames[0]))
    states = ["// Generated by tools/generate_rifle_run.py"]
    families = [('rifle','wrfl',FITS,1.60971),('pistol','wpst',['pistol'],1.66667),
                ('launcher','wlnr',['launcher'],.707401)]
    rifle = read_clip(args.reference / 'amovpercmsprslowwrfldf.rtm')
    loops = 0
    for family, suffix, fits, rate in families:
        base = read_clip(args.reference / f'amovpercmsprslow{suffix}df.rtm')
        cycles, offset = align(base, donor)
        for fit in fits:
            motions = [*MOTION,'fatigue_blend','fatigue_return']
            if family == 'rifle': motions.extend(['upright','lower'])
            for motion in motions:
                for inhale in (False,True):
                    clips = render(base,donor,cycles,offset,idle,grip,fit,motion,inhale,rifle)
                    if args.check and fit != 'launcher' and motion == 'travel' and not inhale:
                        check_free_hand(clips,donor,cycles,offset,fit,base,idle)
                    for level,clip in clips.items():
                        pose = motion + ('_inhale' if inhale else '') + (f'_h{level}' if level else '')
                        stem = f'rifle_run_{fit}' if family == 'rifle' else f'{fit}_run'
                        name = f'{stem}_{pose}.rtm'
                        data = encode(clip)
                        path = out/name
                        if args.check:
                            if path.read_bytes()!=data: raise SystemExit(f'{name} differs from bake')
                        else: path.write_bytes(data)
                        assert np.allclose(read_clip(path).phases,clip.phases)
                        if motion != 'lower':
                            assert clip.frames[0] == clip.frames[-1]
                        elif args.check:
                            check_rifle_drop(clip,base)
                        if family=='pistol':
                            check_pistol_grip(clip,grip)
                            if args.check and level == 0 and motion in ('travel','tired'):
                                check_pistol_carry(read_clip(path),read_clip(out/f'rifle_run_standard_{pose}.rtm'))
                        if args.check and family == 'rifle' and level == 0:
                            exported = read_clip(path)
                            check_rifle_grip(exported)
                        if args.check and level == 0:
                            check_sprint_gaze(read_clip(path),base,fit,motion)
                        loops += 1
                        parent = {'rifle':'GAIT_RifleRunSprint','pistol':'GAIT_PistolRunSprint',
                                  'launcher':'GAIT_LauncherRunSprint'}[family]
                        for band,ratio in CADENCES.items():
                            state = f'GAIT_RifleRun_{fit}_{pose}_{band}'
                            playback = rate*ratio
                            if motion == 'lower':
                                parent = 'GAIT_RifleLower'
                                playback /= LOWER_STRIDES
                            states.append(f'class {state}: {parent} {{ file = "\\gait\\data\\{name}"; speed = {playback:.6f}; }};')
                        if (family == 'rifle' and not inhale and
                            (motion,level) in [('upright',0),('lower',0),('travel',3),('tired',6)]):
                            jog = read_clip(args.reference/'amovpercmrunslowwrfldf.rtm')
                            catch = (catch_clip(clip,jog,.49,LOWER_STRIDES) if motion == 'lower'
                                     else catch_clip(clip,jog,0))
                            if args.check and any(track != jog.sample(jog.bones.index(n),.95)
                                                  for n,track in zip(catch.bones,catch.frames[-1])):
                                raise ValueError(f'{fit} {motion} catch does not finish on the native jog')
                            name = f'{stem}_catch_{motion}.rtm'
                            path = out/name
                            if args.check:
                                if path.read_bytes()!=encode(catch): raise SystemExit(f'{name} differs from bake')
                            else: path.write_bytes(encode(catch))
                            states.append(f'class GAIT_RifleRun_{fit}_catch_{motion}: GAIT_RifleCatch {{ file = "\\gait\\data\\{name}"; }};')
                            for quarter in range(4):
                                leg = quarter/4
                                start = (.5+leg/LOWER_STRIDES if motion == 'lower' else
                                         (leg-.75)%1 if motion == 'tired' else leg)
                                gather = catch_clip(clip,base,start,LOWER_STRIDES if motion == 'lower' else 1,True,leg)
                                name = f'{stem}_gather_{motion}_{quarter}.rtm'
                                path = out/name
                                if args.check:
                                    assert path.read_bytes()==encode(gather)
                                    assert gather.frames[-1]==[base.sample(base.bones.index(n),leg+1.35) for n in gather.bones]
                                    exported = read_clip(path)
                                    check_rifle_grip(exported)
                                    check_rifle_grip(exported,'left',4)
                                else: path.write_bytes(encode(gather))
                                states.append(f'class GAIT_RifleRun_{fit}_gather_{motion}_{quarter}: GAIT_RifleGather {{ file = "\\gait\\data\\{name}"; }};')
    config = out.parent / 'rifle_run_states.hpp'
    body = '\n'.join(states)+'\n'
    if args.check:
        if config.read_text() != body:
            raise SystemExit('Rifle run state definitions differ from bake')
    else:
        config.write_text(body)
    print(f'{loops} carry and transition clips, {len(states)-1} playback states')
