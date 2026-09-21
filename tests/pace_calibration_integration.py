"""Source linkage checks supplement the executed SQF model/lifecycle suites."""
import unittest
from pathlib import Path
from feature_preservation import tokenize
ROOT=Path(__file__).resolve().parents[1]
F=ROOT/'addons/gait/functions'
class PaceIntegration(unittest.TestCase):
    def test_load_and_frame_observation(self):
        main=(F/'fn_initSprintSystem.sqf').read_text();graph=(F/'fn_slopeLocomotion.sqf').read_text()
        self.assertLess(main.index('fn_paceCalibration.sqf'),main.index('[] call GAIT_fnc_installLocomotionController;'))
        self.assertIn('getUnitMovesInfo _unit',main)
        self.assertIn('[player, _input] call GAIT_fnc_observePaceCalibration;',graph)
        self.assertIn('[_unit, _animation, _target] call GAIT_fnc_beginPaceHandoff;',graph)
    def test_target_and_writer_connections(self):
        release=(F/'fn_releaseMomentum.sqf').read_text();writer=(F/'fn_nativeController.sqf').read_text();main=(F/'fn_initSprintSystem.sqf').read_text()
        self.assertIn('GAIT_fnc_lookupUnitPaceReference',main)
        self.assertIn('GAIT_fnc_resolveMovingPaceReference',main)
        self.assertIn('GAIT_sprintReferenceCalibrated',main)
        self.assertIn('GAIT_fnc_downhillGravityTargetKmh',main)
        self.assertIn('[_unit, _animation, _family, _direction, _speed, _applied, _ordinary] call GAIT_fnc_releasePaceMatch;',release)
        self.assertIn('[_now, _speed, _applied, _releaseTarget, _window, _curve]',release)
        self.assertIn('[_unit, _coefficient] call GAIT_fnc_samplePaceHandoff;',writer)
        self.assertIn('GAIT_fnc_clearPaceHandoff;',writer)
    def test_measurements_are_guarded_and_have_no_motion_writes(self):
        text=(F/'fn_paceCalibration.sqf').read_text()
        for guard in ['lineIntersects [_from, _ahead, _unit, objNull]','GAIT_fnc_nativeMovementEligible','isTouchingGround','GAIT_braceActive','GAIT_vegDragFactor','GAIT_fnc_lookupPaceReference','ace_common_effect_forceWalk','GAIT_nativeLastWritten']:
            self.assertIn(guard,text)
        for command in ['setAnimSpeedCoef','setVelocity','switchMove','playMoveNow','forceWalk','allowSprint']:
            self.assertNotIn(command,tokenize(text))
    def test_bridge_and_retap_are_bounded(self):
        text=(F/'fn_paceCalibration.sqf').read_text();main=(F/'fn_initSprintSystem.sqf').read_text()
        self.assertIn('diag_tickTime + 0.5, false',text)
        self.assertIn('_turbo isNotEqualTo _reversing',text)
        self.assertIn('GAIT_releaseResume',text)
        anchor=main.index('private _releaseResume =')
        handoff=main.index('if ((player getVariable ["GAIT_paceHandoff", []]) isNotEqualTo [])')
        self.assertLess(handoff,anchor)
        self.assertIn('call GAIT_fnc_applyNativeMovement;',main[handoff:anchor])
if __name__=='__main__':unittest.main()
