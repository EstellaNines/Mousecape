#import <Cocoa/Cocoa.h>
#import "apply.h"
#import "backup.h"
#import "restore.h"
#import "MCPrefs.h"

// WindowServer and preferences are replaced so these tests never change the desktop.
static NSMutableDictionary *registry;
static NSMutableArray *registrations;
static NSString *rejectedName;
static BOOL rejectOnce;
static BOOL modernNames;
static BOOL unavailableCoreCursor;
static id appliedCape;
NSString *MCPreferencesAppliedCursorKey = @"MCAppliedCursor";
NSString *MCPreferencesHandednessKey = @"MCHandedness";

CGSConnectionID CGSMainConnectionID(void) { return 1; }
char *CGSCursorNameForSystemCursor(CGSCursorID cursor) {
    if (modernNames && cursor == 100) return "com.apple.coregraphics.ArrowS";
    if (modernNames && cursor == 101) return "com.apple.coregraphics.IBeamS";
    if (cursor == 0) return "com.apple.coregraphics.Arrow";
    if (cursor == 6) return "com.apple.coregraphics.ArrowCtx";
    return NULL;
}
CGError CGSRegisterCursorWithImages(CGSConnectionID cid, char *name, bool global, bool instantly,
                                  CGSize size, CGPoint hotspot, NSUInteger frames, CGFloat duration,
                                  CFArrayRef images, int *seed) {
    NSString *identifier = @(name);
    [registrations addObject:identifier];
    if ([identifier isEqualToString:rejectedName]) {
        if (rejectOnce) rejectedName = nil;
        return kCGErrorFailure;
    }
    assert(cid == 1 && global && instantly && images && CFArrayGetCount(images));
    registry[identifier] = @{ @"FrameCount": @(frames), @"FrameDuration": @(duration),
        @"PointsWide": @(size.width), @"PointsHigh": @(size.height),
        @"HotSpotX": @(hotspot.x), @"HotSpotY": @(hotspot.y),
        @"Representations": (__bridge NSArray *)images };
    *seed = 1;
    return kCGErrorSuccess;
}
CGError CGSGetRegisteredCursorDataSize(CGSConnectionID cid, char *name, size_t *size) {
    *size = registry[@(name)] ? 4 : 0;
    return *size ? kCGErrorSuccess : kCGErrorFailure;
}
CGError CGSCopyRegisteredCursorImages(CGSConnectionID cid, char *name, CGSize *size, CGPoint *hotspot,
                                    NSUInteger *frames, CGFloat *duration, CFArrayRef *images) {
    NSDictionary *cursor = registry[@(name)];
    if (!cursor) return kCGErrorFailure;
    *size = CGSizeMake([cursor[@"PointsWide"] doubleValue], [cursor[@"PointsHigh"] doubleValue]);
    *hotspot = CGPointMake([cursor[@"HotSpotX"] doubleValue], [cursor[@"HotSpotY"] doubleValue]);
    *frames = [cursor[@"FrameCount"] unsignedIntegerValue];
    *duration = [cursor[@"FrameDuration"] doubleValue];
    *images = (CFArrayRef)CFRetain((__bridge CFArrayRef)cursor[@"Representations"]);
    return kCGErrorSuccess;
}
CGError CGSRemoveRegisteredCursor(CGSConnectionID cid, char *name, bool flag) {
    [registry removeObjectForKey:@(name)];
    return kCGErrorSuccess;
}
CGError CoreCursorUnregisterAll(CGSConnectionID cid) { return kCGErrorSuccess; }
CGError CoreCursorSet(CGSConnectionID cid, CGSCursorID cursor) {
    return unavailableCoreCursor && (cursor == 6 || cursor == 44) ? -25190 : kCGErrorSuccess;
}
id MCDefault(NSString *key) { return [key isEqual:MCPreferencesAppliedCursorKey] ? appliedCape : nil; }
void MCSetDefaultFor(id value, NSString *key, NSString *user, NSString *host) {
    if ([key isEqual:MCPreferencesAppliedCursorKey]) appliedCape = value;
}

static NSArray *imageRepresentations(NSUInteger frames) {
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
        pixelsWide:16 pixelsHigh:16 * frames bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES
        isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
    return @[(__bridge id)bitmap.CGImage];
}

static void resetTest(void) {
    registry = [NSMutableDictionary dictionary];
    registrations = [NSMutableArray array];
    rejectedName = nil;
    rejectOnce = NO;
    appliedCape = nil;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        modernNames = argc > 1 && strcmp(argv[1], "modern") == 0;
        resetTest();
        NSArray *images = imageRepresentations(24);
        assert(applyCursorForIdentifier(24, 0.05, CGPointZero, CGSizeMake(16, 16), images,
                                        @"com.apple.coregraphics.Arrow", 0));
        NSArray *expected = modernNames ? @[@"com.apple.coregraphics.Arrow", @"com.apple.coregraphics.ArrowS"]
                                       : @[@"com.apple.coregraphics.Arrow"];
        if (![registrations isEqual:expected]) {
            fprintf(stderr, "FAIL: Arrow did not reach the system names in use: %s\n", registrations.description.UTF8String);
            return 1;
        }
        assert([registry[@"com.apple.coregraphics.Arrow"][@"FrameCount"] integerValue] == 24);
        assert([registry[@"com.apple.coregraphics.Arrow"][@"FrameDuration"] doubleValue] == 0.05);

        resetTest();
        assert(applyCursorForIdentifier(1, 0, CGPointZero, CGSizeMake(16, 16), images,
                                        @"com.apple.coregraphics.ArrowCtx", 0));
        assert([registrations isEqual:@[@"com.apple.coregraphics.ArrowCtx"]]);

        resetTest();
        assert(applyCursorForIdentifier(24, 0.05, CGPointZero, CGSizeMake(16, 16), images,
                                        @"com.apple.coregraphics.IBeam", 0));
        expected = modernNames ? @[@"com.apple.coregraphics.IBeam", @"com.apple.coregraphics.IBeamS"]
                               : @[@"com.apple.coregraphics.IBeam"];
        assert([registrations isEqual:expected]);

        if (modernNames) {
            resetTest();
            NSArray *originalImages = imageRepresentations(1);
            assert(applyCursorForIdentifier(1, 0, CGPointZero, CGSizeMake(16, 16), originalImages,
                                            @"com.apple.coregraphics.Arrow", 0));
            NSDictionary *original = [[registry copy] autorelease];
            NSDictionary *theme = @{ @"Identifier": @"test.theme", @"CapeName": @"Test", @"CapeVersion": @1,
                @"Cursors": @{ @"com.apple.coregraphics.Arrow": @{
                    @"FrameCount": @24, @"FrameDuration": @0.05, @"PointsWide": @16, @"PointsHigh": @16,
                    @"HotSpotX": @0, @"HotSpotY": @0, @"Representations": images } } };
            rejectedName = @"com.alexzielenski.mousecape.com.apple.coregraphics.ArrowS";
            if (applyCape(theme)) {
                fprintf(stderr, "FAIL: application continued without the original ArrowS backup\n");
                return 1;
            }
            assert([registry[@"com.apple.coregraphics.Arrow"][@"FrameCount"] integerValue] == 1);
            rejectedName = nil;
            assert(resetAllCursors());
            assert([registry isEqual:original]);

            rejectedName = @"com.apple.coregraphics.ArrowS";
            rejectOnce = YES;
            assert(!applyCape(theme));
            assert([registry isEqual:original]);
            assert(appliedCape == nil);

            resetTest();
            rejectedName = @"com.apple.coregraphics.ArrowS";
            assert(!applyCursorForIdentifier(1, 0, CGPointZero, CGSizeMake(16, 16), images,
                                             @"com.apple.coregraphics.Arrow", 0));
        }

        resetTest();
        assert(!applyCursorForIdentifier(25, 0.05, CGPointZero, CGSizeMake(16, 16), images, @"test", 0));
        assert(!applyCursorForIdentifier(2, 0, CGPointZero, CGSizeMake(16, 16), images, @"test", 0));
        assert(!applyCursorForIdentifier(1, 0, CGPointZero, CGSizeMake(16, 16), @[], @"test", 0));
        assert(registrations.count == 0);

        NSMutableDictionary *invalidCursor = [@{ @"FrameCount": @1, @"FrameDuration": @0,
            @"PointsWide": @16, @"PointsHigh": @16, @"HotSpotX": @0, @"HotSpotY": @0,
            @"Representations": @[[NSData dataWithBytes:"bad" length:3]] } mutableCopy];
        assert(!applyCapeForIdentifier(invalidCursor, @"test", NO));
        invalidCursor[@"FrameCount"] = @1.5;
        assert(!applyCapeForIdentifier(invalidCursor, @"test", NO));
        [invalidCursor release];
        assert(!applyCape(@{}));
        assert(registrations.count == 0);
        unavailableCoreCursor = YES;
        if (!resetAllCursors()) {
            fprintf(stderr, "FAIL: unavailable legacy core cursor IDs block restoring defaults\n");
            return 1;
        }
        unavailableCoreCursor = NO;

        resetTest();
        NSArray *originalImages = imageRepresentations(1);
        assert(applyCursorForIdentifier(1, 0, CGPointZero, CGSizeMake(16, 16), originalImages,
                                        @"com.apple.coregraphics.Arrow", 0));
        NSDictionary *original = [[registry copy] autorelease];
        backupAllCursors();
        assert(applyCursorForIdentifier(24, 0.05, CGPointZero, CGSizeMake(16, 16), images,
                                        @"com.apple.coregraphics.Arrow", 0));
        resetAllCursors();
        assert([registry isEqual:original]);
        assert(appliedCape == nil);

        if (modernNames) {
            resetTest();
            assert(applyCursorForIdentifier(1, 0, CGPointZero, CGSizeMake(16, 16), originalImages,
                                            @"com.apple.coregraphics.Arrow", 0));
            // A previous 1813 backup must not prevent backing up Tahoe's additional name.
            backupCursorForIdentifier(@"com.apple.coregraphics.Arrow");
            assert(applyCursorForIdentifier(1, 0, CGPointMake(3, 4), CGSizeMake(16, 16), originalImages,
                                            @"com.apple.coregraphics.ArrowS", 0));
            original = [[registry copy] autorelease];
            backupAllCursors();
            assert(applyCursorForIdentifier(24, 0.05, CGPointZero, CGSizeMake(16, 16), images,
                                            @"com.apple.coregraphics.Arrow", 0));
            resetAllCursors();
            NSMutableDictionary *expectedRegistry = [[original mutableCopy] autorelease];
            [expectedRegistry removeObjectForKey:@"com.alexzielenski.mousecape.com.apple.coregraphics.Arrow"];
            assert([registry isEqual:expectedRegistry]);

            backupAllCursors();
            assert(applyCursorForIdentifier(24, 0.05, CGPointZero, CGSizeMake(16, 16), images,
                                            @"com.apple.coregraphics.Arrow", 0));
            rejectedName = @"com.apple.coregraphics.ArrowS";
            assert(!resetAllCursors());
            if (!registry[@"com.alexzielenski.mousecape.com.apple.coregraphics.ArrowS"]) {
                fprintf(stderr, "FAIL: failed restoration discarded the only original ArrowS backup\n");
                return 1;
            }
            rejectedName = nil;
            assert(resetAllCursors());
            assert(!registry[@"com.alexzielenski.mousecape.com.apple.coregraphics.ArrowS"]);
        }
        printf("PASS: %s system names, animation arguments, alias failure, invalid inputs, backup/restore\n",
               modernNames ? "Tahoe" : "legacy");
    }
    return 0;
}
