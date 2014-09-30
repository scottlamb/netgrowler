/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

// Rest of the includes
#import "NetGrowlerController.h"
#import "SCDynamicStore.h"
#import "PowerNotifier.h"
#import "IPv4Observer.h"
#import "EthernetObserver.h"
#import "AirportObserver.h"
#import "PPPObserver.h"
#import <Growl/GrowlApplicationBridge.h>
#import <Cocoa/Cocoa.h>

static NSString *APP_NAME                       = @"NetGrowler.app";

@interface NetGrowlerController (PRIVATE)
- (id)sleepWithNil:(id)nilObject;
- (id)wakeWithNil:(id)nilObject;
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

		// Add the appropriate observers for the network services we can see
		struct servicePlugins {
			NSString *suffix;
			Class class;
		} plugins[] = {
			{ @"Ethernet",		[EthernetObserver class] },
			{ @"AirPort",		[AirportObserver class] },
			// buggy: { @"PPP",			[PPPObserver class] },
			{ nil,				nil }
		};
		int i;
		for (i = 0; plugins[i].suffix != nil; i++) {
			NSString *prefix = @"Setup:/Network/Service/";
			NSString *pattern = [NSString stringWithFormat:@"%@[^/]*/Interface",prefix];
			NSEnumerator *e = [[scNotificationManager keysForPattern:pattern] objectEnumerator];
			NSString *key;

			while ((key = [e nextObject]) != nil) {
				// Find the service part
				int startIndex = [prefix length];
				int j;
				for (j = startIndex; [key characterAtIndex:j] != '/'; j++) ;
				NSString *service = [key substringWithRange:NSMakeRange(startIndex, j-startIndex)];
				NSString *type = [[scNotificationManager valueForKey:key] valueForKey:@"Hardware"];
				NSString *deviceKey = [NSString stringWithFormat:@"Setup:/Network/Service/%@/Interface", service];
				NSString *deviceName = [[scNotificationManager valueForKey:deviceKey] valueForKey:@"DeviceName"];
				NSString *linkKey = [NSString stringWithFormat:@"State:/Network/Interface/%@/Link", deviceName];

				if ([plugins[i].suffix isEqualToString:type] && [scNotificationManager valueForKey:linkKey] != nil){
					id observer = [((id) plugins[i].class) performSelector:NSSelectorFromString(@"alloc")];
					[observer initWithService:service andStore:scNotificationManager];
					[observers addObject:observer];
				}
			}
		}

		powerNotifier = [[PowerNotifier powerNotifier] retain];
		[powerNotifier addSleepObserver:self withSelector:@selector(sleepWithNil:)];
		[powerNotifier addWakeObserver:self withSelector:@selector(wakeWithNil:)];
		[GrowlApplicationBridge setGrowlDelegate:self];
	}
	return self;
}

- (void)dealloc
{
	[powerNotifier release];
	[scNotificationManager release];
	[observers release];
	[super dealloc];
}

- (NSDictionary*)registrationDictionaryForGrowl {
	NSArray *allNotes = [NSArray arrayWithObjects:
		NOTE_ETHERNET_LINK_UP,
		NOTE_ETHERNET_LINK_DOWN,
		NOTE_PPP_LINK_UP,
		NOTE_PPP_LINK_DOWN,
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

- (NSString*)applicationNameForGrowl {
	return APP_NAME;
}

- (id)sleepWithNil:(id)nilObject {
	//NSLog(@"Sleep event");
	NSEnumerator *e = [observers objectEnumerator];
	id o;
	while ((o = [e nextObject]) != nil) {
		[o sleep];
	}
	return nil;
}

- (id)wakeWithNil:(id)nilObject {
	//NSLog(@"Wake event");
	return nil;
}

- (void)dumpEverything:(NSString*)keyName {
	NSDictionary *newValue = [scNotificationManager valueForKey:keyName];
	NSLog(@"Key:\t%@\n%@\n\n", keyName, newValue);
}

@end
