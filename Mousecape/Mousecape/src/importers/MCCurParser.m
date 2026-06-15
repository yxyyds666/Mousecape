//
//  MCCurParser.m
//  Mousecape
//

#import "MCCurParser.h"

#import "MCDefs.h"
#import "MCWindowsCursorFrame.h"

static uint16_t MCCurReadUInt16(const uint8_t *bytes, NSUInteger offset) {
    return (uint16_t)bytes[offset] | ((uint16_t)bytes[offset + 1] << 8);
}

static uint32_t MCCurReadUInt32(const uint8_t *bytes, NSUInteger offset) {
    return (uint32_t)bytes[offset] |
           ((uint32_t)bytes[offset + 1] << 8) |
           ((uint32_t)bytes[offset + 2] << 16) |
           ((uint32_t)bytes[offset + 3] << 24);
}

static int32_t MCCurReadInt32(const uint8_t *bytes, NSUInteger offset) {
    return (int32_t)MCCurReadUInt32(bytes, offset);
}

static NSBitmapImageRep *MCCurDecodeICOCursorData(NSData *imageData, NSError **error) {
    const uint8_t *bytes = imageData.bytes;
    NSUInteger length = imageData.length;

    if (length < 40) {
        if (error) *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidCapeCode
                                            userInfo:@{ NSLocalizedDescriptionKey: @"ICON data too small." }];
        return nil;
    }

    uint32_t bmpHeaderSize = MCCurReadUInt32(bytes, 0);
    if (bmpHeaderSize < 40 || bmpHeaderSize > length) {
        if (error) *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidCapeCode
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Invalid BMP header in CUR data." }];
        return nil;
    }

    int32_t bmpWidth = MCCurReadInt32(bytes, 4);
    int32_t bmpHeight = MCCurReadInt32(bytes, 8);
    uint16_t planes = MCCurReadUInt16(bytes, 12);
    uint16_t bitCount = MCCurReadUInt16(bytes, 14);
    uint32_t compression = MCCurReadUInt32(bytes, 16);

    if (bmpWidth <= 0 || bmpHeight <= 0 || bmpHeight % 2 != 0 || planes != 1) {
        if (error) *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidCapeCode
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Invalid BMP dimensions in CUR data." }];
        return nil;
    }

    NSUInteger actualHeight = (NSUInteger)(bmpHeight / 2);
    NSUInteger actualWidth = (NSUInteger)bmpWidth;

    NSUInteger xorRowBytes = ((actualWidth * bitCount + 31) / 32) * 4;
    NSUInteger xorSize = xorRowBytes * actualHeight;
    NSUInteger andRowBytes = ((actualWidth + 31) / 32) * 4;
    NSUInteger andSize = andRowBytes * actualHeight;

    NSUInteger paletteSize = 0;
    if (bitCount == 8) {
        paletteSize = 256 * 4;
    } else if (bitCount == 4) {
        paletteSize = 16 * 4;
    }

    NSUInteger pixelDataOffset = bmpHeaderSize + paletteSize;
    NSUInteger andMaskOffset = pixelDataOffset + xorSize;

    if (andMaskOffset + andSize > length) {
        if (error) *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidCapeCode
                                            userInfo:@{ NSLocalizedDescriptionKey: @"CUR image data truncated." }];
        return nil;
    }

    // Parse palette if present
    uint8_t palette[256 * 4];
    if (bitCount == 8 || bitCount == 4) {
        NSUInteger paletteBytes = bmpHeaderSize + paletteSize;
        if (paletteBytes > length) {
            if (error) *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidCapeCode
                                                userInfo:@{ NSLocalizedDescriptionKey: @"CUR palette truncated." }];
            return nil;
        }
        for (NSUInteger i = 0; i < paletteSize; i++) {
            palette[i] = bytes[bmpHeaderSize + i];
        }
    }

    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc]
                                  initWithBitmapDataPlanes:NULL
                                  pixelsWide:actualWidth
                                  pixelsHigh:actualHeight
                                  bitsPerSample:8
                                  samplesPerPixel:4
                                  hasAlpha:YES
                                  isPlanar:NO
                                  colorSpaceName:NSDeviceRGBColorSpace
                                  bytesPerRow:actualWidth * 4
                                  bitsPerPixel:32];

    if (!imageRep) {
        if (error) *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidCapeCode
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Unable to create bitmap for CUR data." }];
        return nil;
    }

    unsigned char *pixelData = [imageRep bitmapData];

    if (bitCount == 32) {
        for (NSUInteger y = 0; y < actualHeight; y++) {
            NSUInteger srcRowOffset = pixelDataOffset + (actualHeight - 1 - y) * xorRowBytes;
            NSUInteger dstRowOffset = y * actualWidth * 4;
            for (NSUInteger x = 0; x < actualWidth; x++) {
                NSUInteger srcPixelOffset = srcRowOffset + x * 4;
                NSUInteger dstPixelOffset = dstRowOffset + x * 4;
                pixelData[dstPixelOffset + 0] = bytes[srcPixelOffset + 2];
                pixelData[dstPixelOffset + 1] = bytes[srcPixelOffset + 1];
                pixelData[dstPixelOffset + 2] = bytes[srcPixelOffset + 0];
                pixelData[dstPixelOffset + 3] = bytes[srcPixelOffset + 3];
            }
        }
    } else if (bitCount == 24) {
        for (NSUInteger y = 0; y < actualHeight; y++) {
            NSUInteger srcRowOffset = pixelDataOffset + (actualHeight - 1 - y) * xorRowBytes;
            NSUInteger dstRowOffset = y * actualWidth * 4;
            for (NSUInteger x = 0; x < actualWidth; x++) {
                NSUInteger srcPixelOffset = srcRowOffset + x * 3;
                NSUInteger dstPixelOffset = dstRowOffset + x * 4;
                pixelData[dstPixelOffset + 0] = bytes[srcPixelOffset + 2];
                pixelData[dstPixelOffset + 1] = bytes[srcPixelOffset + 1];
                pixelData[dstPixelOffset + 2] = bytes[srcPixelOffset + 0];
                pixelData[dstPixelOffset + 3] = 255;
            }
        }
    } else if (bitCount == 8) {
        for (NSUInteger y = 0; y < actualHeight; y++) {
            NSUInteger srcRowOffset = pixelDataOffset + (actualHeight - 1 - y) * xorRowBytes;
            NSUInteger dstRowOffset = y * actualWidth * 4;
            for (NSUInteger x = 0; x < actualWidth; x++) {
                NSUInteger paletteIndex = bytes[srcRowOffset + x];
                NSUInteger palEntry = paletteIndex * 4;
                NSUInteger dstPixelOffset = dstRowOffset + x * 4;
                pixelData[dstPixelOffset + 0] = palette[palEntry + 2];
                pixelData[dstPixelOffset + 1] = palette[palEntry + 1];
                pixelData[dstPixelOffset + 2] = palette[palEntry + 0];
                pixelData[dstPixelOffset + 3] = 255;
            }
        }
    } else if (bitCount == 4) {
        for (NSUInteger y = 0; y < actualHeight; y++) {
            NSUInteger srcRowOffset = pixelDataOffset + (actualHeight - 1 - y) * xorRowBytes;
            NSUInteger dstRowOffset = y * actualWidth * 4;
            for (NSUInteger x = 0; x < actualWidth; x++) {
                NSUInteger byteIndex = srcRowOffset + (x / 2);
                BOOL highNibble = (x % 2 == 0);
                uint8_t paletteIndex = highNibble ? ((bytes[byteIndex] >> 4) & 0x0F) : (bytes[byteIndex] & 0x0F);
                NSUInteger palEntry = paletteIndex * 4;
                NSUInteger dstPixelOffset = dstRowOffset + x * 4;
                pixelData[dstPixelOffset + 0] = palette[palEntry + 2];
                pixelData[dstPixelOffset + 1] = palette[palEntry + 1];
                pixelData[dstPixelOffset + 2] = palette[palEntry + 0];
                pixelData[dstPixelOffset + 3] = 255;
            }
        }
    } else if (bitCount == 1) {
        for (NSUInteger y = 0; y < actualHeight; y++) {
            NSUInteger srcRowOffset = pixelDataOffset + (actualHeight - 1 - y) * xorRowBytes;
            NSUInteger dstRowOffset = y * actualWidth * 4;
            for (NSUInteger x = 0; x < actualWidth; x++) {
                NSUInteger byteIndex = srcRowOffset + (x / 8);
                NSUInteger bitIndex = 7 - (x % 8);
                BOOL white = (bytes[byteIndex] >> bitIndex) & 1;
                NSUInteger dstPixelOffset = dstRowOffset + x * 4;
                pixelData[dstPixelOffset + 0] = white ? 255 : 0;
                pixelData[dstPixelOffset + 1] = white ? 255 : 0;
                pixelData[dstPixelOffset + 2] = white ? 255 : 0;
                pixelData[dstPixelOffset + 3] = 255;
            }
        }
    } else {
        if (error) *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidCapeCode
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Unsupported CUR bit depth." }];
        return nil;
    }

    if (andSize > 0) {
        for (NSUInteger y = 0; y < actualHeight; y++) {
            NSUInteger andRowOffset = andMaskOffset + (actualHeight - 1 - y) * andRowBytes;
            NSUInteger dstRowOffset = y * actualWidth * 4;
            for (NSUInteger x = 0; x < actualWidth; x++) {
                NSUInteger byteIndex = andRowOffset + (x / 8);
                NSUInteger bitIndex = 7 - (x % 8);
                if (byteIndex < andMaskOffset + andSize && (bytes[byteIndex] >> bitIndex) & 1) {
                    pixelData[dstRowOffset + x * 4 + 3] = 0;
                }
            }
        }
    }

    return imageRep;
}

@implementation MCCurParser

+ (NSArray<MCWindowsCursorFrame *> *)framesFromData:(NSData *)data error:(NSError **)error {
    if (data.length < 6) {
        [self setError:error description:@"Invalid CUR file."];
        return nil;
    }

    const uint8_t *bytes = data.bytes;
    uint16_t reserved = MCCurReadUInt16(bytes, 0);
    uint16_t type = MCCurReadUInt16(bytes, 2);
    uint16_t count = MCCurReadUInt16(bytes, 4);

    if (reserved != 0 || type != 2 || count == 0) {
        [self setError:error description:@"Invalid CUR file."];
        return nil;
    }

    NSUInteger directoryLength = 6 + ((NSUInteger)count * 16);
    if (directoryLength > data.length) {
        [self setError:error description:@"Invalid CUR file."];
        return nil;
    }

    NSUInteger selectedEntryOffset = NSNotFound;
    NSUInteger selectedArea = 0;
    NSSize nominalSize = NSZeroSize;
    for (NSUInteger index = 0; index < count; index++) {
        NSUInteger entryOffset = 6 + (index * 16);
        NSUInteger icoWidth = bytes[entryOffset];
        NSUInteger icoHeight = bytes[entryOffset + 1];
        NSUInteger width = icoWidth == 0 ? 256 : icoWidth;
        NSUInteger height = icoHeight == 0 ? 256 : icoHeight;
        NSUInteger area = width * height;

        if (selectedEntryOffset == NSNotFound || area > selectedArea) {
            selectedEntryOffset = entryOffset;
            selectedArea = area;
            // Only use nominal size if the ICO entry explicitly specifies dimensions
            if (icoWidth > 0 && icoHeight > 0) {
                nominalSize = NSMakeSize(icoWidth, icoHeight);
            }
        }
    }

    if (selectedEntryOffset == NSNotFound) {
        [self setError:error description:@"CUR file contains no images."];
        return nil;
    }

    uint16_t hotSpotX = MCCurReadUInt16(bytes, selectedEntryOffset + 4);
    uint16_t hotSpotY = MCCurReadUInt16(bytes, selectedEntryOffset + 6);
    uint32_t bytesInResource = MCCurReadUInt32(bytes, selectedEntryOffset + 8);
    uint32_t imageOffset = MCCurReadUInt32(bytes, selectedEntryOffset + 12);

    if (bytesInResource == 0 || imageOffset > data.length || bytesInResource > data.length - imageOffset) {
        [self setError:error description:@"CUR image data is out of bounds."];
        return nil;
    }

    NSData *imageData = [data subdataWithRange:NSMakeRange(imageOffset, bytesInResource)];
    NSBitmapImageRep *imageRep = MCCurDecodeICOCursorData(imageData, error);
    if (!imageRep) {
        return nil;
    }

    MCWindowsCursorFrame *frame = [[MCWindowsCursorFrame alloc] initWithImageRep:imageRep
                                                                        hotSpot:NSMakePoint(hotSpotX, hotSpotY)
                                                                       duration:1.0
                                                                    nominalSize:nominalSize];
    return @[ frame ];
}

+ (void)setError:(NSError **)error description:(NSString *)description {
    if (error) {
        *error = [NSError errorWithDomain:MCErrorDomain
                                     code:MCErrorInvalidCapeCode
                                 userInfo:@{ NSLocalizedDescriptionKey: description }];
    }
}

@end
