//
//  MCWindowsCursorImportResult.m
//  Mousecape
//

#import "MCWindowsCursorImportResult.h"

#import "MCCursorLibrary.h"

@interface MCWindowsCursorImportResult ()

@property (nonatomic, readwrite, strong) MCCursorLibrary *cursorLibrary;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *warnings;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *skippedRoles;
@property (nonatomic, readwrite, copy) NSArray<NSError *> *errors;

@end

@implementation MCWindowsCursorImportResult

- (instancetype)initWithCursorLibrary:(MCCursorLibrary *)cursorLibrary
                             warnings:(NSArray<NSString *> *)warnings
                         skippedRoles:(NSArray<NSString *> *)skippedRoles
                               errors:(NSArray<NSError *> *)errors {
    if ((self = [super init])) {
        self.cursorLibrary = cursorLibrary;
        self.warnings = warnings ?: @[];
        self.skippedRoles = skippedRoles ?: @[];
        self.errors = errors ?: @[];
    }

    return self;
}

- (BOOL)isSuccessful {
    return self.errors.count == 0;
}

@end
