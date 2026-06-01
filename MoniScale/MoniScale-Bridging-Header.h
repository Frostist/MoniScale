//  MoniScale
//  Private CGS display APIs
//
//  MoniScale-Bridging-Header.h
//  MoniScale
//
//  Created by Will Frost on 2026/05/31.
//


#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

extern CFDictionaryRef CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID);

// CGVirtualDisplay private API

@interface CGVirtualDisplay : NSObject
@property(readonly, nonatomic) unsigned int displayID;
- (BOOL)applySettings:(id)arg1;
- (id)initWithDescriptor:(id)arg1;
@end

@interface CGVirtualDisplayDescriptor : NSObject
@property(retain, nonatomic) id queue;
@property(copy, nonatomic) id terminationHandler;
@property(retain, nonatomic) NSString *name;
@property(nonatomic) struct CGPoint whitePoint;
@property(nonatomic) struct CGPoint bluePrimary;
@property(nonatomic) struct CGPoint greenPrimary;
@property(nonatomic) struct CGPoint redPrimary;
@property(nonatomic) unsigned int maxPixelsHigh;
@property(nonatomic) unsigned int maxPixelsWide;
@property(nonatomic) struct CGSize sizeInMillimeters;
@property(nonatomic) unsigned int serialNum;
@property(nonatomic) unsigned int productID;
@property(nonatomic) unsigned int vendorID;
- (id)init;
@end

@interface CGVirtualDisplayMode : NSObject
@property(readonly, nonatomic) double refreshRate;
@property(readonly, nonatomic) unsigned int height;
@property(readonly, nonatomic) unsigned int width;
- (id)initWithWidth:(unsigned int)arg1 height:(unsigned int)arg2 refreshRate:(double)arg3;
@end

@interface CGVirtualDisplaySettings : NSObject
@property(nonatomic) unsigned int hiDPI;
@property(retain, nonatomic) NSArray *modes;
- (id)init;
@end

typedef struct {
    uint32_t modeNumber;
    uint32_t flags;
    uint32_t width;
    uint32_t height;
    uint32_t depth;
    uint8_t  unknown[170];
    uint16_t freq;
    uint8_t  more_unknown[16];
    float    density;
} CGSDisplayMode;

void CGSGetCurrentDisplayMode(CGDirectDisplayID display, int* modeNum);
void CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int* nModes);
void CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx, CGSDisplayMode* mode, int length);
void CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);
