//
//  MCCurParser.h
//  Mousecape
//

#import <Foundation/Foundation.h>

@class MCWindowsCursorFrame;

@interface MCCurParser : NSObject

+ (NSArray<MCWindowsCursorFrame *> *)framesFromData:(NSData *)data error:(NSError **)error;

@end
