/*
 * Written by Theo Hultberg (theo@iconara.net) 2004-03-09 with help from Boaz Stuller.
 * This code is in the public domain, provided that this notice remains.
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>


/*!
 * @class          IXSCNotificationManager
 * @abstract       Listens for changes in the system configuration database
 *                 and posts the changes to the default notification center.
 * @discussion     To get notifications when the key "State:/Network/Global/IPv4"
 *                 changes, register yourself as an observer for notifications
 *                 with the name "State:/Network/Global/IPv4".
 *                 If you want to recieve notifications on any change in the
 *                 system configuration databse, register for notifications
 *                 on the IXSCNotificationManager object.
 *                 The user info in the notification is the data in the database
 *                 for the key you listen for.
 */
@interface IXSCNotificationManager : NSObject {
	SCDynamicStoreRef dynStore;
	CFRunLoopSourceRef rlSrc;
	
	// Dictionary of watched key names (NSString) to observers (internal Observer class)
	NSMutableDictionary *watchedKeysDict;
}

- (NSDictionary*)getValueForKey:(NSString*)aKey;
- (void)addObserver:(id)anObserver selector:(SEL)aSelector forKey:(NSString*)aKey;

@end

@interface SLObserver : NSObject
{
	id observer;
	SEL selector;
}

+ observer:(id)anObserver withSelector:(SEL)aSelector;

@end