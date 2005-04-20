/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>

@class SCDynamicStore;

@interface AirportObserver : NSObject
{
	NSString *interface;
	SCDynamicStore *dynStore;
	NSImage *airportIcon;

	// Keep track of old status to suppress uninteresting notifications.
	NSDictionary *currentStatus;
}

- (id)initWithService:(NSString*)service andStore:(SCDynamicStore*)dynStore;
- (void)sleep;
@end
