/*
 * $Id$
 *
 * Copyright (C) 2004 Scott Lamb <slamb@slamb.org>
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>
#import "IXSCNotificationManager.h"

typedef enum {
	S_GROWL_NO_LAUNCH,
	S_GROWL_LAUNCHING,
	S_GROWL_LAUNCHED
} State;

@interface NetGrowlerController : NSObject {
	State state;
	IXSCNotificationManager *scNotificationManager;
	NSMutableDictionary *airportStatus;
	NSImage *airportIcon;
	NSImage *ipIcon;
}

@end
