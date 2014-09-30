/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import "PPPObserver.h"
#import "SCDynamicStore.h"
#import "NetGrowlerController.h"
#import <Cocoa/Cocoa.h>

#define IP_APP_NAME                    @"Internet Connect.app"

@interface PPPObserver (PRIVATE)
- (void)statusChange:(NSString*)keyName;
@end

@implementation PPPObserver

- (id)initWithService:(NSString*)aService andStore:(SCDynamicStore*)aDynStore {
	self = [super init];

	if (self) {
		NSLog(@"Initializing PPPObserver on service %@", aService);
		service = [aService retain];
		dynStore = [aDynStore retain];
		NSString *keyName = [NSString stringWithFormat:@"State:/Network/Service/%@/PPP", service];
		currentStatus = [dynStore valueForKey:keyName];
		[dynStore addObserver:self
					 selector:@selector(statusChange:)
					   forKey:keyName];

		NSString *path = [[NSWorkspace sharedWorkspace] fullPathForApplication:IP_APP_NAME];
		ipIcon = [[[NSWorkspace sharedWorkspace] iconForFile:path] retain];
	}

	return self;
}

- (void)dealloc {
	// XXX: should remove observer
	[dynStore release];
	[service release];
	[currentStatus release];
	[super dealloc];
}

- (void)statusChange:(NSString*)keyName {
	NSDictionary *newStatus = [dynStore valueForKey:keyName];
	NSString *oldRemoteAddress = [currentStatus valueForKey:@"CommRemoteAddress"];
	NSString *newRemoteAddress = [newStatus     valueForKey:@"CommRemoteAddress"];
	if (   (oldRemoteAddress == nil && newRemoteAddress == nil)
		|| [oldRemoteAddress isEqualToString:newRemoteAddress]) {
		NSLog(@"Suppressed duplicate PPP notification.");
	} else if (newRemoteAddress == nil) {
		NSLog(@"Sending notification: PPP deactivated");
		NSString *desc = [NSString stringWithFormat:@"Remote address: %@", oldRemoteAddress];
		[GrowlApplicationBridge notifyWithTitle:@"PPP deactivated"
									description:desc
							   notificationName:NOTE_PPP_LINK_DOWN
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];		
	} else {
		NSLog(@"Sending notification: PPP activated");
		NSString *desc = [NSString stringWithFormat:@"Remote address: %@", newRemoteAddress];
		[GrowlApplicationBridge notifyWithTitle:@"PPP activated"
									description:desc
							   notificationName:NOTE_PPP_LINK_UP
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	}
	[currentStatus release];
	currentStatus = [newStatus retain];
}

- (void)sleep {
	[currentStatus release];
	currentStatus = nil;
}

@end
