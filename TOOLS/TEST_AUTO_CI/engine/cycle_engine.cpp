// ═══════════════════════════════════════════════════════════════════════════
// cycle_engine.cpp — Moteur interactif FB_Cycle (T173)
// ═══════════════════════════════════════════════════════════════════════════
// Binaire compilé depuis WORKING_COPY (jamais CODE/). Processus persistant :
//   stdin  : une ligne par scan, "key=value key=value ..." (stimuli)
//   stdout : une ligne par scan, "key=value key=value ..." (sorties du FB)
// L'état du FB (R_TRIG, timers, STATE) est conservé entre les lignes.
// Le serveur Python fait le JSON web <-> protocole ligne. Aucune logique métier
// dans le navigateur : le binaire décide, le JS affiche.
// ═══════════════════════════════════════════════════════════════════════════
#include "FB_Cycle.hpp"
using namespace strucpp;
#include <iostream>
#include <string>
#include <sstream>
#include <map>
#include <cstdlib>
#include <cstdint>

static std::map<std::string, std::string> parseLine(const std::string& line) {
    std::map<std::string, std::string> kv;
    std::istringstream iss(line);
    std::string tok;
    while (iss >> tok) {
        auto eq = tok.find('=');
        if (eq != std::string::npos) kv[tok.substr(0, eq)] = tok.substr(eq + 1);
    }
    return kv;
}

// Helpers de lecture (clé absente => ne pas toucher la valeur courante)
static void setB(const std::map<std::string,std::string>& kv, const char* k, IEC_BOOL& m) {
    auto it = kv.find(k); if (it != kv.end()) m.set(it->second == "1");
}
static void setI(const std::map<std::string,std::string>& kv, const char* k, IEC_INT& m) {
    auto it = kv.find(k); if (it != kv.end()) m.set(std::atoi(it->second.c_str()));
}
static void setR(const std::map<std::string,std::string>& kv, const char* k, IEC_REAL& m) {
    auto it = kv.find(k); if (it != kv.end()) m.set(std::atof(it->second.c_str()));
}
static void setT(const std::map<std::string,std::string>& kv, const char* k, IEC_TIME& m) {
    auto it = kv.find(k); if (it != kv.end()) m.set(std::atoll(it->second.c_str()));
}
static void setMode(const std::map<std::string,std::string>& kv, const char* k, IEC_E_MODE& m) {
    auto it = kv.find(k); if (it == kv.end()) return;
    const std::string& v = it->second;
    if (v == "SEMI_AUTO") m.set(E_MODE::SEMI_AUTO);
    else if (v == "MAINT_N1") m.set(E_MODE::MAINT_N1);
    else if (v == "MAINT_N2") m.set(E_MODE::MAINT_N2);
    else if (v == "DISABLE") m.set(E_MODE::DISABLE);
    else m.set(static_cast<E_MODE>(std::atoi(v.c_str())));
}

// Lit la valeur numérique d'un IEC_ENUM_Var (get() -> IEC_ENUM_Value -> .get() -> enum)
template<typename E> static int enumInt(const IEC_ENUM_Var<E>& v) {
    return static_cast<int>(v.get().get());
}

int main() {
    FB_CYCLE fb;
    std::string line;
    while (std::getline(std::cin, line)) {
        if (line.empty() || line[0] == '#') continue;
        auto kv = parseLine(line);

        // ── Entrées (stimuli) ──────────────────────────────────────────────
        setB(kv, "ENABLE", fb.ENABLE);
        setB(kv, "RESET", fb.RESET);
        setB(kv, "POWERCONTACTORENGAGED", fb.POWERCONTACTORENGAGED);
        setMode(kv, "MODE", fb.MODE);
        setB(kv, "CYCLEMOTIONPERMIT", fb.CYCLEMOTIONPERMIT);
        setB(kv, "DEADMANARMED", fb.DEADMANARMED);
        setB(kv, "HEARTBEATIHMOK", fb.HEARTBEATIHMOK);
        setB(kv, "STARTCYCLE", fb.STARTCYCLE);
        setB(kv, "ABORTCYCLE", fb.ABORTCYCLE);
        setI(kv, "SELTARGET", fb.SELTARGET);
        setR(kv, "SETDEPTHM", fb.SETDEPTHM);
        setR(kv, "SETOFFSETM", fb.SETOFFSETM);
        setB(kv, "KOBOLDCONTACTFOND", fb.KOBOLDCONTACTFOND);
        setB(kv, "LIMITLEGALREACHED", fb.LIMITLEGALREACHED);
        setR(kv, "LIMITLEGALDEPTHM", fb.LIMITLEGALDEPTHM);
        setB(kv, "WINCHSYNCERROR", fb.WINCHSYNCERROR);
        setR(kv, "WINCHSYNCDELTAM", fb.WINCHSYNCDELTAM);
        setR(kv, "M1_CABLEPOSM", fb.M1_CABLEPOSM);
        setR(kv, "M2_CABLEPOSM", fb.M2_CABLEPOSM);
        setR(kv, "M1_MEASUREDSPEEDMPS", fb.M1_MEASUREDSPEEDMPS);
        setR(kv, "M2_MEASUREDSPEEDMPS", fb.M2_MEASUREDSPEEDMPS);
        setR(kv, "SPEEDMISMATCHTHRESHOLDMPS", fb.SPEEDMISMATCHTHRESHOLDMPS);
        setT(kv, "SPEEDMISMATCHTIMEOUT", fb.SPEEDMISMATCHTIMEOUT);
        setR(kv, "CABLELIMITM1ASCENTM", fb.CABLELIMITM1ASCENTM);
        setB(kv, "TRANSLATION_AT_P1", fb.TRANSLATION_AT_P1);
        setB(kv, "TRANSLATION_AT_TREMIE", fb.TRANSLATION_AT_TREMIE);
        setB(kv, "TRANSLATION_AT_MAINTENANCE", fb.TRANSLATION_AT_MAINTENANCE);
        setB(kv, "TRANSLATION_BUSY", fb.TRANSLATION_BUSY);
        setB(kv, "TRANSLATION_DONE", fb.TRANSLATION_DONE);
        setB(kv, "BENNE_BUSY", fb.BENNE_BUSY);
        setB(kv, "BENNE_DONE", fb.BENNE_DONE);
        setB(kv, "BENNE_ISOPEN", fb.BENNE_ISOPEN);
        setB(kv, "BENNE_ISCLOSED", fb.BENNE_ISCLOSED);
        setB(kv, "BENNE_ISROUGHLYCLOSED", fb.BENNE_ISROUGHLYCLOSED);
        setB(kv, "HOMEDM1", fb.HOMEDM1);
        setB(kv, "HOMEDM2", fb.HOMEDM2);
        setB(kv, "TOPPOSITIONSENSOR", fb.TOPPOSITIONSENSOR);
        setB(kv, "HOMINGREQUEST", fb.HOMINGREQUEST);
        setI(kv, "SAMPLECOUNT", fb.SAMPLECOUNT);  // IN_OUT

        // ── Exécution d'un scan ────────────────────────────────────────────
        fb();

        // ── Sorties ────────────────────────────────────────────────────────
        std::cout
            << "READY=" << (fb.READY.get() ? 1 : 0)
            << " FAULT.ERROR=" << (fb.FAULT.ERROR.get() ? 1 : 0)
            << " FAULT.ERRORID=" << (int)fb.FAULT.ERRORID.get()
            << " FAULT.LATCHED=" << (fb.FAULT.LATCHED.get() ? 1 : 0)
            << " FAULT.LATCHEDID=" << (int)fb.FAULT.LATCHEDID.get()
            << " LIFECYCLE.BUSY=" << (fb.LIFECYCLE.BUSY.get() ? 1 : 0)
            << " LIFECYCLE.DONE=" << (fb.LIFECYCLE.DONE.get() ? 1 : 0)
            << " SPEEDMISMATCHMPS=" << fb.SPEEDMISMATCHMPS.get()
            << " SPEEDMISMATCHACTIVE=" << (fb.SPEEDMISMATCHACTIVE.get() ? 1 : 0)
            << " SPEEDMISMATCHCONFIRMED=" << (fb.SPEEDMISMATCHCONFIRMED.get() ? 1 : 0)
            << " WINCHM1CMD.STARTSTOP=" << (fb.WINCHM1CMD.STARTSTOP.get() ? 1 : 0)
            << " WINCHM1CMD.DIRECTION=" << (int)fb.WINCHM1CMD.DIRECTION.get()
            << " WINCHM1CMD.SPEEDPCT=" << fb.WINCHM1CMD.SPEEDPCT.get()
            << " WINCHM2CMD.STARTSTOP=" << (fb.WINCHM2CMD.STARTSTOP.get() ? 1 : 0)
            << " WINCHM2CMD.DIRECTION=" << (int)fb.WINCHM2CMD.DIRECTION.get()
            << " WINCHM2CMD.SPEEDPCT=" << fb.WINCHM2CMD.SPEEDPCT.get()
            << " TRANSLATIONCMD.START=" << (fb.TRANSLATIONCMD.START.get() ? 1 : 0)
            << " TRANSLATIONCMD.TARGET=" << (int)fb.TRANSLATIONCMD.TARGET.get()
            << " BUCKETCMD.OPEN=" << (fb.BUCKETCMD.OPEN.get() ? 1 : 0)
            << " BUCKETCMD.CLOSE=" << (fb.BUCKETCMD.CLOSE.get() ? 1 : 0)
            << " BUCKETCMD.KOBOLDCONTACTORCMD=" << (fb.BUCKETCMD.KOBOLDCONTACTORCMD.get() ? 1 : 0)
            << " CYCLESTEP=" << enumInt(fb.CYCLESTEP)
            << " CYCLESTATESTR=" << fb.CYCLESTATESTR.get().c_str()
            << " CYCLESTEPATERROR=" << enumInt(fb.CYCLESTEPATERROR)
            << " OPERATORACTIONID=" << (unsigned)fb.OPERATORACTIONID.get()
            << " OPERATORACTION=" << fb.OPERATORACTION.get().c_str()
            << " EXPECTEDAXIS=" << enumInt(fb.EXPECTEDAXIS)
            << " EXPECTEDDIRECTION=" << (int)fb.EXPECTEDDIRECTION.get()
            << " WAITINGFOROPERATOR=" << (fb.WAITINGFOROPERATOR.get() ? 1 : 0)
            << " WAITINGFORPROCESS=" << (fb.WAITINGFORPROCESS.get() ? 1 : 0)
            << " REQUESTACTIVE=" << (fb.REQUESTACTIVE.get() ? 1 : 0)
            << " SAMPLECOUNT=" << (int)fb.SAMPLECOUNT.get()
            << std::endl;
    }
    return 0;
}
