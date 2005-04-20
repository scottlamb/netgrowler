/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>

@class SCDynamicStore, NSImage;

/**
 * Watches for changes on a PPP interface.
 * I've only tested with a PPTP VPN (Virtual Private Network).
 */
@interface PPPObserver : NSObject
{
	NSString *service;
	SCDynamicStore *dynStore;
	NSDictionary *currentStatus;
	NSImage *ipIcon;
}

- (id)initWithService:(NSString*)service andStore:(SCDynamicStore*)store;
- (void)sleep;
@end
