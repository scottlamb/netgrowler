/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <mach/mach_port.h>
#import <mach/mach_interface.h>
#import <mach/mach_init.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/IOMessage.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

/**
 * Notifies of power events.
 * Should be a singleton.
 */
@interface PowerNotifier : NSObject {
	IONotificationPortRef notifyPortRef;
	io_object_t notifier;
	CFRunLoopSourceRef src;
}

/**
 * Returns a shared instance of this class.
 * You still should retain/release it; it will clean up on dealloc.
 */
+ (id)powerNotifier;

- (id)addSleepObserver:(id)object withSelector:(SEL)selector;
- (id)addWakeObserver:(id)object withSelector:(SEL)selector;
@end
