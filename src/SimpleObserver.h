/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import <Foundation/Foundation.h>

@interface SimpleObserver : NSObject
{
	id observer;
	SEL selector;
}

+ observer:(id)anObserver withSelector:(SEL)aSelector;
- (id)invokeWithObject:(id)object;

@end
