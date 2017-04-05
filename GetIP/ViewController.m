//
//  ViewController.m
//  GetIP
//
//  Created by tomfriwel on 05/04/2017.
//  Copyright © 2017 tomfriwel. All rights reserved.
//

#import "ViewController.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#import "ALNetwork.h"

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
//#define IOS_VPN       @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSLog(@"%@", [self getIPAddresses]);
    NSLog(@"%@", [self getIPAddress:YES]);
    NSLog(@"%@", [self getIPAddress:NO]);
    NSLog(@"%@", [self getIPAddress]);
    NSLog(@"externalIPAddress:%@", [ALNetwork externalIPAddress]);
}

//+ (NSString *)externalIPAddress {
//    // Check if we have an internet connection then try to get the External IP Address
//    if (![self connectedViaWiFi] && ![self connectedVia3G]) {
//        // Not connected to anything, return nil
//        return nil;
//    }
//    
//    // Get the external IP Address based on dynsns.org
//    NSError *error = nil;
//    NSString *theIpHtml = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.dyndns.org/cgi-bin/check_ip.cgi"]
//                                                   encoding:NSUTF8StringEncoding
//                                                      error:&error];
//    if (!error) {
//        NSUInteger  an_Integer;
//        NSArray *ipItemsArray;
//        NSString *externalIP;
//        NSScanner *theScanner;
//        NSString *text = nil;
//        
//        theScanner = [NSScanner scannerWithString:theIpHtml];
//        
//        while ([theScanner isAtEnd] == NO) {
//            
//            // find start of tag
//            [theScanner scanUpToString:@"<" intoString:NULL] ;
//            
//            // find end of tag
//            [theScanner scanUpToString:@">" intoString:&text] ;
//            
//            // replace the found tag with a space
//            //(you can filter multi-spaces out later if you wish)
//            theIpHtml = [theIpHtml stringByReplacingOccurrencesOfString:
//                         [ NSString stringWithFormat:@"%@>", text]
//                                                             withString:@" "] ;
//            ipItemsArray = [theIpHtml  componentsSeparatedByString:@" "];
//            an_Integer = [ipItemsArray indexOfObject:@"Address:"];
//            externalIP =[ipItemsArray objectAtIndex:++an_Integer];
//        }
//        // Check that you get something back
//        if (externalIP == nil || externalIP.length <= 0) {
//            // Error, no address found
//            return nil;
//        }
//        // Return External IP
//        return externalIP;
//    } else {
//        // Error, no address found
//        return nil;
//    }
//}

- (NSString *)getIPAddress {
    
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    
                }
                
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
    
}

- (NSString *)getIPAddress:(BOOL)preferIPv4
{
    NSArray *searchArray = preferIPv4 ?
    @[ /*IOS_VPN @"/" IP_ADDR_IPv4, IOS_VPN @"/" IP_ADDR_IPv6,*/ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ /*IOS_VPN @"/" IP_ADDR_IPv6, IOS_VPN @"/" IP_ADDR_IPv4,*/ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self getIPAddresses];
//    NSLog(@"addresses: %@", addresses);
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    return address ? address : @"0.0.0.0";
}

- (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}


@end
