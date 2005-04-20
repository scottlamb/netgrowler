/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>

@class SCDynamicStore;

@interface NullObserver : NSObject
{
	SCDynamicStore *dynStore;
}

- (id)initWithStore:(SCDynamicStore*)store;
@end
