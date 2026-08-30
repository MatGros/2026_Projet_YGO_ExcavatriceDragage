#include "generated.hpp"
#include "iec_test.hpp"
static std::string __trace_fields(const strucpp::FB_CYCLETIME& fb) {
    return "\"DEFAULTVALUES\":\"" + strucpp::json_escape(strucpp::to_display_string(fb.DEFAULTVALUES)) + "\"" + "," + "\"CYCLETIMES\":\"" + strucpp::json_escape(strucpp::to_display_string(fb.CYCLETIMES)) + "\"" + "," + "\"TIMECURRENT\":\"" + strucpp::json_escape(strucpp::to_display_string(fb.TIMECURRENT)) + "\"" + "," + "\"TIMELAST\":\"" + strucpp::json_escape(strucpp::to_display_string(fb.TIMELAST)) + "\"" + "," + "\"DELTATIMEMS\":\"" + strucpp::json_escape(strucpp::to_display_string(fb.DELTATIMEMS)) + "\"" + "," + "\"INITDONE\":\"" + strucpp::json_escape(strucpp::to_display_string(fb.INITDONE)) + "\"" + "," + "\"CST_MAXCYCLEDELTAMS\":\"" + strucpp::json_escape(strucpp::to_display_string(fb.CST_MAXCYCLEDELTAMS)) + "\"";
}
static int __scan_id = 0;

#include <cstring>

using namespace strucpp;

struct TestSetup_1 {
    FB_CYCLETIME FB;

    void setup() {
    }

    void teardown() {
    }
};

// TEST 'Premier cycle retourne la valeur de secours (pas de dt mesurable)'
bool test_1(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        __scan_id = 0; const char* __test_name = "Premier cycle retourne la valeur de secours (pas de dt mesurable)";
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        if (!ctx.assert_near(s.FB.CYCLETIMES, 0.004, 0.0001, "FB.CYCLETIMES", "0.004", "0.0001", 9, "premier appel : aucun dt reel disponible, DefaultValueS renvoye tel quel")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'Cycle suivant calcule le dt reel ecoule (ms->s)'
bool test_2(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        __scan_id = 0; const char* __test_name = "Cycle suivant calcule le dt reel ecoule (ms->s)";
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        if (!ctx.assert_near(s.FB.CYCLETIMES, 0.01, 0.0001, "FB.CYCLETIMES", "0.01", "0.0001", 16, "10ms ecoulees entre les 2 appels -> 0.01s calcule (pas la valeur de secours)")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(25000000);
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        if (!ctx.assert_near(s.FB.CYCLETIMES, 0.025, 0.0001, "FB.CYCLETIMES", "0.025", "0.0001", 20, "dt variable d un cycle a l autre correctement mesure (25ms)")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(1000000000);
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        if (!ctx.assert_near(s.FB.CYCLETIMES, 1.0, 0.0001, "FB.CYCLETIMES", "1.0", "0.0001", 24, "borne haute INCLUSE : dt = 1000ms = CST_MaxCycleDeltaMs -> dt reel publie (pas secours)")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'Delta nul (deux appels sans avance horloge) : borne basse -> valeur de secours'
bool test_3(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        __scan_id = 0; const char* __test_name = "Delta nul (deux appels sans avance horloge) : borne basse -> valeur de secours";
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        if (!ctx.assert_near(s.FB.CYCLETIMES, 0.004, 0.0001, "FB.CYCLETIMES", "0.004", "0.0001", 32, "dt = 0 : anti-zero conserve, DefaultValueS publie")) return false;
        return true;
    }();
    s.teardown();
    return __passed;
}

// TEST 'Delta aberrant > plafond (5s, simule rebouclage TIME() / reprise) : borne haute -> secours, non latche'
bool test_4(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        __scan_id = 0; const char* __test_name = "Delta aberrant > plafond (5s, simule rebouclage TIME() / reprise) : borne haute -> secours, non latche";
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(5000000000);
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        if (!ctx.assert_near(s.FB.CYCLETIMES, 0.004, 0.0001, "FB.CYCLETIMES", "0.004", "0.0001", 39, "dt > CST_MaxCycleDeltaMs : artefact non propage, DefaultValueS publie")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(1001000000);
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        if (!ctx.assert_near(s.FB.CYCLETIMES, 0.004, 0.0001, "FB.CYCLETIMES", "0.004", "0.0001", 43, "borne haute EXCLUE : dt = 1001ms (juste au-dessus du plafond) -> DefaultValueS")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.DEFAULTVALUES = 0.004;
        s.FB();
        s.FB.ENO = true;
        printf("SCANTRACE {\"test\":\"%s\",\"scan\":%d,\"t_ns\":%lld,\"fields\":{%s}}\n", __test_name, __scan_id++, (long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());
        if (!ctx.assert_near(s.FB.CYCLETIMES, 0.01, 0.0001, "FB.CYCLETIMES", "0.01", "0.0001", 47, "scan suivant a dt nominal : le dt reel est de nouveau publie (secours non latche)")) return false;
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

    strucpp::TestRunner runner("test_fb_cycletime.st");
    runner.set_json_mode(json_mode);
    runner.add("Premier cycle retourne la valeur de secours (pas de dt mesurable)", test_1);
    runner.add("Cycle suivant calcule le dt reel ecoule (ms->s)", test_2);
    runner.add("Delta nul (deux appels sans avance horloge) : borne basse -> valeur de secours", test_3);
    runner.add("Delta aberrant > plafond (5s, simule rebouclage TIME() / reprise) : borne haute -> secours, non latche", test_4);
    return runner.run();
}
