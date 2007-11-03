/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import "AirportObserver.h"
#import "SCDynamicStore.h"
#import "NetGrowlerController.h"
#import <Cocoa/Cocoa.h>
#include <sys/utsname.h>

const static NSString* ICON_PATHS[] = {
	@"/Applications/Utilities/Airport Utility.app",			/* 10.5 */
	@"/Applications/Utilities/Airport Admin Utility.app",	/* 10.4 and earlier */
};

@interface AirportObserver (PRIVATE)
- (void)airportStatusChange:(NSString*)keyName;
@end

@implementation AirportObserver

- (id)initWithService:(NSString*)aService andStore:(SCDynamicStore*)aDynStore {
	self = [super init];

	if (self) {
		int i;
		struct utsname name;

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
		for (i = 0; i < sizeof(ICON_PATHS)/sizeof(ICON_PATHS[0]); i++) {
			airportIcon = [[[NSWorkspace sharedWorkspace] iconForFile:(NSString*)ICON_PATHS[i]] retain];
			if (airportIcon != nil)
				break;
		}

		uname(&name);
		beforeLeopard = strcmp(name.release, "9.") < 0;
	}

	return self;
}

- (void)dealloc {
	[interface release];
	// XXX: should remove observer
	[dynStore release];
	[currentStatus release];
	[airportIcon release];
	[super dealloc];
}

- (void)airportStatusChange:(NSString*)keyName {
	NSDictionary *newStatus = [dynStore valueForKey:keyName];
	bool disconnected;
	NSData *oldBSSID = [currentStatus objectForKey:@"BSSID"];
	NSData *newBSSID = [newStatus     objectForKey:@"BSSID"];
	NSString *oldSSID, *newSSID;

	if (beforeLeopard) {
		const static int LINK_DISCONNECTED = 1;
		disconnected = [[newStatus objectForKey:@"Link Status"] intValue]
					   == LINK_DISCONNECTED;
		oldSSID = [currentStatus objectForKey:@"SSID"];
		newSSID = [newStatus     objectForKey:@"SSID"];
	} else {
		oldSSID = [currentStatus objectForKey:@"SSID_STR"];
		newSSID = [newStatus     objectForKey:@"SSID_STR"];
		disconnected = newSSID == nil || [newSSID length] == 0;
	}

	if ((currentStatus == nil && disconnected)
		|| (oldBSSID == nil && newBSSID == nil)
		|| [oldBSSID isEqualToData:newBSSID]) {
		// I seem to get a couple bogus notifications before joining a new network. Not sure why.
		// Also suppress disconnect message on waking.
		NSLog(@"Suppressed boring airportStatusChange");
	} else {
		if (disconnected) {
			NSString *desc = [NSString stringWithFormat:@"Left network %@.", oldSSID];
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
			NSAssert(bssidBytes != NULL, @"NULL bssid");
			NSString *bssid = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
														 bssidBytes[0],
														 bssidBytes[1],
														 bssidBytes[2],
														 bssidBytes[3],
														 bssidBytes[4],
														 bssidBytes[5]];
			NSString *desc = [NSString stringWithFormat:@"Joined network.\nSSID:\t\t%@\nBSSID:\t%@",
														newSSID,
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
