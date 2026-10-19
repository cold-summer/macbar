// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 cold-summer and MacBar contributors.
// Menu bar event/capture portions adapted with reference to Ice,
// Copyright (C) 2024 Jordan Baird. See LICENSE and NOTICE.
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <dlfcn.h>
#import "MBPolicy.h"

typedef CFMachPortRef (*MBEventTapForPid)(pid_t, CGEventTapPlacement, CGEventTapOptions, CGEventMask, CGEventTapCallBack, void *);

static const CGFloat kButton = 30;
static const CGFloat kGap = 4;
static const CGFloat kPadX = 10;
static const CGFloat kPadY = 6;

@interface BarItem : NSObject
@property pid_t pid;
@property CGWindowID windowID;
@property NSString *bundleID;
@property NSString *name;
@property NSImage *icon;
@property NSImage *statusImage;
@property BOOL persistentIdentity;
@property NSString *identityToken;
@property NSString *issue;
@property CGFloat width;
@property CGFloat sortX;
@property NSString *key;
@property BOOL systemItem;
@property NSString *placement;
@end
@implementation BarItem
@end

@class App;

@interface IconCell : NSView
@property (nonatomic, weak) App *owner;
@property NSString *itemKey;
@property BOOL highlighted;
@property BOOL rightClick;
@end

@interface App : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSStatusItem *anchor;
@property (nonatomic, strong) NSStatusItem *spacer;
@property (nonatomic, strong) NSPanel *panel;
@property (nonatomic, strong) NSVisualEffectView *effect;
@property (nonatomic, strong) NSView *row;
@property (nonatomic, strong) NSMutableArray<BarItem *> *items;
@property (nonatomic, strong) NSMutableArray<BarItem *> *catalog;
@property (nonatomic, strong) NSTimer *rehideTimer;
@property (nonatomic, assign) BOOL suppressed;
@property (nonatomic, strong) id globalClick;
@property (nonatomic, strong) id localKey;
@property (nonatomic, strong) NSWindow *settingsWindow;
@property (nonatomic, strong) NSDate *panelOpenedAt;
@property (nonatomic, strong) BarItem *pendingRehide;
@property (nonatomic, assign) CGWindowID pendingPopup;
@property (nonatomic, assign) BOOL revealingForClick;
@property (nonatomic, assign) BOOL trackingMenu;
- (void)activateItem:(BarItem *)item right:(BOOL)right;
- (BOOL)clickOpensApplicationForItem:(BarItem *)item right:(BOOL)right;
- (BarItem *)itemForKey:(NSString *)key;
- (BOOL)moveItem:(BarItem *)item toHidden:(BOOL)hidden;
- (BOOL)dragItem:(BarItem *)item beforeWindow:(CGWindowID)targetWindow;
- (CGRect)boundsForWindowID:(CGWindowID)windowID;
- (BOOL)itemHasVisibleCopy:(BarItem *)item;
- (void)reloadItems;
- (void)refreshEnvironment;
- (void)logEvent:(NSString *)event item:(BarItem *)item detail:(NSString *)detail;
@property NSScreen *activeScreen;
@property NSDate *pendingStarted;
@property NSDictionary *pendingBefore;
@property NSUInteger absentSamples;
@property NSUInteger restoreFailures;
@property BOOL restoreSuspended;
@property BOOL restoringIcon;
@property NSTimer *environmentTimer;
@property BOOL refreshScheduled;
@property BOOL refreshing;
@property BOOL lastTrusted;
@property BOOL layoutDirty;
@property BOOL screenNeedsRefresh;
@property NSString *lastError;
@property NSMutableDictionary *imageCache;
@property NSTextField *statusLabel;
@property NSMutableDictionary *axDiagnostics;
@property NSString *viewFingerprint;
@property NSString *rowFingerprint;
@property BOOL pendingRight;
@property BOOL lastCapturePermission;
@property NSNumber *collectionDark;
@property NSUInteger captureInvocationCount;
@property (nonatomic, strong) NSScrollView *settingsScroll;
@end

@implementation App

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (![defaults objectForKey:@"NSStatusItem Preferred Position MacBarAnchor"])
        [defaults setDouble:300 forKey:@"NSStatusItem Preferred Position MacBarAnchor"];
    if (![defaults objectForKey:@"NSStatusItem Preferred Position MacBarSpacer"])
        [defaults setDouble:360 forKey:@"NSStatusItem Preferred Position MacBarSpacer"];
    self.imageCache = [NSMutableDictionary dictionary];
    self.layoutDirty = YES;

    self.items = [NSMutableArray array];
    self.anchor = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    self.anchor.autosaveName = @"MacBarAnchor";
    self.anchor.button.image = [self anchorImage];
    self.anchor.button.imageScaling = NSImageScaleProportionallyDown;
    self.anchor.button.toolTip = @"MacBar";
    self.anchor.button.target = self;
    self.anchor.button.action = @selector(anchorClicked:);
    [self.anchor.button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];

    self.spacer = [NSStatusBar.systemStatusBar statusItemWithLength:1];
    self.spacer.autosaveName = @"MacBarSpacer";
    self.spacer.button.title = @"";
    self.spacer.button.image = nil;
    self.suppressed = NO;

    [self buildPanel];
    [self installObservers];
    self.lastTrusted = AXIsProcessTrusted();
    self.lastCapturePermission = [self capturePermissionGranted];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshEnvironment];
        NSInteger settingsVersion = [[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] integerValue];
        if ([defaults integerForKey:@"MBSettingsShownVersion"] < settingsVersion) {
            [defaults setInteger:settingsVersion forKey:@"MBSettingsShownVersion"];
            [self showSettings];
        }
    });
}

- (void)applicationWillTerminate:(NSNotification *)note {
    [self cancelPendingRehide];
    [self.environmentTimer invalidate];
    [self revealMenuBar];
    if (self.globalClick) [NSEvent removeMonitor:self.globalClick];
    if (self.localKey) [NSEvent removeMonitor:self.localKey];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)visible {
    if (!self.revealingForClick) [self showSettings];
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (NSImage *)anchorImage {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(16, 16) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [[NSColor blackColor] setFill];
        CGFloat size = 4.5;
        CGFloat gap = 2;
        CGFloat origin = 2.5;
        for (NSInteger row = 0; row < 2; row++) {
            for (NSInteger col = 0; col < 2; col++) {
                NSRect box = NSMakeRect(origin + col * (size + gap), origin + row * (size + gap), size, size);
                [[NSBezierPath bezierPathWithRoundedRect:box xRadius:1.2 yRadius:1.2] fill];
            }
        }
        return YES;
    }];
    image.template = YES;
    return image;
}

- (void)requestAccessibility {
    if (AXIsProcessTrusted()) return;
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

- (void)openAccessibilitySettings {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
    [self requestAccessibility];
}

- (BOOL)nativeAppearanceEnabled {
    NSUserDefaults *defaults = [self layoutDefaults];
    // Earlier versions enabled capture by default. That is not explicit consent
    // to the system's screen-capture indicator; require a fresh opt-in instead.
    return [defaults boolForKey:@"MBNativeCaptureOptInV1"] && [defaults boolForKey:@"MBCaptureIcons"];
}

- (BOOL)collectionIsVisible { return self.panel.isVisible; }

- (BOOL)capturePermissionGranted { return CGPreflightScreenCaptureAccess(); }

- (void)openScreenRecordingSettings {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"]];
    if (![self capturePermissionGranted]) CGRequestScreenCaptureAccess();
}

- (NSString *)settingsStatus {
    if (self.lastError.length) return self.lastError;
    if (!AXIsProcessTrusted()) return @"请启用辅助功能；授权前不会隐藏图标";
    if ([self nativeAppearanceEnabled] && ![self capturePermissionGranted]) return @"要保留顶部的图标和动态文字，请点击「屏幕录制权限」授权 MacBar。";
    if ([self nativeAppearanceEnabled]) {
        NSUInteger missing = 0;
        for (BarItem *item in self.items) if (!item.statusImage) missing++;
        if (missing) return [NSString stringWithFormat:@"%lu 个图标暂用应用图标；打开收集栏后读取原样画面", (unsigned long)missing];
    }
    return [self nativeAppearanceEnabled] ? @"仅在收集栏打开时读取原样画面；macOS 会显示屏幕捕获提示" : @"使用应用图标，不捕获屏幕；菜单栏图标仍会自动检测";
}

- (void)reportError:(NSString *)message {
    self.lastError = message;
    self.anchor.button.toolTip = [@"MacBar — " stringByAppendingString:message];
    [self logEvent:@"error" item:nil detail:message];
    if (self.statusLabel) self.statusLabel.stringValue = message;
    NSBeep();
}

- (void)logEvent:(NSString *)event item:(BarItem *)item detail:(NSString *)detail {
    NSString *folder = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/MacBar"];
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *path = [folder stringByAppendingPathComponent:@"events.jsonl"];
    if ([[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil] fileSize] > 2 * 1024 * 1024) {
        [NSFileManager.defaultManager removeItemAtPath:[path stringByAppendingString:@".previous"] error:nil];
        [NSFileManager.defaultManager moveItemAtPath:path toPath:[path stringByAppendingString:@".previous"] error:nil];
    }
    NSDictionary *entry = @{@"time": @([NSDate date].timeIntervalSince1970), @"process": @(getpid()), @"event": event, @"key": item.key ?: @"", @"window": @(item.windowID), @"detail": detail ?: @""};
    NSMutableData *data = [[NSJSONSerialization dataWithJSONObject:entry options:0 error:nil] mutableCopy];
    [data appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) [NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    @try { [file seekToEndOfFile]; [file writeData:data]; } @finally { [file closeFile]; }
}

- (void)installObservers {
    NSNotificationCenter *center = NSWorkspace.sharedWorkspace.notificationCenter;
    [center addObserver:self selector:@selector(appsChanged:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
    [center addObserver:self selector:@selector(appsChanged:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
    [center addObserver:self selector:@selector(appsChanged:) name:NSWorkspaceDidWakeNotification object:nil];
    [center addObserver:self selector:@selector(appsChanged:) name:NSWorkspaceActiveSpaceDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appsChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(menuBegan:) name:NSMenuDidBeginTrackingNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(menuEnded:) name:NSMenuDidEndTrackingNotification object:nil];
    __weak App *weakSelf = self;
    self.environmentTimer = [NSTimer scheduledTimerWithTimeInterval:3 repeats:YES block:^(NSTimer *timer) {
        [weakSelf refreshEnvironment];
    }];
    self.localKey = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (event.keyCode == 53 && self.panel.isVisible && !self.trackingMenu) {
            [self closePanel];
            return nil;
        }
        return event;
    }];
    self.globalClick = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown handler:^(NSEvent *event) {
        if (!self.panel.isVisible || self.trackingMenu) return;
        if (self.panelOpenedAt && [[NSDate date] timeIntervalSinceDate:self.panelOpenedAt] < 0.25) return;
        NSPoint point = NSEvent.mouseLocation;
        if (!NSPointInRect(point, self.panel.frame)) [self closePanel];
    }];
}

- (void)menuBegan:(NSNotification *)note { self.trackingMenu = YES; }
- (void)menuEnded:(NSNotification *)note { self.trackingMenu = NO; }

- (BOOL)accessibilityGranted { return AXIsProcessTrusted(); }

- (void)freezeMenuScreen {
    if (!self.activeScreen || ![NSScreen.screens containsObject:self.activeScreen]) {
        self.activeScreen = self.anchor.button.window.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    }
}

- (void)reconcilePlacements {
    [self performPlacementPassForKeys:nil];
}

- (void)performPlacementPassForKeys:(NSSet<NSString *> *)keys {
    if (self.revealingForClick || self.pendingRehide || ![self accessibilityGranted]) return;
    // Ordinary discoveries affect only the new items. A user-expanded menu bar
    // must stay expanded until the user explicitly reapplies the layout.
    if (keys && !self.suppressed) return;
    [self freezeMenuScreen];
    [self logEvent:@"layout-pass" item:nil detail:keys ? [NSString stringWithFormat:@"new items: %lu", (unsigned long)keys.count] : @"explicit/startup/display change"];
    self.revealingForClick = YES;
    BOOL success = YES;
    @try {
        // Keep configured top items accessible before expanding the separator.
        for (BarItem *item in self.catalog) {
            if (keys && ![keys containsObject:item.key]) continue;
            if (![item.placement isEqualToString:@"top"]) continue;
            if (![self moveItem:item toHidden:NO]) { item.issue = @"无法移到顶部，已保留展开"; [self logEvent:@"layout-top-failed" item:item detail:nil]; success = NO; }
        }
        if (success && !self.suppressed) {
            [self suppressMenuBar];
            // Expanding the spacer exposes obsolete/off-display copies: a live
            // status item cannot occupy the same rectangle as our spacer.
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.15, false);
            [self reloadItems];
        }
        for (BarItem *item in self.catalog) {
            if (keys && ![keys containsObject:item.key]) continue;
            if (!item.persistentIdentity || [item.placement isEqualToString:@"top"]) continue;
            if (![self moveItem:item toHidden:YES]) { item.issue = @"收起失败"; [self logEvent:@"layout-hide-failed" item:item detail:nil]; success = NO; }
        }
    } @finally { self.revealingForClick = NO; }
    if (!success) {
        if (!keys) [self revealMenuBar];
        [self reportError:keys ? @"新图标暂未收起，已停止自动移动。可重新应用布局。" : @"部分图标未能移动，顶栏已展开；已停止自动移动，可重新应用布局。"];
    }
    if (success) { self.lastError = nil; self.anchor.button.toolTip = @"MacBar"; }
    self.layoutDirty = NO;
}

- (void)refreshEnvironment {
    if (self.refreshing || self.revealingForClick || (self.pendingRehide && !self.restoreSuspended) || self.trackingMenu) return;
    self.refreshing = YES;
    @try {
    if (self.screenNeedsRefresh) { self.activeScreen = nil; self.screenNeedsRefresh = NO; }
    [self freezeMenuScreen];
    BOOL trusted = [self accessibilityGranted];
    BOOL capturePermission = [self capturePermissionGranted];
    if (capturePermission != self.lastCapturePermission) {
        self.lastCapturePermission = capturePermission;
        [self.imageCache removeAllObjects]; self.viewFingerprint = nil;
    }
    if (trusted != self.lastTrusted) { self.lastTrusted = trusted; self.layoutDirty = YES; }
    if (!trusted) {
        [self revealMenuBar];
        self.anchor.button.toolTip = @"MacBar — 请在设置中启用辅助功能；顶栏保持展开";
    }
    NSSet *before = [NSSet setWithArray:[self.catalog valueForKey:@"key"] ?: @[]];
    [self reloadItems];
    NSMutableSet *newHiddenKeys = [NSMutableSet set];
    for (BarItem *item in self.catalog) if (![before containsObject:item.key] && item.persistentIdentity && ![item.placement isEqualToString:@"top"]) [newHiddenKeys addObject:item.key];
    // Capture indicators, disappearing items, title changes and app activation
    // are read-only refreshes; none should initiate a full drag pass.
    if (trusted && !self.pendingRehide) {
        if (self.layoutDirty) { [self reconcilePlacements]; [self reloadItems]; }
        else if (newHiddenKeys.count && self.suppressed) { [self performPlacementPassForKeys:newHiddenKeys]; [self reloadItems]; }
    }
    } @finally { self.refreshing = NO; }
}

- (void)appsChanged:(NSNotification *)note {
    if ([note.name isEqualToString:NSApplicationDidChangeScreenParametersNotification] || [note.name isEqualToString:NSWorkspaceDidWakeNotification]) {
        self.layoutDirty = YES;
        self.screenNeedsRefresh = YES;
    }
    if (self.refreshScheduled) return;
    self.refreshScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.refreshScheduled = NO;
        [self refreshEnvironment];
    });
}

- (void)buildPanel {
    self.panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 200, 42)
                                             styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
    self.panel.level = NSPopUpMenuWindowLevel;
    self.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorIgnoresCycle;
    self.panel.opaque = NO;
    self.panel.backgroundColor = NSColor.clearColor;
    self.panel.hasShadow = YES;
    self.panel.hidesOnDeactivate = NO;
    self.panel.movable = NO;

    self.effect = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    self.effect.material = NSVisualEffectMaterialMenu;
    self.effect.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.effect.state = NSVisualEffectStateActive;
    self.effect.wantsLayer = YES;
    self.effect.layer.cornerRadius = 18;
    self.effect.layer.masksToBounds = YES;
    self.effect.layer.borderWidth = 1;
    self.effect.layer.borderColor = [NSColor colorWithWhite:1 alpha:0.35].CGColor;
    self.panel.contentView = self.effect;

    self.row = [[NSView alloc] initWithFrame:NSZeroRect];
    [self.effect addSubview:self.row];
}

- (NSScreen *)menuScreen {
    if (self.activeScreen && [NSScreen.screens containsObject:self.activeScreen]) return self.activeScreen;
    return self.anchor.button.window.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
}

- (NSString *)shortNameFromDescription:(NSString *)desc bundle:(NSString *)bundle fallback:(NSString *)fallback {
    if ([bundle isEqualToString:@"com.apple.Spotlight"]) return @"聚焦";
    if ([bundle isEqualToString:@"com.apple.TextInputMenuAgent"]) return @"输入法";
    if ([desc containsString:@"Wi-Fi"] || [desc containsString:@"Wi‑Fi"]) return @"Wi-Fi";
    if (desc.length) {
        NSRange comma = [desc rangeOfString:@"，"];
        if (comma.location != NSNotFound && comma.location > 0) return [desc substringToIndex:comma.location];
        return desc;
    }
    return fallback.length ? fallback : @"未命名";
}

static id MBAXValue(AXUIElementRef element, CFStringRef attribute) {
    CFTypeRef value = NULL;
    if (AXUIElementCopyAttributeValue(element, attribute, &value) != kAXErrorSuccess || !value) return nil;
    return CFBridgingRelease(value);
}

- (NSArray<NSDictionary *> *)accessibilityItemsForPID:(pid_t)pid {
    if (!AXIsProcessTrusted()) return @[];
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    AXUIElementSetMessagingTimeout(app, 0.15);
    id extras = MBAXValue(app, CFSTR("AXExtrasMenuBar"));
    if (!extras) extras = MBAXValue(app, kAXMenuBarAttribute);
    CFArrayRef names = NULL;
    AXError diagnosticError = kAXErrorSuccess;
    if (!self.axDiagnostics) self.axDiagnostics = [NSMutableDictionary dictionary];
    self.axDiagnostics[@(pid).stringValue] = @{@"error": @(diagnosticError), @"attributes": names ? (__bridge NSArray *)names : @[], @"extras": extras ? CFBridgingRelease(CFCopyTypeIDDescription(CFGetTypeID((__bridge CFTypeRef)extras))) : @"nil"};
    if (names) CFRelease(names);
    NSMutableArray *result = [NSMutableArray array];
    if (extras && CFGetTypeID((__bridge CFTypeRef)extras) == AXUIElementGetTypeID()) {
        id children = MBAXValue((__bridge AXUIElementRef)extras, kAXChildrenAttribute);
        NSMutableDictionary *diagnostic = [self.axDiagnostics[@(pid).stringValue] mutableCopy];
        diagnostic[@"children"] = @([children isKindOfClass:NSArray.class] ? [children count] : 0);
        self.axDiagnostics[@(pid).stringValue] = diagnostic;
        if ([children isKindOfClass:NSArray.class]) for (id child in children) {
            AXUIElementRef element = (__bridge AXUIElementRef)child;
            id pos = MBAXValue(element, kAXPositionAttribute);
            id size = MBAXValue(element, kAXSizeAttribute);
            CGPoint point = CGPointZero; CGSize dimensions = CGSizeZero;
            if (!pos || !size || CFGetTypeID((__bridge CFTypeRef)pos) != AXValueGetTypeID() || CFGetTypeID((__bridge CFTypeRef)size) != AXValueGetTypeID()) continue;
            if (!AXValueGetValue((__bridge AXValueRef)pos, kAXValueCGPointType, &point) || !AXValueGetValue((__bridge AXValueRef)size, kAXValueCGSizeType, &dimensions)) continue;
            id identifier = MBAXValue(element, CFSTR("AXIdentifier"));
            id description = MBAXValue(element, kAXDescriptionAttribute);
            [result addObject:@{@"bounds": [NSValue valueWithRect:(CGRect){point, dimensions}],
                @"identifier": [identifier isKindOfClass:NSString.class] ? identifier : @"",
                @"name": [description isKindOfClass:NSString.class] ? description : @""}];
        }
    }
    CFRelease(app);
    NSMutableDictionary *diagnostic = [self.axDiagnostics[@(pid).stringValue] mutableCopy];
    diagnostic[@"matchedRecords"] = @(result.count);
    NSMutableArray *records = [NSMutableArray array];
    for (NSDictionary *r in result) [records addObject:@{@"bounds": NSStringFromRect([r[@"bounds"] rectValue]), @"id": r[@"identifier"], @"name": r[@"name"]}];
    diagnostic[@"records"] = records;
    self.axDiagnostics[@(pid).stringValue] = diagnostic;
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"MBDiagnostics"]) [[NSJSONSerialization dataWithJSONObject:self.axDiagnostics options:NSJSONWritingPrettyPrinted error:nil] writeToFile:@"/tmp/macbar-ax.json" atomically:YES];
    return result;
}

- (CGFloat)menuHeight {
    // NSStatusItem's window can be a replica on a different display. Use the
    // anchor replica actually inside the frozen display instead.
    CGRect anchor = [self boundsForWindowID:[self macBarWindowWide:NO]];
    CGFloat height = CGRectIsNull(anchor) ? 0 : anchor.size.height;
    return height > 0 ? height : MAX(NSStatusBar.systemStatusBar.thickness, [self menuScreen].safeAreaInsets.top);
}

- (CGRect)displayRect { return MBDisplayRect([self menuScreen]); }

- (NSRunningApplication *)applicationForPID:(pid_t)pid { return [NSRunningApplication runningApplicationWithProcessIdentifier:pid]; }

- (NSArray<NSDictionary *> *)windowList:(BOOL)onScreen {
    CFArrayRef list = CGWindowListCopyWindowInfo(onScreen ? kCGWindowListOptionOnScreenOnly : kCGWindowListOptionAll, kCGNullWindowID);
    return list ? CFBridgingRelease(list) : @[];
}

- (NSSet<NSNumber *> *)menuWindowIDs {
    typedef int (*ConnectionFn)(void);
    typedef CGError (*ListFn)(int, int, int, CGWindowID *, int *);
    ConnectionFn connection = (ConnectionFn)dlsym(RTLD_DEFAULT, "CGSMainConnectionID");
    ListFn list = (ListFn)dlsym(RTLD_DEFAULT, "CGSGetProcessMenuBarWindowList");
    if (!connection || !list) return nil;
    CGWindowID ids[4096]; int count = 0;
    if (list(connection(), 0, 4096, ids, &count) != kCGErrorSuccess) return nil;
    NSMutableSet *result = [NSMutableSet set];
    for (int i = 0; i < MIN(count, 4096); i++) [result addObject:@(ids[i])];
    return result;
}

- (NSUserDefaults *)layoutDefaults { return NSUserDefaults.standardUserDefaults; }

- (void)rememberLayoutForItems:(NSArray<BarItem *> *)found {
    NSUserDefaults *defaults = [self layoutDefaults];
    NSArray *legacyTop = [defaults stringArrayForKey:@"MacBarTopOrder"] ?: @[];
    NSMutableArray *top = [[defaults stringArrayForKey:@"MBTopOrderV2"] mutableCopy] ?: [NSMutableArray array];
    NSMutableArray *bar = [[defaults stringArrayForKey:@"MBBarOrderV2"] mutableCopy] ?: [NSMutableArray array];
    NSMutableArray *hidden = [[defaults stringArrayForKey:@"MBHiddenOrderV2"] mutableCopy] ?: [NSMutableArray array];
    for (BarItem *item in found) {
        if (!item.persistentIdentity || !item.bundleID.length || !item.key.length) continue;
        if ([top containsObject:item.key] || [bar containsObject:item.key] || [hidden containsObject:item.key]) continue;
        BOOL wasTop = item.systemItem || MBLegacyContainsBundle(legacyTop, item.bundleID);
        [(wasTop ? top : bar) addObject:item.key];
    }
    [defaults setObject:[NSOrderedSet orderedSetWithArray:top].array forKey:@"MBTopOrderV2"];
    [bar removeObjectsInArray:top];
    [hidden removeObjectsInArray:top];
    [bar removeObjectsInArray:hidden];
    [defaults setObject:[NSOrderedSet orderedSetWithArray:bar].array forKey:@"MBBarOrderV2"];
    [defaults setObject:[NSOrderedSet orderedSetWithArray:hidden].array forKey:@"MBHiddenOrderV2"];
}

- (NSArray<BarItem *> *)itemsInPlacement:(NSString *)placement from:(NSArray<BarItem *> *)found {
    NSUserDefaults *defaults = [self layoutDefaults];
    NSArray *top = [defaults stringArrayForKey:@"MBTopOrderV2"] ?: @[];
    NSArray *hidden = [defaults stringArrayForKey:@"MBHiddenOrderV2"] ?: @[];
    NSString *store = [placement isEqualToString:@"top"] ? @"MBTopOrderV2" : ([placement isEqualToString:@"hidden"] ? @"MBHiddenOrderV2" : @"MBBarOrderV2");
    NSArray *order = [defaults stringArrayForKey:store] ?: @[];
    NSMutableDictionary *byKey = [NSMutableDictionary dictionary];
    for (BarItem *item in found) {
        item.placement = !item.persistentIdentity || [top containsObject:item.key] ? @"top" : ([hidden containsObject:item.key] ? @"hidden" : @"bar");
        byKey[item.key] = item;
    }
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *key in order) { BarItem *item = byKey[key]; if (item && [item.placement isEqualToString:placement]) [result addObject:item]; }
    for (BarItem *item in found) if ([item.placement isEqualToString:placement] && ![result containsObject:item]) [result addObject:item];
    if ([placement isEqualToString:@"top"]) [result sortUsingComparator:^NSComparisonResult(BarItem *a, BarItem *b) { return a.sortX == b.sortX ? NSOrderedSame : (a.sortX < b.sortX ? NSOrderedAscending : NSOrderedDescending); }];
    return result;
}

- (NSArray<BarItem *> *)scanItems {
    CGRect display = [self displayRect];
    CGRect separator = self.suppressed ? [self boundsForWindowID:[self macBarWindowWide:YES]] : CGRectNull;
    CGFloat menuHeight = [self menuHeight];
    NSSet *menuIDs = [self menuWindowIDs];
    NSMutableDictionary<NSNumber *, NSMutableArray *> *groups = [NSMutableDictionary dictionary];
    for (NSDictionary *dict in [self windowList:NO]) {
        if ([dict[(id)kCGWindowLayer] intValue] != 25) continue;
        if (menuIDs && ![menuIDs containsObject:dict[(id)kCGWindowNumber]]) continue;
        CGRect bounds = [self windowBounds:dict];
        if (!MBRectIsMenuItem(bounds, display)) continue;
        if (!CGRectIsNull(separator) && CGRectIntersectsRect(CGRectInset(separator, 2, 0), bounds)) continue;
        if (menuHeight > 0 && fabs(bounds.size.height - menuHeight) > 4) continue;
        pid_t pid = [dict[(id)kCGWindowOwnerPID] intValue];
        if (pid == getpid()) continue;
        NSRunningApplication *app = [self applicationForPID:pid];
        if (!app.bundleIdentifier.length || [app.bundleIdentifier isEqualToString:@"cc.icc.macbar"] || [app.bundleIdentifier isEqualToString:@"com.macbar.app"]) continue;
        NSNumber *key = @(pid);
        if (!groups[key]) groups[key] = [NSMutableArray array];
        [groups[key] addObject:dict];
    }
    NSMutableArray *result = [NSMutableArray array];
    for (NSNumber *pidNumber in groups) {
        pid_t pid = pidNumber.intValue;
        NSRunningApplication *app = [self applicationForPID:pid];
        // A process may exit between window enumeration and this second lookup.
        NSString *bundle = [app.bundleIdentifier copy];
        if (!bundle.length) continue;
        NSString *appName = [app.localizedName copy] ?: bundle;
        NSArray *axItems = [self accessibilityItemsForPID:pid];
        NSMutableArray *candidates = [NSMutableArray array];
        for (NSDictionary *dict in groups[pidNumber]) {
            CGRect bounds = [self windowBounds:dict];
            NSDictionary *matched = nil;
            for (NSDictionary *ax in axItems) {
                CGRect axBounds = [ax[@"bounds"] rectValue];
                if (MBAXFrameMatchesWindow(axBounds, bounds)) { matched = ax; break; }
            }
            BarItem *item = [BarItem new];
            item.pid = pid; item.windowID = [dict[(id)kCGWindowNumber] unsignedIntValue];
            item.bundleID = bundle; item.systemItem = [bundle hasPrefix:@"com.apple."];
            item.name = item.systemItem ? [self shortNameFromDescription:matched[@"name"] ?: @"" bundle:bundle fallback:appName] : appName;
            item.width = bounds.size.width; item.sortX = bounds.origin.x; item.icon = app.icon;
            item.identityToken = [matched[@"identifier"] length] ? [@"ax:" stringByAppendingString:matched[@"identifier"]] : nil;
            // Retain identity for this exact living window even if AX temporarily fails.
            if (!item.identityToken) for (BarItem *old in self.catalog) if (old.pid == pid && old.windowID == item.windowID && old.persistentIdentity) item.identityToken = old.identityToken;
            if (!item.identityToken && item.systemItem && [matched[@"name"] length]) item.identityToken = [@"system:" stringByAppendingString:item.name];
            item.issue = matched ? nil : @"此图标未提供辅助功能名称";
            [candidates addObject:item];
        }
        // No width/name-based deduplication: multiple unidentifiable items stay independent.
        for (BarItem *item in candidates) {
            if (!item.identityToken && candidates.count == 1) item.identityToken = @"primary";
            NSString *primaryKey = MBItemKey(item.bundleID, @"primary");
            if (candidates.count == 1 && ([[self.layoutDefaults stringArrayForKey:@"MBTopOrderV2"] containsObject:primaryKey] || [[self.layoutDefaults stringArrayForKey:@"MBBarOrderV2"] containsObject:primaryKey] || [[self.layoutDefaults stringArrayForKey:@"MBHiddenOrderV2"] containsObject:primaryKey])) item.identityToken = @"primary";
            item.persistentIdentity = item.identityToken.length > 0;
            item.key = MBItemKey(item.bundleID, item.identityToken ?: [NSString stringWithFormat:@"session:%d:%u", pid, item.windowID]);
            if (!item.persistentIdentity) item.issue = @"无法稳定识别，保持在顶部";
            item.statusImage = [self nativeAppearanceEnabled] ? self.imageCache[item.key] : nil;
            [result addObject:item];
        }
    }
    return [result sortedArrayUsingComparator:^NSComparisonResult(BarItem *a, BarItem *b) {
        if (a.sortX == b.sortX) return [a.key compare:b.key];
        return a.sortX < b.sortX ? NSOrderedAscending : NSOrderedDescending;
    }];
}

- (void)reloadItems {
    NSArray<BarItem *> *found = [self scanItems];
    [self rememberLayoutForItems:found];
    self.catalog = [[self itemsInPlacement:@"top" from:found] mutableCopy];
    [self.catalog addObjectsFromArray:[self itemsInPlacement:@"bar" from:found]];
    [self.catalog addObjectsFromArray:[self itemsInPlacement:@"hidden" from:found]];
    self.items = [[self itemsInPlacement:@"bar" from:found] mutableCopy];
    [self captureAvailableImages];
    [self updateCollectionAppearance];
    NSMutableArray *signature = [NSMutableArray array];
    for (BarItem *item in self.catalog) [signature addObject:@[item.key, item.name ?: @"", item.placement, @(item.windowID)]];
    [signature addObject:@[@(AXIsProcessTrusted()), @(self.pendingRehide != nil), @(self.revealingForClick), self.lastError ?: @"", @([self nativeAppearanceEnabled]), @([self capturePermissionGranted])]];
    NSString *fingerprint = [signature description];
    NSMutableArray *rowSignature = [NSMutableArray arrayWithObjects:NSStringFromRect([self menuScreen].visibleFrame), self.collectionDark ?: @NO, nil];
    for (BarItem *item in self.items) [rowSignature addObject:@[item.key, item.name ?: @"", @([self slotWidthForItem:item]), @([self clickOpensApplicationForItem:item right:NO])]];
    NSString *rowFingerprint = rowSignature.description;
    if (![rowFingerprint isEqualToString:self.rowFingerprint]) {
        self.rowFingerprint = rowFingerprint;
        [self layoutRow];
    } else if (self.panel.isVisible) {
        for (NSView *cell in self.row.subviews) [cell setNeedsDisplay:YES];
    }
    if (![fingerprint isEqualToString:self.viewFingerprint]) {
        self.viewFingerprint = fingerprint;
        if (self.settingsWindow.isVisible && !self.trackingMenu) [self refillSettings];
    }
    if (self.settingsWindow.isVisible) self.statusLabel.stringValue = [self settingsStatus];
    NSUInteger nativeCount = 0;
    for (BarItem *item in self.items) if (item.statusImage) nativeCount++;
    NSMutableString *line = [NSMutableString stringWithFormat:@"trusted=%d\nnativeMode=%d screenCapture=%d nativeImages=%lu/%lu appearance=%@ captureRequests=%lu\nbar=%@\n", AXIsProcessTrusted(), [self nativeAppearanceEnabled], [self capturePermissionGranted], (unsigned long)nativeCount, (unsigned long)self.items.count, self.collectionDark.boolValue ? @"dark" : @"light", (unsigned long)self.captureInvocationCount, [[self.items valueForKey:@"name"] componentsJoinedByString:@", "]];
    for (BarItem *item in self.catalog) {
        [line appendFormat:@"%@ | %@ | %@ | native=%@ size=%@ window=%u left=%@\n", item.placement, item.name, item.key, item.statusImage ? @"yes" : @"no", NSStringFromSize(item.statusImage.size), item.windowID, [self clickOpensApplicationForItem:item right:NO] ? @"application" : @"native"];
    }
    [line writeToFile:@"/tmp/macbar-row.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (BarItem *)itemForKey:(NSString *)key {
    for (BarItem *item in self.catalog) if ([item.key isEqualToString:key]) return item;
    return nil;
}

- (NSImage *)nativeImageForItem:(BarItem *)item bounds:(CGRect)bounds {
    if (![self nativeAppearanceEnabled] || ![self collectionIsVisible] || ![self capturePermissionGranted]) return nil;
    // Explicit ID arrays also include offscreen status windows. The list-option
    // form can return no drawable content after an item is moved off the display.
    const void *window = (const void *)(uintptr_t)item.windowID;
    CFArrayRef windows = CFArrayCreate(kCFAllocatorDefault, &window, 1, NULL);
    if (!windows) return nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.captureInvocationCount++;
    CGImageRef image = CGWindowListCreateImageFromArray(CGRectNull, windows, kCGWindowImageBoundsIgnoreFraming | kCGWindowImageBestResolution);
#pragma clang diagnostic pop
    CFRelease(windows);
    if (!image) return nil;
    NSImage *native = MBStatusImage(image, bounds.size);
    CGImageRelease(image);
    return native;
}

- (void)captureAvailableImages {
    if (![self nativeAppearanceEnabled] || ![self collectionIsVisible] || ![self capturePermissionGranted]) return;
    NSMutableArray *missing = [NSMutableArray array];
    for (BarItem *item in self.catalog) {
        if ([item.placement isEqualToString:@"hidden"]) continue;
        CGRect bounds = [self boundsForWindowID:item.windowID];
        if (CGRectIsNull(bounds)) continue;
        NSImage *native = [self nativeImageForItem:item bounds:bounds];
        if (native) { item.statusImage = native; self.imageCache[item.key] = native; }
        else [missing addObject:@{@"key": item.key, @"pid": @(item.pid), @"window": @(item.windowID), @"bounds": [NSValue valueWithRect:bounds]}];
    }
    if (missing.count) [self requestNativeFallback:missing];
}

- (BOOL)acceptNativeImage:(NSImage *)image forKey:(NSString *)key pid:(pid_t)pid window:(CGWindowID)window {
    if (!image || ![self nativeAppearanceEnabled] || ![self capturePermissionGranted]) return NO;
    BarItem *current = [self itemForKey:key];
    // Captured content must never update a restarted process or a sibling status item.
    if (!current || current.pid != pid || current.windowID != window || [current.placement isEqualToString:@"hidden"]) return NO;
    current.statusImage = image; self.imageCache[key] = image;
    return YES;
}

- (void)requestNativeFallback:(NSArray<NSDictionary *> *)requests {
    if (!requests.count || ![self nativeAppearanceEnabled] || ![self collectionIsVisible] || ![self capturePermissionGranted]) return;
    // Composite window capture uses the same approved window snapshots as the
    // primary path. Do not start/stop a ScreenCaptureKit session every refresh.
    const void **identifiers = calloc(requests.count, sizeof(void *));
    if (!identifiers) return;
    CGRect frame = CGRectNull;
    for (NSUInteger index = 0; index < requests.count; index++) {
        identifiers[index] = (const void *)(uintptr_t)[requests[index][@"window"] unsignedIntValue];
        frame = CGRectUnion(frame, [requests[index][@"bounds"] rectValue]);
    }
    CFArrayRef windows = CFArrayCreate(kCFAllocatorDefault, identifiers, requests.count, NULL);
    free(identifiers);
    if (!windows) return;
    CGImageRef image = NULL;
    if (!CGRectIsEmpty(frame) && frame.size.width <= 16384) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        self.captureInvocationCount++;
        image = CGWindowListCreateImageFromArray(CGRectNull, windows, kCGWindowImageBoundsIgnoreFraming | kCGWindowImageBestResolution);
#pragma clang diagnostic pop
    }
    CFRelease(windows);
    if (!image) return;
    CGFloat scaleX = CGImageGetWidth(image) / frame.size.width;
    CGFloat scaleY = CGImageGetHeight(image) / frame.size.height;
    if (fabs(scaleX - scaleY) <= 0.05) for (NSDictionary *request in requests) {
        CGRect bounds = [request[@"bounds"] rectValue];
        CGRect crop = CGRectMake((bounds.origin.x - frame.origin.x) * scaleX, (bounds.origin.y - frame.origin.y) * scaleY, bounds.size.width * scaleX, bounds.size.height * scaleY);
        CGImageRef content = CGImageCreateWithImageInRect(image, crop);
        if (!content) continue;
        [self acceptNativeImage:MBStatusImage(content, bounds.size) forKey:request[@"key"] pid:[request[@"pid"] intValue] window:[request[@"window"] unsignedIntValue]];
        CGImageRelease(content);
    }
    CGImageRelease(image);
}

- (void)toggleCapture:(NSButton *)button {
    BOOL enabled = button.state == NSControlStateValueOn;
    [[self layoutDefaults] setBool:enabled forKey:@"MBCaptureIcons"];
    [[self layoutDefaults] setBool:enabled forKey:@"MBNativeCaptureOptInV1"];
    if (enabled && ![self capturePermissionGranted]) [self openScreenRecordingSettings];
    if (!enabled) [self.imageCache removeAllObjects];
    [self reloadItems];
}

- (NSButton *)gearButton {
    NSButton *gear = [NSButton buttonWithTitle:@"" target:self action:@selector(showSettings)];
    gear.bordered = NO;
    gear.imagePosition = NSImageOnly;
    gear.imageScaling = NSImageScaleProportionallyDown;
    NSImage *gearImage = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"设置"];
    gearImage.size = NSMakeSize(16, 16);
    gear.image = gearImage;
    gear.contentTintColor = NSColor.secondaryLabelColor;
    gear.toolTip = @"设置";
    return gear;
}

- (CGFloat)slotWidthForItem:(BarItem *)item {
    if (item.statusImage) return MAX(22, item.statusImage.size.width + 6);
    return kButton;
}

- (void)updateCollectionAppearance {
    NSMutableArray<NSNumber *> *tones = [NSMutableArray array];
    for (BarItem *item in self.items) {
        if (!item.statusImage) continue;
        NSNumber *tone = MBNativeForegroundLuminance(item.statusImage);
        if (tone) [tones addObject:tone];
    }
    NSString *systemStyle = [NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
    BOOL dark = MBPreferDarkBackground(tones, [systemStyle isEqualToString:NSAppearanceNameDarkAqua]);
    if (self.collectionDark && dark == self.collectionDark.boolValue) return;
    self.collectionDark = @(dark);
    // Captured pixels retain the source menu's foreground color. Match their
    // contrast with the capsule, without tinting or inverting the captured image.
    NSAppearance *appearance = [NSAppearance appearanceNamed:dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
    self.panel.appearance = appearance;
    self.effect.appearance = appearance;
    self.effect.layer.backgroundColor = nil;
    self.effect.layer.borderColor = [NSColor colorWithWhite:dark ? 1 : 0 alpha:dark ? 0.2 : 0.12].CGColor;
    [self.effect setNeedsDisplay:YES];
}

- (void)layoutRow {
    for (NSView *view in self.row.subviews.copy) [view removeFromSuperview];
    NSScreen *screen = [self menuScreen];
    CGFloat maxWidth = screen.visibleFrame.size.width - 24;
    CGFloat limit = maxWidth - kPadX;
    NSMutableArray<NSNumber *> *widths = [NSMutableArray array];
    for (BarItem *item in self.items) {
        CGFloat slot = [self slotWidthForItem:item];
        [widths addObject:@(slot)];
    }
    CGFloat rowWidth = 0;
    CGFloat widest = kButton;
    NSInteger rows = 1;
    for (NSInteger idx = 0; idx <= (NSInteger)self.items.count; idx++) {
        CGFloat slot = idx == (NSInteger)self.items.count ? kButton : widths[idx].doubleValue;
        CGFloat next = (rowWidth == 0 ? kPadX : rowWidth) + slot;
        if (rowWidth > kPadX && next > limit) {
            widest = MAX(widest, rowWidth - kGap + kPadX);
            rows += 1;
            rowWidth = kPadX + slot + kGap;
        } else {
            rowWidth = next + kGap;
        }
    }
    widest = MAX(widest, rowWidth - kGap + kPadX);
    if (self.items.count == 0) widest = MAX(widest, 196);
    CGFloat width = MIN(maxWidth, widest);
    CGFloat height = kPadY * 2 + rows * kButton + MAX(0, rows - 1) * kGap;
    self.effect.layer.cornerRadius = rows == 1 ? height / 2.0 : 18;

    if (self.items.count == 0) {
        NSTextField *label = [NSTextField labelWithString:@"没有收进 MacBar 的图标"];
        label.font = [NSFont systemFontOfSize:12];
        label.textColor = NSColor.secondaryLabelColor;
        label.frame = NSMakeRect(kPadX, (height - 16) / 2.0, width - kPadX * 2 - kButton, 16);
        [self.row addSubview:label];
    }

    CGFloat x = kPadX;
    NSInteger row = 0;
    for (NSInteger idx = 0; idx < (NSInteger)self.items.count; idx++) {
        CGFloat slot = widths[idx].doubleValue;
        if (x > kPadX && x + slot > width - kPadX) {
            row += 1;
            x = kPadX;
        }
        IconCell *cell = [[IconCell alloc] initWithFrame:NSMakeRect(x, height - kPadY - kButton - row * (kButton + kGap), slot, kButton)];
        cell.owner = self;
        cell.itemKey = self.items[idx].key;
        cell.toolTip = [self.items[idx].name stringByAppendingString:[self clickOpensApplicationForItem:self.items[idx] right:NO] ? @"\n左键：打开应用\n右键：原生菜单" : @"\n左键：原生操作\n右键：原生菜单"];
        [self.row addSubview:cell];
        x += slot + kGap;
    }
    if (x > kPadX && x + kButton > width - kPadX + 1) {
        row += 1;
        x = kPadX;
    }
    NSButton *gear = [self gearButton];
    gear.frame = NSMakeRect(x, height - kPadY - kButton - row * (kButton + kGap), kButton, kButton);
    [self.row addSubview:gear];

    self.row.frame = NSMakeRect(0, 0, width, height);
    self.effect.frame = self.row.frame;
    [self.panel setContentSize:NSMakeSize(width, height)];
    [self placePanel];
}

- (void)placePanel {
    NSScreen *screen = [self menuScreen];
    NSRect frame = self.panel.frame;
    CGFloat x = NSMaxX(screen.visibleFrame) - frame.size.width - 12;
    CGFloat y = NSMaxY(screen.visibleFrame) - frame.size.height - 5;
    NSWindow *statusWindow = self.anchor.button.window;
    if (statusWindow && statusWindow.screen == screen) {
        x = NSMidX(statusWindow.frame) - frame.size.width + 20;
    }
    CGFloat minX = NSMinX(screen.visibleFrame) + 8;
    CGFloat maxX = NSMaxX(screen.visibleFrame) - frame.size.width - 8;
    if (x < minX) x = minX;
    if (x > maxX) x = maxX;
    [self.panel setFrame:NSMakeRect(x, y, frame.size.width, frame.size.height) display:YES];
}

- (void)anchorClicked:(id)sender {
    NSEvent *event = NSApp.currentEvent;
    if (!self.pendingRehide) {
        NSPoint pointer = NSEvent.mouseLocation;
        for (NSScreen *screen in NSScreen.screens) if (NSPointInRect(pointer, screen.frame)) self.activeScreen = screen;
    }
    if (event.type == NSEventTypeRightMouseUp) {
        [self showQuitMenu];
        return;
    }
    if (self.panel.isVisible) [self closePanel];
    else [self showPanel];
}

- (void)showQuitMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *settings = [menu addItemWithTitle:@"打开设置" action:@selector(showSettings) keyEquivalent:@""];
    settings.target = self;
    NSMenuItem *retry = [menu addItemWithTitle:@"重新应用布局" action:@selector(retryLayout:) keyEquivalent:@""];
    retry.target = self;
    NSMenuItem *reveal = [menu addItemWithTitle:@"展开所有顶部图标" action:@selector(revealAll:) keyEquivalent:@""];
    reveal.target = self;
    NSMenuItem *quit = [menu addItemWithTitle:@"退出并恢复顶部图标" action:@selector(quit:) keyEquivalent:@""];
    quit.target = self;
    self.trackingMenu = YES;
    [menu popUpMenuPositioningItem:nil atLocation:NSEvent.mouseLocation inView:nil];
    self.trackingMenu = NO;
}

- (NSButton *)smallButton:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleRounded;
    button.font = [NSFont systemFontOfSize:12];
    return button;
}

- (CGFloat)placeSection:(NSString *)title items:(NSArray<BarItem *> *)items y:(CGFloat)cursor document:(NSView *)document {
    cursor -= 28;
    NSTextField *header = [NSTextField labelWithString:title];
    header.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    header.frame = NSMakeRect(16, cursor + 4, 240, 20);
    [document addSubview:header];
    for (NSUInteger idx = 0; idx < items.count; idx++) {
        cursor -= 46;
        [self addSettingsRow:items[idx] atY:cursor index:idx count:items.count inDocument:document];
    }
    return cursor;
}

- (void)refillSettings {
    if (!self.settingsScroll) return;
    self.statusLabel.stringValue = [self settingsStatus];
    NSView *document = self.settingsScroll.documentView;
    for (NSView *view in document.subviews.copy) [view removeFromSuperview];
    NSArray<BarItem *> *top = [self itemsInPlacement:@"top" from:self.catalog];
    NSArray<BarItem *> *bar = [self itemsInPlacement:@"bar" from:self.catalog];
    NSArray<BarItem *> *hidden = [self itemsInPlacement:@"hidden" from:self.catalog];
    CGFloat height = 24 + 28 + top.count * 46 + 28 + bar.count * 46 + (hidden.count ? 28 + hidden.count * 46 : 0);
    CGFloat width = MAX(560, NSWidth(self.settingsScroll.contentView.bounds));
    CGFloat visible = NSHeight(self.settingsScroll.contentView.bounds);
    document.frame = NSMakeRect(0, 0, width, MAX(height, visible));
    CGFloat cursor = NSHeight(document.frame) - 8;
    cursor = [self placeSection:@"顶部菜单栏" items:top y:cursor document:document];
    cursor = [self placeSection:@"MacBar" items:bar y:cursor document:document];
    if (hidden.count) [self placeSection:@"不显示（可随时改回）" items:hidden y:cursor document:document];
}

- (void)addSettingsRow:(BarItem *)item atY:(CGFloat)y index:(NSUInteger)idx count:(NSUInteger)count inDocument:(NSView *)document {
    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSMakeRect(16, y + 10, 26, 26)];
    NSImage *image = item.icon ?: [NSImage imageNamed:NSImageNameApplicationIcon];
    image = [image copy];
    image.size = NSMakeSize(22, 22);
    icon.image = image;
    [document addSubview:icon];

    NSTextField *name = [NSTextField labelWithString:item.name];
    name.font = [NSFont systemFontOfSize:13];
    name.frame = NSMakeRect(50, y + 13, 180, 20);
    name.lineBreakMode = NSLineBreakByTruncatingTail;
    [document addSubview:name];

    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(220, y + 8, 140, 28) pullsDown:NO];
    [popup addItemsWithTitles:@[@"顶部菜单栏", @"收进 MacBar", @"不显示"]];
    [popup selectItemAtIndex:[item.placement isEqualToString:@"top"] ? 0 : ([item.placement isEqualToString:@"hidden"] ? 2 : 1)];
    popup.target = self;
    popup.action = @selector(placementChanged:);
    popup.identifier = item.key;
    popup.enabled = item.persistentIdentity && AXIsProcessTrusted() && !self.pendingRehide && !self.revealingForClick;
    popup.toolTip = item.issue;
    [document addSubview:popup];

    NSButton *up = [self smallButton:@"上移" action:@selector(moveSetting:)];
    up.frame = NSMakeRect(368, y + 9, 72, 28);
    up.identifier = [@"up|" stringByAppendingString:item.key];
    up.enabled = idx > 0 && item.persistentIdentity && AXIsProcessTrusted() && !self.pendingRehide && !self.revealingForClick && ![item.placement isEqualToString:@"hidden"];
    [document addSubview:up];

    NSButton *down = [self smallButton:@"下移" action:@selector(moveSetting:)];
    down.frame = NSMakeRect(446, y + 9, 72, 28);
    down.identifier = [@"down|" stringByAppendingString:item.key];
    down.enabled = idx + 1 < count && item.persistentIdentity && AXIsProcessTrusted() && !self.pendingRehide && !self.revealingForClick && ![item.placement isEqualToString:@"hidden"];
    [document addSubview:down];
}

- (void)placementChanged:(NSPopUpButton *)popup {
    BarItem *item = [self itemForKey:popup.identifier];
    if (popup.indexOfSelectedItem < 0 || popup.indexOfSelectedItem > 2) return;
    NSString *placement = @[@"top", @"bar", @"hidden"][popup.indexOfSelectedItem];
    [self applyPlacement:placement toItem:item];
    [self reloadItems];
}

- (BOOL)applyPlacement:(NSString *)placement toItem:(BarItem *)item {
    if (!item || !item.persistentIdentity || self.pendingRehide || self.revealingForClick || ![@[@"top", @"bar", @"hidden"] containsObject:placement]) return NO;
    BOOL toTop = [placement isEqualToString:@"top"];
    if (!toTop && !self.suppressed) {
        NSString *key = item.key;
        [self reconcilePlacements];
        [self reloadItems];
        item = [self itemForKey:key];
        if (!self.suppressed || !item) { [self reportError:@"请先重新应用布局，再设置收起或不显示。"] ; return NO; }
    }
    self.revealingForClick = YES;
    BOOL moved = NO;
    @try { moved = [self moveItem:item toHidden:!toTop]; }
    @finally { self.revealingForClick = NO; }
    if (moved) {
        [self moveKey:item.key toPlacement:placement];
        self.lastError = nil;
        self.anchor.button.toolTip = @"MacBar";
    } else {
        NSString *reason = item.systemItem ? @"该系统图标未能移动，已保留原设置。" : @"移动未完成，已保留原设置。请重新应用布局后再试。";
        [self reportError:reason];
    }
    return moved;
}

- (void)moveKey:(NSString *)key toPlacement:(NSString *)placement {
    if (!key.length || ![@[@"top", @"bar", @"hidden"] containsObject:placement]) return;
    NSUserDefaults *defaults = [self layoutDefaults];
    NSMutableArray *top = [[defaults stringArrayForKey:@"MBTopOrderV2"] mutableCopy] ?: [NSMutableArray array];
    NSMutableArray *bar = [[defaults stringArrayForKey:@"MBBarOrderV2"] mutableCopy] ?: [NSMutableArray array];
    NSMutableArray *hidden = [[defaults stringArrayForKey:@"MBHiddenOrderV2"] mutableCopy] ?: [NSMutableArray array];
    [top removeObject:key];
    [bar removeObject:key];
    [hidden removeObject:key];
    NSMutableArray *destination = [placement isEqualToString:@"top"] ? top : ([placement isEqualToString:@"hidden"] ? hidden : bar);
    [destination addObject:key];
    [defaults setObject:top forKey:@"MBTopOrderV2"];
    [defaults setObject:bar forKey:@"MBBarOrderV2"];
    [defaults setObject:hidden forKey:@"MBHiddenOrderV2"];
}

- (void)moveSetting:(NSButton *)button {
    if (self.pendingRehide || self.revealingForClick) return;
    BOOL up = [button.identifier hasPrefix:@"up|"];
    NSString *key = [button.identifier substringFromIndex:up ? 3 : 5];
    BarItem *item = [self itemForKey:key];
    if (!item || !item.persistentIdentity || [item.placement isEqualToString:@"hidden"]) return;
    NSString *store = [item.placement isEqualToString:@"top"] ? @"MBTopOrderV2" : @"MBBarOrderV2";
    NSMutableArray *visible = [[self itemsInPlacement:item.placement from:self.catalog] mutableCopy];
    NSUInteger index = [visible indexOfObject:item];
    if (index == NSNotFound || (up && index == 0) || (!up && index + 1 >= visible.count)) return;
    NSUInteger otherIndex = up ? index - 1 : index + 1;
    BarItem *other = visible[otherIndex];
    if ([item.placement isEqualToString:@"top"]) {
        if (!other.persistentIdentity) { [self reportError:@"相邻图标无法稳定识别，请用 Command 拖动调整。"] ; return; }
        self.revealingForClick = YES;
        BOOL moved = up ? [self dragItem:item beforeWindow:other.windowID] : [self dragItem:other beforeWindow:item.windowID];
        self.revealingForClick = NO;
        CGRect a = [self boundsForWindowID:item.windowID], b = [self boundsForWindowID:other.windowID];
        if (!moved || CGRectIsNull(a) || CGRectIsNull(b) || (up ? a.origin.x >= b.origin.x : a.origin.x <= b.origin.x)) {
            [self reportError:@"顶部排序未完成，设置没有更改。"];
            [self reloadItems]; return;
        }
    }
    NSMutableArray *order = [[[self layoutDefaults] stringArrayForKey:store] mutableCopy];
    NSUInteger a = [order indexOfObject:key], b = [order indexOfObject:other.key];
    if (a != NSNotFound && b != NSNotFound) {
        [order exchangeObjectAtIndex:a withObjectAtIndex:b];
        [[self layoutDefaults] setObject:order forKey:store];
    }
    [self reloadItems];
}

- (void)retryLayout:(id)sender {
    if (self.revealingForClick) return;
    if (self.pendingRehide) {
        if ([self itemStillShowingInterface:self.pendingRehide]) { [self reportError:@"请先关闭原生菜单，再重新应用布局。"] ; return; }
        // Explicit retry transfers the saved placement to a fresh layout pass.
        [self cancelPendingRehide];
    }
    self.layoutDirty = YES; self.lastError = nil;
    [self refreshEnvironment];
}

- (void)revealAll:(id)sender {
    if (self.revealingForClick) return;
    [self cancelPendingRehide];
    [self revealMenuBar];
    self.layoutDirty = NO;
    [self reloadItems];
}

- (void)showSettings {
    [self closePanel];
    [self reloadItems];
    if (!self.settingsWindow) {
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 580, 630)
                                                        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO];
        window.title = @"MacBar 偏好设置";
        window.minSize = NSMakeSize(580, 500);
        window.releasedWhenClosed = NO;
        NSView *content = window.contentView;
        NSTextField *note = [NSTextField wrappingLabelWithString:@"这里只管理右上角菜单栏图标，普通 Dock 应用不会自动加入。默认不捕获屏幕；开启原样图标后，macOS 会显示屏幕捕获提示。"];
        note.font = [NSFont systemFontOfSize:12];
        note.textColor = NSColor.secondaryLabelColor;
        note.frame = NSMakeRect(16, 10, 548, 48);
        note.autoresizingMask = NSViewWidthSizable;
        [content addSubview:note];
        NSButton *access = [self smallButton:@"辅助功能权限" action:@selector(openAccessibilitySettings)];
        access.frame = NSMakeRect(16, 64, 140, 28); [content addSubview:access];
        NSButton *capture = [NSButton checkboxWithTitle:@"原样图标（会触发录屏提示）" target:self action:@selector(toggleCapture:)];
        capture.frame = NSMakeRect(170, 64, 250, 28);
        capture.state = [self nativeAppearanceEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
        [content addSubview:capture];
        NSButton *screenCapture = [self smallButton:@"录屏权限（可选）" action:@selector(openScreenRecordingSettings)];
        screenCapture.frame = NSMakeRect(434, 64, 130, 28);
        [content addSubview:screenCapture];
        self.statusLabel = [NSTextField labelWithString:@""];
        self.statusLabel.frame = NSMakeRect(16, 96, 548, 20);
        self.statusLabel.font = [NSFont systemFontOfSize:11];
        self.statusLabel.textColor = NSColor.secondaryLabelColor;
        [content addSubview:self.statusLabel];
        NSButton *openBar = [self smallButton:@"打开收集栏" action:@selector(showPanel)];
        openBar.frame = NSMakeRect(16, 568, 144, 28); openBar.autoresizingMask = NSViewMinYMargin;
        [content addSubview:openBar];
        NSButton *reveal = [self smallButton:@"展开全部顶栏图标" action:@selector(revealAll:)];
        reveal.frame = NSMakeRect(172, 568, 180, 28); reveal.autoresizingMask = NSViewMinYMargin;
        [content addSubview:reveal];
        NSButton *retry = [self smallButton:@"重新应用布局" action:@selector(retryLayout:)];
        retry.frame = NSMakeRect(364, 568, 160, 28); retry.autoresizingMask = NSViewMinYMargin;
        [content addSubview:retry];
        self.settingsScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 124, 580, 430)];
        self.settingsScroll.hasVerticalScroller = YES;
        self.settingsScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.settingsScroll.drawsBackground = NO;
        NSView *document = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 560, 500)];
        self.settingsScroll.documentView = document;
        [content addSubview:self.settingsScroll];
        self.settingsWindow = window;
    }
    [self refillSettings];
    [self.settingsWindow center];
    [self.settingsWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)showPanel {
    [self.settingsWindow orderOut:nil];
    if (!AXIsProcessTrusted()) [self revealMenuBar];
    [self.panel orderFrontRegardless];
    self.viewFingerprint = nil;
    self.rowFingerprint = nil;
    [self reloadItems];
    [self placePanel];
    self.panelOpenedAt = [NSDate date];
    [self.panel orderFrontRegardless];
}

- (void)closePanel {
    [self.panel orderOut:nil];
}

- (void)revealMenuBar {
    self.suppressed = NO;
    self.spacer.length = 24;
}

- (void)suppressMenuBar {
    self.suppressed = YES;
    self.spacer.length = 10000;
}

- (CGRect)windowBounds:(NSDictionary *)dict {
    CGRect bounds = CGRectNull;
    NSDictionary *value = dict[(id)kCGWindowBounds];
    if (value) CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)value, &bounds);
    return bounds;
}

- (BOOL)rectOnThisScreen:(CGRect)bounds {
    return MBRectIsVisible(bounds, [self displayRect]);
}

- (NSArray<NSDictionary *> *)statusCopiesForItem:(BarItem *)item {
    for (NSDictionary *dict in [self windowList:NO]) {
        if ([dict[(id)kCGWindowNumber] unsignedIntValue] != item.windowID || [dict[(id)kCGWindowOwnerPID] intValue] != item.pid) continue;
        CGRect bounds = [self windowBounds:dict];
        if ([dict[(id)kCGWindowLayer] intValue] != 25 || !MBRectIsMenuItem(bounds, [self displayRect]) || fabs(bounds.size.height - [self menuHeight]) > 4) return @[];
        return @[@{@"id": @(item.windowID), @"bounds": [NSValue valueWithRect:bounds], @"on": @([dict[(id)kCGWindowIsOnscreen] boolValue])}];
    }
    return @[];
}

- (CGRect)statusBoundsForItem:(BarItem *)item onScreenOnly:(BOOL)onScreenOnly windowID:(CGWindowID *)outID {
    for (NSDictionary *copy in [self statusCopiesForItem:item]) {
        CGRect bounds = [copy[@"bounds"] rectValue];
        if (onScreenOnly && (![copy[@"on"] boolValue] || ![self rectOnThisScreen:bounds])) continue;
        if (outID) *outID = item.windowID;
        return bounds;
    }
    return CGRectNull;
}

typedef struct {
    CGEventRef event;
    pid_t pid;
    int64_t marker;
    BOOL done;
    CFMachPortRef firstTap;
    CFMachPortRef secondTap;
} MacBarRelay;

static BOOL macbarEventMatches(CGEventRef a, CGEventRef b) {
    CGEventField fields[] = {
        kCGEventSourceUserData,
        kCGMouseEventWindowUnderMousePointer,
        kCGMouseEventWindowUnderMousePointerThatCanHandleThisEvent,
        (CGEventField)0x33
    };
    for (int i = 0; i < 4; i++) {
        if (CGEventGetIntegerValueField(a, fields[i]) != CGEventGetIntegerValueField(b, fields[i])) return NO;
    }
    return YES;
}

static CGEventRef macbarRelayCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef incoming, void *raw) {
    MacBarRelay *relay = raw;
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) return incoming;
    if (type == kCGEventNull && CGEventGetIntegerValueField(incoming, kCGEventSourceUserData) == relay->marker) {
        if (relay->firstTap) CGEventTapEnable(relay->firstTap, false);
        CGEventPost(kCGSessionEventTap, relay->event);
        return NULL;
    }
    if (type == CGEventGetType(relay->event) && macbarEventMatches(incoming, relay->event)) {
        relay->done = YES;
        if (relay->secondTap) CGEventTapEnable(relay->secondTap, false);
        CGEventPostToPid(relay->pid, relay->event);
        return incoming;
    }
    return incoming;
}

- (NSDictionary<NSNumber *, NSValue *> *)windowBoundsSnapshot {
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    for (NSDictionary *dict in [self windowList:YES]) map[dict[(id)kCGWindowNumber]] = [NSValue valueWithRect:[self windowBounds:dict]];
    return map;
}

- (CGWindowID)popupSince:(NSDictionary<NSNumber *, NSValue *> *)before preferPid:(pid_t)pid {
    for (NSDictionary *dict in [self windowList:YES]) {
        if ([dict[(id)kCGWindowOwnerPID] intValue] != pid) continue;
        int layer = [dict[(id)kCGWindowLayer] intValue];
        if (layer == 25 || layer <= 0) continue; // main application windows are not menus
        CGRect bounds = [self windowBounds:dict];
        if (![self rectOnThisScreen:bounds] || bounds.size.width < 8 || bounds.size.height < 8) continue;
        NSNumber *number = dict[(id)kCGWindowNumber];
        NSValue *old = before[number];
        if (!old || !CGRectEqualToRect(old.rectValue, bounds)) return number.unsignedIntValue;
    }
    return 0;
}

- (BOOL)windowIDIsOnScreen:(CGWindowID)windowID {
    for (NSDictionary *dict in [self windowList:YES]) if ([dict[(id)kCGWindowNumber] unsignedIntValue] == windowID) return YES;
    return NO;
}

- (BOOL)scrombleEvent:(CGEventRef)event pid:(pid_t)pid {
    MBEventTapForPid createTap = (MBEventTapForPid)dlsym(RTLD_DEFAULT, "CGEventTapCreateForPid");
    if (!createTap || !event || !AXIsProcessTrusted()) return NO;
    MacBarRelay relay = {0};
    relay.event = event;
    relay.pid = pid;
    relay.marker = (int64_t)(uintptr_t)&relay;
    CGEventMask nullMask = CGEventMaskBit(kCGEventNull);
    CGEventMask eventMask = CGEventMaskBit(CGEventGetType(event));
    relay.firstTap = createTap(pid, kCGTailAppendEventTap, kCGEventTapOptionDefault, nullMask, macbarRelayCallback, &relay);
    relay.secondTap = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionListenOnly, eventMask, macbarRelayCallback, &relay);
    if (!relay.firstTap || !relay.secondTap) {
        if (relay.firstTap) CFRelease(relay.firstTap);
        if (relay.secondTap) CFRelease(relay.secondTap);
        return NO;
    }
    CFRunLoopSourceRef firstSource = CFMachPortCreateRunLoopSource(NULL, relay.firstTap, 0);
    CFRunLoopSourceRef secondSource = CFMachPortCreateRunLoopSource(NULL, relay.secondTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), firstSource, kCFRunLoopCommonModes);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), secondSource, kCFRunLoopCommonModes);
    CGEventTapEnable(relay.firstTap, true);
    CGEventTapEnable(relay.secondTap, true);
    CGEventRef nullEvent = CGEventCreate(NULL);
    CGEventSetIntegerValueField(nullEvent, kCGEventSourceUserData, relay.marker);
    CGEventPostToPid(pid, nullEvent);
    CFRelease(nullEvent);
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.3];
    while (!relay.done && deadline.timeIntervalSinceNow > 0) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
    }
    CGEventTapEnable(relay.firstTap, false);
    CGEventTapEnable(relay.secondTap, false);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), firstSource, kCFRunLoopCommonModes);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), secondSource, kCFRunLoopCommonModes);
    CFRelease(firstSource);
    CFRelease(secondSource);
    CFRelease(relay.firstTap);
    CFRelease(relay.secondTap);
    return relay.done;
}

- (void)stampEvent:(CGEventRef)event pid:(pid_t)pid windowID:(CGWindowID)windowID {
    CGEventSetIntegerValueField(event, kCGEventTargetUnixProcessID, pid);
    CGEventSetIntegerValueField(event, kCGEventSourceUserData, (int64_t)(uintptr_t)event);
    CGEventSetIntegerValueField(event, kCGMouseEventWindowUnderMousePointer, windowID);
    CGEventSetIntegerValueField(event, kCGMouseEventWindowUnderMousePointerThatCanHandleThisEvent, windowID);
    CGEventSetIntegerValueField(event, (CGEventField)0x33, windowID);
}

- (CGWindowID)macBarWindowWide:(BOOL)wide {
    CGRect display = [self displayRect];
    CGWindowID direct = (CGWindowID)(wide ? self.spacer.button.window.windowNumber : self.anchor.button.window.windowNumber);
    CGRect directBounds = [self boundsForWindowID:direct];
    if (!CGRectIsNull(directBounds) && fabs(directBounds.origin.y - display.origin.y) <= 4 && (wide ? (CGRectGetMaxX(directBounds) >= CGRectGetMinX(display) && CGRectGetMaxX(directBounds) <= CGRectGetMaxX(display)) : MBRectIsVisible(directBounds, display))) return direct;
    for (NSDictionary *dict in [self windowList:NO]) {
        if ([dict[(id)kCGWindowOwnerPID] intValue] != getpid() || [dict[(id)kCGWindowLayer] intValue] != 25) continue;
        CGRect bounds = [self windowBounds:dict];
        if (fabs(bounds.origin.y - display.origin.y) > 4) continue;
        if ((bounds.size.width > 1000) == wide && (wide ? (CGRectGetMaxX(bounds) >= CGRectGetMinX(display) && CGRectGetMaxX(bounds) <= CGRectGetMaxX(display)) : MBRectIsVisible(bounds, display))) return [dict[(id)kCGWindowNumber] unsignedIntValue];
    }
    return 0;
}

- (CGRect)boundsForWindowID:(CGWindowID)windowID {
    CFArrayRef info = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
    CGRect found = CGRectNull;
    for (NSDictionary *dict in (__bridge NSArray *)info) {
        if ([dict[(id)kCGWindowNumber] unsignedIntValue] != windowID) continue;
        found = [self windowBounds:dict];
        break;
    }
    if (info) CFRelease(info);
    return found;
}

- (BOOL)itemHasVisibleCopy:(BarItem *)item {
    return !CGRectIsNull([self statusBoundsForItem:item onScreenOnly:YES windowID:NULL]);
}

- (BOOL)dragItem:(BarItem *)item beforeWindow:(CGWindowID)targetWindow {
    [self freezeMenuScreen];
    CGRect original = [self boundsForWindowID:item.windowID];
    CGRect target = [self boundsForWindowID:targetWindow];
    if (!AXIsProcessTrusted() || ![self statusCopiesForItem:item].count || CGRectIsNull(target) || CGRectIsNull(original) || item.windowID == targetWindow) return NO;
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (!source) return NO;
    CGEventRef pointer = CGEventCreate(NULL);
    CGPoint saved = pointer ? CGEventGetLocation(pointer) : CGPointZero;
    if (pointer) CFRelease(pointer);
    CGEventRef down = CGEventCreateMouseEvent(source, kCGEventLeftMouseDown, CGPointMake(20000, 20000), kCGMouseButtonLeft);
    CGEventRef up = CGEventCreateMouseEvent(source, kCGEventLeftMouseUp, CGPointMake(CGRectGetMinX(target) - 4, CGRectGetMidY(target)), kCGMouseButtonLeft);
    if (!down || !up) { if (down) CFRelease(down); if (up) CFRelease(up); CFRelease(source); return NO; }
    CGEventSourceSetLocalEventsSuppressionInterval(source, 0);
    CGEventSourceSetLocalEventsFilterDuringSuppressionState(source, kCGEventFilterMaskPermitAllEvents, kCGEventSuppressionStateRemoteMouseDrag);
    CGEventSourceSetLocalEventsFilterDuringSuppressionState(source, kCGEventFilterMaskPermitAllEvents, kCGEventSuppressionStateSuppressionInterval);
    CGEventSetFlags(up, 0);
    CGEventSetFlags(down, kCGEventFlagMaskCommand);
    [self stampEvent:down pid:item.pid windowID:item.windowID];
    [self stampEvent:up pid:item.pid windowID:targetWindow];
    BOOL sentDown = NO, sentUp = NO;
    CGAssociateMouseAndMouseCursorPosition(false); [NSCursor hide];
    @try {
        sentDown = [self scrombleEvent:down pid:item.pid];
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.03, false);
        sentUp = [self scrombleEvent:up pid:item.pid]; // always release a potentially delivered down
    } @finally {
        CGWarpMouseCursorPosition(saved); CGAssociateMouseAndMouseCursorPosition(true); [NSCursor unhide];
        CFRelease(down); CFRelease(up); CFRelease(source);
    }
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.8];
    NSDate *stableSince = [NSDate date]; CGRect last = CGRectNull;
    while (deadline.timeIntervalSinceNow > 0) {
        CGRect current = [self boundsForWindowID:item.windowID];
        if (!CGRectEqualToRect(current, last)) { last = current; stableSince = [NSDate date]; }
        if (!CGRectIsNull(current) && !CGRectEqualToRect(current, original) && -stableSince.timeIntervalSinceNow >= 0.15) return YES;
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
    }
    [self logEvent:@"drag-unconfirmed" item:item detail:[NSString stringWithFormat:@"down=%d up=%d from=%@ to=%@", sentDown, sentUp, NSStringFromRect(original), NSStringFromRect(last)]];
    return NO;
}

- (BOOL)moveItem:(BarItem *)item toHidden:(BOOL)hidden {
    if (!AXIsProcessTrusted() || ![self statusCopiesForItem:item].count) return NO;
    NSUInteger attempts = self.restoringIcon ? 1 : 3;
    for (NSUInteger attempt = 0; attempt < attempts; attempt++) {
        CGRect current = [self boundsForWindowID:item.windowID];
        CGRect separator = [self boundsForWindowID:[self macBarWindowWide:YES]];
        if (CGRectIsNull(current) || CGRectIsNull(separator)) return NO;
        if (MBPlacementMatches(current, separator, [self displayRect], hidden)) return YES;
        CGWindowID target = [self macBarWindowWide:hidden];
        [self dragItem:item beforeWindow:target];
        // Verify actual final placement, including the last attempt. Event receipt
        // alone does not prove movement, and a delayed receipt need not mean failure.
        current = [self boundsForWindowID:item.windowID];
        separator = [self boundsForWindowID:[self macBarWindowWide:YES]];
        if (CGRectIsNull(current) || CGRectIsNull(separator)) return NO;
        if (MBPlacementMatches(current, separator, [self displayRect], hidden)) return YES;
    }
    return NO;
}

- (BOOL)waitForVisibleItem:(BarItem *)item {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.8];
    CGRect last = CGRectNull; NSDate *stableSince = nil;
    while (deadline.timeIntervalSinceNow > 0) {
        CGRect current = [self statusBoundsForItem:item onScreenOnly:YES windowID:NULL];
        if (!CGRectIsNull(current) && CGRectEqualToRect(current, last)) {
            if (stableSince && -stableSince.timeIntervalSinceNow >= 0.15) return YES;
        } else { last = current; stableSince = [NSDate date]; }
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
    }
    return NO;
}

typedef struct { CGEventRef expected; BOOL received; } MBClickReceipt;
static CGEventRef MBObserveClick(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *context) {
    MBClickReceipt *receipt = context;
    if (type == CGEventGetType(receipt->expected) && macbarEventMatches(event, receipt->expected)) receipt->received = YES;
    return event;
}

- (BOOL)postClickEvent:(CGEventRef)event {
    MBClickReceipt receipt = {event, NO};
    CFMachPortRef tap = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionListenOnly, CGEventMaskBit(CGEventGetType(event)), MBObserveClick, &receipt);
    if (!tap) return NO;
    CFRunLoopSourceRef loop = CFMachPortCreateRunLoopSource(NULL, tap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), loop, kCFRunLoopCommonModes);
    CGEventTapEnable(tap, true);
    // Click once. The PID/session relay is for Command-drag only: relaying a click
    // can deliver it twice and immediately toggle a native popover closed.
    CGEventPost(kCGSessionEventTap, event);
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.3];
    while (!receipt.received && deadline.timeIntervalSinceNow > 0) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
    CGEventTapEnable(tap, false);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), loop, kCFRunLoopCommonModes);
    CFRelease(loop); CFRelease(tap);
    return receipt.received;
}

- (CGError)warpCursorToPoint:(CGPoint)point {
    return CGWarpMouseCursorPosition(point);
}

- (BOOL)clickVisibleItem:(BarItem *)item right:(BOOL)right {
    CGWindowID windowID = 0;
    CGRect bounds = [self statusBoundsForItem:item onScreenOnly:YES windowID:&windowID];
    if (CGRectIsNull(bounds) || !windowID) return NO;
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (!source) return NO;
    CGEventSourceSetLocalEventsSuppressionInterval(source, 0);
    CGEventSourceSetLocalEventsFilterDuringSuppressionState(source, kCGEventFilterMaskPermitAllEvents, kCGEventSuppressionStateSuppressionInterval);
    CGEventSourceSetLocalEventsFilterDuringSuppressionState(source, kCGEventFilterMaskPermitAllEvents, kCGEventSuppressionStateRemoteMouseDrag);
    CGPoint point = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    CGMouseButton button = right ? kCGMouseButtonRight : kCGMouseButtonLeft;
    CGEventRef down = CGEventCreateMouseEvent(source, right ? kCGEventRightMouseDown : kCGEventLeftMouseDown, point, button);
    CGEventRef up = CGEventCreateMouseEvent(source, right ? kCGEventRightMouseUp : kCGEventLeftMouseUp, point, button);
    if (!down || !up) { if (down) CFRelease(down); if (up) CFRelease(up); CFRelease(source); return NO; }
    CGEventSetFlags(down, 0); CGEventSetFlags(up, 0);
    CGEventSetIntegerValueField(down, kCGMouseEventClickState, 1); CGEventSetIntegerValueField(up, kCGMouseEventClickState, 1);
    [self stampEvent:down pid:item.pid windowID:windowID]; [self stampEvent:up pid:item.pid windowID:windowID];
    BOOL a = NO, b = NO;
    @try {
        // The native control lives in the top bar after revealing it. Move the
        // pointer there once, then let the user navigate the opened menu freely.
        // Restoring the collection-row position here caused the apparent offset.
        if ([self warpCursorToPoint:point] != kCGErrorSuccess) return NO;
        [self logEvent:@"cursor-follow" item:item detail:NSStringFromPoint(point)];
        a = [self postClickEvent:down];
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.03, false);
        b = [self postClickEvent:up];
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
    }
    @finally {
        CFRelease(down); CFRelease(up); CFRelease(source);
    }
    return a && b;
}

- (void)cancelPendingRehide {
    [self.rehideTimer invalidate]; self.rehideTimer = nil;
    self.pendingRehide = nil; self.pendingPopup = 0; self.pendingBefore = nil;
    self.viewFingerprint = nil;
    self.pendingStarted = nil; self.absentSamples = 0; self.restoreFailures = 0; self.restoreSuspended = NO;
}

- (void)recordRestoreFailure:(BarItem *)item {
    self.restoreFailures++;
    [self logEvent:@"restore-retry" item:item detail:[NSString stringWithFormat:@"attempt=%lu", (unsigned long)self.restoreFailures]];
    if (self.restoreFailures >= 3) {
        self.restoreSuspended = YES;
        [self.rehideTimer invalidate]; self.rehideTimer = nil;
        [self logEvent:@"restore-suspended" item:item detail:@"automatic dragging stopped; task retained"];
        [self reportError:@"图标暂未收回，已停止自动拖动。请点「重新应用布局」重试，或展开全部图标。"];
    }
}

- (void)rehidePendingItem {
    BarItem *item = self.pendingRehide;
    if (!item || self.revealingForClick || self.restoreSuspended) return;
    [self freezeMenuScreen];
    BOOL exists = NO;
    for (NSDictionary *window in [self windowList:NO]) if ([window[(id)kCGWindowNumber] unsignedIntValue] == item.windowID && [window[(id)kCGWindowOwnerPID] intValue] == item.pid) { exists = YES; break; }
    if (!exists) {
        [self logEvent:@"target-disappeared" item:item detail:@"No other window will be substituted"];
        [self cancelPendingRehide]; return;
    }
    if (![self statusCopiesForItem:item].count) { [self recordRestoreFailure:item]; return; }
    self.revealingForClick = YES;
    self.restoringIcon = YES;
    BOOL restored = NO;
    @try {
        // One move is sufficient to restore the hidden section. Collection order
        // is persisted separately; dragging to an offscreen neighbor adds flicker.
        restored = [self moveItem:item toHidden:YES];
    }
    @finally { self.revealingForClick = NO; self.restoringIcon = NO; }
    if (restored) { [self logEvent:@"restored" item:item detail:nil]; [self cancelPendingRehide]; }
    else {
        [self recordRestoreFailure:item];
    }
}

- (BOOL)itemStillShowingInterface:(BarItem *)item {
    if (self.pendingPopup && [self windowIDIsOnScreen:self.pendingPopup]) return YES;
    CGWindowID popup = [self popupSince:self.pendingBefore ?: @{} preferPid:item.pid];
    if (popup) { self.pendingPopup = popup; [self logEvent:@"interface-observed" item:item detail:[NSString stringWithFormat:@"window=%u", popup]]; return YES; }
    return NO;
}

- (void)watchPendingRehide {
    [self.rehideTimer invalidate];
    if (self.restoreSuspended) return;
    __weak App *weakSelf = self;
    self.rehideTimer = [NSTimer timerWithTimeInterval:0.35 repeats:YES block:^(NSTimer *timer) {
        App *owner = weakSelf;
        if (!owner.pendingRehide) { [timer invalidate]; return; }
        if (owner.revealingForClick) return;
        BOOL open = [owner itemStillShowingInterface:owner.pendingRehide];
        owner.absentSamples = open ? 0 : owner.absentSamples + 1;
        if (!MBShouldRestore(open, -owner.pendingStarted.timeIntervalSinceNow, owner.absentSamples)) return;
        if (![owner mouseIsIdleForAutomaticMovement]) return;
        [owner rehidePendingItem];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.rehideTimer forMode:NSRunLoopCommonModes];
}

- (BOOL)mouseIsIdleForAutomaticMovement {
    if (NSEvent.pressedMouseButtons) return NO;
    CGEventType types[] = {kCGEventMouseMoved, kCGEventLeftMouseDragged, kCGEventRightMouseDragged};
    for (NSUInteger i = 0; i < 3; i++) if (CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateHIDSystemState, types[i]) < 0.5) return NO;
    return YES;
}

- (BOOL)clickOpensApplicationForItem:(BarItem *)item right:(BOOL)right {
    if (right || !item) return NO;
    NSRunningApplication *app = [self applicationForPID:item.pid];
    if (!app.bundleURL) return NO;
    NSDictionary *info = [NSBundle bundleWithURL:app.bundleURL].infoDictionary;
    return MBClickOpensApplication(info, app.activationPolicy, right);
}

- (void)activateItem:(BarItem *)item right:(BOOL)right {
    if (!item || self.revealingForClick || [item.placement isEqualToString:@"hidden"]) return;
    if ([self clickOpensApplicationForItem:item right:right]) {
        [self closePanel];
        [self openApplicationForItem:item];
        // A previously revealed icon retains its recovery task. App activation
        // dismisses its native menu; the existing watcher restores it afterward.
        return;
    }
    [self activateNativeItem:item right:right];
}

- (void)openApplicationForItem:(BarItem *)item {
    NSURL *url = [self applicationForPID:item.pid].bundleURL;
    if (!url) { [self reportError:@"未找到应用位置，请确认该应用仍在运行。"] ; return; }
    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
    configuration.activates = YES;
    configuration.createsNewApplicationInstance = NO;
    [self logEvent:@"application-open-requested" item:item detail:@"left click"];
    [NSWorkspace.sharedWorkspace openApplicationAtURL:url configuration:configuration completionHandler:^(NSRunningApplication *app, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!app || error) [self reportError:[NSString stringWithFormat:@"打开应用失败：%@", error.localizedDescription ?: @"应用未响应"]];
            else [self logEvent:@"application-activated" item:item detail:app.bundleIdentifier];
        });
    }];
}

- (void)activateNativeItem:(BarItem *)item right:(BOOL)right {
    if (!AXIsProcessTrusted()) { [self revealMenuBar]; [self openAccessibilitySettings]; return; }
    if (self.restoreSuspended) { [self reportError:@"恢复任务已暂停自动拖动，请先点「重新应用布局」重试。"] ; return; }
    if (self.pendingRehide) {
        // Never abandon the first item's restoration when another item is clicked.
        BOOL sameGesture = MBClickMatchesPending(item.key, right, self.pendingRehide.key, self.pendingRight);
        if ([self itemStillShowingInterface:self.pendingRehide]) {
            // A second click toggles the same native control, rather than abandoning it.
            self.revealingForClick = YES;
            [self clickVisibleItem:self.pendingRehide right:self.pendingRight];
            self.revealingForClick = NO;
            if ([self itemStillShowingInterface:self.pendingRehide]) {
                [self reportError:@"当前原生面板仍在打开，请先关闭它再切换图标。"];
                return;
            }
        }
        [self rehidePendingItem];
        if (self.pendingRehide || sameGesture) return;
    }
    [self closePanel];
    self.revealingForClick = YES;
    self.pendingRehide = item;
    self.pendingRight = right;
    self.pendingBefore = [self windowBoundsSnapshot];
    self.pendingStarted = [NSDate date];
    BOOL shown = NO, sent = NO;
    @try {
        shown = [self moveItem:item toHidden:NO];
        [self logEvent:shown ? @"revealed" : @"reveal-failed" item:item detail:nil];
        if (shown && [self waitForVisibleItem:item]) {
            [self captureAvailableImages];
            sent = [self clickVisibleItem:item right:right];
            [self logEvent:sent ? @"events-sent" : @"events-failed" item:item detail:right ? @"right" : @"left"];
        }
    } @finally { self.revealingForClick = NO; }
    if (!shown || !sent) [self reportError:@"未能完成原生点击，正在恢复图标；可展开顶部后直接操作。"];
    [self watchPendingRehide];
}

- (void)quit:(id)sender {
    [self revealMenuBar];
    [NSApp terminate:nil];
}

@end

@implementation IconCell

- (BOOL)allowsVibrancy { return NO; }

- (BarItem *)item {
    return [self.owner itemForKey:self.itemKey];
}

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSAccessibilityRole)accessibilityRole {
    return NSAccessibilityButtonRole;
}

- (NSString *)accessibilityLabel {
    return [self item].name ?: @"图标";
}

- (void)sendClick:(BOOL)right {
    NSString *key = self.itemKey;
    __weak App *owner = self.owner;
    dispatch_async(dispatch_get_main_queue(), ^{ [owner activateItem:[owner itemForKey:key] right:right]; });
}

- (BOOL)accessibilityPerformPress {
    [self sendClick:NO];
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    if (self.highlighted) {
        [[NSColor colorWithWhite:1 alpha:0.28] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 1, 2) xRadius:6 yRadius:6] fill];
    }
    BarItem *item = [self item];
    NSImage *image = item.statusImage ?: item.icon;
    if (!image) return;
    image = [image copy];
    image.template = NO;
    CGFloat ratio = image.size.height > 0 ? image.size.width / image.size.height : 1;
    CGFloat drawWidth = item.statusImage ? image.size.width : 22 * ratio;
    CGFloat scale = MIN(1, MIN((NSWidth(self.bounds) - 4) / MAX(drawWidth, 1), (NSHeight(self.bounds) - 4) / MAX(item.statusImage ? image.size.height : 22, 1)));
    NSSize size = NSMakeSize(drawWidth * scale, (item.statusImage ? image.size.height : 22) * scale);
    if (size.width > NSWidth(self.bounds) - 2) size.width = NSWidth(self.bounds) - 2;
    if (size.height > NSHeight(self.bounds) - 4) size.height = NSHeight(self.bounds) - 4;
    NSRect rect = NSMakeRect((NSWidth(self.bounds) - size.width) / 2.0, (NSHeight(self.bounds) - size.height) / 2.0, size.width, size.height);
    [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
}

- (void)mouseDown:(NSEvent *)event {
    self.owner.trackingMenu = YES;
    self.highlighted = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    self.owner.trackingMenu = NO;
    self.highlighted = NO;
    [self setNeedsDisplay:YES];
    NSPoint local = [self convertPoint:event.locationInWindow fromView:nil];
    if (!NSPointInRect(local, self.bounds)) return;
    [self sendClick:NO];
}

- (void)rightMouseDown:(NSEvent *)event {
    self.owner.trackingMenu = YES;
    self.highlighted = YES;
    [self setNeedsDisplay:YES];
}

- (void)rightMouseUp:(NSEvent *)event {
    if (NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds)) [self sendClick:YES];
    self.owner.trackingMenu = NO;
    self.highlighted = NO;
    [self setNeedsDisplay:YES];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        App *delegate = [App new];
        if (argc > 1 && strcmp(argv[1], "--diagnose") == 0) {
            delegate.imageCache = [NSMutableDictionary dictionary];
            NSMutableArray *items = [NSMutableArray array];
            for (BarItem *item in [delegate scanItems]) [items addObject:@{@"key": item.key, @"name": item.name ?: @"", @"window": @(item.windowID), @"pid": @(item.pid), @"stable": @(item.persistentIdentity), @"token": item.identityToken ?: @"", @"x": @(item.sortX), @"width": @(item.width)}];
            NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"trusted": @(AXIsProcessTrusted()), @"items": items} options:NSJSONWritingPrettyPrinted error:nil];
            fwrite(json.bytes, 1, json.length, stdout); return 0;
        }
        NSArray *others = [NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier ?: @"cc.icc.macbar"];
        for (NSRunningApplication *other in others) if (other.processIdentifier != getpid()) { [other activateWithOptions:0]; return 0; }
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}
