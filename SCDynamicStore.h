/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

/**
 * An AppKit-style wrapper around the Foundation-style SystemConfiguration framework's dynamic stores.
 * Provides access to the SystemConfiguration keys.
 * Both simple queries and change notifications are supported.
 */
@interface SCDynamicStore : NSObject {
	/** A reference to the SystemConfiguration dynamic store. */
	SCDynamicStoreRef dynStore;
	
	/** Our run loop source for notification. */
	CFRunLoopSourceRef rlSrc;
	
	/** Dictionary of watched key names (NSString) to observers (internal Observer class). */
	NSMutableDictionary *watchedKeysDict;
}

/**
 * Finds the keys matching the given pattern.
 * Accepts a regex(3) regular expression pattern.
 */
- (NSArray*)keysForPattern:(NSString*)aPattern;

/**
 * Retrieves the value of the specified key.
 * @return The key's dictionary of values, or null if the key is not found.
 */
- (NSDictionary*)valueForKey:(NSString*)aKey;

/**
 * Monitors a single key for changes.
 * On change, the given selector will be called with the key name.
 */
- (void)addObserver:(id)anObserver selector:(SEL)aSelector forKey:(NSString*)aKey;

/**
 * Monitors a pattern of key for changes.
 * On change, the given selector will be called with the key name.
 * Accepts a regex(3) regular expression pattern.
 */
-(void)addObserver:(id)anObserver selector:(SEL)aSelector forKeyPattern:(NSString*)aKeyPattern;

@end
