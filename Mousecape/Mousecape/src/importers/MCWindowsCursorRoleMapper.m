//
//  MCWindowsCursorRoleMapper.m
//  Mousecape
//

#import "MCWindowsCursorRoleMapper.h"

@implementation MCWindowsCursorRoleMapper

+ (NSArray<NSString *> *)mousecapeIdentifiersForWindowsRole:(NSString *)role {
    NSString *normalizedRole = [[role stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (!normalizedRole.length) {
        return @[];
    }

    static NSDictionary<NSString *, NSArray<NSString *> *> *roleMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        roleMap = @{
            @"arrow": @[@"com.apple.coregraphics.Arrow"],
            @"help": @[@"com.apple.cursor.40"],
            @"appstarting": @[@"com.apple.cursor.4"],
            @"wait": @[@"com.apple.coregraphics.Wait"],
            @"crosshair": @[@"com.apple.cursor.7", @"com.apple.cursor.8", @"com.apple.cursor.41"],
            @"ibeam": @[@"com.apple.coregraphics.IBeam"],
            @"no": @[@"com.apple.cursor.3"],
            @"sizeall": @[@"com.apple.cursor.39"],
            @"sizens": @[@"com.apple.cursor.32", @"com.apple.cursor.21", @"com.apple.cursor.22", @"com.apple.cursor.23", @"com.apple.cursor.31", @"com.apple.cursor.36"],
            @"sizewe": @[@"com.apple.cursor.28", @"com.apple.cursor.17", @"com.apple.cursor.18", @"com.apple.cursor.19", @"com.apple.cursor.27", @"com.apple.cursor.38"],
            @"sizenwse": @[@"com.apple.cursor.34", @"com.apple.cursor.33", @"com.apple.cursor.35"],
            @"sizenesw": @[@"com.apple.cursor.30", @"com.apple.cursor.29", @"com.apple.cursor.37"],
            @"uparrow": @[@"com.apple.cursor.2"],
            @"hand": @[@"com.apple.cursor.13"],
        };
    });

    return roleMap[normalizedRole] ?: @[];
}

@end
