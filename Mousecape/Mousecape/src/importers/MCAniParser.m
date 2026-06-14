//
//  MCAniParser.m
//  Mousecape
//

#import "MCAniParser.h"

#import "MCCurParser.h"
#import "MCDefs.h"
#import "MCWindowsCursorFrame.h"

static uint32_t MCAniReadUInt32(const uint8_t *bytes, NSUInteger offset) {
    return (uint32_t)bytes[offset] |
           ((uint32_t)bytes[offset + 1] << 8) |
           ((uint32_t)bytes[offset + 2] << 16) |
           ((uint32_t)bytes[offset + 3] << 24);
}

static BOOL MCAniChunkIDEquals(const uint8_t *bytes, NSUInteger offset, const char *chunkID) {
    return bytes[offset] == chunkID[0] &&
           bytes[offset + 1] == chunkID[1] &&
           bytes[offset + 2] == chunkID[2] &&
           bytes[offset + 3] == chunkID[3];
}

static BOOL MCAniAppendFramesFromChunks(NSData *data,
                                        NSUInteger startOffset,
                                        NSUInteger endOffset,
                                        NSTimeInterval *duration,
                                        NSSize *nominalSize,
                                        NSMutableArray<MCWindowsCursorFrame *> *frames,
                                        NSError **error) {
    const uint8_t *bytes = data.bytes;
    NSUInteger offset = startOffset;
    while (offset + 8 <= endOffset) {
        uint32_t chunkSize = MCAniReadUInt32(bytes, offset + 4);
        NSUInteger chunkDataOffset = offset + 8;
        if (chunkSize > endOffset - chunkDataOffset) {
            break;
        }

        if (MCAniChunkIDEquals(bytes, offset, "rate")) {
            if (chunkSize >= 4) {
                uint32_t jiffies = MCAniReadUInt32(bytes, chunkDataOffset);
                *duration = (NSTimeInterval)jiffies / 60.0;
            }
        } else if (MCAniChunkIDEquals(bytes, offset, "anih")) {
            if (chunkSize >= 20) {
                uint32_t iWidth = MCAniReadUInt32(bytes, chunkDataOffset + 12);
                uint32_t iHeight = MCAniReadUInt32(bytes, chunkDataOffset + 16);
                if (iWidth > 0 && iHeight > 0) {
                    *nominalSize = NSMakeSize(iWidth, iHeight);
                }
            }
        } else if (MCAniChunkIDEquals(bytes, offset, "icon")) {
            NSData *curData = [data subdataWithRange:NSMakeRange(chunkDataOffset, chunkSize)];
            NSError *curError = nil;
            NSArray<MCWindowsCursorFrame *> *curFrames = [MCCurParser framesFromData:curData error:&curError];
            MCWindowsCursorFrame *curFrame = curFrames.firstObject;
            if (!curFrame) {
                if (error) {
                    *error = curError ?: [NSError errorWithDomain:MCErrorDomain
                                                            code:MCErrorInvalidCapeCode
                                                        userInfo:@{ NSLocalizedDescriptionKey: @"Invalid ANI icon chunk." }];
                }
                return NO;
            }

            MCWindowsCursorFrame *frame = [[MCWindowsCursorFrame alloc] initWithImageRep:curFrame.imageRep
                                                                                hotSpot:curFrame.hotSpot
                                                                               duration:*duration
                                                                            nominalSize:*nominalSize];
            [frames addObject:frame];
        } else if (MCAniChunkIDEquals(bytes, offset, "LIST") && chunkSize >= 4) {
            if (!MCAniAppendFramesFromChunks(data, chunkDataOffset + 4, chunkDataOffset + chunkSize, duration, nominalSize, frames, error)) {
                return NO;
            }
        }

        offset = chunkDataOffset + chunkSize + (chunkSize % 2);
    }

    return YES;
}

@implementation MCAniParser

+ (NSArray<MCWindowsCursorFrame *> *)framesFromData:(NSData *)data error:(NSError **)error {
    if (data.length < 12) {
        [self setError:error description:@"Invalid ANI file."];
        return nil;
    }

    const uint8_t *bytes = data.bytes;
    if (!MCAniChunkIDEquals(bytes, 0, "RIFF") || !MCAniChunkIDEquals(bytes, 8, "ACON")) {
        [self setError:error description:@"Invalid ANI file."];
        return nil;
    }

    NSTimeInterval duration = 1.0 / 12.0;
    NSSize nominalSize = NSZeroSize;
    NSMutableArray<MCWindowsCursorFrame *> *frames = [NSMutableArray array];
    if (!MCAniAppendFramesFromChunks(data, 12, data.length, &duration, &nominalSize, frames, error)) {
        return nil;
    }

    if (!frames.count) {
        [self setError:error description:@"ANI file contains no cursor frames."];
        return nil;
    }

    return frames;
}

+ (void)setError:(NSError **)error description:(NSString *)description {
    if (error) {
        *error = [NSError errorWithDomain:MCErrorDomain
                                     code:MCErrorInvalidCapeCode
                                 userInfo:@{ NSLocalizedDescriptionKey: description }];
    }
}

@end
