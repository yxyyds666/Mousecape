//
//  MCAniParser.h
//  Mousecape
//

#import <Foundation/Foundation.h>

@class MCWindowsCursorFrame;

@interface MCAniParser : NSObject

+ (NSArray<MCWindowsCursorFrame *> *)framesFromData:(NSData *)data error:(NSError **)error;

@end
