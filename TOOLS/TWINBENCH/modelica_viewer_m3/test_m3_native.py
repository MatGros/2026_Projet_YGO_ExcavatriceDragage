import unittest

from m3_native import M3Config, M3Inputs, M3NativePlant


class M3NativePlantTests(unittest.TestCase):
    def setUp(self):
        self.cfg = M3Config(brake_open_delay_s=0.10, brake_close_delay_s=0.05)

    def test_sensor_words_match_code_contract(self):
        expected = [
            (0.0, 0b11111),
            (2.0, 0b01111),
            (10.0, 0b00111),
            (20.0, 0b00011),
            (30.0, 0b00001),
            (35.0, 0b00000),
        ]
        for x, word in expected:
            plant = M3NativePlant(self.cfg, x)
            out = plant.outputs(M3Inputs())
            self.assertEqual(out.sensors_word, word, x)
            self.assertFalse(out.sensor_incoherent)

    def test_x100_frequency_and_brake_gate_motion(self):
        plant = M3NativePlant(self.cfg, 25.0)
        cmd = M3Inputs(command_word=2, setpoint_frequency_x100=4000, brake_release_request=True)
        out = plant.step(0.05, cmd)
        self.assertFalse(out.brake_is_open)
        self.assertEqual(out.actual_frequency_x100, 0)
        x0 = out.position_m
        out = plant.step(0.06, cmd)
        self.assertTrue(out.brake_is_open)
        self.assertGreater(out.actual_frequency_x100, 0)
        self.assertGreater(out.position_m, x0)

    def test_direction_words(self):
        plant = M3NativePlant(self.cfg, 20.0)
        to_tremie = M3Inputs(1, 3000, True)
        plant.step(0.11, to_tremie)
        self.assertLess(plant.step(0.2, to_tremie).velocity_m_s, 0.0)
        plant.reset(20.0)
        to_maint = M3Inputs(2, 3000, True)
        plant.step(0.11, to_maint)
        self.assertGreater(plant.step(0.2, to_maint).velocity_m_s, 0.0)

    def test_fault_removes_drive_and_brake(self):
        plant = M3NativePlant(self.cfg, 20.0)
        run = M3Inputs(2, 4000, True)
        plant.step(0.2, run)
        self.assertTrue(plant.brake_is_open)
        fault = M3Inputs(2, 4000, True, thermal_ok=False)
        out = plant.step(0.2, fault)
        self.assertTrue(out.status_word & plant.ST_FAULT)
        self.assertFalse(out.brake_is_open)
        self.assertLess(out.actual_frequency_x100, 4000)


if __name__ == "__main__":
    unittest.main()
