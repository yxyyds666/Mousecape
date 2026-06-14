//
//  MCWindowsCursorFrame.h
//  Mousecape
//

#import <Cocoa/Cocoa.h>

@interface MCWindowsCursorFrame : NSObject

@property (nonatomic, readonly, strong) NSBitmapImageRep *imageRep;
@property (nonatomic, readonly, assign) NSPoint hotSpot;
@property (nonatomic, readonly, assign) NSTimeInterval duration;
@property (nonatomic, readonly, assign) NSSize nominalSize;

- (instancetype)initWithImageRep:(NSBitmapImageRep *)imageRep
                         hotSpot:(NSPoint)hotSpot
                        duration:(NSTimeInterval)duration;

- (instancetype)initWithImageRep:(NSBitmapImageRep *)imageRep
                         hotSpot:(NSPoint)hotSpot
                        duration:(NSTimeInterval)duration
                     nominalSize:(NSSize)nominalSize;

@end
