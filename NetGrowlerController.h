//
//  NetGrowlerController.h
//  NetGrowler
//
//  Created by Scott Lamb on Fri Aug 27 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IXSCNotificationManager.h"

typedef enum {
	S_GROWL_NO_LAUNCH,
	S_GROWL_LAUNCHING,
	S_GROWL_LAUNCHED
} State;

@interface NetGrowlerController : NSObject {
	State state;
	IXSCNotificationManager *scNotificationManager;
}

@end
