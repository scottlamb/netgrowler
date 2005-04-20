/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import "AirportObserver.h"
#import "SCDynamicStore.h"
#import "NetGrowlerController.h"

#define AIRPORT_APP_NAME @"Airport Admin Utility.app"

@interface AirportObserver (PRIVATE)
- (void)airportStatusChange:(NSString*)keyName;
@end

@implementation AirportObserver

- (id)initWithService:(NSString*)aService andStore:(SCDynamicStore*)aDynStore {
	self = [super init];

	if (self) {
		dynStore = [aDynStore retain];
		NSString *interfaceKey = [NSString stringWithFormat:@"Setup:/Network/Service/%@/Interface", aService];
		interface = [[[dynStore valueForKey:interfaceKey] valueForKey:@"DeviceName"] retain];

		NSLog(@"Initializing AirPortObserver for interface %@", interface);
		NSString *airportKey = [NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort", interface];
		currentStatus = [dynStore valueForKey:airportKey];
		[dynStore addObserver:self
					 selector:@selector(airportStatusChange:)
					   forKey:airportKey];

		// Load AirPort icon
		NSString *path = [[NSWorkspace sharedWorkspace] fullPathForApplication:AIRPORT_APP_NAME];
		airportIcon = [[[NSWorkspace sharedWorkspace] iconForFile:path] retain];
	}

	return self;
}

- (void)dealloc {
	[interface release];
	// XXX: should remove observer
	[dynStore release];
	[currentStatus release];
	[airportIcon release];
}

- (void)airportStatusChange:(NSString*)keyName {
	NSDictionary *newStatus = [dynStore valueForKey:keyName];
	int LINK_DISCONNECTED = 1;
	int newLink = [[newStatus objectForKey:@"Link Status"] intValue];
	NSData *oldBSSID = [currentStatus objectForKey:@"BSSID"];
	NSData *newBSSID = [newStatus objectForKey:@"BSSID"];
	
	if ((currentStatus == nil && newLink == LINK_DISCONNECTED) || [oldBSSID isEqualToData:newBSSID]) {
		// I seem to get a couple bogus notifications before joining a new network. Not sure why.
		// Also suppress disconnect message on waking.
		NSLog(@"Suppressed boring airportStatusChange");
	} else {
		if (newLink == LINK_DISCONNECTED) {
			NSString *desc = [NSString stringWithFormat:@"Left network %@.", [currentStatus objectForKey:@"SSID"]];
			NSLog(@"Sending notification: AirPort disconnected");
			[GrowlApplicationBridge notifyWithTitle:@"AirPort disconnected"
										description:desc
								   notificationName:NOTE_AIRPORT_DISCONNECT
										   iconData:[airportIcon TIFFRepresentation]
										   priority:0
										   isSticky:NO
									   clickContext:nil];
		} else { // connected
			const unsigned char *bssidBytes = [newBSSID bytes];
			NSString *bssid = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
														 bssidBytes[0],
														 bssidBytes[1],
														 bssidBytes[2],
														 bssidBytes[3],
														 bssidBytes[4],
														 bssidBytes[5]];
			NSString *desc = [NSString stringWithFormat:@"Joined network.\nSSID:\t\t%@\nBSSID:\t%@",
														[newStatus objectForKey:@"SSID"],
														bssid];
			NSLog(@"Sending notification: AirPort connected");
			[GrowlApplicationBridge notifyWithTitle:@"AirPort connected"
										description:desc
								   notificationName:NOTE_AIRPORT_DISCONNECT
										   iconData:[airportIcon TIFFRepresentation]
										   priority:0
										   isSticky:NO
									   clickContext:nil];
		}

		[currentStatus release];
		currentStatus = [newStatus retain];
	}
}

- (void)sleep {
	//NSLog(@"AirPortObserver noting pending sleep");
	[currentStatus release];
	currentStatus = nil;
}

@end
