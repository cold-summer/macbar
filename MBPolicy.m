// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 cold-summer and MacBar contributors.
#import "MBPolicy.h"
NSString *MBItemKey(NSString *bundle, NSString *identifier) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[bundle ?: @"", identifier ?: @"primary"] options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
BOOL MBLegacyContainsBundle(NSArray<NSString *> *keys, NSString *bundle) {
    if (![bundle isKindOfClass:NSString.class] || !bundle.length) return NO;
    NSString *prefix = [bundle stringByAppendingString:@"|"];
    for (id key in keys.copy) if ([key isKindOfClass:NSString.class] && [key hasPrefix:prefix]) return YES;
    return NO;
}
CGRect MBDisplayRect(NSScreen *screen) {
    NSNumber *number = screen.deviceDescription[@"NSScreenNumber"];
    return number ? CGDisplayBounds(number.unsignedIntValue) : CGRectNull;
}
BOOL MBRectIsVisible(CGRect rect, CGRect display) {
    if (CGRectIsNull(rect) || CGRectIsNull(display) || CGRectIsEmpty(rect)) return NO;
    return CGRectIntersectsRect(rect, display) && CGRectContainsPoint(display, CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect)));
}
BOOL MBRectIsMenuItem(CGRect rect, CGRect display) {
    return !CGRectIsNull(display) && rect.size.width >= 1 && rect.size.width <= 512 &&
        rect.size.height >= 16 && rect.size.height <= 64 && fabs(rect.origin.y - display.origin.y) <= 4;
}
BOOL MBShouldRestore(BOOL interfaceOpen, NSTimeInterval elapsed, NSUInteger absentSamples) {
    // No absolute deadline may interrupt an open native menu/popover.
    return !interfaceOpen && elapsed >= 1.5 && absentSamples >= 3;
}
BOOL MBAXFrameMatchesWindow(CGRect accessibilityFrame, CGRect windowFrame) {
    if (CGRectIsEmpty(accessibilityFrame) || CGRectIsNull(windowFrame)) return NO;
    // AX reports the image/button inside the status window, including its padding.
    return CGRectContainsRect(CGRectInset(windowFrame, -1, -1), accessibilityFrame);
}

NSImage *MBStatusImage(CGImageRef image, CGSize windowSize) {
    if (!image || windowSize.width <= 0 || windowSize.height <= 0) return nil;
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    if (!width || !height) return nil;
    CGFloat scale = height / windowSize.height;
    CGFloat cropHeight = MIN(height, ceil(MIN(24, windowSize.height) * scale));
    CGRect region = CGRectMake(0, floor((height - cropHeight) / 2), width, cropHeight);
    CGImageRef cropped = CGImageCreateWithImageInRect(image, region);
    if (!cropped) return nil;
    // Offscreen windows can return a transparent or solid placeholder. Preserve
    // the last good native content rather than replacing it with an empty box.
    uint8_t pixels[32 * 16 * 4] = {0};
    CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, 32, 16, 8, 32 * 4, color, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    if (!context) { CGImageRelease(cropped); return nil; }
    CGContextDrawImage(context, CGRectMake(0, 0, 32, 16), cropped);
    unsigned int low[4] = {255, 255, 255, 255}, high[4] = {0};
    for (NSUInteger i = 0; i < 32 * 16; i++) for (NSUInteger c = 0; c < 4; c++) {
        low[c] = MIN(low[c], pixels[i * 4 + c]); high[c] = MAX(high[c], pixels[i * 4 + c]);
    }
    CGContextRelease(context);
    BOOL content = NO;
    for (NSUInteger c = 0; c < 4; c++) if (high[c] - low[c] > 8) content = YES;
    NSImage *result = content ? [[NSImage alloc] initWithCGImage:cropped size:NSMakeSize(windowSize.width, cropHeight / scale)] : nil;
    CGImageRelease(cropped);
    return result;
}

NSNumber *MBNativeForegroundLuminance(NSImage *image) {
    CGImageRef source = [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (!source) return nil;
    uint8_t pixels[96 * 24 * 4] = {0};
    CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, 96, 24, 8, 96 * 4, color, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    if (!context) return nil;
    CGContextDrawImage(context, CGRectMake(0, 0, 96, 24), source);
    CGContextRelease(context);
    double total = 0, weight = 0;
    for (NSUInteger i = 0; i < 96 * 24; i++) {
        double alpha = pixels[i * 4 + 3] / 255.0;
        if (alpha < 0.65) continue; // Ignore transparent padding and soft shadows.
        double r = pixels[i * 4] / (255.0 * alpha), g = pixels[i * 4 + 1] / (255.0 * alpha), b = pixels[i * 4 + 2] / (255.0 * alpha);
        if (MAX(r, MAX(g, b)) - MIN(r, MIN(g, b)) > 0.12) continue; // Brand colors do not determine the menu foreground.
        total += (0.2126 * r + 0.7152 * g + 0.0722 * b) * alpha;
        weight += alpha;
    }
    return weight >= 4 ? @(total / weight) : nil;
}

BOOL MBPreferDarkBackground(NSArray<NSNumber *> *luminances, BOOL fallback) {
    NSInteger votes = 0;
    for (NSNumber *value in luminances) {
        if (value.doubleValue > 0.6) votes++;
        else if (value.doubleValue < 0.4) votes--;
    }
    return votes ? votes > 0 : fallback;
}

BOOL MBClickOpensApplication(NSDictionary *info, NSApplicationActivationPolicy policy, BOOL right) {
    if (right || !info || policy == NSApplicationActivationPolicyProhibited || [info[@"LSBackgroundOnly"] boolValue]) return NO;
    // Regular apps may hide their Dock icon while their main window is closed.
    // Their launch metadata still identifies them as a normal application.
    // Agent-only utilities retain their native tray controls instead.
    return policy == NSApplicationActivationPolicyRegular || ![info[@"LSUIElement"] boolValue];
}

BOOL MBClickMatchesPending(NSString *key, BOOL right, NSString *pendingKey, BOOL pendingRight) {
    return [key isEqualToString:pendingKey] && right == pendingRight;
}

BOOL MBPlacementMatches(CGRect item, CGRect separator, CGRect display, BOOL hidden) {
    if (CGRectIsNull(separator) || !MBRectIsMenuItem(item, display) || fabs(item.size.height - separator.size.height) > 4) return NO;
    BOOL inHiddenSection = CGRectGetMaxX(item) <= CGRectGetMinX(separator) + 2;
    // An inactive display can report onScreen=false for correctly positioned
    // menu windows. Placement must not drag them merely to change this flag.
    return hidden ? inHiddenSection : (!inHiddenSection && MBRectIsVisible(item, display));
}
