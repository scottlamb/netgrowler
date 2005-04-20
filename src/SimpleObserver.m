/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import "SimpleObserver.h"

@implementation SimpleObserver

+ observer:(id)anObserver withSelector:(SEL)aSelector {
	SimpleObserver *o = [[SimpleObserver alloc] init];
	o->observer = anObserver;
	o->selector = aSelector;
	return [o autorelease];
}

- (id)invokeWithObject:(id)object {
	return [observer performSelector:selector
						  withObject:object];
}

@end
