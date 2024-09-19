//
//  PFSkinCare.h
//  PerfectLibSkinCare
//
//  Created by Steven Chen on 2020/8/26.
//  Copyright © 2020 Perfect Corp. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN


@class PFSkinCare, PFSkinCareQualityCheck, PFSkinAnalysisData, PFSkinTypeAnalysisData;

NS_SWIFT_NAME(SkinCareDelegate)
/**
This protocol provides information of the `PFSkinCare` object.
*/
@protocol PFSkinCareDelegate <NSObject>

@optional
/**
 This delegate method is called when getting the skincare check result.
 
 @param skinCare  The `PFSkinCare` instance.
 @param checkedResult The analysis check result.
 */
- (void)skinCare:(PFSkinCare *)skinCare checkedResult:(PFSkinCareQualityCheck *)checkedResult;

@end

NS_SWIFT_NAME(SkinCare)
/**
The class performs skin health analysis.

Initialize a `PFSkinCare` object with `+[PFSkinCare createWithModelPath:completion:]`.
The object created will not open camera device and rendering view, external camera source is required.
Use `-sendCameraBuffer:` to input camera frames. Receive quality check results from `PFSkinCareDelegate`. Set an image for skin analysis via `-[PFSkinCare setImage:completion:]`. Get reports and overall score via `-[PFSkinCare getReportsBySkinFeatures:completion:]` and `-[PFSkinCare getOverallScore]`. Use `-[PFSkinCare getAnalyzedImageBySkinFeatures:completion:]` to get an image with analysis report.

@note the kCVPixelBufferPixelFormatTypeKey must be specified as kCVPixelFormatType_420YpCbCr8BiPlanarFullRange when setting `AVCaptureVideoDataOutput.videoSettings`.
 
*/
@interface PFSkinCare : NSObject

/**
 Create a `PFSkinCare` instance.
 
 @param completion A completion called when the init operation completes.
*/
+ (void)create:(void (^)(PFSkinCare * _Nullable skinCare, NSError * _Nullable error))completion;

/**
 Create a `PFSkinCare` instance.
 
 @param path Specify the path of the model files. If the path is null then the model files are in APP's main bundle.
 @param completion A completion called when the init operation completes.
*/
+ (void)createWithModelPath:(NSString * _Nullable)path completion:(void (^)(PFSkinCare * _Nullable skinCare, NSError * _Nullable error))completion __deprecated_msg("Use `PFSkinCare.create` and set model path with `PerfectLibConfiguration.modelsPath`");

/// An object implements `PFSkinCareDelegate` protocol for receiving the quality of preview sent by calling `-sendCameraBuffer:`.
@property (weak, nonatomic) id<PFSkinCareDelegate> delegate;

/// The available feature(s) for skin analysis.
@property (nonatomic, readonly) NSArray <NSString *> *availableFeatures;
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
/**
 Set an image for skin analysis.

 @param image The image for skin analysis
 @param completion A completion called when the analysis operation completes.
 @note The image must have face inside and it will analysis the largest face from detected result.
*/
- (void)setImage:(UIImage *)image completion:(void (^)(NSError * _Nullable error))completion;
/**
 Get analyzed reports of the specified features.

 @param features  the features to be analyzed.
 @param completion A completion called when the analysis operation completes.
*/
- (void)getReportsBySkinFeatures:(NSArray <NSString *> *)features completion:(void (^)(NSArray <PFSkinAnalysisData *> *reports))completion NS_SWIFT_NAME(getReports(bySkinFeatures:completion:));

/**
 Get analyzed report of the skin types.

 @param completion A completion called when the analysis operation completes.
*/
- (void)getSkinTypes:(void (^)(NSArray <PFSkinTypeAnalysisData *> *reports))completion;

/**
 Get the overall score and the skin age. The overall score and skin age are calculated based on the scores of analyzed features. Use `-getReportsBySkinFeatures:completion:` to analyze features.

 @note The input features must called by `-getReportsBySkinFeatures:completion:` before or it will failed to get the overall score and skin age..
*/
- (void)getOverallScoreWithCompletion:(void (^)(int overallScore, int skinAge))completion;

/**
 Get an image with analyzed result of the specified features.

 @param features  Specify the features and their order to be drawn.
 @param completion A completion called when the operation completes.
 @note The input features must called by `-getReportsBySkinFeatures:completion:` before or it will failed to get the result image.
*/
- (void)getAnalyzedImageBySkinFeatures:(NSArray <NSString *> *)features completion:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completion;

/**
 Get an image with analyzed skin type result.

 @param completion A completion called when the operation completes.
 @note The input features must called by `-getSkinTypes:` before or it will failed to get the result image.
*/
- (void)getSkinTypeAnalyzedImage:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completion;

/**
 Unavailable. Use `+createWithModelPath:completion:` for `PFSkinCare` object initializing.
 */
- (id)init __attribute__((unavailable("Use +create")));

/**
 Unavailable. Use `+createWithModelPath:completion` for `PFSkinCare` object initializing.
 */
+ (instancetype)new __attribute__((unavailable("Use +create")));

@end

NS_ASSUME_NONNULL_END
