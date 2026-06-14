//
//  MCInfCursorThemeParser.m
//  Mousecape
//

#import "MCInfCursorThemeParser.h"

#import "MCDefs.h"

static NSString *MCInfFilenameFromPath(NSString *path) {
    NSRange slashRange = [path rangeOfString:@"/" options:NSBackwardsSearch];
    NSRange backslashRange = [path rangeOfString:@"\\" options:NSBackwardsSearch];
    NSUInteger separatorLocation = NSNotFound;

    if (slashRange.location != NSNotFound) {
        separatorLocation = slashRange.location;
    }
    if (backslashRange.location != NSNotFound && (separatorLocation == NSNotFound || backslashRange.location > separatorLocation)) {
        separatorLocation = backslashRange.location;
    }

    if (separatorLocation == NSNotFound || separatorLocation + 1 >= path.length) {
        return path;
    }

    return [path substringFromIndex:separatorLocation + 1];
}

static NSString *MCInfNormalizeBackslashes(NSString *path) {
    return [path stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
}

@interface MCInfCursorThemeParser ()
+ (NSDictionary<NSString *, NSArray<NSString *> *> *)sectionsFromContent:(NSString *)content;
+ (NSDictionary<NSString *, NSString *> *)variablesFromStringsSection:(NSArray<NSString *> *)lines;
@end

@implementation MCInfCursorThemeParser

+ (NSDictionary<NSString *, NSString *> *)cursorRoleToFilenameMapForINFAtURL:(NSURL *)url error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) {
        return nil;
    }

    NSString *contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!contents) {
        contents = [[NSString alloc] initWithData:data encoding:NSWindowsCP1252StringEncoding];
    }
    if (!contents) {
        [self setError:error description:@"Unable to decode INF file."];
        return nil;
    }

    NSDictionary<NSString *, NSArray<NSString *> *> *sections = [self sectionsFromContent:contents];
    NSDictionary<NSString *, NSString *> *variables = [self variablesFromStringsSection:sections[@"Strings"]];

    NSMutableDictionary<NSString *, NSString *> *roleToFilename = [NSMutableDictionary dictionary];

    // Resolve AddReg section names from [DefaultInstall]
    NSMutableArray<NSString *> *addRegSections = [NSMutableArray array];
    for (NSString *line in sections[@"DefaultInstall"]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSRange eqRange = [trimmed rangeOfString:@"=" options:NSCaseInsensitiveSearch];
        if (eqRange.location == NSNotFound) continue;
        NSString *key = [[trimmed substringToIndex:eqRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([key caseInsensitiveCompare:@"AddReg"] != NSOrderedSame) continue;
        NSString *value = [[trimmed substringFromIndex:eqRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        for (NSString *sectionName in [value componentsSeparatedByString:@","]) {
            NSString *name = [sectionName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (name.length) {
                [addRegSections addObject:name];
            }
        }
    }

    // Also try common registry section names
    NSArray<NSString *> *fallbackSections = @[@"Wreg", @"Scheme.Reg", @"AddReg", @"Registry"];
    for (NSString *name in fallbackSections) {
        if (sections[name] && ![addRegSections containsObject:name]) {
            [addRegSections addObject:name];
        }
    }

    // Parse each AddReg section for Windows role → file_variable mappings
    for (NSString *sectionName in addRegSections) {
        NSArray<NSString *> *lines = sections[sectionName];
        if (!lines.count) continue;

        for (NSString *line in lines) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!trimmed.length || [trimmed hasPrefix:@";"]) continue;

            // Parse registry line: HKCU,"Control Panel\Cursors",RoleName,flags,"value"
            NSMutableArray<NSString *> *components = [NSMutableArray array];
            NSScanner *scanner = [NSScanner scannerWithString:trimmed];
            NSCharacterSet *commaSet = [NSCharacterSet characterSetWithCharactersInString:@","];
            NSString *temp;

            while (![scanner isAtEnd]) {
                if ([scanner scanString:@"\"" intoString:nil]) {
                    [scanner scanUpToString:@"\"" intoString:&temp];
                    [scanner scanString:@"\"" intoString:nil];
                } else {
                    [scanner scanUpToCharactersFromSet:commaSet intoString:&temp];
                }
                if (temp) [components addObject:temp];
                [scanner scanCharactersFromSet:commaSet intoString:nil];
                temp = nil;
            }

            // Need at least: hku, path, role, flags, value
            if (components.count < 5) continue;

            NSString *rawRole = components[2];
            NSString *rawValue = components[4];

            // Extract filename from value:
            //   e.g. "%10%\%CUR_DIR%\Normal.ani" or "%CUR_DIR%\Normal.ani"
            NSString *resolved = [self expandVariables:rawValue withVariables:variables];
            NSString *normalized = MCInfNormalizeBackslashes(resolved);

            // Try direct file in value
            NSString *filename = MCInfFilenameFromPath(normalized);
            NSString *ext = [[filename pathExtension] lowercaseString];

            if (![ext isEqualToString:@"cur"] && ![ext isEqualToString:@"ani"]) {
                // Value might be a bare variable reference like "%CUR_DIR%"
                // Try looking up the variable name as a [Strings] key for a .cur/.ani file
                // e.g. "Arrow" role → pointer variable → "Normal.ani" file
                NSString *varName = [self unquotedString:rawValue];
                varName = [varName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"%"]];
                if ([varName length]) {
                    // Strip path to get just the variable name
                    varName = MCInfFilenameFromPath(MCInfNormalizeBackslashes(varName));
                    NSString *lookup = variables[varName];
                    if (lookup) {
                        NSString *varExt = [[lookup pathExtension] lowercaseString];
                        if ([varExt isEqualToString:@"cur"] || [varExt isEqualToString:@"ani"]) {
                            filename = MCInfFilenameFromPath(MCInfNormalizeBackslashes(lookup));
                        }
                    }
                }
            }

            if ([ext isEqualToString:@"cur"] || [ext isEqualToString:@"ani"]) {
                roleToFilename[[rawRole lowercaseString]] = filename;
            }
        }
    }

    // Fallback: parse [Strings] section directly for variable→file mappings
    // This handles packs where [Strings] contains cursor name → filename entries
    if (!roleToFilename.count) {
        for (NSString *key in variables) {
            NSString *val = variables[key];
            NSString *ext = [[val pathExtension] lowercaseString];
            if ([ext isEqualToString:@"cur"] || [ext isEqualToString:@"ani"]) {
                // Map [Strings] variable name to Windows role name using known convention
                NSString *normalizedKey = [key lowercaseString];
                NSString *mappedRole = [self mappedRoleName:normalizedKey];
                if (mappedRole) {
                    roleToFilename[mappedRole] = MCInfFilenameFromPath(MCInfNormalizeBackslashes(val));
                }
            }
        }
    }

    return roleToFilename;
}

+ (NSDictionary<NSString *, NSArray<NSString *> *> *)sectionsFromContent:(NSString *)content {
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *sections = [NSMutableDictionary dictionary];
    NSString *currentSection = nil;

    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSString *line in [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:whitespace];
        if (!trimmed.length) continue;

        if ([trimmed hasPrefix:@"["] && [trimmed hasSuffix:@"]"]) {
            currentSection = [trimmed substringWithRange:NSMakeRange(1, trimmed.length - 2)];
            if (!sections[currentSection]) {
                sections[currentSection] = [NSMutableArray array];
            }
            continue;
        }

        if (currentSection) {
            [sections[currentSection] addObject:line];
        }
    }

    return sections;
}

+ (NSDictionary<NSString *, NSString *> *)variablesFromStringsSection:(NSArray<NSString *> *)lines {
    NSMutableDictionary<NSString *, NSString *> *variables = [NSMutableDictionary dictionary];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!trimmed.length || [trimmed hasPrefix:@";"]) continue;

        NSRange eqRange = [trimmed rangeOfString:@"="];
        if (eqRange.location == NSNotFound) continue;

        NSString *key = [[trimmed substringToIndex:eqRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *value = [[trimmed substringFromIndex:eqRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (key.length && value.length) {
            variables[key] = [self unquotedString:value];
        }
    }
    return variables;
}

+ (NSString *)expandVariables:(NSString *)string withVariables:(NSDictionary<NSString *, NSString *> *)variables {
    NSMutableString *result = [string mutableCopy];
    for (NSString *key in variables) {
        NSString *token = [NSString stringWithFormat:@"%%%@%%", key];
        [result replaceOccurrencesOfString:token
                                withString:variables[key]
                                   options:NSCaseInsensitiveSearch
                                     range:NSMakeRange(0, result.length)];
        // Also try %var without closing %
        NSString *tokenNoClose = [NSString stringWithFormat:@"%%%@", key];
        [result replaceOccurrencesOfString:tokenNoClose
                                withString:variables[key]
                                   options:NSCaseInsensitiveSearch
                                     range:NSMakeRange(0, result.length)];
    }
    return result;
}

+ (NSString *)unquotedString:(NSString *)string {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length >= 2 && [trimmed hasPrefix:@"\""] && [trimmed hasSuffix:@"\""]) {
        return [trimmed substringWithRange:NSMakeRange(1, trimmed.length - 2)];
    }
    return trimmed;
}

+ (NSString *)mappedRoleName:(NSString *)name {
    static NSDictionary<NSString *, NSString *> *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            // Direct Windows registry names
            @"arrow": @"arrow",
            @"help": @"help",
            @"appstarting": @"appstarting",
            @"wait": @"wait",
            @"crosshair": @"crosshair",
            @"ibeam": @"ibeam",
            @"no": @"no",
            @"sizeall": @"sizeall",
            @"sizens": @"sizens",
            @"sizewe": @"sizewe",
            @"sizenwse": @"sizenwse",
            @"sizenesw": @"sizenesw",
            @"uparrow": @"uparrow",
            @"hand": @"hand",
            @"nwpen": @"nwpen",
            @"person": @"person",
            @"pin": @"pin",

            // Common [Strings] variable names used by cursor packs
            @"pointer": @"arrow",
            @"working": @"appstarting",
            @"busy": @"wait",
            @"precision": @"crosshair",
            @"precisionhair": @"crosshair",
            @"text": @"ibeam",
            @"handwriting": @"hand",
            @"unavailable": @"no",
            @"vert": @"sizens",
            @"vertical": @"sizens",
            @"horz": @"sizewe",
            @"horizontal": @"sizewe",
            @"dgn1": @"sizenwse",
            @"diagonal1": @"sizenwse",
            @"dgn2": @"sizenesw",
            @"diagonal2": @"sizenesw",
            @"move": @"sizeall",
            @"alternate": @"hand",
            @"link": @"uparrow",
        };
    });
    return map[name];
}

+ (void)setError:(NSError **)error description:(NSString *)description {
    if (error) {
        *error = [NSError errorWithDomain:MCErrorDomain
                                     code:MCErrorInvalidCapeCode
                                 userInfo:@{ NSLocalizedDescriptionKey: description }];
    }
}

@end
