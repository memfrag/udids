//
//  Copyright (c) 2013 Martin Johannesson
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//
//  (MIT License)
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

#define USB_VENDOR_ID_APPLE 0x05AC

#define USB_PRODUCT_ID_IPHONE_2G 0x1290
#define USB_PRODUCT_ID_IPHONE_3G 0x1292
#define USB_PRODUCT_ID_IPHONE_3GS 0x1294
#define USB_PRODUCT_ID_IPHONE_4 0x1297
#define USB_PRODUCT_ID_IPHONE_4_CDMA 0x129c
#define USB_PRODUCT_ID_IPHONE_4S 0x12A0
#define USB_PRODUCT_ID_IPHONE_5 0x12A8

#define USB_PRODUCT_ID_IPAD_1 0x129A
#define USB_PRODUCT_ID_IPAD_2_WIFI 0x129F
#define USB_PRODUCT_ID_IPAD_2_GSM 0x12A2
#define USB_PRODUCT_IPAD_2_CDMA	0x12A3
#define USB_PRODUCT_IPAD_2_R2 0x12A9
#define USB_PRODUCT_IPAD_3_WIFI 0x12A4
#define USB_PRODUCT_IPAD_3_CDMA 0x12A5
#define USB_PRODUCT_IPAD_3_GLOBAL 0x12A6
#define USB_PRODUCT_IPAD_MINI_WIFI 0x12AB

#define USB_PRODUCT_IPOD_TOUCH 0x1291
#define USB_PRODUCT_IPOD_TOUCH_2G 0x1293
#define USB_PRODUCT_IPOD_TOUCH_3G 0x1299
#define USB_PRODUCT_IPOD_TOUCH_4G 0x129E
#define USB_PRODUCT_IPOD_TOUCH_5G 0x12AA

static void getStringDescriptor(IOUSBDeviceInterface182 **deviceInterface,
                                uint8_t index,
                                io_name_t stringBuffer)
{
    io_name_t buffer;
    
    IOUSBDevRequest request = {
        .bmRequestType = USBmakebmRequestType(kUSBIn, kUSBStandard, kUSBDevice),
        .bRequest = kUSBRqGetDescriptor,
        .wValue = (kUSBStringDesc << 8) | index,
        .wIndex = 0x409,
        .wLength = sizeof(buffer),
        .pData = buffer
    };
    
    kern_return_t result;
    result = (*deviceInterface)->DeviceRequest(deviceInterface, &request);
    if (result != KERN_SUCCESS) {
        return;
    }
        
    uint32_t count = 0;
    for (uint32_t j = 2; j < request.wLenDone; j += 2) {
        stringBuffer[count++] = buffer[j];
    }
    stringBuffer[count] = '\0';
}

static void getUDID(io_service_t device, io_name_t udidBuffer)
{
    kern_return_t result;
    
    SInt32 score;
    IOCFPlugInInterface **plugin = NULL;
    result = IOCreatePlugInInterfaceForService(device,
                                               kIOUSBDeviceUserClientTypeID,
                                               kIOCFPlugInInterfaceID,
                                               &plugin,
                                               &score);
    if (result != KERN_SUCCESS) {
        return;
    }
    
    IOUSBDeviceInterface182 **deviceInterface = NULL;
    result = (*plugin)->QueryInterface(plugin,
                                CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID182),
                                (void **)&deviceInterface);
    if (result != KERN_SUCCESS) {
        IODestroyPlugInInterface(plugin);
        return;
    }
    IODestroyPlugInInterface(plugin);
    
    UInt8 index;
    (*deviceInterface)->USBGetSerialNumberStringIndex(deviceInterface, &index);
    getStringDescriptor(deviceInterface, index, udidBuffer);
}

static int intUSBProperty(io_service_t device, CFStringRef propertyName)
{
    CFNumberRef	number;
    number = (CFNumberRef)IORegistryEntryCreateCFProperty(device, propertyName,
                                                        kCFAllocatorDefault, 0);
    int value = 0;
    CFNumberGetValue(number, kCFNumberSInt32Type, &value);
    CFRelease(number);
    return value;
}

static const char *iOSModel(const char *deviceName, int vendorId, int productId)
{
    if (vendorId != USB_VENDOR_ID_APPLE) {
        return NULL;
    }
    
    switch (productId) {
        case USB_PRODUCT_ID_IPHONE_2G: return "iPhone 2G";
        case USB_PRODUCT_ID_IPHONE_3G: return "iPhone 3G";
        case USB_PRODUCT_ID_IPHONE_3GS: return "iPhone 3GS";
        case USB_PRODUCT_ID_IPHONE_4: return "iPhone 4";
        case USB_PRODUCT_ID_IPHONE_4_CDMA: return "iPhone 4 CDMA";
        case USB_PRODUCT_ID_IPHONE_4S: return "iPhone 4S";
        case USB_PRODUCT_ID_IPHONE_5: return "iPhone 5";
            
        case USB_PRODUCT_ID_IPAD_1: return "iPad 1";
        case USB_PRODUCT_ID_IPAD_2_WIFI: return "iPad 2 WiFi";
        case USB_PRODUCT_ID_IPAD_2_GSM: return "iPad 2 GSM";
        case USB_PRODUCT_IPAD_2_CDMA: return "iPad 2 CDMA";
        case USB_PRODUCT_IPAD_2_R2: return "iPad 2 R2";
        case USB_PRODUCT_IPAD_3_WIFI: return "iPad 3 WiFi";
        case USB_PRODUCT_IPAD_3_CDMA: return "iPad 3 CDMA";
        case USB_PRODUCT_IPAD_3_GLOBAL: return "iPad 3 Global";
        case USB_PRODUCT_IPAD_MINI_WIFI: return "iPad Mini WiFi";
            
        case USB_PRODUCT_IPOD_TOUCH: return "iPod Touch 1G";
        case USB_PRODUCT_IPOD_TOUCH_2G: return "iPod Touch 2G";
        case USB_PRODUCT_IPOD_TOUCH_3G: return "iPod Touch 3G";
        case USB_PRODUCT_IPOD_TOUCH_4G: return "iPod Touch 4G";
        case USB_PRODUCT_IPOD_TOUCH_5G: return "iPod Touch 5G";
    }
    
    if (!strcmp("iPhone", deviceName)) {
        return "iPhone (Unknown)";
    }
    
    if (!strcmp("iPad", deviceName)) {
        return "iPad (Unknown)";
    }
    
    return NULL;
}

static int listUDIDs(void)
{
    kern_return_t result;
    
    mach_port_t masterPort;
    result = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (result != KERN_SUCCESS) {
        fprintf(stderr, "ERROR: Unable to get master port.\n");
        return 1;
    }
    
    CFMutableDictionaryRef matching = IOServiceMatching(kIOUSBDeviceClassName);
    if (matching == NULL) {
        fprintf(stderr, "ERROR: Unable to create USB match pattern.\n");
        return 1;
    }
    
    io_iterator_t iterator = 0;
    result = IOServiceGetMatchingServices(masterPort, matching, &iterator);
    if (result != KERN_SUCCESS) {
        fprintf(stderr,  "ERROR: Unable to find USB devices.\n");
        return 1;
    }
    
    io_service_t device;
    while ((device = IOIteratorNext(iterator))) {
        int vendorId = intUSBProperty(device, CFSTR("idVendor"));
        int productId = intUSBProperty(device, CFSTR("idProduct"));        
        
        if (vendorId != USB_VENDOR_ID_APPLE) {
            continue;
        }

        io_name_t deviceName;
        if (IORegistryEntryGetName(device, deviceName) != KERN_SUCCESS) {
            continue;
        }
        
        const char *modelName = iOSModel(deviceName, vendorId, productId);
        if (modelName == NULL) {
            continue;
        }
        
        io_name_t udid = "<unknown>";
        getUDID(device, udid);
        
        printf("model=\"%s\" udid=%s\n", modelName, udid);
    
        IOObjectRelease(device);
    }
    
    return 0;
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return listUDIDs();
    }
}
