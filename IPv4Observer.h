/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>

@class SCDynamicStore, NSImage;

@interface IPv4Observer : NSObject
{
	SCDynamicStore *dynStore;
	NSImage *ipIcon;
}

- (id)initWithStore:(SCDynamicStore*)store;
@end
