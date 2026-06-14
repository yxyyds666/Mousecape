//
//  MCAppDelegate.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "MCAppDelegate.h"
#import "MCLibraryController.h"
#import <Security/Security.h>
#import <ServiceManagement/ServiceManagement.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "MCCursorLibrary.h"
#import "create.h"
#import "MASPreferencesWindowController.h"
#import "MCGeneralPreferencesController.h"
#import "MCWindowsCursorImporter.h"
#import "MCWindowsCursorImportResult.h"

static NSString * const MCMousecloakHelperIdentifier = @"com.alexzielenski.mousecloakhelper";

@interface MCAppDelegate () {
    MASPreferencesWindowController *_preferencesWindowController;
}
@property (readonly) MASPreferencesWindowController *preferencesWindowController;
- (void)configureHelperToolMenuItem;
- (BOOL)isMousecloakHelperEnabled;
- (BOOL)setMousecloakHelperEnabled:(BOOL)enabled error:(NSError **)error;
@end

@implementation MCAppDelegate
@dynamic preferencesWindowController;

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    self.libraryWindowController = [[MCLibraryWindowController alloc] initWithWindowNibName:@"Library"];
    [self.libraryWindowController loadWindow];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self configureHelperToolMenuItem];
    [self.libraryWindowController showWindow:self];
    
    // Re-apply currently applied cape
    if (self.libraryWindowController.libraryController.appliedCape != NULL) {
        [self.libraryWindowController.libraryController applyCape:self.libraryWindowController.libraryController.appliedCape];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
    BOOL open = [filename.pathExtension.lowercaseString isEqualToString:@"cape"];
    NSURL *url = [NSURL fileURLWithPath:filename];
    if (open) {
        [self.libraryWindowController.libraryController importCapeAtURL:url];
    }
    return open;
}

- (void)configureHelperToolMenuItem {
    BOOL enabled = [self isMousecloakHelperEnabled];
    
    [self.toggleHelperItem setTag:enabled ? 1 : 0];
    [self.toggleHelperItem setTitle:self.toggleHelperItem.tag ?
                    NSLocalizedString(@"Uninstall Helper Tool", "Uninstall Helper Tool Menu Item") :
                    NSLocalizedString(@"Install Helper Tool", "Install Helper Tool Menu Item")];
}

- (BOOL)isMousecloakHelperEnabled {
    SMAppService *service = [SMAppService loginItemServiceWithIdentifier:MCMousecloakHelperIdentifier];
    return service.status == SMAppServiceStatusEnabled;
}

- (BOOL)setMousecloakHelperEnabled:(BOOL)enabled error:(NSError **)error {
    SMAppService *service = [SMAppService loginItemServiceWithIdentifier:MCMousecloakHelperIdentifier];
    return enabled ? [service registerAndReturnError:error] : [service unregisterAndReturnError:error];
}

- (IBAction)toggleInstall:(NSMenuItem *)sender {
    BOOL shouldEnable = self.toggleHelperItem.tag == 0;
    NSError *error = nil;
    BOOL success = [self setMousecloakHelperEnabled:shouldEnable error:&error];
    NSAlert *alert = [[NSAlert alloc] init];
    
    if (success) {
        [self configureHelperToolMenuItem];
        alert.messageText = NSLocalizedString(@"Success", "Helper Tool Result Title Success");
        alert.informativeText = shouldEnable ?
            NSLocalizedString(@"The Mousecape helper was installed.", "Helper Tool Install Success Result Description") :
            NSLocalizedString(@"The Mousecape helper was uninstalled.", "Helper Tool Uninstall Success Result Description");
    } else {
        alert.messageText = NSLocalizedString(@"Failure", "Helper Tool Result Title Failure");
        alert.informativeText = error.localizedDescription ?: NSLocalizedString(@"The action did not complete successfully.", "Helper Tool Result Failure Description");
    }
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "Helper Tool Result Button")];
    [alert beginSheetModalForWindow:self.libraryWindowController.window completionHandler:nil];
    
}

- (MASPreferencesWindowController *)preferencesWindowController {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSViewController *general = [[MCGeneralPreferencesController alloc] init];
        _preferencesWindowController = [[MASPreferencesWindowController alloc] initWithViewControllers:@[ general ] title:NSLocalizedString(@"Preferences", "Preferences Window Title")];
    });
    
    return _preferencesWindowController;
}

#pragma mark - Interface Actions

- (IBAction)importWindowsCursor:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    panel.title = NSLocalizedString(@"Import Cursors", @"Panel title for cursor import");
    panel.message = NSLocalizedString(@"Select .cur, .ani files or a Windows cursor theme folder.", @"Panel message for cursor file selection");
    panel.allowedContentTypes = @[
        [UTType typeWithFilenameExtension:@"cur"],
        [UTType typeWithFilenameExtension:@"ani"],
        UTTypeFolder
    ];

    [panel beginSheetModalForWindow:self.libraryWindowController.window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) {
            return;
        }
        NSError *error = nil;
        MCWindowsCursorImportResult *importResult = [MCWindowsCursorImporter importCursorAtURL:panel.URL error:&error];
        NSAlert *alert = [[NSAlert alloc] init];
        if (!importResult || error) {
            alert.messageText = NSLocalizedString(@"Import Failed", @"Alert title when import fails");
            alert.informativeText = error.localizedDescription ?: NSLocalizedString(@"Mousecape could not import this cursor.", @"Alert message when import fails");
        } else {
            [self.libraryWindowController.libraryController importCape:importResult.cursorLibrary];
            alert.messageText = NSLocalizedString(@"Import Complete", @"Alert title when import succeeds");
            alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Imported %@. %lu warnings, %lu skipped roles.", @"Import result summary (ObjC, %lu)"), importResult.cursorLibrary.name, importResult.warnings.count, importResult.skippedRoles.count];
        }
        [alert addButtonWithTitle:NSLocalizedString(@"OK", @"Alert button")];
        [alert beginSheetModalForWindow:self.libraryWindowController.window completionHandler:nil];
    }];
}

- (IBAction)restoreCape:(id)sender {
    [self.libraryWindowController.libraryController restoreCape];
}

- (IBAction)convertCape:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    UTType *mightyMouseType = [UTType typeWithFilenameExtension:@"MightyMouse"];
    if (mightyMouseType) {
        panel.allowedContentTypes = @[ mightyMouseType ];
    } else {
        panel.allowedFileTypes = @[ @"MightyMouse" ];
    }
    panel.title             = NSLocalizedString(@"Import", "MightyMouse Import Panel Title");
    panel.message           = NSLocalizedString(@"Choose a MightyMouse file to import", "MightyMouse Import Panel useless description");
    panel.prompt            = NSLocalizedString(@"Import", "MightyMouse Import Panel Prompt");
    if ([panel runModal] == NSFileHandlingPanelOKButton) {
        NSString *name = panel.URL.lastPathComponent.stringByDeletingPathExtension;
        NSDictionary *metadata = @{
                                   @"name": name,
                                   @"version": @1.0,
                                   @"author": NSLocalizedString(@"Unknown", "MightyMouse Import Default Author"),
                                   @"identifier": [NSString stringWithFormat:@"local.import.%@.%f", name, [NSDate timeIntervalSinceReferenceDate]]
                                   };
        
        NSDictionary *cape = createCapeFromMightyMouse([NSDictionary dictionaryWithContentsOfURL:panel.URL], metadata);
        MCCursorLibrary *library = [MCCursorLibrary cursorLibraryWithDictionary:cape];
        [self.libraryWindowController.libraryController importCape:library];
    }
}

- (IBAction)newDocument:(id)sender {
    [self.libraryWindowController.libraryController importCape:[[MCCursorLibrary alloc] init]];
}

- (IBAction)openDocument:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    UTType *capeType = [UTType typeWithFilenameExtension:@"cape"];
    if (capeType) {
        panel.allowedContentTypes = @[ capeType ];
    } else {
        panel.allowedFileTypes = @[ @"cape" ];
    }
    panel.title             = NSLocalizedString(@"Import", "Mousecape Import Title");
    panel.message           = NSLocalizedString(@"Choose a Mousecape to import", "Mousecape Import useless description");
    panel.prompt            = NSLocalizedString(@"Import", "Mousecape Import Prompt");
    if ([panel runModal] == NSFileHandlingPanelOKButton) {
        [self.libraryWindowController.libraryController importCapeAtURL:panel.URL];
    }
}

- (IBAction)showPreferences:(id)sender {
    [self.preferencesWindowController showWindow:sender];
}

@end
