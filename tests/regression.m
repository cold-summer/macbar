// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 cold-summer and MacBar contributors.
#define main MacBarApplicationMain
#import "../main.m"
#undef main

static NSUInteger checks = 0;
#define CHECK(condition, message) do { checks++; if (!(condition)) { fprintf(stderr, "FAIL: %s (line %d)\n", message, __LINE__); exit(1); } } while (0)

@interface FakeApplication : NSObject
@property NSString *bundleIdentifier;
@property NSString *localizedName;
@property NSImage *icon;
@property NSURL *bundleURL;
@property NSApplicationActivationPolicy activationPolicy;
@end
@implementation FakeApplication
@end

@interface TestApp : App
@property NSArray *windows;
@property NSDictionary *axRecords;
@property NSDictionary *apps;
@property NSSet *validWindows;
@property BOOL restoreResult;
@property NSUInteger restoreCalls;
@property CGRect testDisplay;
@property NSUInteger lookupCount;
@property BOOL terminateDuringScan;
@property CGWindowID testSeparator;
@property NSMutableArray<NSValue *> *cursorPositions;
@property NSMutableArray<NSDictionary *> *clickEvents;
@property CGError cursorResult;
@property NSUserDefaults *testDefaults;
@property BOOL nativeEnabled;
@property BOOL captureAllowed;
@property NSDictionary *nativeFrames;
@property NSUInteger captureCalls;
@property NSArray *fallbackRequests;
@property NSUInteger appOpenCalls;
@property NSUInteger nativeActivationCalls;
@property BOOL lastNativeRight;
@property BOOL trustedForLayout;
@property NSArray<BarItem *> *scanOverride;
@property BOOL recordPlacementPasses;
@property NSUInteger layoutPassCount;
@property NSSet *lastPlacementKeys;
@end
@implementation TestApp
- (NSUserDefaults *)layoutDefaults { return self.testDefaults ?: [super layoutDefaults]; }
- (BOOL)accessibilityGranted { return self.trustedForLayout; }
- (NSArray *)scanItems { return self.scanOverride ?: [super scanItems]; }
- (void)performPlacementPassForKeys:(NSSet *)keys {
    if (!self.recordPlacementPasses) { [super performPlacementPassForKeys:keys]; return; }
    self.layoutPassCount++; self.lastPlacementKeys = keys.copy; self.layoutDirty = NO;
}
- (BOOL)nativeAppearanceEnabled { return self.nativeEnabled; }
- (BOOL)capturePermissionGranted { return self.captureAllowed; }
- (NSImage *)nativeImageForItem:(BarItem *)item bounds:(CGRect)bounds {
    self.captureCalls++; return self.nativeFrames[item.key];
}
- (void)requestNativeFallback:(NSArray *)requests { self.fallbackRequests = requests; }
- (void)openApplicationForItem:(BarItem *)item { self.appOpenCalls++; }
- (void)activateNativeItem:(BarItem *)item right:(BOOL)right { self.nativeActivationCalls++; self.lastNativeRight = right; }
- (void)layoutRow {}
- (NSArray *)windowList:(BOOL)onScreen {
    if (!onScreen) return self.windows ?: @[];
    return [self.windows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *d, NSDictionary *unused) { return [d[(id)kCGWindowIsOnscreen] boolValue]; }]];
}
- (NSSet *)menuWindowIDs { return self.validWindows; }
- (NSArray *)accessibilityItemsForPID:(pid_t)pid { return self.axRecords[@(pid)] ?: @[]; }
- (NSRunningApplication *)applicationForPID:(pid_t)pid {
    if (self.terminateDuringScan && self.lookupCount++ > 0) return nil;
    return (id)self.apps[@(pid)];
}
- (CGFloat)menuHeight { return 37; }
- (CGWindowID)macBarWindowWide:(BOOL)wide { return self.testSeparator; }
- (CGRect)displayRect { return self.testDisplay; }
- (CGRect)boundsForWindowID:(CGWindowID)wid {
    for (NSDictionary *d in self.windows) if ([d[(id)kCGWindowNumber] unsignedIntValue] == wid) return [self windowBounds:d];
    return CGRectNull;
}
- (BOOL)moveItem:(BarItem *)item toHidden:(BOOL)hidden { self.restoreCalls++; return self.restoreResult; }
- (void)logEvent:(NSString *)event item:(BarItem *)item detail:(NSString *)detail {}
- (void)reportError:(NSString *)message { self.lastError = message; }
- (CGError)warpCursorToPoint:(CGPoint)point {
    [self.cursorPositions addObject:[NSValue valueWithPoint:point]];
    return self.cursorResult;
}
- (BOOL)postClickEvent:(CGEventRef)event {
    [self.clickEvents addObject:@{@"point": [NSValue valueWithPoint:CGEventGetLocation(event)], @"type": @(CGEventGetType(event))}];
    return YES;
}
@end
static NSDictionary *Window(int pid, int wid, CGRect rect, BOOL on, int layer) {
    return @{(id)kCGWindowOwnerPID: @(pid), (id)kCGWindowNumber: @(wid), (id)kCGWindowBounds: CFBridgingRelease(CGRectCreateDictionaryRepresentation(rect)), (id)kCGWindowIsOnscreen: @(on), (id)kCGWindowLayer: @(layer)};
}
static NSDictionary *AX(CGRect rect, NSString *identifier, NSString *name) {
    return @{@"bounds": [NSValue valueWithRect:rect], @"identifier": identifier, @"name": name};
}
static NSImage *GlyphImage(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha, BOOL shadow) {
    CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(NULL, 96, 24, 8, 96 * 4, color, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(color);
    if (shadow) { CGContextSetRGBFillColor(bitmap, 0, 0, 0, 0.3); CGContextFillRect(bitmap, CGRectMake(2, 1, 92, 22)); }
    CGContextSetRGBFillColor(bitmap, red, green, blue, alpha);
    CGContextFillRect(bitmap, CGRectMake(24, 6, 48, 12));
    CGImageRef image = CGBitmapContextCreateImage(bitmap);
    NSImage *result = [[NSImage alloc] initWithCGImage:image size:NSMakeSize(96, 24)];
    CGImageRelease(image); CGContextRelease(bitmap);
    return result;
}
int main(void) {
    @autoreleasepool {
        CHECK(MBAXFrameMatchesWindow(CGRectMake(1419, 7.5, 26, 22), CGRectMake(1411, 0, 42, 37)), "AX icon insets match their containing status window");
        CHECK(!MBAXFrameMatchesWindow(CGRectMake(1461, 7.5, 22, 22), CGRectMake(1411, 0, 42, 37)), "neighbor icon never matches");
        CHECK(MBRectIsVisible(CGRectMake(-1500, 10, 30, 24), CGRectMake(-1920, 0, 1920, 1080)), "left display has negative visible x");
        CHECK(MBRectIsVisible(CGRectMake(200, -800, 30, 24), CGRectMake(0, -900, 1600, 900)), "display above primary");
        CHECK(!MBRectIsVisible(CGRectMake(-2000, 0, 30, 24), CGRectMake(0, 0, 1728, 1117)), "offscreen is hidden");
        CHECK(MBRectIsMenuItem(CGRectMake(-1500, -900, 84, 24), CGRectMake(-1920, -900, 1920, 1080)), "menu coordinates relative to selected display");
        CHECK(!MBShouldRestore(YES, 120, 50), "never force hide open menu after twelve seconds");
        CHECK(!MBShouldRestore(NO, 0.5, 3), "allow asynchronous popup to appear");
        CHECK(!MBShouldRestore(NO, 2, 2), "debounce disappearing popup");
        CHECK(MBShouldRestore(NO, 2, 3), "restore after closure");
        CHECK(MBLegacyContainsBundle(@[@"com.example|App|38", @"com.example|App|84"], @"com.example"), "legacy widths migrate by application");
        CHECK(!MBLegacyContainsBundle(@[@"com.example.extra|App|38"], @"com.example"), "migration cannot prefix-match another app");
        CHECK(!MBLegacyContainsBundle(@[@"com.example|App|38"], nil), "terminated application cannot crash legacy migration");
        CHECK(!MBLegacyContainsBundle(@[@"|App|38"], @""), "empty bundle cannot migrate preferences");
        CHECK(MBLegacyContainsBundle((id)@[@42, NSNull.null, @"com.example|App|38"], @"com.example"), "malformed old entries are ignored");
        TestApp *app = [TestApp new]; app.testDisplay = CGRectMake(0, 0, 1728, 1117);
        FakeApplication *fake = [FakeApplication new]; fake.bundleIdentifier = @"com.example"; fake.localizedName = @"Example";
        app.apps = @{@42: fake}; app.imageCache = [NSMutableDictionary dictionary];
        CGRect first = CGRectMake(1400, 0, 38, 37), second = CGRectMake(-4000, 0, 38, 37);
        app.windows = @[Window(42, 100, first, YES, 25), Window(42, 101, second, NO, 25)];
        app.axRecords = @{@42: @[AX(first, @"first", @"A 10%"), AX(second, @"second", @"B") ]};
        NSArray *scan = [app scanItems]; CHECK(scan.count == 2, "same process has two distinct items");
        BarItem *hidden = scan[0], *visible = scan[1];
        CHECK(![hidden.key isEqualToString:visible.key], "same width never merges two items");
        CHECK(![app itemHasVisibleCopy:hidden], "visible sibling must not make hidden item visible");
        CHECK([app itemHasVisibleCopy:visible], "exact visible window recognized");
        NSString *key = visible.key;
        CGRect changed = CGRectMake(1390, 0, 84, 37);
        app.windows = @[Window(42, 100, changed, YES, 25), Window(42, 101, second, NO, 25)];
        app.axRecords = @{@42: @[AX(changed, @"first", @"A 90%"), AX(second, @"second", @"B") ]};
        CHECK([((BarItem *)[app scanItems].lastObject).key isEqualToString:key], "width and dynamic title do not change identity");
        app.catalog = [[app scanItems] mutableCopy]; app.axRecords = @{};
        CHECK([((BarItem *)[app scanItems].lastObject).key isEqualToString:key], "temporary AX failure preserves exact living instance");
        app.axRecords = @{@42: @[AX(changed, @"replacement", @"Replacement")]};
        CHECK(![((BarItem *)[app scanItems].lastObject).key isEqualToString:key], "fresh AX identity overrides stale cached window identity");
        app.axRecords = @{};
        app.catalog = nil;
        for (BarItem *item in [app scanItems]) CHECK(!item.persistentIdentity, "ambiguous no-ID items are not silently combined");
        app.windows = @[Window(42, 100, changed, YES, 25)];
        NSString *primary = ((BarItem *)[app scanItems].firstObject).key;
        app.windows = @[Window(42, 200, CGRectMake(1300, 0, 99, 37), YES, 25)];
        CHECK([primary isEqualToString:((BarItem *)[app scanItems].firstObject).key], "single fallback identity survives restart and width change");
        app.terminateDuringScan = YES;
        CHECK([app scanItems].count == 0, "process exit between window scan and app lookup is safely skipped");
        app.terminateDuringScan = NO;
        // An unrelated app's popup must never extend the click transaction.
        app.windows = @[Window(99, 300, CGRectMake(1200, 40, 200, 200), YES, 101)];
        CHECK([app popupSince:@{} preferPid:42] == 0, "unrelated popup ignored");
        app.windows = @[Window(42, 301, CGRectMake(1200, 40, 200, 200), NO, 101)];
        CHECK([app popupSince:@{} preferPid:42] == 0, "offscreen old popup ignored");
        app.windows = @[Window(42, 301, CGRectMake(1200, 40, 200, 200), YES, 101)];
        CHECK([app popupSince:@{} preferPid:42] == 301, "target native popup observed");
        CHECK([app popupSince:[app windowBoundsSnapshot] preferPid:42] == 0, "preexisting popup excluded");
        // Recovery failure retains the exact original item; only confirmed restoration clears it.
        app.windows = @[Window(42, 100, first, YES, 25)];
        app.pendingRehide = visible; app.restoreResult = NO;
        [app rehidePendingItem];
        CHECK(app.pendingRehide == visible && app.restoreFailures == 1, "failed restoration stays queued");
        app.restoreResult = YES; [app rehidePendingItem];
        CHECK(!app.pendingRehide && app.restoreCalls == 2, "successful restoration clears transaction");
        app.pendingRehide = hidden; app.windows = @[Window(42, 999, first, YES, 25)];
        [app rehidePendingItem];
        CHECK(!app.pendingRehide && app.restoreCalls == 2, "dead target never replaced with same-PID sibling");
        app.suppressed = YES; app.testSeparator = 900;
        app.windows = @[Window(getpid(), 900, CGRectMake(-3000, 0, 4300, 37), NO, 25),
            Window(42, 401, CGRectMake(-3100, 0, 38, 37), NO, 25),
            Window(42, 402, CGRectMake(-1500, 0, 38, 37), NO, 25)];
        scan = [app scanItems];
        CHECK(scan.count == 1 && ((BarItem *)scan.firstObject).windowID == 401, "stale copy overlapping spacer is excluded while real hidden item remains");
        // Opening a native menu must leave the pointer at its revealed icon.
        // Observe cursor moves and event delivery without touching the real mouse.
        app.cursorPositions = [NSMutableArray array]; app.clickEvents = [NSMutableArray array];
        app.windows = @[Window(42, visible.windowID, first, YES, 25)];
        CHECK([app clickVisibleItem:visible right:NO], "left native click delivered");
        CHECK(app.cursorPositions.count == 1 && NSEqualPoints(app.cursorPositions.lastObject.pointValue, NSMakePoint(1419, 18.5)), "pointer follows top icon once without jumping back to collection row");
        CHECK(app.clickEvents.count == 2 && [app.clickEvents[0][@"type"] unsignedIntValue] == kCGEventLeftMouseDown && [app.clickEvents[1][@"type"] unsignedIntValue] == kCGEventLeftMouseUp, "following pointer preserves single down/up click");
        app.testDisplay = CGRectMake(-1920, -900, 1920, 1080);
        app.windows = @[Window(42, visible.windowID, CGRectMake(-1500, -900, 38, 37), YES, 25)];
        [app.cursorPositions removeAllObjects]; [app.clickEvents removeAllObjects];
        CHECK([app clickVisibleItem:visible right:YES] && NSEqualPoints(app.cursorPositions.lastObject.pointValue, NSMakePoint(-1481, -881.5)), "right click follows exact Quartz coordinates on negative-coordinate display");
        CHECK([app.clickEvents[0][@"type"] unsignedIntValue] == kCGEventRightMouseDown && [app.clickEvents[1][@"type"] unsignedIntValue] == kCGEventRightMouseUp, "right-click behavior remains intact");
        app.cursorResult = kCGErrorFailure; [app.clickEvents removeAllObjects];
        CHECK(![app clickVisibleItem:visible right:NO] && app.clickEvents.count == 0, "cursor positioning failure does not click at a mismatched location");
        NSString *suite = [@"cc.icc.macbar.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
        TestApp *layout = [TestApp new];
        layout.testDefaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        layout.testDisplay = CGRectMake(0, 0, 1728, 1117);
        layout.apps = @{@42: fake}; layout.windows = @[Window(42, 500, first, YES, 25)];
        layout.imageCache = [NSMutableDictionary dictionary];
        NSString *hiddenKey = MBItemKey(@"com.example", @"primary");
        [layout moveKey:hiddenKey toPlacement:@"hidden"];
        [layout reloadItems];
        CHECK(layout.catalog.count == 1 && layout.items.count == 0, "not-displayed item stays in settings catalog but is absent from collection row");
        CHECK([((BarItem *)layout.catalog.firstObject).placement isEqualToString:@"hidden"], "hidden placement survives automatic preference migration");
        CHECK([layout itemsInPlacement:@"top" from:layout.catalog].count == 0 && [layout itemsInPlacement:@"hidden" from:layout.catalog].count == 1, "hidden item is excluded from top and included in recoverable settings section");
        layout.testDefaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        layout.axRecords = @{@42: @[AX(first, @"new-id", @"New name")]};
        [layout reloadItems];
        CHECK(layout.items.count == 0 && [((BarItem *)layout.catalog.firstObject).key isEqualToString:hiddenKey], "hidden preference survives defaults reopening and newly available AX identifier");
        [layout moveKey:hiddenKey toPlacement:@"bar"]; [layout reloadItems];
        CHECK(layout.items.count == 1 && [layout.testDefaults stringArrayForKey:@"MBHiddenOrderV2"].count == 0, "hidden item can be restored to collection row without conflicting preferences");
        [layout moveKey:hiddenKey toPlacement:@"hidden"]; [layout moveKey:hiddenKey toPlacement:@"top"]; [layout reloadItems];
        CHECK([((BarItem *)layout.catalog.firstObject).placement isEqualToString:@"top"] && [layout.testDefaults stringArrayForKey:@"MBHiddenOrderV2"].count == 0, "hidden item can be restored to top menu bar");
        BarItem *system = [BarItem new]; system.key = @"system-test"; system.bundleID = @"com.apple.test"; system.systemItem = YES; system.persistentIdentity = YES;
        [layout moveKey:system.key toPlacement:@"hidden"]; [layout rememberLayoutForItems:@[system]];
        CHECK([[layout.testDefaults stringArrayForKey:@"MBHiddenOrderV2"] containsObject:system.key] && ![[layout.testDefaults stringArrayForKey:@"MBTopOrderV2"] containsObject:system.key], "explicit system icon hidden preference is preserved during migration");
        CHECK([layout itemsInPlacement:@"hidden" from:@[system]].count == 1, "system icon can appear in hidden settings section");
        [layout moveKey:system.key toPlacement:@"bar"]; [layout rememberLayoutForItems:@[system]];
        CHECK([layout itemsInPlacement:@"bar" from:@[system]].count == 1, "system icon collection placement is preserved");
        BarItem *newSystem = [BarItem new]; newSystem.key = @"new-system"; newSystem.bundleID = @"com.apple.new"; newSystem.systemItem = YES; newSystem.persistentIdentity = YES;
        [layout rememberLayoutForItems:@[newSystem]];
        CHECK([layout itemsInPlacement:@"top" from:@[newSystem]].count == 1, "new system icon defaults to top until explicitly changed");
        layout.suppressed = YES; layout.restoreResult = NO;
        CHECK(![layout applyPlacement:@"hidden" toItem:system] && [[layout.testDefaults stringArrayForKey:@"MBBarOrderV2"] containsObject:system.key], "rejected system movement keeps original saved placement");
        CHECK([layout.lastError containsString:@"系统图标"], "rejected system movement explains failure");
        layout.restoreResult = YES;
        CHECK([layout applyPlacement:@"hidden" toItem:system] && !layout.lastError && [[layout.testDefaults stringArrayForKey:@"MBHiddenOrderV2"] containsObject:system.key], "confirmed system movement saves new placement and clears old error");
        // A native status item is wider than its app icon and includes text.
        CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
        CGContextRef bitmap = CGBitmapContextCreate(NULL, 336, 74, 8, 336 * 4, color, kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(color);
        CGImageRef empty = CGBitmapContextCreateImage(bitmap);
        CHECK(MBStatusImage(empty, CGSizeMake(168, 37)) == nil, "blank offscreen image is rejected");
        CGImageRelease(empty);
        CGContextSetRGBFillColor(bitmap, 1, 1, 1, 1);
        CGContextFillRect(bitmap, CGRectMake(280, 18, 40, 38));
        CGImageRef raw = CGBitmapContextCreateImage(bitmap);
        NSImage *native = MBStatusImage(raw, CGSizeMake(168, 37));
        CHECK(NSEqualSizes(native.size, NSMakeSize(168, 24)), "native text width retained at original point scale while vertical padding trimmed");
        CGImageRef cropped = [native CGImageForProposedRect:NULL context:nil hints:nil];
        CHECK(CGImageGetWidth(cropped) == 336 && CGImageGetHeight(cropped) == 48, "Retina pixel resolution retained");
        CHECK(MBStatusImage(raw, CGSizeZero) == nil, "invalid window geometry cannot produce distorted native content");
        CGContextSetRGBFillColor(bitmap, 0, 0, 0, 1); CGContextFillRect(bitmap, CGRectMake(0, 0, 336, 74));
        CGImageRef solid = CGBitmapContextCreateImage(bitmap);
        CHECK(MBStatusImage(solid, CGSizeMake(168, 37)) == nil, "solid placeholder cannot overwrite cached native text");
        CGImageRelease(solid); CGImageRelease(raw); CGContextRelease(bitmap);
        TestApp *render = [TestApp new]; render.nativeEnabled = YES;
        BarItem *textItem = [BarItem new]; textItem.key = @"native-text"; textItem.windowID = 700; textItem.placement = @"bar";
        render.catalog = [NSMutableArray arrayWithObject:textItem];
        render.windows = @[Window(42, 700, CGRectMake(-5000, 0, 168, 37), NO, 25)];
        render.imageCache = [NSMutableDictionary dictionary]; render.nativeFrames = @{textItem.key: native};
        [render captureAvailableImages];
        CHECK(render.captureCalls == 0 && textItem.statusImage == nil, "native capture never runs without screen recording permission");
        render.captureAllowed = YES; [render captureAvailableImages];
        CHECK(textItem.statusImage == native && [render slotWidthForItem:textItem] == 174, "native image uses full width instead of old 96-point cap");
        NSImage *updated = [native copy]; updated.size = NSMakeSize(190, 24);
        render.nativeFrames = @{textItem.key: updated}; [render captureAvailableImages];
        CHECK(textItem.statusImage == updated && [render slotWidthForItem:textItem] == 196, "dynamic text changes refresh snapshot and layout width");
        render.nativeFrames = @{}; [render captureAvailableImages];
        CHECK(textItem.statusImage == updated && render.imageCache[textItem.key] == updated, "failed capture retains last successful native image");
        CHECK(render.fallbackRequests.count == 1 && [render.fallbackRequests[0][@"window"] unsignedIntValue] == 700, "missing native frame requests fallback for exact status window");
        textItem.pid = 42;
        CHECK(![render acceptNativeImage:native forKey:textItem.key pid:42 window:701], "late fallback for replaced status window is rejected");
        CHECK(![render acceptNativeImage:native forKey:textItem.key pid:43 window:700], "late fallback for another process is rejected");
        CHECK([render acceptNativeImage:native forKey:textItem.key pid:42 window:700] && textItem.statusImage == native, "valid asynchronous frame updates native status content");
        render.captureAllowed = NO;
        CHECK(![render acceptNativeImage:updated forKey:textItem.key pid:42 window:700], "permission revocation rejects in-flight capture results");
        NSImage *whiteGlyph = GlyphImage(1, 1, 1, 1, NO);
        NSImage *blackGlyph = GlyphImage(0, 0, 0, 1, NO);
        CHECK(MBNativeForegroundLuminance(whiteGlyph).doubleValue > 0.99, "white native glyph detected despite transparent padding");
        CHECK(MBNativeForegroundLuminance(blackGlyph) != nil && MBNativeForegroundLuminance(blackGlyph).doubleValue < 0.01, "black native glyph detected independently of transparent padding");
        CHECK(MBNativeForegroundLuminance(GlyphImage(1, 1, 1, 1, YES)).doubleValue > 0.99, "soft black shadow cannot make white native content select a light capsule");
        NSImage *brand = GlyphImage(1, 0, 0.6, 1, NO);
        NSData *brandPixels = brand.TIFFRepresentation;
        CHECK(MBNativeForegroundLuminance(brand) == nil && [brandPixels isEqualToData:brand.TIFFRepresentation], "brand colors are excluded from tone voting and remain unchanged");
        CHECK(MBPreferDarkBackground(@[@1, @0.95, @0.1], NO), "white native content selects dark background even in light system appearance");
        CHECK(!MBPreferDarkBackground(@[@0, @0.1, @0.9], YES), "black native content selects light background even in dark system appearance");
        CHECK(MBPreferDarkBackground(@[], YES) && !MBPreferDarkBackground(@[], NO), "application-icon-only row follows system appearance");
        TestApp *contrast = [TestApp new];
        BarItem *contrastItem = [BarItem new]; contrastItem.statusImage = whiteGlyph;
        contrast.items = [NSMutableArray arrayWithObject:contrastItem]; [contrast updateCollectionAppearance];
        CHECK(contrast.collectionDark.boolValue, "collection applies dark appearance for captured white glyphs");
        contrastItem.statusImage = blackGlyph; [contrast updateCollectionAppearance];
        CHECK(!contrast.collectionDark.boolValue, "collection appearance updates when source menu switches foreground color");
        CHECK(MBClickOpensApplication(@{}, NSApplicationActivationPolicyRegular, NO), "normal application left click opens the client without a bundle allowlist");
        CHECK(MBClickOpensApplication(@{}, NSApplicationActivationPolicyAccessory, NO), "normal app that temporarily hides its Dock icon can still reopen its main window");
        CHECK(!MBClickOpensApplication(@{}, NSApplicationActivationPolicyRegular, YES), "right click always retains the native tray path");
        CHECK(!MBClickOpensApplication(@{@"LSUIElement": @YES}, NSApplicationActivationPolicyAccessory, NO), "agent-only utility left click retains native panel behavior");
        CHECK(MBClickOpensApplication(@{@"LSUIElement": @YES}, NSApplicationActivationPolicyRegular, NO), "agent that promotes itself to a normal app can reopen its client");
        CHECK(!MBClickOpensApplication(@{@"LSBackgroundOnly": @YES}, NSApplicationActivationPolicyRegular, NO), "background-only app is never reopened by a tray click");
        CHECK(!MBClickOpensApplication(@{}, NSApplicationActivationPolicyProhibited, NO) && !MBClickOpensApplication(nil, NSApplicationActivationPolicyRegular, NO), "missing metadata and prohibited helpers cannot be mistaken for normal applications");
        CHECK(MBClickMatchesPending(@"item", YES, @"item", YES) && !MBClickMatchesPending(@"item", NO, @"item", YES), "opposite buttons on the same item are different gestures");
        NSString *fixtureRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSString *normalPath = [fixtureRoot stringByAppendingPathComponent:@"Normal.app"];
        NSString *agentPath = [fixtureRoot stringByAppendingPathComponent:@"Agent.app"];
        for (NSString *path in @[normalPath, agentPath]) {
            [NSFileManager.defaultManager createDirectoryAtPath:[path stringByAppendingPathComponent:@"Contents"] withIntermediateDirectories:YES attributes:nil error:nil];
            NSMutableDictionary *info = [@{@"CFBundlePackageType": @"APPL", @"CFBundleIdentifier": [path isEqualToString:normalPath] ? @"org.unlisted.normal" : @"org.unlisted.agent"} mutableCopy];
            if ([path isEqualToString:agentPath]) info[@"LSUIElement"] = @YES;
            [info writeToFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"] atomically:YES];
        }
        FakeApplication *clickApp = [FakeApplication new]; clickApp.bundleURL = [NSURL fileURLWithPath:normalPath]; clickApp.activationPolicy = NSApplicationActivationPolicyAccessory;
        TestApp *clicks = [TestApp new];
        clicks.apps = @{@42: clickApp};
        BarItem *client = [BarItem new]; client.pid = 42; client.bundleID = @"org.never-seen-before"; client.key = @"generic-client"; client.placement = @"bar";
        [clicks activateItem:client right:NO];
        CHECK(clicks.appOpenCalls == 1 && clicks.nativeActivationCalls == 0 && clicks.restoreCalls == 0, "left click opens main window without replaying tray click or moving the icon");
        [clicks activateItem:client right:YES];
        CHECK(clicks.appOpenCalls == 1 && clicks.nativeActivationCalls == 1 && clicks.lastNativeRight, "right click forwards to native context-menu path");
        clicks.pendingRehide = client; clicks.restoreSuspended = YES; [clicks activateItem:client right:NO];
        CHECK(clicks.appOpenCalls == 2 && clicks.pendingRehide == client && clicks.restoreSuspended, "opening main window keeps existing suspended recovery transaction alive");
        client.placement = @"hidden"; [clicks activateItem:client right:NO];
        CHECK(clicks.appOpenCalls == 2, "stale cell cannot activate an item configured not to display");
        client.placement = @"bar"; clicks.pendingRehide = nil; clicks.restoreSuspended = NO;
        clickApp.bundleURL = [NSURL fileURLWithPath:agentPath];
        [clicks activateItem:client right:NO];
        CHECK(clicks.appOpenCalls == 2 && clicks.nativeActivationCalls == 2 && !clicks.lastNativeRight, "unknown agent-only app uses native left click without launching a client");
        [clicks activateItem:client right:YES];
        CHECK(clicks.appOpenCalls == 2 && clicks.nativeActivationCalls == 3 && clicks.lastNativeRight, "agent right click retains its distinct native button");
        clickApp.bundleURL = nil; [clicks activateItem:client right:NO];
        CHECK(clicks.appOpenCalls == 2 && clicks.nativeActivationCalls == 4 && !clicks.lastNativeRight, "missing application bundle safely retains native behavior");
        clicks.apps = @{}; [clicks activateItem:client right:NO];
        CHECK(clicks.appOpenCalls == 2 && clicks.nativeActivationCalls == 5, "terminated process cannot cause an unrelated app to be opened");
        [NSFileManager.defaultManager removeItemAtPath:fixtureRoot error:nil];
        TestApp *refresh = [TestApp new]; refresh.testDefaults = layout.testDefaults;
        refresh.trustedForLayout = YES; refresh.lastTrusted = YES; refresh.recordPlacementPasses = YES; refresh.suppressed = YES;
        BarItem *oldBar = [BarItem new]; oldBar.key = @"refresh-old"; oldBar.bundleID = @"org.refresh.old"; oldBar.name = @"Old"; oldBar.persistentIdentity = YES;
        refresh.scanOverride = @[oldBar]; refresh.catalog = [NSMutableArray arrayWithObject:oldBar];
        [refresh refreshEnvironment];
        CHECK(refresh.layoutPassCount == 0, "periodic snapshot refresh never moves existing icons");
        BarItem *indicator = [BarItem new]; indicator.key = @"refresh-recording"; indicator.bundleID = @"com.apple.controlcenter"; indicator.name = @"Recording"; indicator.systemItem = YES; indicator.persistentIdentity = YES;
        refresh.scanOverride = @[oldBar, indicator]; [refresh refreshEnvironment];
        CHECK(refresh.layoutPassCount == 0, "appearing screen-capture indicator cannot trigger full menu-bar dragging");
        refresh.scanOverride = @[oldBar]; [refresh refreshEnvironment];
        CHECK(refresh.layoutPassCount == 0, "disappearing capture indicator cannot trigger full menu-bar dragging");
        [refresh appsChanged:[NSNotification notificationWithName:NSWorkspaceDidLaunchApplicationNotification object:nil]];
        CHECK(!refresh.layoutDirty && !refresh.screenNeedsRefresh, "ordinary app launch notification does not invalidate display context or full layout");
        BarItem *newBar = [BarItem new]; newBar.key = @"refresh-new"; newBar.bundleID = @"org.refresh.new"; newBar.name = @"New"; newBar.persistentIdentity = YES;
        refresh.scanOverride = @[oldBar, newBar]; [refresh refreshEnvironment];
        CHECK(refresh.layoutPassCount == 1 && [refresh.lastPlacementKeys isEqualToSet:[NSSet setWithObject:newBar.key]], "new collected item applies only its own placement without moving other icons");
        [refresh refreshEnvironment];
        CHECK(refresh.layoutPassCount == 1, "next timer tick does not repeat placement pass for the same item");
        refresh.suppressed = NO;
        BarItem *expandedNew = [BarItem new]; expandedNew.key = @"refresh-expanded"; expandedNew.bundleID = @"org.refresh.expanded"; expandedNew.name = @"Expanded"; expandedNew.persistentIdentity = YES;
        refresh.scanOverride = @[oldBar, newBar, expandedNew]; [refresh refreshEnvironment];
        CHECK(refresh.layoutPassCount == 1, "user-expanded top bar stays expanded when new icons appear");
        [refresh retryLayout:nil];
        CHECK(refresh.layoutPassCount == 2 && refresh.lastPlacementKeys == nil, "explicit retry can still apply the complete saved layout");
        [refresh appsChanged:[NSNotification notificationWithName:NSWorkspaceActiveSpaceDidChangeNotification object:nil]];
        CHECK(!refresh.layoutDirty, "space activation alone does not force a layout pass");
        [refresh appsChanged:[NSNotification notificationWithName:NSApplicationDidChangeScreenParametersNotification object:nil]];
        CHECK(refresh.layoutDirty && refresh.screenNeedsRefresh, "real display geometry change requests fresh screen context");
        TestApp *recovery = [TestApp new]; recovery.testDisplay = CGRectMake(0, 0, 1728, 1117);
        recovery.pendingRehide = visible; recovery.windows = @[Window(42, visible.windowID, first, YES, 25)];
        recovery.restoreResult = NO;
        for (NSUInteger attempt = 0; attempt < 6; attempt++) [recovery rehidePendingItem];
        [recovery watchPendingRehide];
        CHECK(recovery.restoreCalls == 3 && recovery.restoreFailures == 3 && recovery.restoreSuspended && recovery.rehideTimer == nil, "three failed restorations stop automatic dragging and timer retries");
        CHECK(recovery.pendingRehide == visible, "suspended restoration retains the exact pending item");
        recovery.testDefaults = layout.testDefaults; recovery.trustedForLayout = YES; recovery.lastTrusted = YES;
        recovery.recordPlacementPasses = YES; recovery.scanOverride = @[visible]; recovery.catalog = [NSMutableArray arrayWithObject:visible]; recovery.layoutDirty = YES;
        [recovery refreshEnvironment];
        CHECK(recovery.layoutPassCount == 0 && recovery.restoreCalls == 3, "suspended recovery allows read-only refresh without more automatic movements");
        [recovery retryLayout:nil];
        CHECK(!recovery.pendingRehide && !recovery.restoreSuspended && recovery.layoutPassCount == 1, "manual retry explicitly transfers suspended task into full layout application");
        TestApp *displayCopy = [TestApp new]; displayCopy.testDisplay = CGRectMake(0, 0, 1728, 1117);
        displayCopy.windows = @[Window(42, visible.windowID, CGRectMake(3143, 0, 38, 24), YES, 25)];
        CHECK([displayCopy statusCopiesForItem:visible].count == 0, "replica on another menu-bar height cannot be mistaken for the active display target");
        FakeApplication *spotlight = [FakeApplication new]; spotlight.bundleIdentifier = @"com.apple.Spotlight"; spotlight.localizedName = @"Spotlight";
        displayCopy.apps = @{@42: spotlight}; displayCopy.testDefaults = layout.testDefaults;
        displayCopy.windows = @[Window(42, 901, first, YES, 25)]; displayCopy.axRecords = @{@42: @[AX(first, @"", @"聚焦")]};
        NSString *spotlightKey = MBItemKey(spotlight.bundleIdentifier, @"primary");
        [displayCopy moveKey:spotlightKey toPlacement:@"hidden"];
        CHECK([((BarItem *)[displayCopy scanItems].firstObject).key isEqualToString:spotlightKey], "new AX description does not change saved singleton system identity and re-trigger placement");
        CGRect wideSeparator = CGRectMake(-2000, 0, 3300, 37), activeDisplay = CGRectMake(0, 0, 1728, 1117);
        CHECK(MBPlacementMatches(first, wideSeparator, activeDisplay, NO), "already-top placement is valid independently of inactive-display onScreen flag");
        CHECK(MBPlacementMatches(CGRectMake(-2100, 0, 38, 37), wideSeparator, activeDisplay, YES), "already-hidden item requires no repeated drag");
        CHECK(!MBPlacementMatches(CGRectMake(3143, 0, 38, 24), wideSeparator, activeDisplay, NO), "another display replica never satisfies current-screen placement");
        [layout.testDefaults removePersistentDomainForName:suite];
        printf("PASS: %lu regression assertions\n", (unsigned long)checks);
    }
    return 0;
}
