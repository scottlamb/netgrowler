/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import "PowerNotifier.h"
#import "SimpleObserver.h"

static PowerNotifier *myself;
static NSMutableArray *sleepObservers;
static NSMutableArray *wakeObservers;
static io_connect_t root_port;

static void sleepCallback(void *unused1, io_service_t unused2, natural_t messageType, void *messageArgument) {
	NSEnumerator *e = nil;
    switch (messageType) {
        case kIOMessageSystemWillSleep:
			NSLog(@"kioMessageSystemWillSleep");
			e = [sleepObservers objectEnumerator];
            break;
        case kIOMessageCanSystemSleep:
			NSLog(@"kioMessageCanSystemSleep");
            break;
        case kIOMessageSystemHasPoweredOn:
			NSLog(@"kioMessageSystemHasPoweredOn");
			e = [wakeObservers objectEnumerator];
            break;
		default:
			NSLog(@"uknown sleepCallback value");
    }
	if (e != nil) {
		SimpleObserver *o;
		while ((o = [e nextObject]) != nil) {
			[o invokeWithObject:nil];
		}
	}
	NSLog(@"sleepCallback finishing");
	IOAllowPowerChange(root_port, (long)messageArgument);
}

@implementation PowerNotifier

- (id)init {
	NSAssert(myself == nil, @"Should be a singleton");
	self = [super init];
	if (self) {
		myself = self;
		sleepObservers = [[NSMutableArray alloc] init];
		wakeObservers = [[NSMutableArray alloc] init];
		root_port = IORegisterForSystemPower(0, &notifyPortRef, sleepCallback, &notifier);
		NSAssert(root_port != 0, @"System power registration failed");
		src = IONotificationPortGetRunLoopSource(notifyPortRef);
		CFRunLoopAddSource(CFRunLoopGetCurrent(), src, kCFRunLoopCommonModes);
	}
	return self;
}

- (void)dealloc {
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, kCFRunLoopCommonModes);
	IODeregisterForSystemPower(&notifier);
	[wakeObservers release];
	wakeObservers = nil;
	[sleepObservers release];
	sleepObservers = nil;
	myself = nil;
	[super dealloc];
}

+ (id)powerNotifier {
	if (myself == nil) {
		myself = [[PowerNotifier alloc] init];
	}
	return [myself autorelease];
}

- (void)addSleepObserver:(id)object withSelector:(SEL)aSelector {
	[sleepObservers addObject:[SimpleObserver observer:object withSelector:aSelector]];
}

- (void)addWakeObserver:(id)object withSelector:(SEL)aSelector {
	[wakeObservers addObject:[SimpleObserver observer:object withSelector:aSelector]];
}

@end
