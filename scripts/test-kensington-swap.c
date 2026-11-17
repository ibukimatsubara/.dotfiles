#include <assert.h>
#include <stdio.h>
#include "../hammerspoon/kensington_swap.c"

static bool test_source_known;

static IOHIDEventRef test_copy_hid(CGEventRef event) {
    (void)event;
    return test_source_known ? (IOHIDEventRef)CFRetain(kCFBooleanTrue) : NULL;
}

static uint64_t test_sender_id(IOHIDEventRef event) {
    (void)event;
    return 42;
}

static void gesture_event(KensingtonTap *state, CGEventType input, unsigned source,
                          CGEventType expected) {
    test_source_known = source != 0;
    state->copy_hid = test_copy_hid;
    state->sender_id = test_sender_id;
    if (test_source_known) {
        state->last_sender = 42;
        state->last_vendor = source == 1 ? 0x047d : 0x3151;
        state->last_product = source == 1 ? 0x80d6 : 0x3020;
    }
    CGMouseButton button = input >= kCGEventRightMouseDown && input <= kCGEventRightMouseUp
        ? kCGMouseButtonRight : input == kCGEventRightMouseDragged
        ? kCGMouseButtonRight : kCGMouseButtonLeft;
    CGEventRef event = CGEventCreateMouseEvent(NULL, input, CGPointMake(10, 20), button);
    assert(event);
    CFDataRef before = CGEventCreateData(NULL, event);
    assert(tap_callback(NULL, input, event, state) == event);
    if (CGEventGetType(event) != expected) {
        fprintf(stderr, "FAIL gesture: input=%u source=%u expected=%u actual=%u\n",
                input, source, expected, CGEventGetType(event));
        assert(CGEventGetType(event) == expected);
    }
    if (input == expected) {
        CFDataRef after = CGEventCreateData(NULL, event);
        assert(CFEqual(before, after));
        CFRelease(after);
    } else {
        assert(CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) == 1 - button);
    }
    CFRelease(before);
    CFRelease(event);
}

static void test_gestures(void) {
    KensingtonTap state = {0};
    gesture_event(&state, kCGEventRightMouseDown, 1, kCGEventLeftMouseDown);
    gesture_event(&state, kCGEventRightMouseDragged, 0, kCGEventLeftMouseDragged);
    gesture_event(&state, kCGEventRightMouseUp, 1, kCGEventLeftMouseUp);
    assert(state.unknown[5] == 1 && state.target[5] == 0);
    gesture_event(&state, kCGEventRightMouseDragged, 0, kCGEventRightMouseDragged);
    gesture_event(&state, kCGEventLeftMouseDown, 1, kCGEventRightMouseDown);
    gesture_event(&state, kCGEventLeftMouseDragged, 0, kCGEventRightMouseDragged);
    gesture_event(&state, kCGEventLeftMouseUp, 0, kCGEventRightMouseUp);
    gesture_event(&state, kCGEventLeftMouseDragged, 0, kCGEventLeftMouseDragged);
    gesture_event(&state, kCGEventLeftMouseDown, 2, kCGEventLeftMouseDown);
    gesture_event(&state, kCGEventLeftMouseDragged, 0, kCGEventLeftMouseDragged);
    gesture_event(&state, kCGEventLeftMouseUp, 2, kCGEventLeftMouseUp);
    gesture_event(&state, kCGEventRightMouseDown, 0, kCGEventRightMouseDown);
    gesture_event(&state, kCGEventRightMouseDragged, 0, kCGEventRightMouseDragged);
    gesture_event(&state, kCGEventRightMouseUp, 0, kCGEventRightMouseUp);
    gesture_event(&state, kCGEventLeftMouseDown, 1, kCGEventRightMouseDown);
    gesture_event(&state, kCGEventRightMouseDown, 1, kCGEventLeftMouseDown);
    gesture_event(&state, kCGEventLeftMouseDragged, 0, kCGEventRightMouseDragged);
    gesture_event(&state, kCGEventRightMouseDragged, 0, kCGEventLeftMouseDragged);
    gesture_event(&state, kCGEventLeftMouseUp, 1, kCGEventRightMouseUp);
    gesture_event(&state, kCGEventRightMouseDragged, 0, kCGEventLeftMouseDragged);
    gesture_event(&state, kCGEventRightMouseUp, 1, kCGEventLeftMouseUp);
    gesture_event(&state, kCGEventRightMouseDown, 1, kCGEventLeftMouseDown);
    gesture_event(&state, kCGEventLeftMouseDown, 2, kCGEventLeftMouseDown);
    gesture_event(&state, kCGEventLeftMouseUp, 2, kCGEventLeftMouseUp);
    gesture_event(&state, kCGEventRightMouseDragged, 0, kCGEventLeftMouseDragged);
    gesture_event(&state, kCGEventRightMouseUp, 1, kCGEventLeftMouseUp);
    gesture_event(&state, kCGEventRightMouseDown, 1, kCGEventLeftMouseDown);
    release_tap(&state);
    gesture_event(&state, kCGEventRightMouseDragged, 0, kCGEventRightMouseDragged);
    state.listen_only = true;
    gesture_event(&state, kCGEventRightMouseDown, 1, kCGEventRightMouseDown);
    gesture_event(&state, kCGEventRightMouseDragged, 0, kCGEventRightMouseDragged);
    gesture_event(&state, kCGEventRightMouseUp, 1, kCGEventRightMouseUp);
    puts("PASS callback gestures: source-less drag/up, pen isolation, independent buttons, stop, observer");
}

int main(void) {
    const CGEventType pairs[][2] = {
        {kCGEventLeftMouseDown, kCGEventRightMouseDown},
        {kCGEventLeftMouseUp, kCGEventRightMouseUp},
        {kCGEventLeftMouseDragged, kCGEventRightMouseDragged},
        {kCGEventRightMouseDown, kCGEventLeftMouseDown},
        {kCGEventRightMouseUp, kCGEventLeftMouseUp},
        {kCGEventRightMouseDragged, kCGEventLeftMouseDragged},
    };
    unsigned checks = 0;
    for (unsigned i = 0; i < 6; ++i) {
        CGMouseButton before = i < 3 ? kCGMouseButtonLeft : kCGMouseButtonRight;
        CGEventRef event = CGEventCreateMouseEvent(NULL, pairs[i][0], CGPointMake(123, 456), before);
        assert(event);
        CGEventSetIntegerValueField(event, kCGMouseEventClickState, 2);
        CGEventSetIntegerValueField(event, kCGMouseEventDeltaX, 17);
        CGEventSetIntegerValueField(event, kCGMouseEventDeltaY, -9);
        CGEventSetDoubleValueField(event, kCGMouseEventPressure, 0.5);
        CGEventSetFlags(event, kCGEventFlagMaskAlternate);
        CGEventSetTimestamp(event, 123456789);
        double pressure = CGEventGetDoubleValueField(event, kCGMouseEventPressure);
        assert(kensington_transform(event, 0x047d, 0x80d6));
        assert(CGEventGetType(event) == pairs[i][1]);
        assert(CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) == 1 - before);
        CGPoint location = CGEventGetLocation(event);
        assert(location.x == 123 && location.y == 456);
        assert(CGEventGetIntegerValueField(event, kCGMouseEventClickState) == 2);
        assert(CGEventGetIntegerValueField(event, kCGMouseEventDeltaX) == 17);
        assert(CGEventGetIntegerValueField(event, kCGMouseEventDeltaY) == -9);
        assert(CGEventGetDoubleValueField(event, kCGMouseEventPressure) == pressure);
        assert(CGEventGetFlags(event) == kCGEventFlagMaskAlternate);
        assert(CGEventGetTimestamp(event) == 123456789);
        CFRelease(event);
        ++checks;
    }
    const uint32_t others[][2] = {{0x3151, 0x3020}, {0x047d, 0x80d7}, {0x1234, 0x80d6}, {0, 0}};
    for (unsigned j = 0; j < 4; ++j) {
        for (unsigned i = 0; i < 6; ++i) {
            CGMouseButton button = i < 3 ? kCGMouseButtonLeft : kCGMouseButtonRight;
            CGEventRef event = CGEventCreateMouseEvent(NULL, pairs[i][0], CGPointMake(10, 20), button);
            CFDataRef before = CGEventCreateData(NULL, event);
            assert(!kensington_transform(event, others[j][0], others[j][1]));
            CFDataRef after = CGEventCreateData(NULL, event);
            assert(CFEqual(before, after));
            CFRelease(before); CFRelease(after); CFRelease(event);
            ++checks;
        }
    }
    const CGEventType untouched[] = {kCGEventMouseMoved, kCGEventScrollWheel, kCGEventOtherMouseDown,
        kCGEventOtherMouseUp, kCGEventOtherMouseDragged, kCGEventKeyDown};
    for (unsigned i = 0; i < sizeof(untouched) / sizeof(untouched[0]); ++i) {
        CGEventRef event = CGEventCreate(NULL);
        CGEventSetType(event, untouched[i]);
        CGEventSetIntegerValueField(event, kCGMouseEventButtonNumber, 2);
        CFDataRef before = CGEventCreateData(NULL, event);
        assert(!kensington_transform(event, 0x047d, 0x80d6));
        CFDataRef after = CGEventCreateData(NULL, event);
        assert(CFEqual(before, after));
        CFRelease(before); CFRelease(after); CFRelease(event);
        ++checks;
    }
    printf("PASS Kensington transform: %u cases; no events posted\n", checks);
    test_gestures();
    return 0;
}
