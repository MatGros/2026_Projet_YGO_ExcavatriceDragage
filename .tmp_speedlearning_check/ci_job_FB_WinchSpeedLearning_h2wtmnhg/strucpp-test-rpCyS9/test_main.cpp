#include "generated.hpp"
#include "iec_test.hpp"
#include <cstring>

using namespace strucpp;

struct TestSetup_1 {
    FB_WINCHSPEEDLEARNING FB;
    ST_FBWINCHSPEEDLEARNING_TABLE TABLE;
    ST_FBWINCHSPEEDLEARNING_CFG CFG;

    void setup() {
    }

    void teardown() {
    }
};

// TEST 'TC-T181-15a LearnStart=FALSE : aucune collecte, table inchangee (AC3)'
bool test_1(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.CFG.MINSPEEDMPS.at(1) = 0.5;
        s.CFG.MAXSPEEDMPS.at(1) = 2.0;
        s.CFG.MINSPEEDMPS.at(2) = 1.0;
        s.CFG.MAXSPEEDMPS.at(2) = 3.0;
        s.CFG.MINSPEEDMPS.at(3) = 1.5;
        s.CFG.MAXSPEEDMPS.at(3) = 4.0;
        s.CFG.MINSPEEDMPS.at(4) = 2.0;
        s.CFG.MAXSPEEDMPS.at(4) = 5.0;
        s.CFG.MINSPEEDMPS.at(5) = 2.5;
        s.CFG.MAXSPEEDMPS.at(5) = 6.0;
        s.CFG.MINSAMPLES = 3;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = true;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.5;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = false;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.5;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_false(static_cast<bool>(s.FB.LEARNING), "FB.LEARNING", 46, "LearnStart=FALSE : pas de collecte (Learning=FALSE)")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.LAMPLEARN), "FB.LAMPLEARN", 47, "LearnStart=FALSE : pas de voyant apprentissage")) return false;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 1, "FB.CELLSFILLED", "1", 48, "LearnStart=FALSE : aucune nouvelle cellule (CellsFilled=1)")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T181-15b Conditions de collecte manquantes une a une : aucune ecriture (AC4)'
bool test_2(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.CFG.MINSPEEDMPS.at(1) = 0.5;
        s.CFG.MAXSPEEDMPS.at(1) = 2.0;
        s.CFG.MINSPEEDMPS.at(2) = 1.0;
        s.CFG.MAXSPEEDMPS.at(2) = 3.0;
        s.CFG.MINSPEEDMPS.at(3) = 1.5;
        s.CFG.MAXSPEEDMPS.at(3) = 4.0;
        s.CFG.MINSPEEDMPS.at(4) = 2.0;
        s.CFG.MAXSPEEDMPS.at(4) = 5.0;
        s.CFG.MINSPEEDMPS.at(5) = 2.5;
        s.CFG.MAXSPEEDMPS.at(5) = 6.0;
        s.CFG.MINSAMPLES = 3;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = true;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.5;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 2;
        s.FB.MEASUREDSPEEDMPS = 1.5;
        s.FB.MEASUREDSPEEDVALID = false;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_false(static_cast<bool>(s.FB.LEARNING), "FB.LEARNING", 66, "Mesure non valide : pas de collecte")) return false;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 1, "FB.CELLSFILLED", "1", 67, "Mesure non valide : aucune nouvelle cellule")) return false;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = true;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.5;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 3;
        s.FB.MEASUREDSPEEDMPS = 1.5;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = false;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_false(static_cast<bool>(s.FB.LEARNING), "FB.LEARNING", 76, "Conditions instables : pas de collecte")) return false;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 1, "FB.CELLSFILLED", "1", 77, "Conditions instables : aucune nouvelle cellule")) return false;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = true;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.5;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 0;
        s.FB.STEPNUMBER = 4;
        s.FB.MEASUREDSPEEDMPS = 1.5;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_false(static_cast<bool>(s.FB.LEARNING), "FB.LEARNING", 86, "Sens nul : pas de collecte")) return false;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 1, "FB.CELLSFILLED", "1", 87, "Sens nul : aucune nouvelle cellule")) return false;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = true;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.5;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 0;
        s.FB.MEASUREDSPEEDMPS = 1.5;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_false(static_cast<bool>(s.FB.LEARNING), "FB.LEARNING", 96, "Palier hors 1..5 : pas de collecte")) return false;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 1, "FB.CELLSFILLED", "1", 97, "Palier hors 1..5 : aucune nouvelle cellule")) return false;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = true;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.5;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 0;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.5;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_false(static_cast<bool>(s.FB.LEARNING), "FB.LEARNING", 106, "Axe hors 1..2 : pas de collecte")) return false;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 1, "FB.CELLSFILLED", "1", 107, "Axe hors 1..2 : aucune nouvelle cellule")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T181-15c Valid seulement a MinSamples : frontiere via CellsFilled (AC2/AC5)'
bool test_3(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    IEC_INT I;
    IEC_INT J;
    IEC_INT K;
    IEC_INT L;
    bool __passed = [&]() -> bool {
        s.CFG.MINSPEEDMPS.at(1) = 0.5;
        s.CFG.MAXSPEEDMPS.at(1) = 2.0;
        s.CFG.MINSPEEDMPS.at(2) = 1.0;
        s.CFG.MAXSPEEDMPS.at(2) = 3.0;
        s.CFG.MINSPEEDMPS.at(3) = 1.5;
        s.CFG.MAXSPEEDMPS.at(3) = 4.0;
        s.CFG.MINSPEEDMPS.at(4) = 2.0;
        s.CFG.MAXSPEEDMPS.at(4) = 5.0;
        s.CFG.MINSPEEDMPS.at(5) = 2.5;
        s.CFG.MAXSPEEDMPS.at(5) = 6.0;
        s.CFG.MINSAMPLES = 3;
        for (I = 1; I <= 2; I++) {
            for (J = 1; J <= 2; J++) {
                for (K = 1; K <= 2; K++) {
                    for (L = 1; L <= 5; L++) {
                        s.TABLE.CELL.at(I).at(J).at(K).at(L).VALID = true;
                    }
                }
            }
        }
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = false;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 1;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.0;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.5;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 39, "FB.CELLSFILLED", "39", 140, "SampleCount 1->2 (<MinSamples) : cellule pas encore valide (39)")) return false;
        for (I = 1; I <= 2; I++) {
            for (J = 1; J <= 2; J++) {
                for (K = 1; K <= 2; K++) {
                    for (L = 1; L <= 5; L++) {
                        s.TABLE.CELL.at(I).at(J).at(K).at(L).VALID = true;
                    }
                }
            }
        }
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = false;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 2;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.0;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.5;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 40, "FB.CELLSFILLED", "40", 158, "SampleCount 2->3 (=MinSamples) : cellule validee (40)")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.TABLECOMPLETE), "FB.TABLECOMPLETE", 159, "MinSamples atteint sur la derniere cellule : TableComplete=TRUE")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T181-15d Hors enveloppe : cellule invalidee (Valid=FALSE, SampleCount=0, SpeedMps=0) (AC5)'
bool test_4(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.CFG.MINSPEEDMPS.at(1) = 0.5;
        s.CFG.MAXSPEEDMPS.at(1) = 2.0;
        s.CFG.MINSPEEDMPS.at(2) = 1.0;
        s.CFG.MAXSPEEDMPS.at(2) = 3.0;
        s.CFG.MINSPEEDMPS.at(3) = 1.5;
        s.CFG.MAXSPEEDMPS.at(3) = 4.0;
        s.CFG.MINSPEEDMPS.at(4) = 2.0;
        s.CFG.MAXSPEEDMPS.at(4) = 5.0;
        s.CFG.MINSPEEDMPS.at(5) = 2.5;
        s.CFG.MAXSPEEDMPS.at(5) = 6.0;
        s.CFG.MINSAMPLES = 3;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = true;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.5;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 5.0;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 0, "FB.CELLSFILLED", "0", 177, "Hors enveloppe haute : cellule invalidee (CellsFilled=0)")) return false;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = true;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.5;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 0.4;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 0, "FB.CELLSFILLED", "0", 186, "Sous borne basse : cellule invalidee (CellsFilled=0)")) return false;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = true;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.5;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 2.0;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 1, "FB.CELLSFILLED", "1", 195, "Borne ==Max (2.0) inclusive : cellule conservee validee (1)")) return false;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).VALID = true;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SPEEDMPS = 1.5;
        s.TABLE.CELL.at(1).at(1).at(1).at(1).SAMPLECOUNT = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 0.5;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 1, "FB.CELLSFILLED", "1", 204, "Borne ==Min (0.5) inclusive : cellule conservee validee (1)")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T181-15e TableComplete : FALSE si une cellule manque, TRUE avec 40 cellules valides (AC6)'
bool test_5(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    IEC_INT I;
    IEC_INT J;
    IEC_INT K;
    IEC_INT L;
    bool __passed = [&]() -> bool {
        s.CFG.MINSPEEDMPS.at(1) = 0.5;
        s.CFG.MAXSPEEDMPS.at(1) = 2.0;
        s.CFG.MINSPEEDMPS.at(2) = 1.0;
        s.CFG.MAXSPEEDMPS.at(2) = 3.0;
        s.CFG.MINSPEEDMPS.at(3) = 1.5;
        s.CFG.MAXSPEEDMPS.at(3) = 4.0;
        s.CFG.MINSPEEDMPS.at(4) = 2.0;
        s.CFG.MAXSPEEDMPS.at(4) = 5.0;
        s.CFG.MINSPEEDMPS.at(5) = 2.5;
        s.CFG.MAXSPEEDMPS.at(5) = 6.0;
        s.CFG.MINSAMPLES = 1;
        for (I = 1; I <= 2; I++) {
            for (J = 1; J <= 2; J++) {
                for (K = 1; K <= 2; K++) {
                    for (L = 1; L <= 5; L++) {
                        s.TABLE.CELL.at(I).at(J).at(K).at(L).VALID = true;
                    }
                }
            }
        }
        s.TABLE.CELL.at(2).at(2).at(2).at(5).VALID = false;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = false;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.0;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_false(static_cast<bool>(s.FB.TABLECOMPLETE), "FB.TABLECOMPLETE", 236, "Table partielle (39/40) : TableComplete=FALSE")) return false;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 39, "FB.CELLSFILLED", "39", 237, "Table partielle : CellsFilled=39")) return false;
        if (!ctx.assert_eq(s.FB.CELLSTOTAL, 40, "FB.CELLSTOTAL", "40", 238, "CellsTotal=40 (2x2x2x5)")) return false;
        s.TABLE.CELL.at(2).at(2).at(2).at(5).VALID = true;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = false;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.0;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_true(static_cast<bool>(s.FB.TABLECOMPLETE), "FB.TABLECOMPLETE", 245, "Table complete (40/40) : TableComplete=TRUE")) return false;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 40, "FB.CELLSFILLED", "40", 246, "Table complete : CellsFilled=40")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T181-15f Passivite : sorties limitees au statut/diagnostic, aucune commande moteur (AC1/AC7)'
bool test_6(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.CFG.MINSPEEDMPS.at(1) = 0.5;
        s.CFG.MAXSPEEDMPS.at(1) = 2.0;
        s.CFG.MINSPEEDMPS.at(2) = 1.0;
        s.CFG.MAXSPEEDMPS.at(2) = 3.0;
        s.CFG.MINSPEEDMPS.at(3) = 1.5;
        s.CFG.MAXSPEEDMPS.at(3) = 4.0;
        s.CFG.MINSPEEDMPS.at(4) = 2.0;
        s.CFG.MAXSPEEDMPS.at(4) = 5.0;
        s.CFG.MINSPEEDMPS.at(5) = 2.5;
        s.CFG.MAXSPEEDMPS.at(5) = 6.0;
        s.CFG.MINSAMPLES = 3;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.0;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_true(static_cast<bool>(s.FB.READY), "FB.READY", 264, "Enable=TRUE -> Ready=TRUE")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.LEARNING), "FB.LEARNING", 265, "Collecte active -> Learning=TRUE")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.LAMPLEARN), "FB.LAMPLEARN", 266, "Collecte active -> LampLearn=TRUE")) return false;
        if (!ctx.assert_eq(s.FB.CELLSTOTAL, 40, "FB.CELLSTOTAL", "40", 267, "CellsTotal=40 (diagnostic)")) return false;
        s.FB.ENABLE = false;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.0;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_false(static_cast<bool>(s.FB.READY), "FB.READY", 273, "Enable=FALSE -> Ready=FALSE")) return false;
        if (!ctx.assert_false(static_cast<bool>(s.FB.LEARNING), "FB.LEARNING", 274, "Enable=FALSE -> Learning=FALSE")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T181-15g Sens descente : cellule descente [1,2,1,1] ecrite, montee inchangee (AC2)'
bool test_7(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    IEC_INT I;
    IEC_INT J;
    IEC_INT K;
    IEC_INT L;
    bool __passed = [&]() -> bool {
        s.CFG.MINSPEEDMPS.at(1) = 0.5;
        s.CFG.MAXSPEEDMPS.at(1) = 2.0;
        s.CFG.MINSPEEDMPS.at(2) = 1.0;
        s.CFG.MAXSPEEDMPS.at(2) = 3.0;
        s.CFG.MINSPEEDMPS.at(3) = 1.5;
        s.CFG.MAXSPEEDMPS.at(3) = 4.0;
        s.CFG.MINSPEEDMPS.at(4) = 2.0;
        s.CFG.MAXSPEEDMPS.at(4) = 5.0;
        s.CFG.MINSPEEDMPS.at(5) = 2.5;
        s.CFG.MAXSPEEDMPS.at(5) = 6.0;
        s.CFG.MINSAMPLES = 1;
        for (I = 1; I <= 2; I++) {
            for (J = 1; J <= 2; J++) {
                for (K = 1; K <= 2; K++) {
                    for (L = 1; L <= 5; L++) {
                        s.TABLE.CELL.at(I).at(J).at(K).at(L).VALID = true;
                    }
                }
            }
        }
        s.TABLE.CELL.at(1).at(2).at(1).at(1).VALID = false;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = -1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.0;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 40, "FB.CELLSFILLED", "40", 306, "Descente : cellule descente [1,2,1,1] ecrite et validee (40)")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.TABLECOMPLETE), "FB.TABLECOMPLETE", 307, "Descente : table complete apres ecriture descente")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T181-15h Charge presente : cellule charge [1,1,2,1] ecrite, vide inchangee (AC2)'
bool test_8(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    IEC_INT I;
    IEC_INT J;
    IEC_INT K;
    IEC_INT L;
    bool __passed = [&]() -> bool {
        s.CFG.MINSPEEDMPS.at(1) = 0.5;
        s.CFG.MAXSPEEDMPS.at(1) = 2.0;
        s.CFG.MINSPEEDMPS.at(2) = 1.0;
        s.CFG.MAXSPEEDMPS.at(2) = 3.0;
        s.CFG.MINSPEEDMPS.at(3) = 1.5;
        s.CFG.MAXSPEEDMPS.at(3) = 4.0;
        s.CFG.MINSPEEDMPS.at(4) = 2.0;
        s.CFG.MAXSPEEDMPS.at(4) = 5.0;
        s.CFG.MINSPEEDMPS.at(5) = 2.5;
        s.CFG.MAXSPEEDMPS.at(5) = 6.0;
        s.CFG.MINSAMPLES = 1;
        for (I = 1; I <= 2; I++) {
            for (J = 1; J <= 2; J++) {
                for (K = 1; K <= 2; K++) {
                    for (L = 1; L <= 5; L++) {
                        s.TABLE.CELL.at(I).at(J).at(K).at(L).VALID = true;
                    }
                }
            }
        }
        s.TABLE.CELL.at(1).at(1).at(2).at(1).VALID = false;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 1;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.0;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = true;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 40, "FB.CELLSFILLED", "40", 339, "Charge : cellule charge [1,1,2,1] ecrite et validee (40)")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.TABLECOMPLETE), "FB.TABLECOMPLETE", 340, "Charge : table complete apres ecriture charge")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'TC-T181-15i Axe M2 (WinchId=2) : cellule [2,1,1,1] ecrite, M1 inchangee (AC2)'
bool test_9(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    IEC_INT I;
    IEC_INT J;
    IEC_INT K;
    IEC_INT L;
    bool __passed = [&]() -> bool {
        s.CFG.MINSPEEDMPS.at(1) = 0.5;
        s.CFG.MAXSPEEDMPS.at(1) = 2.0;
        s.CFG.MINSPEEDMPS.at(2) = 1.0;
        s.CFG.MAXSPEEDMPS.at(2) = 3.0;
        s.CFG.MINSPEEDMPS.at(3) = 1.5;
        s.CFG.MAXSPEEDMPS.at(3) = 4.0;
        s.CFG.MINSPEEDMPS.at(4) = 2.0;
        s.CFG.MAXSPEEDMPS.at(4) = 5.0;
        s.CFG.MINSPEEDMPS.at(5) = 2.5;
        s.CFG.MAXSPEEDMPS.at(5) = 6.0;
        s.CFG.MINSAMPLES = 1;
        for (I = 1; I <= 2; I++) {
            for (J = 1; J <= 2; J++) {
                for (K = 1; K <= 2; K++) {
                    for (L = 1; L <= 5; L++) {
                        s.TABLE.CELL.at(I).at(J).at(K).at(L).VALID = true;
                    }
                }
            }
        }
        s.TABLE.CELL.at(2).at(1).at(1).at(1).VALID = false;
        s.FB.ENABLE = true;
        s.FB.LEARNSTART = true;
        s.FB.WINCHID = 2;
        s.FB.DIRECTION = 1;
        s.FB.STEPNUMBER = 1;
        s.FB.MEASUREDSPEEDMPS = 1.0;
        s.FB.MEASUREDSPEEDVALID = true;
        s.FB.LOADPRESENT = false;
        s.FB.STABLEFORLEARN = true;
        s.FB.CONFIG = s.CFG;
        s.FB.TABLE = s.TABLE;
        s.FB();
        s.FB.ENO = true;
        s.TABLE = s.FB.TABLE;
        if (!ctx.assert_eq(s.FB.CELLSFILLED, 40, "FB.CELLSFILLED", "40", 372, "M2 : cellule [2,1,1,1] ecrite et validee (40)")) return false;
        if (!ctx.assert_true(static_cast<bool>(s.FB.TABLECOMPLETE), "FB.TABLECOMPLETE", 373, "M2 : table complete apres ecriture M2")) return false;
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

    strucpp::TestRunner runner("test_fb_winch_speed_learning.st");
    runner.set_json_mode(json_mode);
    runner.add("TC-T181-15a LearnStart=FALSE : aucune collecte, table inchangee (AC3)", test_1);
    runner.add("TC-T181-15b Conditions de collecte manquantes une a une : aucune ecriture (AC4)", test_2);
    runner.add("TC-T181-15c Valid seulement a MinSamples : frontiere via CellsFilled (AC2/AC5)", test_3);
    runner.add("TC-T181-15d Hors enveloppe : cellule invalidee (Valid=FALSE, SampleCount=0, SpeedMps=0) (AC5)", test_4);
    runner.add("TC-T181-15e TableComplete : FALSE si une cellule manque, TRUE avec 40 cellules valides (AC6)", test_5);
    runner.add("TC-T181-15f Passivite : sorties limitees au statut/diagnostic, aucune commande moteur (AC1/AC7)", test_6);
    runner.add("TC-T181-15g Sens descente : cellule descente [1,2,1,1] ecrite, montee inchangee (AC2)", test_7);
    runner.add("TC-T181-15h Charge presente : cellule charge [1,1,2,1] ecrite, vide inchangee (AC2)", test_8);
    runner.add("TC-T181-15i Axe M2 (WinchId=2) : cellule [2,1,1,1] ecrite, M1 inchangee (AC2)", test_9);
    return runner.run();
}
