/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

// Rest of the includes
#import "NetGrowlerController.h"
#import "IPv4Observer.h"
#import "EthernetObserver.h"
#import "AirportObserver.h"
#import <Growl/GrowlApplicationBridge.h>

static NSString *APP_NAME                       = @"NetGrowler.app";

@interface NetGrowlerController (PRIVATE)
- (void)dumpEverything:(NSString*)keyName;
@end

@implementation NetGrowlerController

- (id)init
{
	NSLog(@"Initializing");
	
	self = [super init];
	if (self) {
		scNotificationManager = [[SCDynamicStore alloc] init];
		//[scNotificationManager addObserver:self
		//						  selector:@selector(dumpEverything:)
		//					 forKeyPattern:@"State:/Network/.*"];

		observers = [[NSMutableArray alloc] init];
		[observers addObject:[[IPv4Observer alloc] initWithStore:scNotificationManager]];
		[observers addObject:[[EthernetObserver alloc] initWithInterface:@"en0" andStore:scNotificationManager]];
		[observers addObject:[[AirportObserver alloc] initWithInterface:@"en1" andStore:scNotificationManager]];

		[GrowlApplicationBridge setGrowlDelegate:self];
	}
	return self;
}

- (void)dealloc
{
	[scNotificationManager release];
	[observers release];
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
	if ([GrowlApplicationBridge isGrowlInstalled] == NO) {
		NSRunAlertPanel(@"NetGrowler error",
						@"Growl is not installed",
						@"Exit",
						NULL,
						NULL);
		[NSApp terminate];
	/*} else if ([GrowlApplicationBridge isGrowlRunning] == NO) {
		NSRunAlertPanel(@"NetGrowler error",
						@"Growl failed to start",
						@"Exit",
						NULL,
						NULL);*/
	}
}

- (NSDictionary*)registrationDictionaryForGrowl
{
	NSArray *allNotes = [NSArray arrayWithObjects:
		NOTE_LINK_UP,
		NOTE_LINK_DOWN,
		NOTE_IP_ACQUIRED,
		NOTE_IP_RELEASED,
		NOTE_AIRPORT_CONNECT,
		NOTE_AIRPORT_DISCONNECT,
		nil];
	return [NSDictionary dictionaryWithObjectsAndKeys:
		allNotes, GROWL_NOTIFICATIONS_ALL,
		allNotes, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
}

- (NSString*)applicationNameForGrowl
{
	return APP_NAME;
}

- (void)dumpEverything:(NSString*)keyName
{
	NSDictionary *newValue = [scNotificationManager valueForKey:keyName];
	NSLog(@"Key:\t%@\n%@\n\n", keyName, newValue);
}

@end
