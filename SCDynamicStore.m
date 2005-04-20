/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFArray.h>
#import "SCDynamicStore.h"

@interface SCDynamicStore (PRIVATE)
- (void)notificationOfChangedKeys:(NSArray*)changedKeys;
@end


@interface SLObserver : NSObject
{
	id observer;
	SEL selector;
}

+ observer:(id)anObserver withSelector:(SEL)aSelector;
- (id)observer;
- (SEL)selector;

@end

@implementation SLObserver
+ observer:(id)anObserver withSelector:(SEL)aSelector
{
	SLObserver *o = [[SLObserver alloc] init];
	o->observer = anObserver;
	o->selector = aSelector;
	return [o autorelease];
}

- (id)observer
{
	return observer;
}

- (SEL)selector
{
	return selector;
}

@end

static void scCallback(SCDynamicStoreRef dynStore, CFArrayRef changedKeys, void *info) {
	[(SCDynamicStore*) info notificationOfChangedKeys:(NSArray*) changedKeys];
}

@implementation SCDynamicStore

- (void)notificationOfChangedKeys:(NSArray*)changedKeys
{
	NSEnumerator *keysE = [changedKeys objectEnumerator];
	NSString *key = nil;

	while (key = [keysE nextObject]) {
		NSEnumerator *observers = [[self->watchedKeysDict objectForKey:key] objectEnumerator];
		SLObserver *o = nil;

		while (o = [observers nextObject]) {
			[[o observer] performSelector:[o selector]
							   withObject:key];
		}
	}
}


- (id)init {
	self = [super init];
	watchedKeysDict = [[NSMutableDictionary alloc] init];

	SCDynamicStoreContext context = {
		.version			= 0,
		.info				= self,
		.retain				= NULL,
		.release			= NULL,
		.copyDescription	= NULL
	};
	
	dynStore = SCDynamicStoreCreate(
		NULL, 
		(CFStringRef) [[NSBundle mainBundle] bundleIdentifier],
		scCallback,
		&context
	);
	
	rlSrc = SCDynamicStoreCreateRunLoopSource(NULL, dynStore, 0);
	CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], rlSrc, kCFRunLoopCommonModes);
	
	return self;
}

- (NSDictionary*)valueForKey:(NSString*)aKey
{
	CFPropertyListRef dict = SCDynamicStoreCopyValue(dynStore, (CFStringRef) aKey);
	return [(NSDictionary*) dict autorelease];
}

- (void)addObserver:(id)anObserver selector:(SEL)aSelector forKey:(NSString*)aKey
{
	NSMutableArray *observers = [self->watchedKeysDict objectForKey:aKey];
	if (observers == nil) {
		observers = [NSMutableArray array];
	}
	[observers addObject:[SLObserver observer:anObserver withSelector:aSelector]];
	[watchedKeysDict setObject:observers forKey:aKey];
	SCDynamicStoreSetNotificationKeys(dynStore,
									  (CFArrayRef) [watchedKeysDict allKeys],
									  NULL);
}

- (void)addObserver:(id)anObserver selector:(SEL)aSelector forKeyPattern:(NSString*)aKeyPattern
{
	NSArray *matchingKeys = [(NSArray*) SCDynamicStoreCopyKeyList(dynStore, (CFStringRef) aKeyPattern) autorelease];
	NSEnumerator *keysE = [matchingKeys objectEnumerator];
	NSString *key = nil;

	while (key = [keysE nextObject]) {
		[self addObserver:anObserver selector:aSelector forKey:key];
	}
}

- (void)dealloc {
	CFRunLoopRemoveSource([[NSRunLoop currentRunLoop] getCFRunLoop], rlSrc, kCFRunLoopCommonModes);

	CFRelease(rlSrc);
	CFRelease(dynStore);

	[watchedKeysDict release];
	[super dealloc];
}

@end
