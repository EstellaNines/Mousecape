//
//  backup.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "backup.h"
#import "apply.h"

NSString *backupStringForIdentifier(NSString *identifier) {
    return [NSString stringWithFormat:@"com.alexzielenski.mousecape.%@", identifier];
}

BOOL backupCursorForIdentifier(NSString *ident) {
    bool registered = false;
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)ident.UTF8String, &registered);
    
//     dont try to backup a nonexistant cursor
    if (!registered)
        return YES;
    
    NSString *backupIdent = backupStringForIdentifier(ident);
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)backupIdent.UTF8String, &registered);
    
//     don't re-back it up
    if (registered)
        return YES;
    
    NSDictionary *cape = capeWithIdentifier(ident);
    return applyCapeForIdentifier(cape, backupIdent, YES);
}

BOOL backupAllCursors() {
    // Backup main cursors first
    NSUInteger i = 0;
    NSString *key = nil;
    while ((key = defaultCursors[i]) != nil) {
        for (NSString *name in MCCursorNamesForIdentifier(key)) {
            if (!backupCursorForIdentifier(name)) {
                MMLog(BOLD RED "Could not back up %s; aborting application." RESET, name.UTF8String);
                return NO;
            }
        }
        i++;
    }
    // no need to backup core cursors
    return YES;
}
