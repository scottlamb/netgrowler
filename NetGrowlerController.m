//
//  NetGrowlerController.m
//  NetGrowler
//
//  Created by Scott Lamb on Fri Aug 27 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "NetGrowlerController.h"
#import <GrowlAppBridge/GrowlApplicationBridge.h>
#import <GrowlAppBridge/GrowlDefines.h>

static NSString *NOTE_IP_ACQUIRED		= @"NetGrowler-IP-Acquired";
static NSString *NOTE_IP_RELEASED		= @"NetGrowler-IP-Released";

static NSString *APP_NAME				= @"NetGrowler";

@interface NetGrowlerController (PRIVATE)
- (void)registerGrowl:(void*)context;
- (void)applicationDidFinishLaunching:(NSNotification*)notification;
- (void)addressChange:(NSNotification*)notification;
@end

@implementation NetGrowlerController

- (id)init
{
	NSLog(@"Initializing");
	
	self = [super init];
	self->state = S_GROWL_LAUNCHING;

	// Register for IP address changes
	self->scNotificationManager = [[IXSCNotificationManager alloc] init];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(addressChange:)
												 name:nil
											   object:(id)self->scNotificationManager];
	
	// Start growl
	if (self) {
		if ([GrowlAppBridge launchGrowlIfInstalledNotifyingTarget:self
														 selector:@selector(registerGrowl:)
														  context:NULL] == NO) {
			self->state = S_GROWL_NO_LAUNCH;
			NSLog(@"Growl failed to launch");
		}
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:nil
												  object:self->scNotificationManager];
	[self->scNotificationManager release];
	[super dealloc];
}

- (void)registerGrowl:(void*)context
{
	NSAssert(self->state == S_GROWL_LAUNCHING, @"Growl must be launching to register");
	self->state = S_GROWL_LAUNCHED;
	NSLog(@"Registering Growl");
	NSArray *allNotes = [NSArray arrayWithObjects:
		NOTE_IP_ACQUIRED,
		NOTE_IP_RELEASED,
		nil];
	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
		APP_NAME, GROWL_APP_NAME,
		allNotes, GROWL_NOTIFICATIONS_ALL,
		allNotes, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_APP_REGISTRATION
						  object:nil
						userInfo:regDict];
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
	NSLog(@"Application finished launching");
	if (self->state == S_GROWL_NO_LAUNCH) {
		NSRunAlertPanel(@"Growl launch error",
						@"Unable to launch growl; not properly installed.",
						@"Exit",
						NULL,
						NULL);
		[NSApp terminate];
	}
}

- (void)addressChange:(NSNotification*)notification
{
	NSLog(@"SystemConfiguration event: '%@': %@",
		  [notification name],
		  [notification userInfo]);
	if ([[notification name] isEqualToString:@"State:/Network/Global/IPv4"]) {
		NSDictionary *scDict = [notification userInfo];
		NSDictionary *noteDict = nil;
		NSLog(@"IPv4 address change: %@", scDict);
		if (scDict == NULL) {
			noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
				NOTE_IP_RELEASED, GROWL_NOTIFICATION_NAME,
				APP_NAME, GROWL_APP_NAME,
				@"IP address released", GROWL_NOTIFICATION_TITLE,
				[NSString stringWithFormat:@"No IP address now"], GROWL_NOTIFICATION_DESCRIPTION,
				nil];
		} else {
			noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
				NOTE_IP_ACQUIRED, GROWL_NOTIFICATION_NAME,
				APP_NAME, GROWL_APP_NAME,
				@"IP address acquired", GROWL_NOTIFICATION_TITLE,
				[NSString stringWithFormat:@"Have IP address now"], GROWL_NOTIFICATION_DESCRIPTION,
				nil];
		}
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION
																	   object:nil
																	 userInfo:noteDict];
	}
}

@end