//
//  restore.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "backup.h"
#import "apply.h"
#import "MCPrefs.h"

NSString *restoreStringForIdentifier(NSString *identifier) {
    return [identifier substringFromIndex:28];
}

BOOL restoreCursorForIdentifier(NSString *ident) {
    bool registered = false;
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)ident.UTF8String, &registered);
    if (!registered) return YES;

    NSString *restoreIdent = restoreStringForIdentifier(ident);
    NSDictionary *cape = capeWithIdentifier(ident);
    
    MMLog("Restoring cursor %s from %s", restoreIdent.UTF8String, ident.UTF8String);
    if (!cape || !applyCapeForIdentifier(cape, restoreIdent, YES)) {
        MMLog(BOLD RED "Could not restore %s; retaining its backup." RESET, restoreIdent.UTF8String);
        return NO;
    }

    return CGSRemoveRegisteredCursor(CGSMainConnectionID(), (char *)ident.UTF8String, false) == kCGErrorSuccess;
}

BOOL resetAllCursors() {
    MMLog("Restoring cursors...");
    
    BOOL restored = YES;
    // Restore each name from its own backup.
    NSUInteger i = 0;
    NSString *key = nil;
    while ((key = defaultCursors[i]) != nil) {
        for (NSString *name in MCCursorNamesForIdentifier(key)) {
            if (!restoreCursorForIdentifier(backupStringForIdentifier(name))) restored = NO;
        }
        i++;
    }

    // Reinitialize known core cursors; gaps in the legacy ID range are not cursors.
    MMLog("Restoring core cursors...");
    if (CoreCursorUnregisterAll(CGSMainConnectionID()) == 0) {
        NSMutableIndexSet *cursorIDs = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)];
        for (NSString *identifier in cursorMap()) {
            if ([identifier hasPrefix:@"com.apple.cursor."]) [cursorIDs addIndex:identifier.pathExtension.integerValue];
        }
        for (NSUInteger cursorID = cursorIDs.firstIndex; cursorID != NSNotFound; cursorID = [cursorIDs indexGreaterThanIndex:cursorID]) {
            CGError error = CoreCursorSet(CGSMainConnectionID(), (CGSCursorID)cursorID);
            if (error != kCGErrorSuccess) {
                MMLog(BOLD RED "Could not initialize core cursor %lu (CGError %d)" RESET, (unsigned long)cursorID, error);
                restored = NO;
            }
        }
    } else {
        restored = NO;
        MMLog(BOLD RED "Received an error while restoring core cursors." RESET);
    }
    if (restored) {
        MCSetDefault(NULL, MCPreferencesAppliedCursorKey);
        MMLog(BOLD GREEN "Successfully restored all cursors." RESET);
    }
    return restored;
}
