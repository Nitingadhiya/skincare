//
//  SkinCareData3.h
//  PerfectLib
//
//  Created by PX Chen on 2020/6/29.
//  Copyright © 2020 Perfect Corp. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __has_include(<PerfectLibCore/PerfectLibCore.h>)
#import <PerfectLibCore/PerfectLibCore.h>
#elif __has_include(<PerfectLibSlimCore/PerfectLibSlimCore.h>)
#import <PerfectLibSlimCore/PerfectLibSlimCore.h>
#endif


NS_ASSUME_NONNULL_BEGIN

/**
 The different types of skin type.
 */
typedef NS_ENUM(NSUInteger, PFSkinType){
    PFSkinTypeUnknown,
    PFSkinTypeNormal,
    PFSkinTypeDry,
    PFSkinTypeOily,
    PFSkinTypeCombination,
    PFSkinTypeNormalAndSensitive,
    PFSkinTypeDryAndSensitive,
    PFSkinTypeOilyAndSensitive,
    PFSkinTypeCombinationAndSensitive,
};

/**
 The skin analyzed result.
*/
@interface PFSkinAnalysisData : NSObject
/**
 The score of specific skin feature.
*/
@property (nonatomic, readonly) int score;
/**
 The skin feature.
*/
@property (nonatomic, readonly) NSString *feature;

@end

/**
 The skin type analyzed result.
*/
@interface PFSkinTypeAnalysisData : NSObject

/**
 The skin type name of the feature.
 @note feature has  one of the following string value (FullFace, T-Zone, U-Zone)
*/
@property (nonatomic, readonly) NSString *feature;
/**
 The skin type of specific feature.
*/
@property (nonatomic, readonly) PFSkinType skinType;

@end

/**
 The results of skin analysis.
 */
@interface PFSkinCareQualityCheck : NSObject
/**
 The lighting quality
 */
//@property (nonatomic, readonly) PFLightingQuality2 lightingQuality;
/**
 The face position quality
 */
//@property (nonatomic, readonly) PFFaceAreaQuality faceAreaQuality;
/**
 The frontal face position quality
*/
//@property (nonatomic, readonly) PFFaceFrontalQuality faceFrontalQuality;
/**
 The frontal face position degree
*/
@property (nonatomic, readonly) float facePoseDegree;

/**
 Indicating if the information is valid
 */
@property (nonatomic, readonly) BOOL isValid;


@end

NS_ASSUME_NONNULL_END
