#import "MCLibraryWindowController.h"
#import "NSFileManager+DirectoryLocations.h"
#import "Mousecape-Swift.h"

@interface MCLibraryWindowController ()
- (void)composeAccessory;
- (void)applyMinimalImportAppearance;
@end

@implementation MCLibraryWindowController

- (void)awakeFromNib {
    [self applyMinimalImportAppearance];
    [self composeAccessory];
    [self setupSwiftContent];
}

- (NSString *)windowNibName {
    return @"Library";
}

- (MCLibraryController *)libraryController {
    return self.mainViewController.libraryController;
}

- (void)setupSwiftContent {
    NSString *capesPath = [[NSFileManager defaultManager] findOrCreateDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appendPathComponent:@"Mousecape/capes" error:NULL];
    MCLibraryController *controller = [[MCLibraryController alloc] initWithURL:[NSURL fileURLWithPath:capesPath]];
    self.mainViewController = [[MainSwiftViewController alloc] initWithController:controller];
    self.window.contentViewController = self.mainViewController;
}

- (void)composeAccessory {
    if (self.appliedAccessory.superview) {
        return;
    }
    NSView *themeFrame = [self.window.contentView superview];
    NSView *accessory = self.appliedAccessory;
    [accessory setTranslatesAutoresizingMaskIntoConstraints:NO];

    NSRect c  = themeFrame.frame;
    NSRect aV = accessory.frame;
    NSRect newFrame = NSMakeRect(
                                 c.size.width - aV.size.width,
                                 c.size.height - aV.size.height,
                                 aV.size.width,
                                 aV.size.height);

    [accessory setFrame:newFrame];
    [themeFrame addSubview:accessory];

    [themeFrame addConstraints:[NSLayoutConstraint
                                constraintsWithVisualFormat:@"H:|-(>=100)-[accessory(245)]-(0)-|"
                                options:0
                                metrics:nil
                                views:NSDictionaryOfVariableBindings(accessory)]];
    [themeFrame addConstraints:[NSLayoutConstraint
                                constraintsWithVisualFormat:@"V:|-(0)-[accessory(20)]-(>=22)-|"
                                options:0
                                metrics:nil
                                views:NSDictionaryOfVariableBindings(accessory)]];
}

- (void)applyMinimalImportAppearance {
    self.window.title = NSLocalizedString(@"Import Cursors", @"Window title for cursor import");
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return self.libraryController.undoManager;
}

#pragma mark - Menu Actions

- (IBAction)applyCapeAction:(NSMenuItem *)sender {
    MCCursorLibrary *cape = nil;
    if (sender.tag == -1)
        cape = self.mainViewController.clickedCape;
    else
        cape = self.mainViewController.selectedCape;
    [self.libraryController applyCape:cape];
}

- (IBAction)editCapeAction:(NSMenuItem *)sender {
    MCCursorLibrary *cape = nil;
    if (sender.tag == -1)
        cape = self.mainViewController.clickedCape;
    else
        cape = self.mainViewController.selectedCape;
    [self.mainViewController editCape:cape];
}

- (IBAction)removeCapeAction:(NSMenuItem *)sender {
    MCCursorLibrary *cape = nil;
    if (sender.tag == -1)
        cape = self.mainViewController.clickedCape;
    else
        cape = self.mainViewController.selectedCape;
    if (cape != self.mainViewController.editingCape) {
        [self.libraryController removeCape:cape];
    } else {
        [[NSSound soundNamed:@"Funk"] play];
        [self.mainViewController editCape:self.mainViewController.editingCape];
    }
}

- (IBAction)duplicateCapeAction:(NSMenuItem *)sender {
    MCCursorLibrary *cape = nil;
    if (sender.tag == -1)
        cape = self.mainViewController.clickedCape;
    else
        cape = self.mainViewController.selectedCape;
    [self.libraryController importCape:cape.copy];
}

- (IBAction)checkCapeAction:(NSMenuItem *)sender {
}

- (IBAction)showCapeAction:(NSMenuItem *)sender {
    MCCursorLibrary *cape = nil;
    if (sender.tag == -1)
        cape = self.mainViewController.clickedCape;
    else
        cape = self.mainViewController.selectedCape;
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ cape.fileURL ]];
}

- (IBAction)dumpCapeAction:(NSMenuItem *)sender {
    [self.window beginSheet:self.progressBar.window completionHandler:nil];
    __weak MCLibraryWindowController *weakSelf = self;
    self.progressBar.doubleValue = 0.0;
    [self.progressBar setIndeterminate:NO];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [weakSelf.libraryController dumpCursorsWithProgressBlock:^BOOL (NSUInteger current, NSUInteger total) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                weakSelf.progressField.stringValue = [NSString stringWithFormat:@"%lu %@ %lu", (unsigned long)current, NSLocalizedString(@"of", @"Dump cursor progress separator (eg: 5 of 129)"), (unsigned long)total];
                weakSelf.progressBar.minValue = 0;
                weakSelf.progressBar.maxValue = total;
                weakSelf.progressBar.doubleValue = current;
            });
            return YES;
        }];

        dispatch_sync(dispatch_get_main_queue(), ^{
            [weakSelf.window endSheet:self.progressBar.window];
            [[NSCursor arrowCursor] set];
        });
    });
}

@end

@implementation MCAppliedCapeValueTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

- (id)transformedValue:(id)value {
    return [
            NSLocalizedString(@"Applied Cape: ", @"Accessory label for applied cape")
            stringByAppendingString:value ? value : NSLocalizedString(@"None", @"Window Titlebar Accessory label for when no cape is applied")];
}

@end
