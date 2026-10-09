#import <Cocoa/Cocoa.h>
#import "MCDefs.h"

// Read-only integration check: compare the running WindowServer with a cape file.
int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "Usage: cursor-readback theme.cape\n");
            return 2;
        }
        NSDictionary *cape = [NSDictionary dictionaryWithContentsOfFile:@(argv[1])];
        NSDictionary *cursors = cape[@"Cursors"];
        if (!cursors.count || CGSMainConnectionID() == 0) {
            fprintf(stderr, "A valid cape and an active desktop connection are required.\n");
            return 1;
        }
        NSUInteger verified = 0;
        for (NSString *identifier in [[cursors allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
            NSDictionary *expected = cursors[identifier];
            for (NSString *name in MCCursorNamesForIdentifier(identifier)) {
                NSDictionary *actual = capeWithIdentifier(name);
                BOOL matches = actual != nil;
                for (NSString *key in @[@"FrameCount", @"FrameDuration", @"PointsWide", @"PointsHigh", @"HotSpotX", @"HotSpotY"]) {
                    matches &= fabs([actual[key] doubleValue] - [expected[key] doubleValue]) < 0.000001;
                }
                matches &= [actual[@"Representations"] count] == [expected[@"Representations"] count];
                if (!matches) {
                    fprintf(stderr, "FAIL: %s does not match the cape metadata\n", name.UTF8String);
                    return 1;
                }
                printf("PASS: %s frames=%lu duration=%g size=%gx%g\n", name.UTF8String,
                    [actual[@"FrameCount"] unsignedIntegerValue], [actual[@"FrameDuration"] doubleValue],
                    [actual[@"PointsWide"] doubleValue], [actual[@"PointsHigh"] doubleValue]);
                verified++;
            }
        }
        printf("PASS: verified %lu registered cursor names against the cape\n", (unsigned long)verified);
    }
    return 0;
}
