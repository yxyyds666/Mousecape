//
//  MCWindowsCursorImporter.m
//  Mousecape
//

#import "MCWindowsCursorImporter.h"

#import "MCAniParser.h"
#import "MCCurParser.h"
#import "MCCursor.h"
#import "MCCursorLibrary.h"
#import "MCDefs.h"
#import "MCInfCursorThemeParser.h"
#import "MCWindowsCursorFrame.h"
#import "MCWindowsCursorImportResult.h"
#import "MCWindowsCursorRoleMapper.h"

static NSString *const MCWindowsCursorDefaultIdentifier = @"com.apple.coregraphics.Arrow";
static NSUInteger const MCWindowsCursorMaximumFrameCount = 24;

@implementation MCWindowsCursorImporter

+ (MCWindowsCursorImportResult *)importCursorAtURL:(NSURL *)url error:(NSError **)error {
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&isDirectory]) {
        [self setError:error description:NSLocalizedString(@"Windows cursor path does not exist.", @"Import path error: path does not exist")];
        return nil;
    }

    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    NSMutableArray<NSString *> *skippedRoles = [NSMutableArray array];
    NSMutableArray<NSError *> *errors = [NSMutableArray array];
    MCCursorLibrary *library = [self cursorLibraryForURL:url];

    if (isDirectory) {
        [self importCursorThemeAtURL:url
                         intoLibrary:library
                            warnings:warnings
                        skippedRoles:skippedRoles
                              errors:errors];
    } else {
        NSError *parseError = nil;
        NSArray<MCWindowsCursorFrame *> *frames = [self framesForCursorAtURL:url error:&parseError];
        if (frames.count) {
            if ([[url.pathExtension lowercaseString] isEqualToString:@"cur"]) {
                [warnings addObject:NSLocalizedString(@"Single file defaults to Arrow, editable in editor", @"Importer warning: single .cur file uses Arrow by default")];
            }
            [self addCursorWithFrames:frames
                           identifier:MCWindowsCursorDefaultIdentifier
                            filename:url.lastPathComponent
                           toLibrary:library
                            warnings:warnings
                              errors:errors];
        } else if (parseError) {
            [errors addObject:parseError];
        }
    }

    if (!library.cursors.count) {
        if (!errors.count) {
            [errors addObject:[self errorWithDescription:NSLocalizedString(@"No Windows cursors were imported.", @"Import result error: no cursors imported")]];
        }
        if (error) {
            *error = errors.firstObject;
        }
        return nil;
    }

    return [[MCWindowsCursorImportResult alloc] initWithCursorLibrary:library
                                                            warnings:warnings
                                                        skippedRoles:skippedRoles
                                                              errors:errors];
}

+ (void)importCursorThemeAtURL:(NSURL *)directoryURL
                   intoLibrary:(MCCursorLibrary *)library
                      warnings:(NSMutableArray<NSString *> *)warnings
                  skippedRoles:(NSMutableArray<NSString *> *)skippedRoles
                        errors:(NSMutableArray<NSError *> *)errors {
    NSURL *infURL = [self firstINFURLInDirectoryAtURL:directoryURL];
    if (!infURL) {
        NSLog(@"MCImport: No INF file found in %@", directoryURL.path);
        [errors addObject:[self errorWithDescription:NSLocalizedString(@"Windows cursor theme contains no INF file.", @"INF theme error: no INF file found")]];
        return;
    }
    NSLog(@"MCImport: Found INF at %@", infURL.path);

    NSError *infError = nil;
    NSDictionary<NSString *, NSString *> *roleToFilename = [MCInfCursorThemeParser cursorRoleToFilenameMapForINFAtURL:infURL error:&infError];
    if (!roleToFilename) {
        NSLog(@"MCImport: INF parsing failed: %@", infError.localizedDescription);
        [errors addObject:infError ?: [self errorWithDescription:NSLocalizedString(@"Unable to parse Windows cursor theme INF file.", @"INF theme error: unable to parse INF")]];
        return;
    }
    NSLog(@"MCImport: Parsed %lu role mappings", (unsigned long)roleToFilename.count);
    for (NSString *role in roleToFilename) {
        NSLog(@"MCImport:   %@ -> %@", role, roleToFilename[role]);
    }

    for (NSString *role in roleToFilename) {
        NSArray<NSString *> *identifiers = [MCWindowsCursorRoleMapper mousecapeIdentifiersForWindowsRole:role];
        if (!identifiers.count) {
            NSLog(@"MCImport:   Skipping role %@ (no macOS mapping)", role);
            [skippedRoles addObject:role];
            continue;
        }

        NSString *filename = roleToFilename[role];
        NSURL *cursorURL = [self URLForFilename:filename inDirectoryAtURL:directoryURL];
        if (!cursorURL) {
            NSLog(@"MCImport:   Missing file for %@: %@", role, filename);
            [errors addObject:[self errorWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Missing cursor file for role %@: %@", @"INF theme error: missing cursor file for role"), role, filename]]];
            continue;
        }
        NSLog(@"MCImport:   Processing %@ -> %@ (%@)", role, filename, cursorURL.path);

        NSError *parseError = nil;
        NSArray<MCWindowsCursorFrame *> *frames = [self framesForCursorAtURL:cursorURL error:&parseError];
        if (!frames.count) {
            NSLog(@"MCImport:   Parse failed for %@: %@", filename, parseError.localizedDescription);
            [errors addObject:parseError ?: [self errorWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to parse cursor file for role %@: %@", @"INF theme error: unable to parse cursor file for role"), role, filename]]];
            continue;
        }
        NSLog(@"MCImport:   Parsed %lu frames for %@", (unsigned long)frames.count, filename);

        for (NSString *identifier in identifiers) {
            [self addCursorWithFrames:frames
                           identifier:identifier
                            filename:filename
                           toLibrary:library
                            warnings:warnings
                              errors:errors];
        }
    }
    NSLog(@"MCImport: Done. Library has %lu cursors", (unsigned long)library.cursors.count);
}

+ (NSArray<MCWindowsCursorFrame *> *)framesForCursorAtURL:(NSURL *)url error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) {
        return nil;
    }

    NSString *extension = [url.pathExtension lowercaseString];
    if ([extension isEqualToString:@"cur"]) {
        return [MCCurParser framesFromData:data error:error];
    }
    if ([extension isEqualToString:@"ani"]) {
        return [MCAniParser framesFromData:data error:error];
    }

    [self setError:error description:NSLocalizedString(@"Unsupported Windows cursor file type.", @"Cursor file error: unsupported format")];
    return nil;
}

+ (NSSize)displaySizeForFrame:(MCWindowsCursorFrame *)frame
                     filename:(NSString *)filename
                     warnings:(NSMutableArray<NSString *> *)warnings {
    NSSize nominalSize = frame.nominalSize;
    if (nominalSize.width > 0 && nominalSize.height > 0) {
        return nominalSize;
    }
    CGFloat pixels = frame.imageRep.pixelsWide;
    if (pixels > 48) {
        NSArray<NSNumber *> *commonSizes = @[ @32.0, @48.0, @64.0, @24.0, @16.0 ];
        for (NSNumber *size in commonSizes) {
            CGFloat ratio = pixels / size.doubleValue;
            if (ratio == floor(ratio)) {
                [warnings addObject:[NSString stringWithFormat:NSLocalizedString(@"%@: no nominal size, displaying at %dx%d.", nil), filename, (int)size.doubleValue, (int)size.doubleValue]];
                return NSMakeSize(size.doubleValue, size.doubleValue);
            }
        }
    }
    return NSMakeSize(pixels, pixels);
}

+ (NSBitmapImageRep *)scaledImageRep:(NSBitmapImageRep *)sourceRep toSize:(NSSize)size {
    if ((NSUInteger)sourceRep.pixelsWide == (NSUInteger)size.width &&
        (NSUInteger)sourceRep.pixelsHigh == (NSUInteger)size.height) {
        return sourceRep;
    }
    NSImage *sourceImage = [[NSImage alloc] initWithSize:NSMakeSize(sourceRep.pixelsWide, sourceRep.pixelsHigh)];
    [sourceImage addRepresentation:sourceRep];
    [sourceImage setSize:NSMakeSize(sourceRep.pixelsWide, sourceRep.pixelsHigh)];

    NSBitmapImageRep *scaledRep = [[NSBitmapImageRep alloc]
                                   initWithBitmapDataPlanes:NULL
                                   pixelsWide:(NSInteger)size.width
                                   pixelsHigh:(NSInteger)size.height
                                   bitsPerSample:8
                                   samplesPerPixel:4
                                   hasAlpha:YES
                                   isPlanar:NO
                                   colorSpaceName:NSCalibratedRGBColorSpace
                                   bytesPerRow:(NSInteger)size.width * 4
                                   bitsPerPixel:32];

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:scaledRep]];
    [sourceImage drawInRect:NSMakeRect(0, 0, size.width, size.height)
                   fromRect:NSZeroRect
                  operation:NSCompositingOperationSourceOver
                   fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];

    return scaledRep;
}

+ (void)addCursorWithFrames:(NSArray<MCWindowsCursorFrame *> *)frames
                  identifier:(NSString *)identifier
                   filename:(NSString *)filename
                  toLibrary:(MCCursorLibrary *)library
                   warnings:(NSMutableArray<NSString *> *)warnings
                     errors:(NSMutableArray<NSError *> *)errors {
    NSUInteger realFrameCount = frames.count;
    NSUInteger frameCount = MIN(realFrameCount, MCWindowsCursorMaximumFrameCount);
    if (realFrameCount > frameCount) {
        [warnings addObject:[NSString stringWithFormat:NSLocalizedString(@"%@ has more than %lu frames, truncated.", nil), filename, (unsigned long)MCWindowsCursorMaximumFrameCount]];
    }

    MCWindowsCursorFrame *firstFrame = frames.firstObject;
    NSSize displaySize = [self displaySizeForFrame:firstFrame filename:filename warnings:warnings];
    NSSize framePixelSize = NSMakeSize(firstFrame.imageRep.pixelsWide, firstFrame.imageRep.pixelsHigh);

    NSMutableArray<NSBitmapImageRep *> *scaledReps = [NSMutableArray arrayWithCapacity:frameCount];
    for (NSUInteger index = 0; index < frameCount; index++) {
        NSBitmapImageRep *rep = frames[index].imageRep;
        if (NSEqualSizes(framePixelSize, displaySize)) {
            [scaledReps addObject:rep];
        } else {
            [scaledReps addObject:[self scaledImageRep:rep toSize:displaySize]];
        }
    }

    NSImageRep *representation = [MCCursor composeRepresentationWithFrames:scaledReps];
    if (!representation) {
        [errors addObject:[self errorWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to compose cursor frames for %@.", @"Cursor compose error: composition failed"), filename]]];
        return;
    }

    double baseDuration = firstFrame.duration > 0.0 ? firstFrame.duration : 1.0;
    if (frameCount > 0 && realFrameCount > frameCount) {
        baseDuration = (baseDuration * (double)realFrameCount) / (double)frameCount;
    }

    MCCursor *cursor = [[MCCursor alloc] init];
    cursor.identifier = identifier;
    cursor.frameCount = frameCount;
    cursor.frameDuration = baseDuration;
    cursor.hotSpot = NSMakePoint(firstFrame.hotSpot.x * (displaySize.width / framePixelSize.width),
                                  firstFrame.hotSpot.y * (displaySize.height / framePixelSize.height));
    [cursor setRepresentation:representation forScale:cursorScaleForScale(1.0)];

    [library removeCursorsWithIdentifier:identifier];
    [library addCursor:cursor];
}

+ (MCCursorLibrary *)cursorLibraryForURL:(NSURL *)url {
    NSString *name = [url.lastPathComponent stringByDeletingPathExtension];
    if (!name.length) {
        name = NSLocalizedString(@"Windows Cursor", @"Default library name for unnamed cursor themes");
    }

    MCCursorLibrary *library = [[MCCursorLibrary alloc] init];
    library.name = name;
    library.identifier = [NSString stringWithFormat:@"local.windows.%@.%f", name, [NSDate timeIntervalSinceReferenceDate]];
    return library;
}

+ (NSURL *)firstINFURLInDirectoryAtURL:(NSURL *)directoryURL {
    NSArray<NSURL *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directoryURL
                                                              includingPropertiesForKeys:nil
                                                                                 options:0
                                                                                   error:nil];
    for (NSURL *url in contents) {
        if ([[url.pathExtension lowercaseString] isEqualToString:@"inf"]) {
            return url;
        }
    }

    return nil;
}

+ (NSURL *)URLForFilename:(NSString *)filename inDirectoryAtURL:(NSURL *)directoryURL {
    NSURL *directURL = [directoryURL URLByAppendingPathComponent:filename];
    if ([[NSFileManager defaultManager] fileExistsAtPath:directURL.path]) {
        return directURL;
    }

    NSArray<NSURL *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directoryURL
                                                              includingPropertiesForKeys:nil
                                                                                 options:0
                                                                                   error:nil];
    for (NSURL *url in contents) {
        if ([url.lastPathComponent caseInsensitiveCompare:filename] == NSOrderedSame) {
            return url;
        }
    }

    return nil;
}

+ (NSError *)errorWithDescription:(NSString *)description {
    return [NSError errorWithDomain:MCErrorDomain
                               code:MCErrorInvalidCapeCode
                           userInfo:@{ NSLocalizedDescriptionKey: description }];
}

+ (void)setError:(NSError **)error description:(NSString *)description {
    if (error) {
        *error = [self errorWithDescription:description];
    }
}

@end
