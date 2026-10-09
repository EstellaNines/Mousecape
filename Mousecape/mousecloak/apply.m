//
//  apply.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "create.h"
#import "backup.h"
#import "restore.h"
#import "MCPrefs.h"
#import "NSBitmapImageRep+ColorSpace.h"

static BOOL registerCursor(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *ident) {
    if (frameCount > 24 || frameCount < 1 || !images.count || !ident.length ||
        !isfinite(frameDuration) || frameDuration < 0 || (frameCount > 1 && frameDuration == 0) ||
        !isfinite(size.width) || !isfinite(size.height) || size.width <= 0 || size.height <= 0 ||
        !isfinite(hotSpot.x) || !isfinite(hotSpot.y)) {
        MMLog(BOLD RED "Invalid cursor metadata for %s" RESET, ident.UTF8String);
        return NO;
    }

    char *idenfifier = (char *)ident.UTF8String;
    int seed = 0;
    CGError err = CGSRegisterCursorWithImages(CGSMainConnectionID(),
                                              idenfifier,
                                              true,
                                              true,
                                              size,
                                              hotSpot,
                                              frameCount,
                                              frameDuration,
                                              (__bridge CFArrayRef)images,
                                              &seed);
    
    if (err != kCGErrorSuccess) {
        MMLog(BOLD RED "Failed to register %s (CGError %d)" RESET, ident.UTF8String, err);
    }
    return (err == kCGErrorSuccess);
}

BOOL applyCursorForIdentifier(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *ident, NSUInteger repeatCount) {
    if (![ident isKindOfClass:[NSString class]] || !ident.length) return NO;
    for (NSString *name in MCCursorNamesForIdentifier(ident)) {
        if (!registerCursor(frameCount, frameDuration, hotSpot, size, images, name)) return NO;
    }
    return YES;
}

BOOL applyCapeForIdentifier(NSDictionary *cursor, NSString *identifier, BOOL restore) {
    if (![cursor isKindOfClass:[NSDictionary class]] ||
        ![identifier isKindOfClass:[NSString class]] || !identifier.length) {
        return NO;
    }

    for (NSString *key in @[@"FrameCount", @"FrameDuration", @"HotSpotX", @"HotSpotY", @"PointsWide", @"PointsHigh"]) {
        if (![cursor[key] isKindOfClass:[NSNumber class]]) return NO;
    }
    double frames = [cursor[MCCursorDictionaryFrameCountKey] doubleValue];
    if (!isfinite(frames) || frames < 1 || frames > 24 || frames != floor(frames)) return NO;
    if (![cursor[MCCursorDictionaryRepresentationsKey] isKindOfClass:[NSArray class]]) return NO;

    BOOL lefty = MCFlag(MCPreferencesHandednessKey);
    BOOL pointer = MCCursorIsPointer(identifier);
    NSNumber *frameCount    = cursor[MCCursorDictionaryFrameCountKey];
    NSNumber *frameDuration = cursor[MCCursorDictionaryFrameDuratiomKey];
    //    NSNumber *repeatCount   = cursor[MCCursorDictionaryRepeatCountKey];
    
    CGPoint hotSpot         = CGPointMake([cursor[MCCursorDictionaryHotSpotXKey] doubleValue],
                                          [cursor[MCCursorDictionaryHotSpotYKey] doubleValue]);
    CGSize size             = CGSizeMake([cursor[MCCursorDictionaryPointsWideKey] doubleValue],
                                         [cursor[MCCursorDictionaryPointsHighKey] doubleValue]);
    NSArray *reps           = cursor[MCCursorDictionaryRepresentationsKey];
    NSMutableArray *images  = [NSMutableArray array];

    if (lefty && !restore && pointer) {
        MMLog("Lefty mode for %s", identifier.UTF8String);
        hotSpot.x = size.width - hotSpot.x - 1;
    }

    for (id object in reps) {
        CFTypeID type = CFGetTypeID((__bridge CFTypeRef)object);
        NSBitmapImageRep *rep;
        if (type == CGImageGetTypeID()) {
            rep = [[[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)object] autorelease];
        } else if ([object isKindOfClass:[NSData class]]) {
            rep = [[[NSBitmapImageRep alloc] initWithData:object] autorelease];
        } else {
            return NO;
        }
        rep = rep.retaggedSRGBSpace;
        if (!rep.CGImage) return NO;

        if (!lefty || restore || !pointer) {
            // special case if array has a type of CGImage already there is no need to convert it
            if (type == CGImageGetTypeID()) {
                images[images.count] = object;
                continue;
            }
            
            images[images.count] = (__bridge id)[rep CGImage];
            
        } else {
            NSBitmapImageRep *newRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                               pixelsWide:rep.pixelsWide
                                                                               pixelsHigh:rep.pixelsHigh
                                                                            bitsPerSample:8
                                                                          samplesPerPixel:4
                                                                                 hasAlpha:YES
                                                                                 isPlanar:NO
                                                                           colorSpaceName:NSCalibratedRGBColorSpace
                                                                              bytesPerRow:4 * rep.pixelsWide
                                                                             bitsPerPixel:32] autorelease];
            NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:newRep];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:ctx];
            NSAffineTransform *transform = [NSAffineTransform transform];
            [transform translateXBy:rep.pixelsWide yBy:0];
            [transform scaleXBy:-1 yBy:1];
            [transform concat];

            [rep drawInRect:NSMakeRect(0, 0, rep.pixelsWide, rep.pixelsHigh)
                   fromRect:NSZeroRect
                  operation:NSCompositingOperationSourceOver
                   fraction:1.0
             respectFlipped:NO
                      hints:nil];
            [NSGraphicsContext restoreGraphicsState];
            images[images.count] = (__bridge id)[newRep CGImage];
        }
    }
    
    // Backups and restores must preserve each original name independently.
    if (restore) return registerCursor(frameCount.unsignedIntegerValue, frameDuration.doubleValue, hotSpot, size, images, identifier);
    return applyCursorForIdentifier(frameCount.unsignedIntegerValue, frameDuration.doubleValue, hotSpot, size, images, identifier, 0);
}

BOOL applyCape(NSDictionary *dictionary) {
    @autoreleasepool {
        if (![dictionary isKindOfClass:[NSDictionary class]] ||
            ![dictionary[MCCursorDictionaryCursorsKey] isKindOfClass:[NSDictionary class]] ||
            ![dictionary[MCCursorDictionaryIdentifierKey] isKindOfClass:[NSString class]]) return NO;
        NSDictionary *cursors = dictionary[MCCursorDictionaryCursorsKey];
        if (!cursors.count) return NO;
        NSString *name = dictionary[MCCursorDictionaryCapeNameKey];
        NSNumber *version = dictionary[MCCursorDictionaryCapeVersionKey];
        
        if (!resetAllCursors()) return NO;
        if (!backupAllCursors()) return NO;
        
        MMLog("Applying cape: %s %.02f", name.UTF8String, version.floatValue);
        
        for (NSString *key in cursors) {
            NSDictionary *cape = cursors[key];
            MMLog("Hooking for %s", key.UTF8String);
            
            BOOL success = applyCapeForIdentifier(cape, key, NO);
            if (!success) {
                MMLog(BOLD RED "Failed to hook identifier %s for some unknown reason. Bailing out..." RESET, key.UTF8String);
                resetAllCursors();
                return NO;
            }
        }
        
        MCSetDefault(dictionary[MCCursorDictionaryIdentifierKey], MCPreferencesAppliedCursorKey);
        
        MMLog(BOLD GREEN "Applied %s successfully!" RESET, name.UTF8String);
        
        return YES;
    }
}

BOOL applyCapeAtPath(NSString *path) {
    NSDictionary *cape = [NSDictionary dictionaryWithContentsOfFile:path];
    if (cape)
        return applyCape(cape);
    MMLog(BOLD RED "Could not find valid file at %s to apply" RESET, path.UTF8String);
    return NO;
}
