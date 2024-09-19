//
//  PFSkinEmulation.h
//  PerfectLibPFSkinEmulation
//
//  Created by Steven Chen on 2020/8/26.
//  Copyright © 2020 Perfect Corp. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN


@class PFSkinEmulation, PFSkinCareQualityCheck;

NS_SWIFT_NAME(SkinEmulationDelegate)
/**
This protocol provides information of the `PFSkinEmulation` object.
*/
@protocol PFSkinEmulationDelegate <NSObject>

@optional
/**
 This delegate method is called when getting the skinemulation quality result.
 
 @param skinEmulation  The `PFSkinEmulation` instance.
 @param checkedResult The quality check result.
 */
- (void)skinEmulation:(PFSkinEmulation *)skinEmulation checkedResult:(PFSkinCareQualityCheck *)checkedResult;

@end

NS_SWIFT_NAME(SkinEmulation)
/**
The class performs skin health analysis.

Initialize a `PFSkinEmulation` object with `+[PFSkinEmulation create:]`.
Use `-sendCameraBuffer:` to input camera frames. Receive quality check results from `PFSkinEmulationDelegate`. Set an image for skin emulation via `-[PFSkinEmulation setImage:completion:]`. Use `-[PFSkinEmulation getEmulationImage:completion:]` to get an image with emulation.

@note the kCVPixelBufferPixelFormatTypeKey must be specified as kCVPixelFormatType_420YpCbCr8BiPlanarFullRange when setting `AVCaptureVideoDataOutput.videoSettings`.
 
*/
@interface PFSkinEmulation : NSObject
/**
 Create a `PFSkinEmulation ` instance.
 
 @param completion A completion called when the init operation completes.
*/
+ (void)create:(void (^)(PFSkinEmulation * _Nullable skinEmulation, NSError * _Nullable error))completion;

/// An object implements `PFSkinEmulationDelegate` protocol for receiving the quality of preview sent by calling `-sendCameraBuffer:`.
@property (weak, nonatomic) id<PFSkinEmulationDelegate> delegate;
/// The available features(s) for skin emulation.
@property (nonatomic, readonly) NSArray <NSString *> *availableFeatures;

/**
 Set an image for skin emulation.

 @param image The image for skin emulation
 @param completion A completion called when the operation completes.
 @note The image must have face inside and it will emulation the largest face from detected result.
*/
- (void)setImage:(UIImage *)image completion:(void (^)(NSError * _Nullable error))completion;

/**
 Get an image with emulated result of the specified emulation(s).

 @param emulationValues  Specify the emulation and intensity value emulated.
 @param completion A completion called when the operation completes.
 @note The input features must called by `-setImage:completion:` before or it will failed to get the result image.

 Wrinkles Parameter key
 @"wrinkleForehead", wrinkleAroundEyes, wrinkleLowerFace"
 DarkCircle Parameter key
 @"darkCircle"
 Spot Removal Parameter key
 @"spot"
 Pore Removal Parameter key
 @"pore"
 Texture Removal Parameter key
 @"texture"
*/
- (void)getEmulationImage:(NSDictionary <NSString*, NSNumber*> *)emulationValues completion:(void (^)(UIImage* _Nullable image, NSError* _Nullable error))completion;

/**
 Send the external camera's frame sample buffer in order for the engine to process.

 @param sampleBuffer The sample buffer from external camera source.
 @note the kCVPixelBufferPixelFormatTypeKey must be specified as kCVPixelFormatType_420YpCbCr8BiPlanarFullRange when setting `AVCaptureVideoDataOutput.videoSettings`.
*/
- (void)sendCameraBuffer:(CMSampleBufferRef)sampleBuffer;
/**
A callback function to be called when external camera device is opened.

@Param isFront Specify if the camera position is front.
*/
- (void)onCameraOpen:(BOOL)isFront;

@end

NS_ASSUME_NONNULL_END
