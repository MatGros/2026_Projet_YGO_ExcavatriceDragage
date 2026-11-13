"""Exploration parametrique M3 (petite vitesse 5-10 Hz) sur equations reelles."""
from __future__ import annotations

DT = 0.01
END_STOP_MARGIN = 0.50


def run_case(
    freq_hz: float = 10.0,
    gain_m_per_hz_s: float = 0.02,
    decel_rate_hz_s: float = 25.0,
    tau_drive_s: float = 0.03,
    brake_close_delay_s: float = 0.09,
    brake_decel_mps2: float = 2.0,
    rolling_friction_mps2: float = 0.30,
    slope_mps2: float = 0.0,
    inertia_decoupled_on_stop: bool = False,
    cam_dropout_width_m: float = 0.0,
    cam_dropout_start_m: float = 0.02,
    finite_cam_length_m: float | None = None,  # si defini, DI=1 seulement sur [-finite_cam_length_m, 0]
    holds_cmd_after_trip: bool = True,  # operateur Manu maintient le joystick
    has_hardstop_latch: bool = False,
    hardstop_enabled: bool = True,  # False simule cote Maintenance (PRG_06:441)
    scan_delay_s: float = 0.0,
) -> dict:
    pos = 0.20  # depart 20 cm avant capteur (0.0), vitesse deja stabilisee a freq_hz
    f_cmd = freq_hz
    f_elec = freq_hz
    vel = -gain_m_per_hz_s * freq_hz
    alpha = DT / (tau_drive_s + DT) if tau_drive_s > 0.001 else 1.0

    trip_t = None
    brake_open = True
    brake_timer = 0.0
    coil_energized = True
    latched_stop = False
    re_energize_count = 0
    was_cut = False
    max_pen = 0.0
    impact_speed = 0.0
    hit = False
    delay_timer = 0.0
    cut_armed = False

    for step in range(3000):  # 30 s max
        t = step * DT
        raw_di = pos <= 0.0
        if finite_cam_length_m is not None:
            raw_di = raw_di and (pos >= -finite_cam_length_m)

        in_dropout = False
        if cam_dropout_width_m > 0.0:
            near = -cam_dropout_start_m
            far = near - cam_dropout_width_m
            in_dropout = (pos <= near) and (pos >= far)

        di_active = raw_di and (not in_dropout)

        if di_active and trip_t is None:
            trip_t = t

        if di_active:
            cut_armed = True
            if has_hardstop_latch:
                latched_stop = True

        if cut_armed:
            delay_timer += DT

        hardstop = hardstop_enabled and (di_active or latched_stop) and (delay_timer >= scan_delay_s)

        if hardstop:
            req_active = False
            coil_energized = False
            was_cut = True
        else:
            if trip_t is None or (holds_cmd_after_trip and not latched_stop):
                if was_cut:
                    re_energize_count += 1
                    was_cut = False
                req_active = True
                coil_energized = True
            else:
                req_active = False
                coil_energized = False

        # Frein
        if coil_energized:
            if not brake_open:
                brake_timer += DT
                if brake_timer >= 0.10:
                    brake_open = True
                    brake_timer = 0.0
            else:
                brake_timer = 0.0
        else:
            if brake_open:
                brake_timer += DT
                if brake_timer >= brake_close_delay_s:
                    brake_open = False
                    brake_timer = 0.0
            else:
                brake_timer = 0.0

        # Variateur
        f_tgt = freq_hz if req_active else 0.0
        f_delta = f_tgt - f_cmd
        f_step = (20.0 if f_delta >= 0 else decel_rate_hz_s) * DT
        f_cmd += max(-f_step, min(f_step, f_delta))
        f_elec += alpha * (f_cmd - f_elec)
        if f_tgt <= 0.0 and f_cmd <= 0.0 and f_elec <= 0.5:
            f_elec = 0.0

        # Dynamique chariot
        if brake_open:
            if req_active or (not inertia_decoupled_on_stop):
                vel = -gain_m_per_hz_s * f_elec
            else:
                accel = slope_mps2 + (rolling_friction_mps2 if vel < 0 else -rolling_friction_mps2)
                new_vel = vel + accel * DT
                if vel < 0 and new_vel >= 0:
                    vel = 0.0
                else:
                    vel = new_vel
        else:
            a_net = brake_decel_mps2 + slope_mps2
            if a_net < 0.01:
                a_net = 0.01
            if vel < 0:
                vel = min(0.0, vel + a_net * DT)
            elif vel > 0:
                vel = max(0.0, vel - a_net * DT)

        pos += vel * DT
        if pos < 0.0:
            max_pen = max(max_pen, -pos)
        if pos <= -END_STOP_MARGIN:
            hit = True
            impact_speed = abs(vel)
            pos = -END_STOP_MARGIN
            vel = 0.0
            break
        if trip_t is not None and abs(vel) < 1e-4 and not req_active:
            break

    return {
        "pen_m": round(max_pen, 4),
        "hit": hit,
        "impact_mps": round(impact_speed, 4),
        "re_energize": re_energize_count,
    }


cases = [
    ("0. Baseline actuel 5 Hz (GVL_Simulation)", dict(freq_hz=5.0, cam_dropout_width_m=0.04, cam_dropout_start_m=0.02)),
    ("0b. Baseline actuel 10 Hz (GVL_Simulation)", dict(freq_hz=10.0, cam_dropout_width_m=0.04, cam_dropout_start_m=0.02)),
    ("H1a: 10 Hz + inertie + frein 0.2s/1.0 m/s2 + CamDropout 0.02->0.06", dict(freq_hz=10.0, inertia_decoupled_on_stop=True, brake_close_delay_s=0.20, brake_decel_mps2=1.0, cam_dropout_width_m=0.04, cam_dropout_start_m=0.02)),
    ("H1b: 10 Hz + inertie + frein 0.25s/0.8 m/s2 + CamDropout des 0.01m", dict(freq_hz=10.0, inertia_decoupled_on_stop=True, brake_close_delay_s=0.25, brake_decel_mps2=0.8, cam_dropout_width_m=0.04, cam_dropout_start_m=0.01)),
    ("H1c: 10 Hz + came finie 0.04m + inertie + frein 0.25s/0.8 m/s2", dict(freq_hz=10.0, inertia_decoupled_on_stop=True, brake_close_delay_s=0.25, brake_decel_mps2=0.8, finite_cam_length_m=0.04)),
    ("H1d: 5 Hz + came finie 0.02m + inertie + frein 0.30s/0.5 m/s2", dict(freq_hz=5.0, inertia_decoupled_on_stop=True, brake_close_delay_s=0.30, brake_decel_mps2=0.5, finite_cam_length_m=0.02)),
    ("H2+Gain0.045: 10 Hz, gain 0.045, frein humide 0.30s/0.35 m/s2 (sans perte DI)", dict(freq_hz=10.0, gain_m_per_hz_s=0.045, inertia_decoupled_on_stop=True, brake_close_delay_s=0.30, brake_decel_mps2=0.35, rolling_friction_mps2=0.10)),
    ("H6: Cote Maintenance (sans HardStop PRG_06) a 5 Hz", dict(freq_hz=5.0, hardstop_enabled=False)),
    ("Contre-epreuve: H1c avec Latch PRG_06 actif (10 Hz)", dict(freq_hz=10.0, inertia_decoupled_on_stop=True, brake_close_delay_s=0.25, brake_decel_mps2=0.8, finite_cam_length_m=0.04, has_hardstop_latch=True)),
]

for name, kw in cases:
    res = run_case(**kw)
    print(f"{name:76s} -> {res}")
