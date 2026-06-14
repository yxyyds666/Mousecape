//
//  MCWindowsCursorRoleMapper.h
//  Mousecape
//

#import <Foundation/Foundation.h>

@interface MCWindowsCursorRoleMapper : NSObject

+ (NSArray<NSString *> *)mousecapeIdentifiersForWindowsRole:(NSString *)role;

@end
