//
//  MCWindowsCursorImportResult.h
//  Mousecape
//

#import <Foundation/Foundation.h>

@class MCCursorLibrary;

@interface MCWindowsCursorImportResult : NSObject

@property (nonatomic, readonly, strong) MCCursorLibrary *cursorLibrary;
@property (nonatomic, readonly, copy) NSArray<NSString *> *warnings;
@property (nonatomic, readonly, copy) NSArray<NSString *> *skippedRoles;
@property (nonatomic, readonly, copy) NSArray<NSError *> *errors;
@property (nonatomic, readonly, getter=isSuccessful) BOOL successful;

- (instancetype)initWithCursorLibrary:(MCCursorLibrary *)cursorLibrary
                             warnings:(NSArray<NSString *> *)warnings
                         skippedRoles:(NSArray<NSString *> *)skippedRoles
                               errors:(NSArray<NSError *> *)errors;

@end
