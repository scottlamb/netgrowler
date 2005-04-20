/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

// Type of address stuff
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>

// Everything else
#import "IPv4Observer.h"
#import "SCDynamicStore.h"
#import "NetGrowlerController.h"

#define IP_APP_NAME                    @"Internet Connect.app"

@interface IPv4Observer (PRIVATE)
- (void)statusChange:(NSString*)keyName;
- (NSString*)typeOfIP:(NSString*)ip;
@end

@implementation IPv4Observer

- (id)initWithStore:(SCDynamicStore*)aDynStore {
	self = [super init];

	if (self) {
		NSLog(@"Initializing IPv4Observer");
		dynStore = [aDynStore retain];

		[dynStore addObserver:self
					 selector:@selector(statusChange:)
					   forKey:@"State:/Network/Global/IPv4"];		

		NSString *path = [[NSWorkspace sharedWorkspace] fullPathForApplication:IP_APP_NAME];
		ipIcon = [[[NSWorkspace sharedWorkspace] iconForFile:path] retain];
	}

	return self;
}

- (void)dealloc {
	// XXX: should remove observer
	[dynStore release];
	[ipIcon release];
}

- (void)statusChange:(NSString*)keyName
{
	NSDictionary *newValue = [dynStore valueForKey:keyName];
	if (newValue == nil) {
		//NSLog(@"IP address released");
		[GrowlApplicationBridge notifyWithTitle:@"IP address released"
									description:[NSString stringWithFormat:@"No IP address now"]
							   notificationName:NOTE_IP_RELEASED
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	} else {
		//NSLog(@"IP address acquired");
		NSString *ipv4Key = [NSString stringWithFormat:@"State:/Network/Interface/%@/IPv4",
			[newValue valueForKey:@"PrimaryInterface"]];
		NSDictionary *ipv4Info = [dynStore valueForKey:ipv4Key];
		NSArray *addrs = [ipv4Info valueForKey:@"Addresses"];
		NSAssert([addrs count] > 0, @"Empty address array");
		NSString *primaryIP = [addrs objectAtIndex:0];
		[GrowlApplicationBridge notifyWithTitle:@"IP address changed"
									description:[NSString stringWithFormat:@"New primary IP.\nType:\t%@\nAddress:\t%@", [self typeOfIP:primaryIP], primaryIP]
							   notificationName:NOTE_IP_ACQUIRED
									   iconData:[ipIcon TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	}
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

@end
