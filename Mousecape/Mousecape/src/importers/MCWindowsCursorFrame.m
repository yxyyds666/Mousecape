//
//  MCWindowsCursorFrame.m
//  Mousecape
//

#import "MCWindowsCursorFrame.h"

@interface MCWindowsCursorFrame ()

@property (nonatomic, readwrite, strong) NSBitmapImageRep *imageRep;
@property (nonatomic, readwrite, assign) NSPoint hotSpot;
@property (nonatomic, readwrite, assign) NSTimeInterval duration;
@property (nonatomic, readwrite, assign) NSSize nominalSize;

@end

@implementation MCWindowsCursorFrame

- (instancetype)initWithImageRep:(NSBitmapImageRep *)imageRep
                         hotSpot:(NSPoint)hotSpot
                        duration:(NSTimeInterval)duration {
    return [self initWithImageRep:imageRep
                          hotSpot:hotSpot
                         duration:duration
                      nominalSize:NSMakeSize(imageRep.pixelsWide, imageRep.pixelsHigh)];
}

- (instancetype)initWithImageRep:(NSBitmapImageRep *)imageRep
                         hotSpot:(NSPoint)hotSpot
                        duration:(NSTimeInterval)duration
                     nominalSize:(NSSize)nominalSize {
    if ((self = [super init])) {
        self.imageRep = imageRep;
        self.hotSpot = hotSpot;
        self.duration = duration;
        self.nominalSize = nominalSize;
    }

    return self;
}

@end
