/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

// Media stuff
#import <sys/socket.h>
#import <sys/sockio.h>
#import <sys/ioctl.h>
#import <net/if.h>
#import <net/if_media.h>
#import <unistd.h>

// Other includes
#import "EthernetObserver.h"
#import "SCDynamicStore.h"
#import "NetGrowlerController.h"

#define IP_APP_NAME                    @"Internet Connect.app"

static struct ifmedia_description ifm_subtype_ethernet_descriptions[] = IFM_SUBTYPE_ETHERNET_DESCRIPTIONS;
static struct ifmedia_description ifm_shared_option_descriptions[] = IFM_SHARED_OPTION_DESCRIPTIONS;

@interface EthernetObserver (PRIVATE)
- (void)linkStatusChange:(NSString*)keyName;
- (NSString*)media;
@end

@implementation EthernetObserver

- (id)initWithInterface:(NSString*)anInterface andStore:(SCDynamicStore*)aDynStore {
	self = [super init];

	if (self) {
		NSString *path = [[NSWorkspace sharedWorkspace] fullPathForApplication:IP_APP_NAME];
		ipIcon = [[[NSWorkspace sharedWorkspace] iconForFile:path] retain];

		interface = [anInterface retain];
		NSLog(@"Initializing EthernetObserver for interface %@", interface);
		dynStore = [aDynStore retain];
		[dynStore addObserver:self
					 selector:@selector(linkStatusChange:)
					   forKey:@"State:/Network/Interface/en0/Link"];		
	}

	return self;
}

- (void)dealloc {
	// XXX: should remove observer
	[dynStore release];
	[interface release];
	[ipIcon release];
}

- (void)linkStatusChange:(NSString*)keyName
{
	NSDictionary *newValue = [dynStore valueForKey:keyName];
	Boolean active = CFBooleanGetValue((CFBooleanRef) [newValue objectForKey:@"Active"]);
	
	if (active) {
		NSString *media = [self media];
		[GrowlApplicationBridge notifyWithTitle:@"Ethernet activated"
									description:[NSString stringWithFormat:@"Interface:\ten0\nMedia:\t%@", media]
							   notificationName:NOTE_LINK_UP
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	} else {
		[GrowlApplicationBridge notifyWithTitle:@"Ethernet deactivated"
									description:[NSString stringWithFormat:@"Interface:\ten0"]
							   notificationName:NOTE_LINK_DOWN
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	}		
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

@end
