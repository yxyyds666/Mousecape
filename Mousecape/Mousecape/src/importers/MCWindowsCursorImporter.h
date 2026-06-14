//
//  MCWindowsCursorImporter.h
//  Mousecape
//

#import <Foundation/Foundation.h>

@class MCWindowsCursorImportResult;

@interface MCWindowsCursorImporter : NSObject

+ (MCWindowsCursorImportResult *)importCursorAtURL:(NSURL *)url error:(NSError **)error;

@end
