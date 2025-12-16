#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "icon-ac" asset catalog image resource.
static NSString * const ACImageNameIconAc AC_SWIFT_PRIVATE = @"icon-ac";

/// The "icon-back" asset catalog image resource.
static NSString * const ACImageNameIconBack AC_SWIFT_PRIVATE = @"icon-back";

/// The "icon-calculator" asset catalog image resource.
static NSString * const ACImageNameIconCalculator AC_SWIFT_PRIVATE = @"icon-calculator";

/// The "icon-divide" asset catalog image resource.
static NSString * const ACImageNameIconDivide AC_SWIFT_PRIVATE = @"icon-divide";

/// The "icon-equal" asset catalog image resource.
static NSString * const ACImageNameIconEqual AC_SWIFT_PRIVATE = @"icon-equal";

/// The "icon-menu" asset catalog image resource.
static NSString * const ACImageNameIconMenu AC_SWIFT_PRIVATE = @"icon-menu";

/// The "icon-minus" asset catalog image resource.
static NSString * const ACImageNameIconMinus AC_SWIFT_PRIVATE = @"icon-minus";

/// The "icon-multiply" asset catalog image resource.
static NSString * const ACImageNameIconMultiply AC_SWIFT_PRIVATE = @"icon-multiply";

/// The "icon-percent" asset catalog image resource.
static NSString * const ACImageNameIconPercent AC_SWIFT_PRIVATE = @"icon-percent";

/// The "icon-plus" asset catalog image resource.
static NSString * const ACImageNameIconPlus AC_SWIFT_PRIVATE = @"icon-plus";

/// The "icon-plusminus" asset catalog image resource.
static NSString * const ACImageNameIconPlusminus AC_SWIFT_PRIVATE = @"icon-plusminus";

#undef AC_SWIFT_PRIVATE
