#include "generated.hpp"
#include "iec_test.hpp"
#include <cstring>

using namespace strucpp;

struct TestSetup_1 {
    FB_SAFETY_EMERGENCYMANAGEMENT FB;

    void setup() {
    }

    void teardown() {
    }
};

// TEST 'bit3 StartupFail latched via FB_FaultCore (correction bug)'
bool test_1(strucpp::TestContext& ctx) {
    TestSetup_1 s;
    s.setup();
    bool __passed = [&]() -> bool {
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.ARMREQUEST = false;
        s.FB.POWERCUTOFFREQUEST = false;
        s.FB.BTNEMERGENCYCUTOFF = false;
        s.FB.EMERGENCYCHAINCLOSED = false;
        s.FB.POWERCONTACTORENGAGED = false;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(s.FB.STATUS.DIAG.ERROR), "FB.STATUS.DIAG.ERROR", 10, "StartupFail -> Error actif")) return false;
        if (!ctx.assert_true(static_cast<bool>(((s.FB.STATUS.FAULT.LATCHEDID) & (0x0008)) != 0x0000), "(FB.STATUS.FAULT.LATCHEDID AND 16#0008) <> 16#0000", 11, "bit3 StartupFail latche")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = false;
        s.FB.ARMREQUEST = false;
        s.FB.POWERCUTOFFREQUEST = false;
        s.FB.BTNEMERGENCYCUTOFF = false;
        s.FB.EMERGENCYCHAINCLOSED = true;
        s.FB.POWERCONTACTORENGAGED = false;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_true(static_cast<bool>(((s.FB.STATUS.FAULT.LATCHEDID) & (0x0008)) != 0x0000), "(FB.STATUS.FAULT.LATCHEDID AND 16#0008) <> 16#0000", 15, "bit3 reste latche sans Reset (correction bug bit3)")) return false;
        strucpp::__CURRENT_TIME_NS += static_cast<int64_t>(10000000);
        s.FB.ENABLE = true;
        s.FB.RESET = true;
        s.FB.ARMREQUEST = false;
        s.FB.POWERCUTOFFREQUEST = false;
        s.FB.BTNEMERGENCYCUTOFF = false;
        s.FB.EMERGENCYCHAINCLOSED = true;
        s.FB.POWERCONTACTORENGAGED = false;
        s.FB();
        s.FB.ENO = true;
        if (!ctx.assert_false(static_cast<bool>(((s.FB.STATUS.FAULT.LATCHEDID) & (0x0008)) != 0x0000), "(FB.STATUS.FAULT.LATCHEDID AND 16#0008) <> 16#0000", 19, "Reset efface le latch bit3")) return false;
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

    strucpp::TestRunner runner("test_bit3_latch.st");
    runner.set_json_mode(json_mode);
    runner.add("bit3 StartupFail latched via FB_FaultCore (correction bug)", test_1);
    return runner.run();
}
