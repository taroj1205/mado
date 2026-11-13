#import "TouchPosition.h"

NSPoint MadoTouchPosition(NSTouch *touch) {
    @try {
        return touch.normalizedPosition;
    } @catch (NSException *exception) {
        return NSMakePoint(NAN, NAN);
    }
}
