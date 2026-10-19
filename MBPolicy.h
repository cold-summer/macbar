// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 cold-summer and MacBar contributors.
#import <Cocoa/Cocoa.h>

// Persistent identity deliberately excludes position, width and display text.
NSString *MBItemKey(NSString *bundle, NSString *identifier);
BOOL MBLegacyContainsBundle(NSArray<NSString *> *keys, NSString *bundle);
CGRect MBDisplayRect(NSScreen *screen);
BOOL MBRectIsVisible(CGRect rect, CGRect display);
BOOL MBRectIsMenuItem(CGRect rect, CGRect display);
BOOL MBShouldRestore(BOOL interfaceOpen, NSTimeInterval elapsed, NSUInteger absentSamples);
BOOL MBAXFrameMatchesWindow(CGRect accessibilityFrame, CGRect windowFrame);
// Keep the full native width and Retina scale, trimming only vertical menu padding.
// Empty/solid captures are rejected so they cannot replace a useful cached image.
NSImage *MBStatusImage(CGImageRef image, CGSize windowSize);
NSNumber *MBNativeForegroundLuminance(NSImage *image);
BOOL MBPreferDarkBackground(NSArray<NSNumber *> *luminances, BOOL fallback);
// Use the application's declared UI type, including apps that hide their Dock
// icon at runtime. No application name or bundle-ID allowlist is involved.
BOOL MBClickOpensApplication(NSDictionary *info, NSApplicationActivationPolicy policy, BOOL right);
BOOL MBClickMatchesPending(NSString *key, BOOL right, NSString *pendingKey, BOOL pendingRight);
BOOL MBPlacementMatches(CGRect item, CGRect separator, CGRect display, BOOL hidden);
