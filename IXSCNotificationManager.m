/*
 * Written by Theo Hultberg (theo@iconara.net) 2004-03-09 with help from Boaz Stuller.
 * This code is in the public domain, provided that this notice remains.
 */

#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFArray.h>
#import "IXSCNotificationManager.h"

@implementation SLObserver
+ observer:(id)anObserver withSelector:(SEL)aSelector
{
	SLObserver *o = [[SLObserver alloc] init];
	o->observer = anObserver;
	o->selector = aSelector;
	return [o autorelease];
}
@end

static void _IXSCNotificationCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
	NSEnumerator *keysE = [(NSArray *)changedKeys objectEnumerator];
	NSString *key = nil;
	IXSCNotificationManager *self = (IXSCNotificationManager*) info;
	
	while (key = [keysE nextObject]) {
		NSEnumerator *observers = [[self->watchedKeysDict objectForKey:key] objectEnumerator];
		SLObserver *o = nil;
		NSDictionary *newValue = [(NSDictionary *)SCDynamicStoreCopyValue(store, (CFStringRef) key) autorelease];
		
		while (o = [observers nextObject]) {
			[o->observer performSelector:o->selector
							  withObject:newValue];
		}
	}
}

@implementation IXSCNotificationManager

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
		_IXSCNotificationCallback,
		&context
	);
	
	rlSrc = SCDynamicStoreCreateRunLoopSource(NULL,dynStore,0);
	CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], rlSrc, kCFRunLoopCommonModes);
	
	return self;
}

- (NSDictionary*)getValueForKey:(NSString*)aKey
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

- (void)dealloc {
	CFRunLoopRemoveSource([[NSRunLoop currentRunLoop] getCFRunLoop], rlSrc, kCFRunLoopCommonModes);

	CFRelease(rlSrc);
	CFRelease(dynStore);

	[watchedKeysDict release];
	[super dealloc];
}

@end