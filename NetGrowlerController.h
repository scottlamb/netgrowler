/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>
#import "SCDynamicStore.h"
#import <Growl/GrowlApplicationBridge.h>

#define NOTE_LINK_UP				@"Link-Up"
#define NOTE_LINK_DOWN				@"Link-Down"
#define NOTE_IP_ACQUIRED			@"IP-Acquired"
#define NOTE_IP_RELEASED			@"IP-Released"
#define NOTE_AIRPORT_CONNECT		@"AirPort-Connect"
#define NOTE_AIRPORT_DISCONNECT		@"AirPort-Disconnect"

@interface NetGrowlerController : NSObject <GrowlApplicationBridgeDelegate> {
	SCDynamicStore *scNotificationManager;
	NSMutableArray *observers;
}

- (NSDictionary*) registrationDictionaryForGrowl;
- (NSString*) applicationNameForGrowl;

@end
