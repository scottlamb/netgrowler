//
//  main.m
//  NetGrowler
//
//  Created by Scott Lamb on Fri Aug 27 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "NetGrowlerController.h"

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
