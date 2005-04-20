/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import "NetGrowlerController.h"
#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSApplication sharedApplication];
	
	NetGrowlerController *netGrowler = [[NetGrowlerController alloc] init];
	
	[NSApp setDelegate:netGrowler];
	[NSApp run];
	
	[netGrowler release];
	[NSApp release];
	[pool release];
	
	return EXIT_SUCCESS;
}
