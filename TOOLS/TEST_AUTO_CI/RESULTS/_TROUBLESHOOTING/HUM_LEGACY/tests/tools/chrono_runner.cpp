#include "generated.hpp"
#include <iostream>
#include <iomanip>
#include <vector>
#include <cmath>

using namespace strucpp;

struct Step {
    int64_t time_advance_ns;
    bool enable;
    bool reset;
    float pos;
    bool pos_valid;
    const char* section;
    const char* note;
};

int main() {
    FB_ENCODER_SPEEDMEASURE fb_nominal;   // Algorithme nominal
    std::vector<Step> scenario;

    // =========================================================================
    // PARTIE 1 : PROFIL NOMINAL IDÉAL (Linéaire, sans perturbation)
    // =========================================================================
    float pos = 0.000f;
    scenario.push_back({ 0, false, false, pos, false, "PARTIE 1 : IDÉAL", "Scan 0  : Repos initial neutralisé" });

    // Démarrage et remplissage (1.50 m/s nominal -> +15.0 mm/10ms)
    scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 1 : IDÉAL", "Scan 1  : Activation (pos 0.000m)" });
    for (int i = 2; i <= 5; ++i) {
        pos += 0.0150f;
        scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 1 : IDÉAL", "Remplissage progressif fenêtre" });
    }

    // Palier stable 1.50 m/s (100 ms)
    for (int i = 6; i <= 12; ++i) {
        pos += 0.0150f;
        scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 1 : IDÉAL", "Palier constant idéal 1.50 m/s" });
    }

    // Accélération vers 2.00 m/s
    pos += 0.0175f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 1 : IDÉAL", "Rampe accélération 1.75 m/s" });
    pos += 0.0200f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 1 : IDÉAL", "Palier constant idéal 2.00 m/s" });
    pos += 0.0200f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 1 : IDÉAL", "Palier constant idéal 2.00 m/s" });
    pos += 0.0200f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 1 : IDÉAL", "Palier constant idéal 2.00 m/s" });

    // Décélération et arrêt
    pos += 0.0100f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 1 : IDÉAL", "Décélération treuil" });
    pos += 0.0050f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 1 : IDÉAL", "Décélération treuil" });
    for (int i = 0; i < 4; ++i) {
        scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 1 : IDÉAL", "Arrêt complet à position fixe" });
    }

    // =========================================================================
    // PARTIE 2 : PROFIL RÉEL AVEC PERTURBATIONS & NON-LINÉARITÉS
    // (Bruit de quantification, vibrations treuil, élasticité câble +/-2 à 6 mm, jitter temps +/-2ms)
    // =========================================================================
    // Repos intermédiaire
    scenario.push_back({ 20000000, true, true, pos, true, "PARTIE 2 : PERTURBÉ", "Reset & Préparation essai avec bruit" });
    
    // Démarrage perturbé (choc mécanique & élasticité câble : pas de déplacement au 1er scan, puis saut élastique)
    scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Démarrage : jeu mécanique (pos figée)" });
    pos += 0.0060f; scenario.push_back({  9000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Tension câble (scan 9ms, +6mm -> bruit)" });
    pos += 0.0240f; scenario.push_back({ 11000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Détente élastique (scan 11ms, +24mm -> pic)" });
    pos += 0.0110f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Ondulation câble (+11mm au lieu de +15mm)" });
    pos += 0.0190f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Ondulation câble (+19mm au lieu de +15mm)" });

    // Palier Vitesse Constante 1.50 m/s avec BRUIT HAUTE FRÉQUENCE (+/- 4mm par scan)
    // Les positions réelles oscillent autour de la droite moyenne (+15mm) :
    float noise_pattern[] = { +0.012f, +0.018f, +0.013f, +0.017f, +0.011f, +0.019f, +0.015f, +0.014f, +0.016f };
    for (size_t k = 0; k < sizeof(noise_pattern)/sizeof(noise_pattern[0]); ++k) {
        pos += noise_pattern[k];
        scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Palier 1.50 m/s avec vibrations câble" });
    }

    // Accélération non-linéaire vers 2.00 m/s avec à-coups
    pos += 0.0130f; scenario.push_back({  9500000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Accélération avec gigue (9.5ms, +13mm)" });
    pos += 0.0240f; scenario.push_back({ 10500000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Accélération avec sursaut (10.5ms, +24mm)" });
    pos += 0.0180f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Régime 2.00 m/s perturbé (+18mm)" });
    pos += 0.0220f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Régime 2.00 m/s perturbé (+22mm)" });
    pos += 0.0190f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Régime 2.00 m/s perturbé (+19mm)" });
    pos += 0.0210f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Régime 2.00 m/s perturbé (+21mm)" });

    // Décélération brutale et rebond d'arrêt
    pos += 0.0140f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Freinage appuyé" });
    pos += 0.0030f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Arrêt mécanique sec" });
    pos -= 0.0020f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Rebond élastique câble arrière (-2mm)" });
    pos += 0.0020f; scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Stabilisation finale (+2mm)" });
    for (int i = 0; i < 3; ++i) {
        scenario.push_back({ 10000000, true, false, pos, true, "PARTIE 2 : PERTURBÉ", "Immobilisation treuil" });
    }

    std::cout << "\n======================================================================================================================================================\n";
    std::cout << "🔬 BENCHMARK & CHRONOGRAMME : VITESSE LINÉAIRE IDÉALE vs VITESSE RÉELLE PERTURBÉE (Bruit mécanique, élasticité +/-4mm, gigue scan)\n";
    std::cout << "======================================================================================================================================================\n";
    std::cout << std::left 
              << std::setw(5)  << "Scan" << " | "
              << std::setw(6)  << "t(ms)" << " | "
              << std::setw(18) << "Section" << " | "
              << std::setw(8)  << "Pos(m)" << " | "
              << std::setw(10) << "V_inst(m/s)" << " | "
              << std::setw(7)  << "Valid" << " | "
              << std::setw(12) << "Speed_Mps(m/s)" << " | "
              << std::setw(12) << "Gain Filtrage" << " | "
              << "Comportement & Observation\n";
    std::cout << "------------------------------------------------------------------------------------------------------------------------------------------------------\n";

    strucpp::__CURRENT_TIME_NS = 0;
    float last_pos = 0.0f;
    int64_t last_time = 0;

    for (size_t i = 0; i < scenario.size(); ++i) {
        strucpp::__CURRENT_TIME_NS += scenario[i].time_advance_ns;

        fb_nominal.ENABLE = scenario[i].enable;
        fb_nominal.RESET = scenario[i].reset;
        fb_nominal.POSITION_M = scenario[i].pos;
        fb_nominal.POSITIONVALID = scenario[i].pos_valid;

        fb_nominal();

        // Calcul de la vitesse brute instantanée sur 1 seul scan (non filtrée)
        float v_inst = 0.0f;
        int64_t dt_ns = strucpp::__CURRENT_TIME_NS - last_time;
        if (dt_ns > 0 && i > 0 && scenario[i].enable && scenario[i].pos_valid) {
            v_inst = (scenario[i].pos - last_pos) / (dt_ns / 1000000000.0f);
        }

        double t_ms = strucpp::__CURRENT_TIME_NS / 1000000.0;
        float speed_out = (float)fb_nominal.SPEED_MPS;

        // Évaluation du lissage du bruit
        std::string gain_txt = "—";
        if (scenario[i].pos_valid && fb_nominal.VALID) {
            float ecart_inst = std::abs(v_inst - 1.50f);
            float ecart_flt  = std::abs(speed_out - 1.50f);
            if (ecart_inst > 0.15f && std::string(scenario[i].section).find("PERTURBÉ") != std::string::npos) {
                float attenuation = (1.0f - (ecart_flt / (ecart_inst + 0.001f))) * 100.0f;
                char buf[32];
                snprintf(buf, sizeof(buf), "-%.0f%% bruit", std::max(0.0f, attenuation));
                gain_txt = buf;
            } else if (ecart_flt < 0.05f) {
                gain_txt = "🎯 Parfait";
            }
        }

        std::cout << std::left 
                  << std::setw(5)  << i << " | "
                  << std::setw(6)  << std::fixed << std::setprecision(0) << t_ms << " | "
                  << std::setw(18) << scenario[i].section << " | "
                  << std::setw(8)  << std::fixed << std::setprecision(3) << scenario[i].pos << " | "
                  << std::setw(10) << std::fixed << std::setprecision(3) << v_inst << " | "
                  << std::setw(7)  << (fb_nominal.VALID ? "TRUE" : "FALSE") << " | "
                  << std::setw(12) << std::fixed << std::setprecision(3) << speed_out << " | "
                  << std::setw(12) << gain_txt << " | "
                  << scenario[i].note << "\n";

        last_pos = scenario[i].pos;
        last_time = strucpp::__CURRENT_TIME_NS;
    }
    std::cout << "======================================================================================================================================================\n";
    return 0;
}
