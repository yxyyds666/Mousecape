//
//  MCInfCursorThemeParser.h
//  Mousecape
//

#import <Foundation/Foundation.h>

@interface MCInfCursorThemeParser : NSObject

+ (NSDictionary<NSString *, NSString *> *)cursorRoleToFilenameMapForINFAtURL:(NSURL *)url error:(NSError **)error;

@end
