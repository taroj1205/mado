#import "TouchPosition.h"

NSPoint MadoTouchPosition(NSTouch *touch) {
    @try {
        NSPoint position = touch.normalizedPosition;
        NSSize size = touch.deviceSize;
        return NSMakePoint(position.x * size.width, position.y * size.height);
    } @catch (NSException *exception) {
        return NSMakePoint(NAN, NAN);
    }
}
