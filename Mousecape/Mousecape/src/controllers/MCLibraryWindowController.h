#import <Cocoa/Cocoa.h>

@class MainSwiftViewController;
@class MCLibraryController;

@interface MCLibraryWindowController : NSWindowController <NSWindowDelegate>
@property (strong) MainSwiftViewController *mainViewController;
@property (readonly) MCLibraryController *libraryController;
@property (weak) IBOutlet NSView *appliedAccessory;
@property (weak) IBOutlet NSProgressIndicator *progressBar;
@property (weak) IBOutlet NSTextField *progressField;
@end

@interface MCAppliedCapeValueTransformer : NSValueTransformer
@end
