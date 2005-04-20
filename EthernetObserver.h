/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>

@class SCDynamicStore, NSImage;

@interface EthernetObserver : NSObject
{
	SCDynamicStore *dynStore;
	NSString *interface;
	NSImage *ipIcon;
}

- (id)initWithInterface:(NSString*)interface andStore:(SCDynamicStore*)store;
@end
