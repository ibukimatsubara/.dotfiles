#include <assert.h>
#include <stdio.h>
#include "../hammerspoon/kensington_swap.c"

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
    return 0;
}
