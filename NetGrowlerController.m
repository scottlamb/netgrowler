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

#define AIRPORT_DISCONNECTED 1 /* @"Link Status" == 1 seems to mean disconnected */

static NSString *NOTE_LINK_UP				= @"NetGrowler-Link-Up";
static NSString *NOTE_LINK_DOWN				= @"NetGrowler-Link-Down";
static NSString *NOTE_IP_ACQUIRED			= @"NetGrowler-IP-Acquired";
static NSString *NOTE_IP_RELEASED			= @"NetGrowler-IP-Released";
static NSString *NOTE_AIRPORT_CONNECT		= @"NetGrowler-AirPort-Connect";
static NSString *NOTE_AIRPORT_DISCONNECT  = @"NetGrowler-AirPort-Disconnect";

static NSString *AIRPORT_APP_NAME			= @"Airport Admin Utility.app";
static NSString *IP_APP_NAME				= @"Internet Connect.app";

static NSString *APP_NAME					= @"NetGrowler.app";

@interface NetGrowlerController (PRIVATE)
- (void)registerGrowl:(void*)context;
- (void)applicationDidFinishLaunching:(NSNotification*)notification;
- (void)linkStatusChange:(NSDictionary*)newValue;
- (void)ipAddressChange:(NSDictionary*)newValue;
- (void)airportStatusChange:(NSDictionary*)newValue;
@end

@implementation NetGrowlerController

- (id)init
{
	NSLog(@"Initializing");
	
	self = [super init];
	state = S_GROWL_LAUNCHING;
	airportStatus = nil;
	
	NSString *path = [[NSWorkspace sharedWorkspace] fullPathForApplication:AIRPORT_APP_NAME];
	airportIcon = [[[NSWorkspace sharedWorkspace] iconForFile:path] retain];

	path = [[NSWorkspace sharedWorkspace] fullPathForApplication:IP_APP_NAME];
	ipIcon = [[[NSWorkspace sharedWorkspace] iconForFile:path] retain];
	
	scNotificationManager = [[IXSCNotificationManager alloc] init];
	[scNotificationManager addObserver:self
							  selector:@selector(linkStatusChange:)
								forKey:@"State:/Network/Interface/en0/Link"];
	[scNotificationManager addObserver:self
							  selector:@selector(ipAddressChange:)
								forKey:@"State:/Network/Global/IPv4"];
	[scNotificationManager addObserver:self
							  selector:@selector(airportStatusChange:)
								forKey:@"State:/Network/Interface/en1/AirPort"];
	airportStatus = [[scNotificationManager getValueForKey:@"State:/Network/Interface/en1/AirPort"] retain];
	
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
	[airportIcon release];
	[airportStatus release];
	[ipIcon release];
	[scNotificationManager release];
	[super dealloc];
}

- (void)registerGrowl:(void*)context
{
	NSAssert(self->state == S_GROWL_LAUNCHING, @"Growl must be launching to register");
	self->state = S_GROWL_LAUNCHED;
	NSLog(@"Registering Growl");
	NSArray *allNotes = [NSArray arrayWithObjects:
		NOTE_LINK_UP,
		NOTE_LINK_DOWN,
		NOTE_IP_ACQUIRED,
		NOTE_IP_RELEASED,
		NOTE_AIRPORT_CONNECT,
		NOTE_AIRPORT_DISCONNECT,
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

- (void)linkStatusChange:(NSDictionary*)newValue
{
	Boolean active = CFBooleanGetValue((CFBooleanRef) [newValue objectForKey:@"Active"]);
	NSDictionary *noteDict = nil;

	if (active) {
		NSLog(@"Ethernet cable plugged");
		noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NOTE_LINK_UP, GROWL_NOTIFICATION_NAME,
			APP_NAME, GROWL_APP_NAME,
			@"Ethernet active", GROWL_NOTIFICATION_TITLE,
			[NSString stringWithFormat:@"Gained wired connection."], GROWL_NOTIFICATION_DESCRIPTION,
			[ipIcon TIFFRepresentation], GROWL_NOTIFICATION_ICON,
			nil];
	} else {
		noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NOTE_LINK_DOWN, GROWL_NOTIFICATION_NAME,
			APP_NAME, GROWL_APP_NAME,
			@"Ethernet inactive", GROWL_NOTIFICATION_TITLE,
			[NSString stringWithFormat:@"Lost wired connection."], GROWL_NOTIFICATION_DESCRIPTION,
			[ipIcon TIFFRepresentation], GROWL_NOTIFICATION_ICON,
			nil];
	}		
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION
																   object:nil
																 userInfo:noteDict];	
}

- (void)ipAddressChange:(NSDictionary*)newValue
{
	NSDictionary *noteDict = nil;

	if (newValue == nil) {
		NSLog(@"IP address released");
		noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NOTE_IP_RELEASED, GROWL_NOTIFICATION_NAME,
			APP_NAME, GROWL_APP_NAME,
			@"IP address released", GROWL_NOTIFICATION_TITLE,
			[NSString stringWithFormat:@"No IP address now"], GROWL_NOTIFICATION_DESCRIPTION,
			[ipIcon TIFFRepresentation], GROWL_NOTIFICATION_ICON,
			nil];
	} else {
		NSLog(@"IP address acquired");
		noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NOTE_IP_ACQUIRED, GROWL_NOTIFICATION_NAME,
			APP_NAME, GROWL_APP_NAME,
			@"IP address acquired", GROWL_NOTIFICATION_TITLE,
			[NSString stringWithFormat:@"Have IP address now"], GROWL_NOTIFICATION_DESCRIPTION,
			[ipIcon TIFFRepresentation], GROWL_NOTIFICATION_ICON,
			nil];
	}
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION
																   object:nil
																 userInfo:noteDict];
}

- (void)airportStatusChange:(NSDictionary*)newValue
{
	NSLog(@"AirPort event");
	NSMutableDictionary *noteDict = nil;
	if ([[airportStatus objectForKey:@"BSSID"] isEqualToData:[newValue objectForKey:@"BSSID"]]) {
		// No change. Ignore.
	} else if ([[newValue objectForKey:@"Link Status"] intValue] == AIRPORT_DISCONNECTED) {
		NSString *desc = [NSString stringWithFormat:@"Left network %@.",
			[airportStatus objectForKey:@"SSID"]];
		noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NOTE_AIRPORT_DISCONNECT, GROWL_NOTIFICATION_NAME,
			APP_NAME, GROWL_APP_NAME,
			@"AirPort disconnected", GROWL_NOTIFICATION_TITLE,
			desc, GROWL_NOTIFICATION_DESCRIPTION,
			[airportIcon TIFFRepresentation], GROWL_NOTIFICATION_ICON,
			nil];
	} else {
		const unsigned char *bssidBytes = [[newValue objectForKey:@"BSSID"] bytes];
		NSString *bssid = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
			bssidBytes[0],
			bssidBytes[1],
			bssidBytes[2],
			bssidBytes[3],
			bssidBytes[4],
			bssidBytes[5]];
		NSString *desc = [NSString stringWithFormat:@"Joined network.\nSSID:\t%@\nBSSID:\t%@",
													[newValue objectForKey:@"SSID"],
													bssid];
		noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NOTE_AIRPORT_CONNECT, GROWL_NOTIFICATION_NAME,
			APP_NAME, GROWL_APP_NAME,
			@"AirPort connected", GROWL_NOTIFICATION_TITLE,
			desc, GROWL_NOTIFICATION_DESCRIPTION,
			[airportIcon TIFFRepresentation], GROWL_NOTIFICATION_ICON,
			nil];
	}
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION
																   object:nil
																 userInfo:noteDict];
	airportStatus = [newValue retain];
}

@end
