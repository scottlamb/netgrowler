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

- (id)initWithInterface:(NSString*)anInterface andStore:(SCDynamicStore*)aDynStore {
	self = [super init];

	if (self) {
		NSLog(@"Initializing AirPortObserver for interface %@", anInterface);
		interface = [anInterface retain];
		dynStore = [aDynStore retain];

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
	NSData *oldBSSID = [currentStatus objectForKey:@"BSSID"];
	NSData *newBSSID = [newStatus objectForKey:@"BSSID"];
	
	if ([oldBSSID isEqualToData:newBSSID]) {
		// I seem to get a couple bogus notifications before joining a new network. Not sure why.
		NSLog(@"Suppressed boring airportStatusChange");
	} else {
		if ([[newStatus objectForKey:@"Link Status"] intValue] == 1 /* disconnected */) {
			NSString *desc = [NSString stringWithFormat:@"Left network %@.", [currentStatus objectForKey:@"SSID"]];
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

@end
