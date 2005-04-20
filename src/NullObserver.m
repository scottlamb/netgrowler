/*
 * $Id$
 *
 * Copyright (C) 2004-2005 Scott Lamb <slamb@slamb.org>.
 * This file is part of NetGrowler, which is released under the MIT license.
 */

#import "NullObserver.h"
#import "SCDynamicStore.h"
#import "NetGrowlerController.h"

@interface NullObserver (PRIVATE)
- (void)someKeyChange:(NSString*)keyName;
@end

@implementation NullObserver

- (id)initWithStore:(SCDynamicStore*)aDynStore {
	self = [super init];

	if (self) {
		NSLog(@"Initializing NullObserver");
		dynStore = [aDynStore retain];
	}

	return self;
}

- (void)dealloc {
	// XXX: should remove observer
	[dynStore release];
}

- (void)someKeyChange:(NSString*)keyName {
	NSDictionary *newStatus = [dynStore valueForKey:keyName];
}

@end
