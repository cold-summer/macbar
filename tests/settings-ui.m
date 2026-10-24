// SPDX-License-Identifier: GPL-3.0-or-later
// Native UI fixtures never move real menu items or request system access.
#define main MacBarApplicationMain
#import "../main.m"
#undef main
@interface PreviewApp : App
@property BOOL previewTrusted;
@property BOOL previewNative;
@property BOOL previewCapture;
@property NSUInteger previewPermissionRequests;
@property NSUserDefaults *previewDefaults;
@end
@implementation PreviewApp
- (void)reloadItems {}
- (NSUserDefaults *)layoutDefaults { return self.previewDefaults; }
- (void)setNativeAppearanceEnabled:(BOOL)enabled { self.previewNative = enabled; [super setNativeAppearanceEnabled:enabled]; }
- (void)openScreenRecordingSettings { self.previewPermissionRequests++; }
- (NSArray<BarItem *> *)itemsInPlacement:(NSString *)placement from:(NSArray<BarItem *> *)found {
    return [found filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(BarItem *item, NSDictionary *bindings) { return [item.placement isEqualToString:placement]; }]];
}
- (BOOL)accessibilityGranted { return self.previewTrusted; }
- (BOOL)nativeAppearanceEnabled { return self.previewNative; }
- (BOOL)capturePermissionGranted { return self.previewCapture; }
@end
static void Snapshot(PreviewApp *preview, NSString *path, NSSize size, NSString *appearance, BOOL bottom) {
    [preview.settingsWindow setContentSize:size];
    preview.settingsWindow.appearance = [NSAppearance appearanceNamed:appearance];
    [preview refillSettings];
    [preview.settingsWindow.contentView layoutSubtreeIfNeeded];
    if (bottom) {
        NSClipView *clip = preview.settingsScroll.contentView;
        [clip scrollToPoint:NSMakePoint(0, MAX(0, NSHeight(preview.settingsScroll.documentView.frame) - NSHeight(clip.bounds)))];
        [preview.settingsScroll reflectScrolledClipView:clip];
    }
    [preview.settingsWindow display];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    NSView *view = preview.settingsWindow.contentView;
    NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSCAssert(argc == 2, @"Pass the repository root for preview output");
        NSString *root = [NSString stringWithUTF8String:argv[1]];
        NSString *output = [root stringByAppendingPathComponent:@"build/settings-ui"];
        [NSFileManager.defaultManager createDirectoryAtPath:output withIntermediateDirectories:YES attributes:nil error:nil];
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        PreviewApp *preview = [PreviewApp new];
        NSString *suite = [@"cc.icc.macbar.ui-tests." stringByAppendingString:NSUUID.UUID.UUIDString];
        preview.previewDefaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        preview.previewTrusted = YES;
        preview.catalog = [NSMutableArray array];
        NSArray *names = @[@"Clash Verge", @"Lark Helper", @"微信", @"ChatGPT", @"magpie", @"声音", @"用户", @"Wi-Fi", @"电池"];
        NSArray *assets = @[@"clash", @"lark", @"wechat", @"chatgpt", @"magpie", @"sound", @"user", @"wifi", @"battery"];
        for (NSUInteger i = 0; i < names.count; i++) {
            BarItem *item = [BarItem new];
            item.name = names[i]; item.key = [NSString stringWithFormat:@"preview-%lu", i];
            item.placement = i < 5 ? @"top" : (i < 8 ? @"bar" : @"hidden");
            item.persistentIdentity = YES; item.systemItem = i >= 5;
            item.icon = [[NSImage alloc] initWithContentsOfFile:[root stringByAppendingPathComponent:[NSString stringWithFormat:@"design-demos/assets/%@.png", assets[i]]]];
            if (!item.icon) item.icon = [NSImage imageNamed:NSImageNameApplicationIcon];
            [preview.catalog addObject:item];
        }
        [preview showSettings];
        [preview.automaticPlacementControl selectItemAtIndex:1];
        [preview defaultItemPlacementChanged:preview.automaticPlacementControl];
        NSCAssert([[preview defaultItemPlacement] isEqualToString:@"top"], @"New-item destination control works");
        NSCAssert([preview itemsInPlacement:@"bar" from:preview.catalog].count == 3, @"Existing fixture placements are unchanged");
        [preview.automaticPlacementControl selectItemAtIndex:0];
        [preview defaultItemPlacementChanged:preview.automaticPlacementControl];
        preview.iconModeControl.selectedSegment = 1;
        [preview iconModeChanged:preview.iconModeControl];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        NSCAssert(preview.settingsWindow.attachedSheet != nil, @"First sync selection explains permission before requesting it");
        NSCAssert(preview.previewPermissionRequests == 0, @"No system permission requested before consent");
        NSWindow *setup = preview.settingsWindow.attachedSheet;
        [setup display];
        NSView *setupView = setup.contentView;
        NSBitmapImageRep *setupBitmap = [setupView bitmapImageRepForCachingDisplayInRect:setupView.bounds];
        [setupView cacheDisplayInRect:setupView.bounds toBitmapImageRep:setupBitmap];
        [[setupBitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[output stringByAppendingPathComponent:@"settings-sync-setup.png"] atomically:YES];
        NSMutableArray *pendingViews = [NSMutableArray arrayWithObject:setupView];
        NSButton *cancel = nil;
        while (pendingViews.count) {
            NSView *view = pendingViews.lastObject; [pendingViews removeLastObject];
            if ([view isKindOfClass:NSButton.class] && [((NSButton *)view).title isEqualToString:@"使用标准图标"]) cancel = (NSButton *)view;
            [pendingViews addObjectsFromArray:view.subviews];
        }
        NSCAssert(cancel != nil, @"Standard mode option exists in first-use flow");
        [cancel performClick:nil];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
        NSCAssert(!preview.previewNative && preview.previewPermissionRequests == 0, @"Cancel retains standard mode without prompting system access");
        [preview configureIconSync:nil];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        pendingViews = [NSMutableArray arrayWithObject:preview.settingsWindow.attachedSheet.contentView];
        NSButton *proceed = nil;
        while (pendingViews.count) {
            NSView *view = pendingViews.lastObject; [pendingViews removeLastObject];
            if ([view isKindOfClass:NSButton.class] && [((NSButton *)view).title isEqualToString:@"前往系统设置"]) proceed = (NSButton *)view;
            [pendingViews addObjectsFromArray:view.subviews];
        }
        NSCAssert(proceed != nil, @"Permission continuation exists in first-use flow");
        [proceed performClick:nil];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
        NSCAssert(preview.previewNative && preview.previewPermissionRequests == 1, @"Only explicit continuation asks for global MacBar access");
        for (NSUInteger trust = 0; trust < 2; trust++) for (NSUInteger native = 0; native < 2; native++) for (NSUInteger capture = 0; capture < 2; capture++) {
            preview.previewTrusted = trust; preview.previewNative = native; preview.previewCapture = capture;
            [preview refillSettings];
            NSCAssert([preview.accessibilityStatus.textColor isEqual:trust ? MBSettingsGreen() : NSColor.systemOrangeColor], @"Accessibility color must reflect OS permission");
            NSCAssert(preview.iconModeControl.selectedSegment == (native ? 1 : 0), @"Feature selection must remain separate from permission");
            NSCAssert([preview.recordingStatus.textColor isEqual:capture ? MBSettingsGreen() : (native ? NSColor.systemOrangeColor : NSColor.secondaryLabelColor)], @"Capture status color must reflect permission and whether needed");
            NSCAssert(preview.recordingSettingsButton.isHidden == !native, @"Only native mode needs a capture permission action");
            if (!trust) NSCAssert([preview.accessibilityStatus.stringValue isEqualToString:@"先开启才能用"], @"Missing required permission must be explicit");
            if (!native) NSCAssert([preview.captureExplanation.stringValue containsString:@"不含菜单栏未读数字"], @"Default mode must disclose badge limitation");
        }
        preview.previewTrusted = YES; preview.previewNative = NO; preview.previewCapture = NO;
        Snapshot(preview, [output stringByAppendingPathComponent:@"settings-light.png"], NSMakeSize(860, 820), NSAppearanceNameAqua, NO);
        [preview.settingsFilters[2] performClick:nil];
        NSCAssert([preview.settingsPlacementFilter isEqualToString:@"bar"], @"Collection filter operates");
        NSCAssert([preview.settingsFilters[2].title containsString:@"3"], @"Collection count remains accurate");
        [preview.settingsFilters[0] performClick:nil];
        NSCAssert(preview.settingsFilters[0].state == NSControlStateValueOn && preview.settingsFilters[2].state == NSControlStateValueOff, @"Filters are mutually exclusive");
        preview.previewTrusted = NO;
        Snapshot(preview, [output stringByAppendingPathComponent:@"settings-needs-accessibility.png"], NSMakeSize(780, 660), NSAppearanceNameAqua, NO);
        preview.previewTrusted = YES; preview.previewNative = YES;
        Snapshot(preview, [output stringByAppendingPathComponent:@"settings-needs-recording.png"], NSMakeSize(860, 820), NSAppearanceNameAqua, NO);
        preview.previewCapture = YES;
        Snapshot(preview, [output stringByAppendingPathComponent:@"settings-native-authorized.png"], NSMakeSize(780, 660), NSAppearanceNameAqua, YES);
        [preview.catalog removeAllObjects]; preview.previewTrusted = NO; preview.previewNative = NO;
        Snapshot(preview, [output stringByAppendingPathComponent:@"settings-empty.png"], NSMakeSize(860, 820), NSAppearanceNameAqua, NO);
        [preview.previewDefaults removePersistentDomainForName:suite];
        NSLog(@"PASS: eight permission/mode combinations, destination control, first-use cancel/continue, filters, resizing and empty state");
        [preview.settingsWindow orderOut:nil];
    }
    return 0;
}
