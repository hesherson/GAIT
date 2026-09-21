"""Check every exposed setting, preset value, retired control and UI range."""
import json,re,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FUNCTIONS=ROOT/'addons/gait/functions'
NUMBER=r'-?\d+(?:\.\d+)?'
def read_settings():
    s=(FUNCTIONS/'fn_registerSettings.sqf').read_text()
    rows=[]
    for m in re.finditer(r'\[\s*"(GAIT_ss_[^"]+)"(.*?)\]\s*call _add(Checkbox|Slider|List);',s,re.S):
        name,body,kind=m.groups()
        strings=re.findall(r'"([^"]*)"',body)
        category=re.search(r'_category(\w+)',body)[1]
        row=dict(name=name,title=strings[0],description=strings[1],kind=kind,category=category)
        tail=body[re.search(r'_category\w+',body).end():]
        if kind=='Slider':
            values=[float(x) for x in re.findall(NUMBER,tail)]
            row.update(min=values[0],max=values[1],default=values[2],decimals=int(values[3]))
        elif kind=='Checkbox':row['default']='true' in tail
        else:
            arrays=re.findall(r'\[[^\]]*\]',tail)
            row['values']=json.loads(arrays[0]);row['labels']=json.loads(arrays[1])
            index=int(re.findall(NUMBER,tail[tail.rfind(']')+1:])[0]);row['default']=row['values'][index]
        rows.append(row)
    return rows
class SettingsAudit(unittest.TestCase):
    def test_registry_unique_and_valid(self):
        rows=read_settings();self.assertEqual(len(rows),122);self.assertEqual(len({r['name'] for r in rows}),122)
        for r in rows:
            if r['kind']=='Slider':self.assertTrue(r['min']<=r['default']<=r['max'],r['name'])
            if r['kind']=='List':self.assertEqual(len(r['values']),len(r['labels']))
    def test_each_setting_has_runtime_reader(self):
        code='\n'.join(p.read_text() for p in FUNCTIONS.glob('*.sqf') if p.name not in ['fn_registerSettings.sqf','fn_applyPreset.sqf'])
        code=re.sub(r'/\*.*?\*/|//[^\n]*','',code,flags=re.S)
        for r in read_settings():self.assertIn('"'+r['name']+'"',code,r['name'])
    def test_retired_settings_are_not_read_or_preset(self):
        removed=json.loads((ROOT/'tests/settings_removals.json').read_text())
        code='\n'.join(p.read_text() for p in FUNCTIONS.glob('*.sqf'))
        for key in removed:self.assertNotIn('"'+key+'"',code)
    def test_presets_only_use_live_controls_and_valid_values(self):
        rows={r['name']:r for r in read_settings()}
        pairs=re.findall(r'\["(GAIT_ss_[^"]+)",\s*('+NUMBER+r'|true|false)\]',(FUNCTIONS/'fn_applyPreset.sqf').read_text())
        for name,value in pairs:
            self.assertIn(name,rows)
            r=rows[name]
            if r['kind']=='Slider':self.assertTrue(r['min']<=float(value)<=r['max'],name)
    def test_effective_ranges_and_modes(self):
        rows={r['name']:r for r in read_settings()}
        self.assertEqual((rows['GAIT_ss_shiftReleaseRunTaperCurve']['min'],rows['GAIT_ss_shiftReleaseRunTaperCurve']['max']),(1,3))
        self.assertEqual(rows['GAIT_ss_debugHudInterval']['min'],0.05)
        self.assertEqual(rows['GAIT_ss_compatibilityMode']['values'],[1,2,3,4])
        self.assertEqual(rows['GAIT_ss_compatibilityMode']['default'],1)
        self.assertIn('10%',rows['GAIT_ss_tinnitusEnabled']['description'])
        self.assertIn('10%',rows['GAIT_ss_enabled']['description'])
        self.assertIn('0.08',rows['GAIT_ss_shiftReleaseRunTaperDuration']['description'])
    def test_cleanup_cannot_be_disabled(self):
        main=(FUNCTIONS/'fn_initSprintSystem.sqf').read_text()
        helper=(FUNCTIONS/'fn_traversalHelpers.sqf').read_text()
        self.assertIn('["player_object_changed"] call GAIT_fnc_resetEffects;',main)
        self.assertIn('if (_foreignCamera) exitWith {true};',helper)
        self.assertIn('if (player getVariable ["ACE_isUnconscious", false]) exitWith {true};',helper)
        self.assertNotIn('GAIT_fnc_isSuspendedContext = {',main)
        self.assertIn('playSound3D [_soundPath, player, false, getPosASL player,',main)
        self.assertIn('_vol, 1, 4, 0, true, false]',main)
        self.assertIn('GAIT_fnc_stopTinnitusSound',main)
        reset=(FUNCTIONS/'fn_resetEffects.sqf').read_text()
        module=(FUNCTIONS/'fn_moduleResetEffects.sqf').read_text()
        self.assertIn('GAIT_fnc_stopTinnitusSound',reset)
        self.assertIn('GAIT_fnc_clearLocomotionInputHistory',reset)
        self.assertIn('CBA_fnc_targetEvent',module)
        self.assertNotIn('remoteExecCall',module)
if __name__=='__main__':unittest.main()
