#include "generated.hpp"
#include "iec_test.hpp"
#include <cstring>

using namespace strucpp;

struct TestSetup_1 {
    FB_MACHINEHOMINGCYCLE FB;
    ST_FBMACHINEHOMINGCYCLE_AXISHOMINGSTATUS STATUSHOMED;
    ST_FBMACHINEHOMINGCYCLE_AXISHOMINGSTATUS STATUSNONE;
    ST_FBMACHINEHOMINGCYCLE_AXISHOMINGSTATUS STATUSBUSY;
    ST_FBMACHINEHOMINGCYCLE_AXISHOMINGSTATUS STATUSDONE;
    ST_FBMACHINEHOMINGCYCLE_AXISHOMINGSTATUS STATUSERR;

    void setup() {
        STATUSHOMED.HOMEDANDRELIABLE = true;
        STATUSBUSY.HOMINGBUSY = true;
        STATUSDONE.HOMEDANDRELIABLE = true;
        STATUSDONE.HOMINGDONE = true;
        STATUSERR.HOMINGERROR = true;
    }

    void teardown() {
    }
};

// TEST 'TC-T185-001 : machine non qualifiee avec 2 codeurs seuls (offset benne absent)'
bool test_1(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::SEMI_AUTO;
        s.FB.TOPPOSITIONACTIVE = false;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.BUCKETOFFSETVALID = false;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_false(static_cast<bool>(s.FB.MACHINEHOMED), "FB.MACHINEHOMED", 28, "Deux codeurs seuls ne qualifient pas la machine")) return false;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::OFFSET_UNKNOWN, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.OFFSET_UNKNOWN", 29, "Guide : passer en MAINT_N2 pour la benne")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-010 : M1 non reference => M1_NOT_HOMED'
bool test_2(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.BUCKETOFFSETVALID = false;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::M1_NOT_HOMED, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.M1_NOT_HOMED", 38, "Cause M1 isolee")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-011 : M2 non reference => M2_NOT_HOMED'
bool test_3(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.BUCKETOFFSETVALID = false;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::M2_NOT_HOMED, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.M2_NOT_HOMED", 45, "Cause M2 isolee")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-012 : les deux non references => BOTH_NOT_HOMED'
bool test_4(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.BUCKETOFFSETVALID = false;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::BOTH_NOT_HOMED, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.BOTH_NOT_HOMED", 52, "Cause conjointe")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-020 : codeurs OK, offset absent, N2 sans capteur haut => NEED_TOP_POSITION'
bool test_5(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = false;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.BUCKETOFFSETVALID = false;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::NEED_TOP_POSITION, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.NEED_TOP_POSITION", 61, "Guide : monter au capteur haut")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-021 : capteur haut atteint mais treuils non arretes => NEED_MECHANICAL_STOP'
bool test_6(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = false;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.BUCKETOFFSETVALID = false;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::NEED_MECHANICAL_STOP, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.NEED_MECHANICAL_STOP", 68, "Guide : attendre l arret")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-022 : fenetre sure => AWAIT_BUCKET_CONFIRM'
bool test_7(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.BUCKETOFFSETVALID = false;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::AWAIT_BUCKET_CONFIRM, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.AWAIT_BUCKET_CONFIRM", 75, "Guide : confirmer la benne")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-030 : confirmation refusee hors MAINT_N2'
bool test_8(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N1;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.CONFIRMOPENPOSITION = true;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_false(static_cast<bool>(s.FB.M1DEMAND.HOMEREQ), "FB.M1DEMAND.HOMEREQ", 85, "Homing conjoint refuse hors N2")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.MACHINEHOMINGACTIVE), "FB.MACHINEHOMINGACTIVE", 86, "Aucune transaction hors N2")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-031 : confirmation fermee admissible => homing M1+M2, cible M2 = top + offset ferme, commit atomique'
bool test_9(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMCLOSEPOSITION = false;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMCLOSEPOSITION = true;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(s.FB.M1DEMAND.HOMEREQ), "FB.M1DEMAND.HOMEREQ", 101, "M1 recoit le homing conjoint")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.M2DEMAND.HOMEREQ), "FB.M2DEMAND.HOMEREQ", 102, "M2 recoit le homing conjoint")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.M2DEMAND.USEDYNAMICTARGET), "FB.M2DEMAND.USEDYNAMICTARGET", 103, "M2 cible geometrique")) return false;
        if (!ctx.assert_eq(s.FB.M2DEMAND.DYNAMICTARGET_M, 11.5, "FB.M2DEMAND.DYNAMICTARGET_M", "11.5", 104, "Cible M2 = 8.5 + 3.0 (ferme)")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.MACHINEHOMINGACTIVE), "FB.MACHINEHOMINGACTIVE", 105, "Transaction active")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.LIFECYCLE.BUSY), "FB.LIFECYCLE.BUSY", 106, "Lifecycle.Busy pendant la transaction")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSBUSY;
        s.FB.M2STATUS = s.STATUSBUSY;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(s.FB.MACHINEHOMINGACTIVE), "FB.MACHINEHOMINGACTIVE", 113, "Transaction conservee pendant les deux homings")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.BUCKETCOMMIT.COMMITCLOSE), "FB.BUCKETCOMMIT.COMMITCLOSE", 114, "Pas de commit tant que les deux ne sont pas Done")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSDONE;
        s.FB.M2STATUS = s.STATUSDONE;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_false(static_cast<bool>(s.FB.MACHINEHOMINGFAILED), "FB.MACHINEHOMINGFAILED", 121, "Succes homing ne doit pas abandonner")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.BUCKETCOMMIT.COMMITCLOSE), "FB.BUCKETCOMMIT.COMMITCLOSE", 122, "Commit ferme apres les deux succes")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.BUCKETCOMMIT.COMMITOPEN), "FB.BUCKETCOMMIT.COMMITOPEN", 123, "Commit ouvert non arme")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.MACHINEHOMED), "FB.MACHINEHOMED", 124, "Machine qualifiee apres commit atomique")) return false;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::VALID, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.VALID", 125, "Etape succes")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.LIFECYCLE.DONE), "FB.LIFECYCLE.DONE", 126, "Lifecycle.Done apres commit")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-040 : abandon si capteur haut perdu pendant la transaction'
bool test_10(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMCLOSEPOSITION = false;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMCLOSEPOSITION = true;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = false;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSBUSY;
        s.FB.M2STATUS = s.STATUSBUSY;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(s.FB.MACHINEHOMINGFAILED), "FB.MACHINEHOMINGFAILED", 143, "Perte capteur haut => abandon")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.MACHINEHOMINGACTIVE), "FB.MACHINEHOMINGACTIVE", 144, "Transaction close")) return false;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::FAILED, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.FAILED", 145, "Guide : recommencer en N2")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-041 : abandon si erreur homing M1 pendant la transaction'
bool test_11(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMCLOSEPOSITION = false;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMCLOSEPOSITION = true;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSERR;
        s.FB.M2STATUS = s.STATUSBUSY;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(s.FB.MACHINEHOMINGFAILED), "FB.MACHINEHOMINGFAILED", 160, "Erreur homing M1 => abandon")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.FAULT.LATCHED), "FB.FAULT.LATCHED", 161, "Cause erreur homing latchee")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-042 : abandon si mouvement pendant la transaction'
bool test_12(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMOPENPOSITION = false;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETOPENM = 1.0;
        s.FB();
        s.FB.ENO = true;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMOPENPOSITION = true;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETOPENM = 1.0;
        s.FB();
        s.FB.ENO = true;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = false;
        s.FB.M1STATUS = s.STATUSBUSY;
        s.FB.M2STATUS = s.STATUSBUSY;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETOPENM = 1.0;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(s.FB.MACHINEHOMINGFAILED), "FB.MACHINEHOMINGFAILED", 176, "Mouvement pendant transaction => abandon")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-050 : Confirm ouverte ET fermee au meme scan => aucune transaction + cause latchee'
bool test_13(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.CONFIRMOPENPOSITION = false;
        s.FB.CONFIRMCLOSEPOSITION = false;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETOPENM = 1.0;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.CONFIRMOPENPOSITION = true;
        s.FB.CONFIRMCLOSEPOSITION = true;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETOPENM = 1.0;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_false(static_cast<bool>(s.FB.M1DEMAND.HOMEREQ), "FB.M1DEMAND.HOMEREQ", 191, "Double confirmation => aucun homing")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.MACHINEHOMINGACTIVE), "FB.MACHINEHOMINGACTIVE", 192, "Double confirmation => aucune transaction")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.FAULT.LATCHED), "FB.FAULT.LATCHED", 193, "Cause double confirmation latchee")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-060 : confirmation ignoree si un homing d axe est deja Busy'
bool test_14(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMCLOSEPOSITION = false;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSBUSY;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMCLOSEPOSITION = true;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_false(static_cast<bool>(s.FB.MACHINEHOMINGACTIVE), "FB.MACHINEHOMINGACTIVE", 206, "Pas de transaction au vol sur homing d axe en cours")) return false;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::HOMING_IN_PROGRESS, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.HOMING_IN_PROGRESS", 207, "Guide : homing d axe en cours")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-070 : perte reference en mouvement => SafeStop, puis pas de requalification auto'
bool test_15(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.BUCKETOFFSETVALID = true;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(s.FB.MACHINEHOMED), "FB.MACHINEHOMED", 217, "Datum valide au depart")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = false;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.BUCKETOFFSETVALID = true;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(s.FB.MACHINEHOMINGLOSSSAFESTOP), "FB.MACHINEHOMINGLOSSSAFESTOP", 223, "Perte M1 en mouvement => arret controle")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.MACHINEHOMED), "FB.MACHINEHOMED", 224, "Datum invalide")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.BUCKETOFFSETVALID = true;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_false(static_cast<bool>(s.FB.MACHINEHOMED), "FB.MACHINEHOMED", 230, "C-1 : pas de requalification automatique sans Reset conscient")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.MACHINEHOMINGLOSSSAFESTOP), "FB.MACHINEHOMINGLOSSSAFESTOP", 231, "SafeStop leve apres arret mecanique")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = true;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSHOMED;
        s.FB.M2STATUS = s.STATUSHOMED;
        s.FB.BUCKETOFFSETVALID = true;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(s.FB.MACHINEHOMED), "FB.MACHINEHOMED", 237, "Apres Reset conscient, datum re-qualifie")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.FAULT.LATCHED), "FB.FAULT.LATCHED", 238, "Reset efface la cause latchee")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T185-080 : Enable FALSE en pleine transaction => retour IDLE, sorties sures'
bool test_16(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMCLOSEPOSITION = false;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CONFIRMCLOSEPOSITION = true;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(s.FB.MACHINEHOMINGACTIVE), "FB.MACHINEHOMINGACTIVE", 251, "Transaction armee")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = false;
        s.FB.RESET = false;
        s.FB.MODE = E_MODE::MAINT_N2;
        s.FB.TOPPOSITIONACTIVE = true;
        s.FB.WINCHESMECHANICALLYSTOPPED = true;
        s.FB.M1STATUS = s.STATUSNONE;
        s.FB.M2STATUS = s.STATUSNONE;
        s.FB.CFGTOPHOMINGTARGETM = 8.5;
        s.FB.CFGOFFSETCLOSEM = 3.0;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_eq(s.FB.MACHINEHOMINGSTEP, E_MACHINEHOMINGSTEP::IDLE, "FB.MACHINEHOMINGSTEP", "E_MACHINEHOMINGSTEP.IDLE", 256, "Enable FALSE => IDLE")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.M1DEMAND.HOMEREQ), "FB.M1DEMAND.HOMEREQ", 257, "Enable FALSE => demandes sures")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.MACHINEHOMED), "FB.MACHINEHOMED", 258, "Enable FALSE => non qualifie")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

int main(int argc, char* argv[]) {
    bool json_mode = false;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--json") == 0) { json_mode = true; break; }
    }

    strucpp::TestRunner runner("test_fb_machinehomingcycle.st");
    runner.set_json_mode(json_mode);
    runner.add("TC-T185-001 : machine non qualifiee avec 2 codeurs seuls (offset benne absent)", test_1);
    runner.add("TC-T185-010 : M1 non reference => M1_NOT_HOMED", test_2);
    runner.add("TC-T185-011 : M2 non reference => M2_NOT_HOMED", test_3);
    runner.add("TC-T185-012 : les deux non references => BOTH_NOT_HOMED", test_4);
    runner.add("TC-T185-020 : codeurs OK, offset absent, N2 sans capteur haut => NEED_TOP_POSITION", test_5);
    runner.add("TC-T185-021 : capteur haut atteint mais treuils non arretes => NEED_MECHANICAL_STOP", test_6);
    runner.add("TC-T185-022 : fenetre sure => AWAIT_BUCKET_CONFIRM", test_7);
    runner.add("TC-T185-030 : confirmation refusee hors MAINT_N2", test_8);
    runner.add("TC-T185-031 : confirmation fermee admissible => homing M1+M2, cible M2 = top + offset ferme, commit atomique", test_9);
    runner.add("TC-T185-040 : abandon si capteur haut perdu pendant la transaction", test_10);
    runner.add("TC-T185-041 : abandon si erreur homing M1 pendant la transaction", test_11);
    runner.add("TC-T185-042 : abandon si mouvement pendant la transaction", test_12);
    runner.add("TC-T185-050 : Confirm ouverte ET fermee au meme scan => aucune transaction + cause latchee", test_13);
    runner.add("TC-T185-060 : confirmation ignoree si un homing d axe est deja Busy", test_14);
    runner.add("TC-T185-070 : perte reference en mouvement => SafeStop, puis pas de requalification auto", test_15);
    runner.add("TC-T185-080 : Enable FALSE en pleine transaction => retour IDLE, sorties sures", test_16);
    return runner.run();
}
