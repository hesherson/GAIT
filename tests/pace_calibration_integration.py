"""Source linkage checks for passive pace calibration and its consumers."""

from pathlib import Path
import unittest

from feature_preservation import tokenize


FUNCTIONS = Path(__file__).resolve().parents[1] / 'addons/gait/functions'


class PaceIntegration(unittest.TestCase):
    def test_load_and_frame_observation(self):
        main = (FUNCTIONS / 'fn_initSprintSystem.sqf').read_text()
        graph = (FUNCTIONS / 'fn_slopeLocomotion.sqf').read_text()
        self.assertLess(main.index('fn_paceCalibration.sqf'),
                        main.index('[] call GAIT_fnc_installLocomotionController;'))
        self.assertIn('getUnitMovesInfo _unit', main)
        self.assertIn('[player, _input] call GAIT_fnc_observePaceCalibration;', graph)

    def test_measured_references_support_live_pace_targets(self):
        main = (FUNCTIONS / 'fn_initSprintSystem.sqf').read_text()
        for connection in ('GAIT_fnc_lookupUnitPaceReference',
                           'call GAIT_fnc_locomotionPaceReferences',
                           'call GAIT_fnc_uphillSprintFloor',
                           'call GAIT_fnc_combatRelativeSprintFloor',
                           'call GAIT_fnc_combatPaceReference',
                           'call GAIT_fnc_sprintReservePace',
                           'GAIT_sprintReferenceCalibrated'):
            self.assertIn(connection, main)
        self.assertEqual(main.count('call GAIT_fnc_capDownhillPace'), 2)

    def test_measurements_are_guarded_and_have_no_motion_writes(self):
        source = (FUNCTIONS / 'fn_paceCalibration.sqf').read_text()
        for guard in ('lineIntersects [_from, _ahead, _unit, objNull]',
                      'GAIT_fnc_nativeMovementEligible', 'isTouchingGround',
                      '(_info param [3, 0]) >= 0.99', 'GAIT_braceActive',
                      'GAIT_vegDragFactor', 'GAIT_fnc_lookupPaceReference'):
            self.assertIn(guard, source)
        tokens = tokenize(source)
        for command in ('setAnimSpeedCoef', 'setVelocity', 'switchMove',
                        'playMoveNow', 'forceWalk', 'allowSprint'):
            self.assertNotIn(command, tokens)


if __name__ == '__main__':
    unittest.main()
