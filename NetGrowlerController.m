/*
 * $Id$
 *
 * Copyright (C) 2004 Scott Lamb <slamb@slamb.org>
 * This file is part of NetGrowler, which is released under the MIT license.
 */

// Media stuff
#import <sys/socket.h>
#import <sys/sockio.h>
#import <sys/ioctl.h>
#import <net/if.h>
#import <net/if_media.h>
#import <unistd.h>

// Rest of the includes
#import "NetGrowlerController.h"
#import <GrowlAppBridge/GrowlApplicationBridge.h>
#import <GrowlAppBridge/GrowlDefines.h>

#define AIRPORT_DISCONNECTED 1 /* @"Link Status" == 1 seems to mean disconnected */

static NSString *NOTE_LINK_UP                   = @"Link-Up";
static NSString *NOTE_LINK_DOWN                 = @"Link-Down";
static NSString *NOTE_IP_ACQUIRED               = @"IP-Acquired";
static NSString *NOTE_IP_RELEASED               = @"IP-Released";
static NSString *NOTE_AIRPORT_CONNECT           = @"AirPort-Connect";
static NSString *NOTE_AIRPORT_DISCONNECT        = @"AirPort-Disconnect";

static NSString *AIRPORT_APP_NAME               = @"Airport Admin Utility.app";
static NSString *IP_APP_NAME                    = @"Internet Connect.app";

static NSString *APP_NAME                       = @"NetGrowler.app";

static struct ifmedia_description ifm_subtype_ethernet_descriptions[] = IFM_SUBTYPE_ETHERNET_DESCRIPTIONS;
static struct ifmedia_description ifm_shared_option_descriptions[] = IFM_SHARED_OPTION_DESCRIPTIONS;

@interface NetGrowlerController (PRIVATE)
- (void)registerGrowl:(void*)context;
- (void)applicationDidFinishLaunching:(NSNotification*)notification;
- (void)linkStatusChange:(NSDictionary*)newValue;
- (void)ipAddressChange:(NSDictionary*)newValue;
- (void)airportStatusChange:(NSDictionary*)newValue;
- (NSString*)getMediaForInterface:(NSString*)anInterface;
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
	
	scNotificationManager = [[SCDynamicStore alloc] init];
	[scNotificationManager addObserver:self
							  selector:@selector(linkStatusChange:)
								forKey:@"State:/Network/Interface/en0/Link"];
	[scNotificationManager addObserver:self
							  selector:@selector(ipAddressChange:)
								forKey:@"State:/Network/Global/IPv4"];
	[scNotificationManager addObserver:self
							  selector:@selector(airportStatusChange:)
								forKey:@"State:/Network/Interface/en1/AirPort"];
	airportStatus = [[scNotificationManager valueForKey:@"State:/Network/Interface/en1/AirPort"] retain];
	
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
		NSString *media = [self getMediaForInterface:@"en0"];
		NSString *desc = [NSString stringWithFormat:@"Interface:\ten0\nMedia:\t%@", media];
		NSLog(@"Ethernet cable plugged");
		noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NOTE_LINK_UP, GROWL_NOTIFICATION_NAME,
			APP_NAME, GROWL_APP_NAME,
			@"Ethernet activated", GROWL_NOTIFICATION_TITLE,
			desc, GROWL_NOTIFICATION_DESCRIPTION,
			[ipIcon TIFFRepresentation], GROWL_NOTIFICATION_ICON,
			nil];
	} else {
		noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NOTE_LINK_DOWN, GROWL_NOTIFICATION_NAME,
			APP_NAME, GROWL_APP_NAME,
			@"Ethernet deactivated", GROWL_NOTIFICATION_TITLE,
			[NSString stringWithFormat:@"Interface:\ten0"], GROWL_NOTIFICATION_DESCRIPTION,
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
		NSLog(@"No primary interface");
		noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NOTE_IP_RELEASED, GROWL_NOTIFICATION_NAME,
			APP_NAME, GROWL_APP_NAME,
			@"IP address released", GROWL_NOTIFICATION_TITLE,
			[NSString stringWithFormat:@"No IP address now"], GROWL_NOTIFICATION_DESCRIPTION,
			[ipIcon TIFFRepresentation], GROWL_NOTIFICATION_ICON,
			nil];
	} else {
		NSLog(@"IP address acquired");
		NSString *ipv4Key = [NSString stringWithFormat:@"State:/Network/Interface/%@/IPv4",
													   [newValue valueForKey:@"PrimaryInterface"]];
		NSDictionary *ipv4Info = [scNotificationManager valueForKey:ipv4Key];
		NSArray *addrs = [ipv4Info valueForKey:@"Addresses"];
		NSAssert([addrs count] > 0, @"Empty address array");
		noteDict = [NSDictionary dictionaryWithObjectsAndKeys:
			NOTE_IP_ACQUIRED, GROWL_NOTIFICATION_NAME,
			APP_NAME, GROWL_APP_NAME,
			@"IP address acquired", GROWL_NOTIFICATION_TITLE,
			[NSString stringWithFormat:@"New primary IP: %@", [addrs objectAtIndex:0]], GROWL_NOTIFICATION_DESCRIPTION,
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
		NSString *desc = [NSString stringWithFormat:@"Joined network.\nSSID:\t\t%@\nBSSID:\t%@",
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

- (NSString*)getMediaForInterface:(NSString*)anInterface {
	// This is all made by looking through Darwin's src/network_cmds/ifconfig.tproj.
	// There's no pretty way to get media stuff; I've stripped it down to the essentials
	// for what I'm doing.

	NSAssert([anInterface cStringLength] < IFNAMSIZ, @"Interface name too long");

	int s = socket(AF_INET, SOCK_DGRAM, 0);
	NSAssert(s >= 0, @"Can't open datagram socket");
	struct ifmediareq ifmr;
	memset(&ifmr, 0, sizeof(ifmr));
	strncpy(ifmr.ifm_name, [anInterface cString], [anInterface cStringLength]);

	if (ioctl(s, SIOCGIFMEDIA, (caddr_t)&ifmr) < 0) {
		// Media not supported.
		close(s);
		return nil;
	}
	
	close(s);

	// Now ifmr.ifm_current holds the selected type (probably auto-select)
	// ifmr.ifm_active holds details (100baseT <full-duplex> or similar)
	// We only want the ifm_active bit.

	const char *type = "Unknown";

	// We'll only look in the Ethernet list. I don't care about anything else.
	struct ifmedia_description *desc;
	for (desc = ifm_subtype_ethernet_descriptions; desc->ifmt_string != NULL; desc++) {
		if (IFM_SUBTYPE(ifmr.ifm_active) == desc->ifmt_word) {
			type = desc->ifmt_string;
			break;
		}
	}

	NSString *options = nil;
	
	// And fill in the duplex settings.
	for (desc = ifm_shared_option_descriptions; desc->ifmt_string != NULL; desc++) {
		if (ifmr.ifm_active & desc->ifmt_word) {
			if (options == nil) {
				options = [NSString stringWithCString:desc->ifmt_string];
			} else {
				options = [NSString stringWithFormat:@"%@,%s", options, desc->ifmt_string];
			}
		}
	}
	
	return (options == nil) ? [NSString stringWithCString:type]
							: [NSString stringWithFormat:@"%s <%@>", type, options];
}

@end
