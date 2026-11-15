"""Etude Bureau d'Etudes M3 : dynamique pendule benne, adherence rail, longueur came, energie d'impact."""
from __future__ import annotations

import math

G = 9.81


def simulate_coupled_stop(
    freq_hz: float,
    gain_k: float,
    brake_delay_s: float,
    brake_decel_mps2: float,
    pendulum_length_m: float = 4.0,
    load_mass_ratio: float = 0.5,
    rail_mu_max: float = 0.12,
    slope_mps2: float = 0.0,
    dt: float = 0.002,
) -> dict:
    """Simule un arret sur FDC avec inertie chariot + balancement pendulaire de la benne."""
    v0 = gain_k * freq_hz
    x = 0.0
    v = v0
    theta = 0.0  # angle benne (rad), >0 = benne en avant dans le sens du mouvement
    omega = 0.0
    t = 0.0
    max_theta_deg = 0.0
    max_x = 0.0
    slip_occurred = False

    mass_factor = load_mass_ratio / max(0.05, 1.0 - load_mass_ratio)
    a_rail_limit = rail_mu_max * G

    for _ in range(10000):  # max 20 s
        t += dt
        # Force de freinage effective apres retard mecanique
        a_brake_req = brake_decel_mps2 if t >= brake_delay_s else 0.0
        # Effort horizontal transmis par le cable de benne (petits angles)
        f_pendulum_on_cart = mass_factor * G * math.sin(theta)
        # Effort de freinage limite par adherence rail-roue
        a_brake_eff = min(a_brake_req, a_rail_limit)
        if a_brake_req > a_rail_limit and abs(v) > 1e-3:
            slip_occurred = True

        # Acceleration chariot (sens approche = +x)
        if v > 0.0:
            a_cart = -a_brake_eff + f_pendulum_on_cart + slope_mps2
        elif abs(f_pendulum_on_cart + slope_mps2) > a_brake_eff:
            a_cart = (f_pendulum_on_cart + slope_mps2) - math.copysign(a_brake_eff, f_pendulum_on_cart + slope_mps2)
        else:
            a_cart = 0.0
            v = 0.0

        # Dynamique pendule benne : theta'' = -(g/L)*sin(theta) - (a_cart/L)*cos(theta) - damping
        alpha_pend = -(G / pendulum_length_m) * math.sin(theta) - (a_cart / pendulum_length_m) * math.cos(theta) - 0.15 * omega
        omega += alpha_pend * dt
        theta += omega * dt
        v_next = v + a_cart * dt
        if v > 0.0 and v_next <= 0.0 and abs(f_pendulum_on_cart + slope_mps2) <= a_brake_eff:
            v = 0.0
        else:
            v = v_next
        x += v * dt
        max_x = max(max_x, x)
        max_theta_deg = max(max_theta_deg, abs(math.degrees(theta)))
        if t > brake_delay_s + 0.5 and abs(v) < 1e-4 and abs(omega) < 1e-3 and abs(theta) < 1e-3:
            break

    return {
        "v0_mps": round(v0, 3),
        "stop_m": round(max_x, 4),
        "max_theta_deg": round(max_theta_deg, 2),
        "slip": slip_occurred,
    }


def main() -> None:
    print("=== 1. SENSIBILITE DYNAMIQUE (PENDULE BENNE + ADHERENCE RAIL) ===")
    scenarios = [
        ("Nominal 5Hz (k=0.02, frein 0.09s/2.0, rail sec mu=0.15)", dict(freq_hz=5.0, gain_k=0.02, brake_delay_s=0.09, brake_decel_mps2=2.0, rail_mu_max=0.15)),
        ("Nominal 10Hz (k=0.02, frein 0.09s/2.0, rail sec mu=0.15)", dict(freq_hz=10.0, gain_k=0.02, brake_delay_s=0.09, brake_decel_mps2=2.0, rail_mu_max=0.15)),
        ("Audit 10Hz (k=0.0551, frein 0.09s/2.0, rail sec mu=0.15)", dict(freq_hz=10.0, gain_k=0.0551, brake_delay_s=0.09, brake_decel_mps2=2.0, rail_mu_max=0.15)),
        ("Audit 10Hz + rail humide (k=0.0551, frein 0.09s/2.0, mu=0.06)", dict(freq_hz=10.0, gain_k=0.0551, brake_delay_s=0.09, brake_decel_mps2=2.0, rail_mu_max=0.06)),
        ("Audit 10Hz + frein degrade + pendule (k=0.0551, 0.30s/0.35)", dict(freq_hz=10.0, gain_k=0.0551, brake_delay_s=0.30, brake_decel_mps2=0.35, rail_mu_max=0.12)),
        ("Approche reduite 5Hz + frein degrade (k=0.0551, 0.30s/0.35)", dict(freq_hz=5.0, gain_k=0.0551, brake_delay_s=0.30, brake_decel_mps2=0.35, rail_mu_max=0.12)),
    ]
    for name, kw in scenarios:
        print(f"{name:64s} -> {simulate_coupled_stop(**kw)}")

    print("\n=== 2. LONGUEUR MINIMALE DE CAME (L_came_min pour rester VU jusqu'a arret) ===")
    for k in (0.02, 0.0551):
        for f in (5.0, 10.0):
            nom = simulate_coupled_stop(f, k, 0.09, 2.0, rail_mu_max=0.15)["stop_m"]
            deg = simulate_coupled_stop(f, k, 0.30, 0.35, rail_mu_max=0.12)["stop_m"]
            print(f"k={k:.4f}, f={f:4.1f}Hz -> nominal={nom:.3f}m | degrade={deg:.3f}m | L_came_min_recommandee={max(0.15, round(deg*1.3, 2)):.2f}m")


if __name__ == "__main__":
    main()
