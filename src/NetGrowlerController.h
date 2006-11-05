/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>
#import <Growl/Growl.h>

#define NOTE_ETHERNET_LINK_UP		@"Ethernet-Link-Up"
#define NOTE_ETHERNET_LINK_DOWN		@"Ethernet-Link-Down"
#define NOTE_PPP_LINK_UP			@"PPP-Link-Up"
#define NOTE_PPP_LINK_DOWN			@"PPP-Link-Up"
#define NOTE_IP_ACQUIRED			@"IP-Acquired"
#define NOTE_IP_RELEASED			@"IP-Released"
#define NOTE_AIRPORT_CONNECT		@"AirPort-Connect"
#define NOTE_AIRPORT_DISCONNECT		@"AirPort-Disconnect"

@class SCDynamicStore, PowerNotifier;

@interface NetGrowlerController : NSObject <GrowlApplicationBridgeDelegate> {
	SCDynamicStore *scNotificationManager;
	NSMutableArray *observers;
	PowerNotifier *powerNotifier;
}

- (NSDictionary*) registrationDictionaryForGrowl;
- (NSString*) applicationNameForGrowl;

@end
