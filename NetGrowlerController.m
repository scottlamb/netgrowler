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

// Type of address stuff
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>

// Rest of the includes
#import "NetGrowlerController.h"
#import <Growl/GrowlApplicationBridge.h>

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
- (void)linkStatusChange:(NSDictionary*)newValue;
- (void)ipAddressChange:(NSDictionary*)newValue;
- (void)airportStatusChange:(NSDictionary*)newValue;
- (NSString*)typeOfIP:(NSString*)ip;
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
		
	[GrowlApplicationBridge setGrowlDelegate:self];
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

- (void)linkStatusChange:(NSDictionary*)newValue
{
	Boolean active = CFBooleanGetValue((CFBooleanRef) [newValue objectForKey:@"Active"]);

	if (active) {
		NSLog(@"Ethernet activated");
		NSString *media = [self getMediaForInterface:@"en0"];
		[GrowlApplicationBridge notifyWithTitle:@"Ethernet activated"
									description:[NSString stringWithFormat:@"Interface:\ten0\nMedia:\t%@", media]
							   notificationName:NOTE_LINK_UP
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	} else {
		NSLog(@"Ethernet deactivated");
		[GrowlApplicationBridge notifyWithTitle:@"Ethernet deactivated"
									description:[NSString stringWithFormat:@"Interface:\ten0"]
							   notificationName:NOTE_LINK_DOWN
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	}		
}

- (void)ipAddressChange:(NSDictionary*)newValue
{
	if (newValue == nil) {
		NSLog(@"IP address released");
		[GrowlApplicationBridge notifyWithTitle:@"IP address released"
									description:[NSString stringWithFormat:@"No IP address now"]
							   notificationName:NOTE_IP_RELEASED
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	} else {
		NSLog(@"IP address acquired");
		NSString *ipv4Key = [NSString stringWithFormat:@"State:/Network/Interface/%@/IPv4",
													   [newValue valueForKey:@"PrimaryInterface"]];
		NSDictionary *ipv4Info = [scNotificationManager valueForKey:ipv4Key];
		NSArray *addrs = [ipv4Info valueForKey:@"Addresses"];
		NSAssert([addrs count] > 0, @"Empty address array");
		NSString *primaryIP = [addrs objectAtIndex:0];
		[GrowlApplicationBridge notifyWithTitle:@"IP address acquired"
									description:[NSString stringWithFormat:@"New primary IP.\nType:\t%@\nAddress:\t%@", [self typeOfIP:primaryIP], primaryIP]
							   notificationName:NOTE_IP_ACQUIRED
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	}
}

- (void)airportStatusChange:(NSDictionary*)newValue
{
	if ([[airportStatus objectForKey:@"BSSID"] isEqualToData:[newValue objectForKey:@"BSSID"]]) {
		// No change. Ignore.
	} else if ([[newValue objectForKey:@"Link Status"] intValue] == AIRPORT_DISCONNECTED) {
		NSLog(@"AirPort disconnect");
		NSString *desc = [NSString stringWithFormat:@"Left network %@.",
			[airportStatus objectForKey:@"SSID"]];
		[GrowlApplicationBridge notifyWithTitle:@"AirPort disconnected"
									description:desc
							   notificationName:NOTE_AIRPORT_DISCONNECT
									   iconData:[airportIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	} else {
		NSLog(@"AirPort connect");
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
		[GrowlApplicationBridge notifyWithTitle:@"AirPort connected"
									description:desc
							   notificationName:NOTE_AIRPORT_DISCONNECT
									   iconData:[airportIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	}
	airportStatus = [newValue retain];
}

- (NSString*) typeOfIP:(NSString*)ipString {
	static struct {
		const char *network;
		char bits;
		NSString *type;
	} types[] = {
		// RFC 1918 addresses
		{ "10.0.0.0", 8,		@"Private" },
		{ "172.16.0.0", 12,		@"Private" },
		{ "192.168.0.0", 16,	@"Private" },
		// Other RFC 3330 addresses
		{ "127.0.0.0", 8,		@"Loopback" },
		{ "169.254.0.0", 16,	@"Link-local" },
		{ "192.0.2.0", 24,		@"Test" },
		{ "192.88.99.0", 24,	@"6to4 relay" },
		{ "198.18.0.0", 15,		@"Benchmark" },
		{ "240.0.0.0", 4,		@"Reserved" },
		{ NULL, 0,				nil }
	};
	struct in_addr addr;
	if (inet_pton(AF_INET, [ipString cString], &addr) <= 0) {
		NSAssert(NO, @"Unable to parse given IP address.");
	}
	unsigned int i;
	for (i = 0; types[i].network != NULL; i++) {
		struct in_addr network_addr;
		if (inet_pton(AF_INET, types[i].network, &network_addr) <= 0) {
			NSAssert(NO, @"Unable to parse network IP address.");
		}
		int mask = ~((1<<types[i].bits) - 1);
		//NSLog(@"Comparing address %13@ (%08x) against %13s (%08x), mask %2d (%08x), type %@",
		//	  ipString, addr, types[i].network, network_addr, types[i].bits, mask, types[i].type);
		if ((network_addr.s_addr & mask) == (addr.s_addr & mask)) {
			return types[i].type;
		}
	}
	return @"Public";
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
