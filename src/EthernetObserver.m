/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import "EthernetObserver.h"
#import "SCDynamicStore.h"
#import "NetGrowlerController.h"
#import <Cocoa/Cocoa.h>

// Media stuff
#import <sys/socket.h>
#import <sys/sockio.h>
#import <sys/ioctl.h>
#import <net/if.h>
#import <net/if_media.h>
#import <unistd.h>

#define IP_APP_NAME                    @"Internet Connect.app"

static struct ifmedia_description ifm_subtype_ethernet_descriptions[] = IFM_SUBTYPE_ETHERNET_DESCRIPTIONS;
static struct ifmedia_description ifm_shared_option_descriptions[] = IFM_SHARED_OPTION_DESCRIPTIONS;

@interface EthernetObserver (PRIVATE)
- (void)linkStatusChange:(NSString*)keyName;
- (NSString*)media;
@end

@implementation EthernetObserver

- (id)initWithService:(NSString*)aService andStore:(SCDynamicStore*)aDynStore {
	self = [super init];

	if (self) {
		dynStore = [aDynStore retain];

		// Load the icon
		NSString *path = [[NSWorkspace sharedWorkspace] fullPathForApplication:IP_APP_NAME];
		ipIcon = [[[NSWorkspace sharedWorkspace] iconForFile:path] retain];

		// Find our interface name
		NSString *interfaceKey = [NSString stringWithFormat:@"Setup:/Network/Service/%@/Interface", aService];
		interface = [[[dynStore valueForKey:interfaceKey] valueForKey:@"DeviceName"] retain];

		NSLog(@"Initializing EthernetObserver for interface %@", interface);

		NSString *linkKey = [NSString stringWithFormat:@"State:/Network/Interface/%@/Link", interface];
		currentActive = CFBooleanGetValue((CFBooleanRef) [[dynStore valueForKey:linkKey] objectForKey:@"Active"]);
		[dynStore addObserver:self
					 selector:@selector(linkStatusChange:)
					   forKey:linkKey];		
	}

	return self;
}

- (void)dealloc {
	// XXX: should remove observer
	[dynStore release];
	[interface release];
	[ipIcon release];
	[super dealloc];
}

- (void)linkStatusChange:(NSString*)keyName
{
	NSDictionary *newStatus = [dynStore valueForKey:keyName];
	Boolean newActive = CFBooleanGetValue((CFBooleanRef) [newStatus objectForKey:@"Active"]);
	
	if (currentActive == newActive) {
		NSLog(@"Suppressed boring Ethernet notification");
	} else if (newActive) {
		NSString *media = [self media];
		NSLog(@"Sending notification: Ethernet activated");
		[GrowlApplicationBridge notifyWithTitle:@"Ethernet activated"
									description:[NSString stringWithFormat:@"Interface:\t%@\nMedia:\t%@", interface, media]
							   notificationName:NOTE_ETHERNET_LINK_UP
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	} else {
		NSLog(@"Sending notification: Ethernet deactivated");
		[GrowlApplicationBridge notifyWithTitle:@"Ethernet deactivated"
									description:[NSString stringWithFormat:@"Interface:\t%@", interface]
							   notificationName:NOTE_ETHERNET_LINK_DOWN
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	}

	currentActive = newActive;
}

- (NSString*)media {
	// This is all made by looking through Darwin's src/network_cmds/ifconfig.tproj.
	// There's no pretty way to get media stuff; I've stripped it down to the essentials
	// for what I'm doing.
	
	NSAssert([interface cStringLength] < IFNAMSIZ, @"Interface name too long");
	
	int s = socket(AF_INET, SOCK_DGRAM, 0);
	NSAssert(s >= 0, @"Can't open datagram socket");
	struct ifmediareq ifmr;
	memset(&ifmr, 0, sizeof(ifmr));
	strncpy(ifmr.ifm_name, [interface cString], [interface cStringLength]);
	
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

- (void)sleep {
	currentActive = NO;
}

@end
