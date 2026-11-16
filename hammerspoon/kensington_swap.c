#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <IOKit/IOKitLib.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>

/* Private SPI is not in the SDK. A missing symbol fails closed and does not prompt. */
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef IOHIDEventRef (*CopyIOHIDEventFn)(CGEventRef event);
typedef uint64_t (*IOHIDSenderIDFn)(IOHIDEventRef event);

static const uint32_t k_target_vendor = 0x047du;
static const uint32_t k_target_product = 0x80d6u;
static const char k_metatable[] = "kensington_swap";
enum { k_swap_count = 6 };

typedef struct {
    CGEventType from;
    CGEventType to;
    int64_t button;
    const char *count_key;
} SwapEntry;

static const SwapEntry k_swaps[k_swap_count] = {
    {kCGEventLeftMouseDown, kCGEventRightMouseDown, kCGMouseButtonRight, "leftDown"},
    {kCGEventLeftMouseUp, kCGEventRightMouseUp, kCGMouseButtonRight, "leftUp"},
    {kCGEventLeftMouseDragged, kCGEventRightMouseDragged, kCGMouseButtonRight, "leftDragged"},
    {kCGEventRightMouseDown, kCGEventLeftMouseDown, kCGMouseButtonLeft, "rightDown"},
    {kCGEventRightMouseUp, kCGEventLeftMouseUp, kCGMouseButtonLeft, "rightUp"},
    {kCGEventRightMouseDragged, kCGEventLeftMouseDragged, kCGMouseButtonLeft, "rightDragged"},
};

typedef struct {
    CFMachPortRef tap;
    CFRunLoopSourceRef source;
    bool listen_only;
    CopyIOHIDEventFn copy_hid;
    IOHIDSenderIDFn sender_id;
    uint64_t target[k_swap_count];
    uint64_t other[k_swap_count];
    uint64_t unknown[k_swap_count];
    uint64_t last_sender;
    uint32_t last_vendor;
    uint32_t last_product;
} KensingtonTap;

/* No held-button tracking: both buttons must be up before stop/reload, or macOS keeps the pre-swap button down. */
bool kensington_transform(CGEventRef event, uint32_t vendor_id, uint32_t product_id) {
    if (!event || vendor_id != k_target_vendor || product_id != k_target_product) return false;
    CGEventType type = CGEventGetType(event);
    for (unsigned i = 0; i < k_swap_count; ++i) {
        if (k_swaps[i].from != type) continue;
        CGEventSetType(event, k_swaps[i].to);
        CGEventSetIntegerValueField(event, kCGMouseEventButtonNumber, k_swaps[i].button);
        return true;
    }
    return false;
}

static int swap_index(CGEventType type) {
    for (unsigned i = 0; i < k_swap_count; ++i) {
        if (k_swaps[i].from == type) return (int)i;
    }
    return -1;
}

static CGEventMask swap_mask(void) {
    CGEventMask mask = 0;
    for (unsigned i = 0; i < k_swap_count; ++i) mask |= CGEventMaskBit(k_swaps[i].from);
    return mask;
}

static bool copy_u32_property(io_registry_entry_t entry, CFStringRef key, uint32_t *out) {
    CFTypeRef value = IORegistryEntryCreateCFProperty(entry, key, kCFAllocatorDefault, 0);
    if (!value) return false;
    bool ok = false;
    if (CFGetTypeID(value) == CFNumberGetTypeID()) {
        int64_t number = 0;
        if (CFNumberGetValue(value, kCFNumberSInt64Type, &number) && number >= 0 && number <= UINT32_MAX) {
            *out = (uint32_t)number;
            ok = true;
        }
    }
    CFRelease(value);
    return ok;
}

static bool lookup_vendor_product(uint64_t sender_id, uint32_t *vendor_id, uint32_t *product_id) {
    CFMutableDictionaryRef matching = IORegistryEntryIDMatching(sender_id);
    if (!matching) return false;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, matching);
    if (!service) return false;
    uint32_t vendor = 0;
    uint32_t product = 0;
    bool ok = copy_u32_property(service, CFSTR("VendorID"), &vendor)
        && copy_u32_property(service, CFSTR("ProductID"), &product);
    IOObjectRelease(service);
    if (!ok) return false;
    *vendor_id = vendor;
    *product_id = product;
    return true;
}

static bool identify_event(KensingtonTap *state, CGEventRef event, uint64_t *sender_id,
                           uint32_t *vendor_id, uint32_t *product_id) {
    *sender_id = 0;
    *vendor_id = 0;
    *product_id = 0;
    if (!state->copy_hid || !state->sender_id) return false;
    IOHIDEventRef hid = state->copy_hid(event);
    if (!hid) return false;
    uint64_t sender = state->sender_id(hid);
    CFRelease(hid);
    *sender_id = sender;
    if (sender == 0) return false;
    if (sender == state->last_sender) {
        *vendor_id = state->last_vendor;
        *product_id = state->last_product;
        return true;
    }
    return lookup_vendor_product(sender, vendor_id, product_id);
}

static void release_tap(KensingtonTap *state) {
    if (!state->tap && !state->source) {
        state->listen_only = false;
        return;
    }
    if (state->tap && CGEventTapIsEnabled(state->tap)) CGEventTapEnable(state->tap, false);
    if (state->tap) CFMachPortInvalidate(state->tap);
    if (state->source) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), state->source, kCFRunLoopCommonModes);
        CFRelease(state->source);
        state->source = NULL;
    }
    if (state->tap) {
        CFRelease(state->tap);
        state->tap = NULL;
    }
    state->listen_only = false;
}

static CGEventRef tap_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    (void)proxy;
    KensingtonTap *state = refcon;
    if (!state) return event;
    /* Timeout/user-input disables this port. Re-enable it; do not create another tap. */
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (state->tap) CGEventTapEnable(state->tap, true);
        return event;
    }
    int index = swap_index(type);
    if (index < 0 || !event) return event;

    uint64_t sender_id = 0;
    uint32_t vendor_id = 0;
    uint32_t product_id = 0;
    bool known = identify_event(state, event, &sender_id, &vendor_id, &product_id);
    if (!known) {
        state->unknown[index] += 1;
        return event;
    }
    state->last_sender = sender_id;
    state->last_vendor = vendor_id;
    state->last_product = product_id;
    if (vendor_id == k_target_vendor && product_id == k_target_product) {
        state->target[index] += 1;
        if (!state->listen_only) kensington_transform(event, vendor_id, product_id);
    } else {
        state->other[index] += 1;
    }
    return event;
}

static KensingtonTap *check_state(lua_State *L) {
    return luaL_checkudata(L, 1, k_metatable);
}

static int fail(lua_State *L, const char *message) {
    lua_pushnil(L);
    lua_pushstring(L, message);
    return 2;
}

static int l_start(lua_State *L) {
    KensingtonTap *state = check_state(L);
    bool listen_only = false;
    if (lua_gettop(L) >= 2 && !lua_isnil(L, 2)) {
        luaL_checktype(L, 2, LUA_TBOOLEAN);
        listen_only = lua_toboolean(L, 2);
    }
    if (state->tap) {
        if (state->listen_only == listen_only) {
            lua_settop(L, 1);
            return 1;
        }
        return fail(L, "stop before changing listenOnly");
    }

    CopyIOHIDEventFn copy_hid = (CopyIOHIDEventFn)dlsym(RTLD_DEFAULT, "CGEventCopyIOHIDEvent");
    IOHIDSenderIDFn sender_id = (IOHIDSenderIDFn)dlsym(RTLD_DEFAULT, "IOHIDEventGetSenderID");
    if (!copy_hid) return fail(L, "CGEventCopyIOHIDEvent unavailable");
    if (!sender_id) return fail(L, "IOHIDEventGetSenderID unavailable");

    CGEventTapOptions options = listen_only ? kCGEventTapOptionListenOnly : kCGEventTapOptionDefault;
    CFMachPortRef tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, options,
                                         swap_mask(), tap_callback, state);
    if (!tap) return fail(L, "event tap creation failed");
    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(NULL, tap, 0);
    if (!source) {
        CFMachPortInvalidate(tap);
        CFRelease(tap);
        return fail(L, "run loop source creation failed");
    }

    state->copy_hid = copy_hid;
    state->sender_id = sender_id;
    state->tap = tap;
    state->source = source;
    state->listen_only = listen_only;
    CGEventTapEnable(tap, true);
    CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
    lua_settop(L, 1);
    return 1;
}

static int l_stop(lua_State *L) {
    release_tap(check_state(L));
    lua_settop(L, 1);
    return 1;
}

static int l_gc(lua_State *L) {
    release_tap(check_state(L));
    return 0;
}

static void push_counts(lua_State *L, const uint64_t counts[k_swap_count]) {
    lua_createtable(L, 0, k_swap_count);
    for (unsigned i = 0; i < k_swap_count; ++i) {
        lua_pushinteger(L, (lua_Integer)counts[i]);
        lua_setfield(L, -2, k_swaps[i].count_key);
    }
}

static void push_sender_id(lua_State *L, uint64_t sender_id) {
    char text[32];
    snprintf(text, sizeof text, "0x%llx", (unsigned long long)sender_id);
    lua_pushstring(L, text);
}

static int l_status(lua_State *L) {
    KensingtonTap *state = check_state(L);
    lua_createtable(L, 0, 8);
    lua_pushboolean(L, state->tap != NULL && CGEventTapIsEnabled(state->tap));
    lua_setfield(L, -2, "running");
    lua_pushboolean(L, state->listen_only);
    lua_setfield(L, -2, "listenOnly");
    push_counts(L, state->target);
    lua_setfield(L, -2, "target");
    push_counts(L, state->other);
    lua_setfield(L, -2, "other");
    push_counts(L, state->unknown);
    lua_setfield(L, -2, "unknown");
    if (state->last_sender != 0) {
        lua_pushinteger(L, (lua_Integer)state->last_vendor);
        lua_setfield(L, -2, "lastVendorID");
        lua_pushinteger(L, (lua_Integer)state->last_product);
        lua_setfield(L, -2, "lastProductID");
        push_sender_id(L, state->last_sender);
        lua_setfield(L, -2, "lastSenderID");
    } else {
        lua_pushnil(L);
        lua_setfield(L, -2, "lastVendorID");
        lua_pushnil(L);
        lua_setfield(L, -2, "lastProductID");
        lua_pushnil(L);
        lua_setfield(L, -2, "lastSenderID");
    }
    return 1;
}

static const luaL_Reg k_methods[] = {
    {"start", l_start},
    {"stop", l_stop},
    {"status", l_status},
    {"__gc", l_gc},
    {NULL, NULL},
};

int luaopen_kensington_swap(lua_State *L) {
    KensingtonTap *state = lua_newuserdatauv(L, sizeof(*state), 0);
    memset(state, 0, sizeof(*state));
    if (luaL_newmetatable(L, k_metatable)) {
        luaL_setfuncs(L, k_methods, 0);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
    return 1;
}
