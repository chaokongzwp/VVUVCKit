
#import "UVCController.h"
#import "UVCUIController.h"
#import "UVCUtils.h"


static NSMutableDictionary<NSString *, NSNumber *> *uvcParamsCache = nil;


//#define NSXLogParam(n,p) NSXLog(@"%@, (%ld)-[%ld]-(%ld), %ld",n,p.min,p.val,p.max,p.def)
#define NSXLogParam(n,p)	{														\
	if (p.supported)	{														\
		if (p.ctrlInfo->isRelative)											\
			NSXLog(@"%@, supported but relative!",n);							\
		else																	\
			NSXLog(@"%@, (%ld)-[%ld]-(%ld), %ld",n,p.min,p.val,p.max,p.def);		\
	}																			\
	else	{																	\
		NSXLog(@"%@ is unsupported",n);											\
	}																			\
}

/*		these values are used to signify whether the uvc_control_info struct affects a hardware parameter (like focus), 
which is one block of "function calls", or whether it affects a software parameter (like brightness), which is in another 
block of "function calls".  one block is the "input terminal", the other block is the "processing unit".  the actual 
addresses of these "blocks" is different from camera to camera ("inputTerminalID" and "processingUnitID" vars in 
VVUVCControl class contain the actual per-camera addresses of these blocks)- these defines just indicate which var to use!		*/
#define UVC_INPUT_TERMINAL_ID 0x01
#define UVC_PROCESSING_UNIT_ID 0x02		//	other cams i've used so far

/*	IMPORTANT: ALL THESE DEFINES WERE TAKEN FROM THE USB SPECIFICATION:
	http://www.usb.org/developers/docs/devclass_docs/USB_Video_Class_1_1_090711.zip			*/
#define UVC_CONTROL_INTERFACE_CLASS 0x0E
#define UVC_CONTROL_INTERFACE_SUBCLASS 0x01

//	video class-specific request codes
#define UVC_SET_CUR	0x01
#define UVC_GET_CUR	0x81
#define UVC_GET_MIN	0x82
#define UVC_GET_MAX	0x83
#define UVC_GET_RES 0x84
#define UVC_GET_LEN 0x85
#define UVC_GET_INFO 0x86
#define UVC_GET_DEF 0x87

#define UVCSetParamToLocal(key, value) [uvcParamsCache setObject:@(value) forKey:key]
#define UVCGetParamFromLocal(key) [[uvcParamsCache objectForKey:key] intValue]

//	camera terminal control selectors
typedef enum	{
	UVC_CT_CONTROL_UNDEFINED = 0x00,
	UVC_CT_SCANNING_MODE_CONTROL = 0x01,
	UVC_CT_AE_MODE_CONTROL = 0x02,
	UVC_CT_AE_PRIORITY_CONTROL = 0x03,
	UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL = 0x04,
	UVC_CT_EXPOSURE_TIME_RELATIVE_CONTROL = 0x05,
	UVC_CT_FOCUS_ABSOLUTE_CONTROL = 0x06,
	UVC_CT_FOCUS_RELATIVE_CONTROL = 0x07,
	UVC_CT_FOCUS_AUTO_CONTROL = 0x08,
	UVC_CT_IRIS_ABSOLUTE_CONTROL = 0x09,
	UVC_CT_IRIS_RELATIVE_CONTROL = 0x0A,
	UVC_CT_ZOOM_ABSOLUTE_CONTROL = 0x0B,
	UVC_CT_ZOOM_RELATIVE_CONTROL = 0x0C,
	UVC_CT_PANTILT_ABSOLUTE_CONTROL = 0x0D,
	UVC_CT_PANTILT_RELATIVE_CONTROL = 0x0E,
	UVC_CT_ROLL_ABSOLUTE_CONTROL = 0x0F,
	UVC_CT_ROLL_RELATIVE_CONTROL = 0x10
} UVC_CT_t;

//	UVC processing unit control selectors
typedef enum	{
	UVC_PU_CONTROL_UNDEFINED = 0x00,
	UVC_PU_BACKLIGHT_COMPENSATION_CONTROL = 0x01,
	UVC_PU_BRIGHTNESS_CONTROL = 0x02,
	UVC_PU_CONTRAST_CONTROL = 0x03,
	UVC_PU_GAIN_CONTROL = 0x04,
	UVC_PU_POWER_LINE_FREQUENCY_CONTROL = 0x05,
	UVC_PU_HUE_CONTROL = 0x06,
	UVC_PU_SATURATION_CONTROL = 0x07,
	UVC_PU_SHARPNESS_CONTROL = 0x08,
	UVC_PU_GAMMA_CONTROL = 0x09,
	UVC_PU_WHITE_BALANCE_TEMPERATURE_CONTROL = 0x0A,
	UVC_PU_WHITE_BALANCE_TEMPERATURE_AUTO_CONTROL = 0x0B,
	UVC_PU_WHITE_BALANCE_COMPONENT_CONTROL = 0x0C,
	UVC_PU_WHITE_BALANCE_COMPONENT_AUTO_CONTROL = 0x0D,
	UVC_PU_DIGITAL_MULTIPLIER_CONTROL = 0x0E,
	UVC_PU_DIGITAL_MULTIPLIER_LIMIT_CONTROL = 0x0F,
	UVC_PU_HUE_AUTO_CONTROL = 0x10,
	UVC_PU_ANALOG_VIDEO_STANDARD_CONTROL = 0x11,
	UVC_PU_ANALOG_LOCK_STATUS_CONTROL = 0x12
} UVC_PU_t;

typedef enum : NSUInteger {
	UVC_XU_CONTROL_CHINGAN_EXTENSION = 0x09,
    UVC_XU_FLIP_HORIZONTAL_VERTICAL_EXTENSION = 0x0A,
} UVC_XU_t;

uvc_control_info_t	_scanCtrl;
uvc_control_info_t	_autoExposureModeCtrl;
uvc_control_info_t	_autoExposurePriorityCtrl;
uvc_control_info_t	_exposureTimeCtrl;
uvc_control_info_t	_irisCtrl;
uvc_control_info_t	_autoFocusCtrl;
uvc_control_info_t	_focusCtrl;
uvc_control_info_t	_zoomCtrl;
uvc_control_info_t	_panTiltCtrl;
uvc_control_info_t	_panTiltRelCtrl;
uvc_control_info_t	_rollCtrl;
uvc_control_info_t	_rollRelCtrl;

uvc_control_info_t	_backlightCtrl;
uvc_control_info_t	_brightCtrl;
uvc_control_info_t	_contrastCtrl;
uvc_control_info_t	_gainCtrl;
uvc_control_info_t	_powerLineCtrl;
uvc_control_info_t	_autoHueCtrl;
uvc_control_info_t	_hueCtrl;
uvc_control_info_t	_saturationCtrl;
uvc_control_info_t	_sharpnessCtrl;
uvc_control_info_t	_gammaCtrl;
uvc_control_info_t	_whiteBalanceAutoTempCtrl;
uvc_control_info_t	_whiteBalanceTempCtrl;
uvc_control_info_t  _extensionFlipSettingCtrl;

@implementation UVCController
+ (void) load	{
	_scanCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_scanCtrl.selector = UVC_CT_SCANNING_MODE_CONTROL;
	_scanCtrl.intendedSize = 1;
	_scanCtrl.hasMin = NO;
	_scanCtrl.hasMax = NO;
	_scanCtrl.hasDef = NO;
	_scanCtrl.isSigned = NO;
	_scanCtrl.isRelative = NO;
	_autoExposureModeCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_autoExposureModeCtrl.selector = UVC_CT_AE_MODE_CONTROL;
	_autoExposureModeCtrl.intendedSize = 1;
	_autoExposureModeCtrl.hasMin = NO;
	_autoExposureModeCtrl.hasMax = NO;
	_autoExposureModeCtrl.hasDef = YES;
	_autoExposureModeCtrl.isSigned = NO;
	_autoExposureModeCtrl.isRelative = NO;
	_autoExposurePriorityCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_autoExposurePriorityCtrl.selector = UVC_CT_AE_PRIORITY_CONTROL;
	_autoExposurePriorityCtrl.intendedSize = 1;
	_autoExposurePriorityCtrl.hasMin = NO;
	_autoExposurePriorityCtrl.hasMax = NO;
	_autoExposurePriorityCtrl.hasDef = NO;
	_autoExposurePriorityCtrl.isSigned = NO;
	_autoExposurePriorityCtrl.isRelative = NO;
	_exposureTimeCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_exposureTimeCtrl.selector = UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL;
	_exposureTimeCtrl.intendedSize = 4;
	_exposureTimeCtrl.hasMin = YES;
	_exposureTimeCtrl.hasMax = YES;
	_exposureTimeCtrl.hasDef = YES;
	_exposureTimeCtrl.isSigned = NO;
	_exposureTimeCtrl.isRelative = NO;
	_irisCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_irisCtrl.selector = UVC_CT_IRIS_ABSOLUTE_CONTROL;
	_irisCtrl.intendedSize = 2;
	_irisCtrl.hasMin = YES;
	_irisCtrl.hasMax = YES;
	_irisCtrl.hasDef = YES;
	_irisCtrl.isSigned = NO;
	_irisCtrl.isRelative = NO;
	_autoFocusCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_autoFocusCtrl.selector = UVC_CT_FOCUS_AUTO_CONTROL;
	_autoFocusCtrl.intendedSize = 1;
	_autoFocusCtrl.hasMin = NO;
	_autoFocusCtrl.hasMax = NO;
	_autoFocusCtrl.hasDef = YES;
	_autoFocusCtrl.isSigned = NO;
	_autoFocusCtrl.isRelative = NO;
	_focusCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_focusCtrl.selector = UVC_CT_FOCUS_ABSOLUTE_CONTROL;
	_focusCtrl.intendedSize = 2;
	_focusCtrl.hasMin = YES;
	_focusCtrl.hasMax = YES;
	_focusCtrl.hasDef = YES;
	_focusCtrl.isSigned = NO;
	_focusCtrl.isRelative = NO;
	_zoomCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_zoomCtrl.selector = UVC_CT_ZOOM_ABSOLUTE_CONTROL;
	_zoomCtrl.intendedSize = 2;
	_zoomCtrl.hasMin = YES;
	_zoomCtrl.hasMax = YES;
	_zoomCtrl.hasDef = YES;
	_zoomCtrl.isSigned = NO;
	_zoomCtrl.isRelative = NO;
	_panTiltCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_panTiltCtrl.selector = UVC_CT_PANTILT_ABSOLUTE_CONTROL;
	_panTiltCtrl.intendedSize = 8;
	_panTiltCtrl.hasMin = YES;
	_panTiltCtrl.hasMax = YES;
	_panTiltCtrl.hasDef = YES;
	_panTiltCtrl.isSigned = YES;
	_panTiltCtrl.isRelative = NO;
	_panTiltRelCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_panTiltRelCtrl.selector = UVC_CT_PANTILT_RELATIVE_CONTROL;
	_panTiltRelCtrl.intendedSize = 4;
	_panTiltRelCtrl.hasMin = YES;
	_panTiltRelCtrl.hasMax = YES;
	_panTiltRelCtrl.hasDef = YES;
	_panTiltRelCtrl.isSigned = YES;
	_panTiltRelCtrl.isRelative = YES;
	_rollCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_rollCtrl.selector = UVC_CT_ROLL_ABSOLUTE_CONTROL;
	_rollCtrl.intendedSize = 2;
	_rollCtrl.hasMin = YES;
	_rollCtrl.hasMax = YES;
	_rollCtrl.hasDef = YES;
	_rollCtrl.isSigned = YES;
	_rollCtrl.isRelative = NO;
	_rollRelCtrl.unit = UVC_INPUT_TERMINAL_ID;
	_rollRelCtrl.selector = UVC_CT_ROLL_RELATIVE_CONTROL;
	_rollRelCtrl.intendedSize = 1;
	_rollRelCtrl.hasMin = YES;
	_rollRelCtrl.hasMax = YES;
	_rollRelCtrl.hasDef = YES;
	_rollRelCtrl.isSigned = YES;
	_rollRelCtrl.isRelative = YES;
	
	_backlightCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_backlightCtrl.selector = UVC_PU_BACKLIGHT_COMPENSATION_CONTROL;
	_backlightCtrl.intendedSize = 2;
	_backlightCtrl.hasMin = YES;
	_backlightCtrl.hasMax = YES;
	_backlightCtrl.hasDef = YES;
	_backlightCtrl.isSigned = NO;
	_backlightCtrl.isRelative = NO;
	_brightCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_brightCtrl.selector = UVC_PU_BRIGHTNESS_CONTROL;
	_brightCtrl.intendedSize = 2;
	_brightCtrl.hasMin = YES;
	_brightCtrl.hasMax = YES;
	_brightCtrl.hasDef = YES;
	_brightCtrl.isSigned = YES;
	_brightCtrl.isRelative = NO;
	_contrastCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_contrastCtrl.selector = UVC_PU_CONTRAST_CONTROL;
	_contrastCtrl.intendedSize = 2;
	_contrastCtrl.hasMin = YES;
	_contrastCtrl.hasMax = YES;
	_contrastCtrl.hasDef = YES;
	_contrastCtrl.isSigned = NO;
	_contrastCtrl.isRelative = NO;
	_gainCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_gainCtrl.selector = UVC_PU_GAIN_CONTROL;
	_gainCtrl.intendedSize = 2;
	_gainCtrl.hasMin = YES;
	_gainCtrl.hasMax = YES;
	_gainCtrl.hasDef = YES;
	_gainCtrl.isSigned = NO;
	_gainCtrl.isRelative = NO;
	_powerLineCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_powerLineCtrl.selector = UVC_PU_POWER_LINE_FREQUENCY_CONTROL;
	_powerLineCtrl.intendedSize = 1;
	_powerLineCtrl.hasMin = YES;
	_powerLineCtrl.hasMax = YES;
	_powerLineCtrl.hasDef = YES;
	_powerLineCtrl.isSigned = NO;
	_powerLineCtrl.isRelative = NO;
	_autoHueCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_autoHueCtrl.selector = UVC_PU_HUE_AUTO_CONTROL;
	_autoHueCtrl.intendedSize = 2;
	_autoHueCtrl.hasMin = NO;
	_autoHueCtrl.hasMax = NO;
	_autoHueCtrl.hasDef = YES;
	_autoHueCtrl.isSigned = NO;
	_autoHueCtrl.isRelative = NO;
	_hueCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_hueCtrl.selector = UVC_PU_HUE_CONTROL;
	_hueCtrl.intendedSize = 2;
	_hueCtrl.hasMin = YES;
	_hueCtrl.hasMax = YES;
	_hueCtrl.hasDef = YES;
	_hueCtrl.isSigned = YES;
	_hueCtrl.isRelative = NO;
	_saturationCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_saturationCtrl.selector = UVC_PU_SATURATION_CONTROL;
	_saturationCtrl.intendedSize = 2;
	_saturationCtrl.hasMin = YES;
	_saturationCtrl.hasMax = YES;
	_saturationCtrl.hasDef = YES;
	_saturationCtrl.isSigned = NO;
	_saturationCtrl.isRelative = NO;
	_sharpnessCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_sharpnessCtrl.selector = UVC_PU_SHARPNESS_CONTROL;
	_sharpnessCtrl.intendedSize = 2;
	_sharpnessCtrl.hasMin = YES;
	_sharpnessCtrl.hasMax = YES;
	_sharpnessCtrl.hasDef = YES;
	_sharpnessCtrl.isSigned = NO;
	_sharpnessCtrl.isRelative = NO;
	_gammaCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_gammaCtrl.selector = UVC_PU_GAMMA_CONTROL;
	_gammaCtrl.intendedSize = 2;
	_gammaCtrl.hasMin = YES;
	_gammaCtrl.hasMax = YES;
	_gammaCtrl.hasDef = YES;
	_gammaCtrl.isSigned = NO;
	_gammaCtrl.isRelative = NO;
	_whiteBalanceAutoTempCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_whiteBalanceAutoTempCtrl.selector = UVC_PU_WHITE_BALANCE_TEMPERATURE_AUTO_CONTROL;
	_whiteBalanceAutoTempCtrl.intendedSize = 1;
	_whiteBalanceAutoTempCtrl.hasMin = NO;
	_whiteBalanceAutoTempCtrl.hasMax = NO;
	_whiteBalanceAutoTempCtrl.hasDef = YES;
	_whiteBalanceAutoTempCtrl.isSigned = NO;
	_whiteBalanceAutoTempCtrl.isRelative = NO;
	_whiteBalanceTempCtrl.unit = UVC_PROCESSING_UNIT_ID;
	_whiteBalanceTempCtrl.selector = UVC_PU_WHITE_BALANCE_TEMPERATURE_CONTROL;
	_whiteBalanceTempCtrl.intendedSize = 4;			//	WARNING: the spec says this should only have a length of "2", but it throws errors unless i use a length of 4!
	_whiteBalanceTempCtrl.hasMin = YES;
	_whiteBalanceTempCtrl.hasMax = YES;
	_whiteBalanceTempCtrl.hasDef = YES;
	_whiteBalanceTempCtrl.isSigned = NO;
	_whiteBalanceTempCtrl.isRelative = NO;
}


/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/
- (id) initWithDeviceIDString:(NSString *)n	{
	if (n != nil)	{
		NSUInteger locationID = 0;
        sscanf([n UTF8String], "0x%16lx",&locationID);
		if (locationID){
			return [self initWithLocationID:locationID];
		}
	}

	return nil;
}

NSString *dictionaryToJSON(NSDictionary *eventAsDictionary) {
  NSError *error = nil;

  if (eventAsDictionary == nil) {
    return nil;
  }

  if (![NSJSONSerialization isValidJSONObject:eventAsDictionary]) {
    return nil;
  }

  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:eventAsDictionary
                                                     options:0
                                                       error:&error];

  if (error == nil) {
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return json;
  } else {
    return nil;
  }
}

- (NSMutableArray<NSString *> *)getVideoName {
    return videoName;
}

- (id) initWithLocationID:(NSUInteger)locationID {
	NSXLog(@"initWithLocationID %lu, 0x%x", locationID, locationID);
	self = [super init];
	if (self!=nil) {
		//	technically i don't need to set these here- they're calculated below from the BusProber, but default values are good, m'kay?
		inputTerminalID = 1;
		processingUnitID = 2;	//	logitech C910
		deviceLocationID = locationID >> 32;
		interface = NULL;
		videoName = [NSMutableArray array];

		//	first of all, i need to harvest a couple pieces of data from the USB device- i need:
		//		- the "Terminal ID" of the "VDC ((Control) Input Terminal" of the "Video/Control" interface in the "Configuration Descriptor"
		//		- the "Unit ID" of the "VDC ((Control) Processing Unit" of the "Video/Control" interface in the "Configuration Descriptor"
		BusProber		*prober = [[BusProber alloc] init];
		NSMutableArray	*devices = [prober devicesArray];
		for (BusProbeDevice *devicePtr in devices)	{
            NSXLog(@"device deviceName %@  locationID %x",[devicePtr deviceName], [devicePtr locationID]);
            NSXLog(@"%@", [devicePtr dictionaryVersionOfMe]);
			if ([devicePtr locationID] == deviceLocationID)	{
				NSXLog(@"found device %@",[devicePtr deviceName]);
				NSDictionary		*tmpDict = [devicePtr dictionaryVersionOfMe];
				NSXLog(@"top-level keys are %@",[tmpDict allKeys]);
				NSXLog(@"device dict is %@",tmpDict);
				NSDictionary		*topLevelNodeDataDict = (tmpDict==nil) ? nil : [tmpDict objectForKey:@"nodeData"];
                
                NSString *json = dictionaryToJSON(tmpDict);
                NSXLog(@"device info\n %@", json);
				//	from the node data dict, get the 'children' array
				NSArray				*topLevelNodeChildren = (topLevelNodeDataDict==nil) ? nil : [topLevelNodeDataDict objectForKey:@"children"];
				//	run through the children- each child is a dict, look for the dict with a "nodeName" that contains the string "Configuration Descriptor"
				for (NSDictionary *topLevelNodeChild in topLevelNodeChildren)	{
					NSString		*topLevelNodeChildName = [topLevelNodeChild objectForKey:@"nodeName"];
					if ([topLevelNodeChildName containsString:@"Configuration Descriptor"])	{
						//	get the 'children' array from the top level node child dict
						NSArray			*configDescriptorChildren = [topLevelNodeChild objectForKey:@"children"];
						//	run through the children- each child is a dict, look for the dict with a "nodeName" that contains the string "Video/Control"
						for (NSDictionary *configDescriptorChild in configDescriptorChildren)	{
							NSString		*configChildName = [configDescriptorChild objectForKey:@"nodeName"];
							if ([configChildName containsString:@"Video/Control"])	{
								//	get the 'children' array from the config descriptor child dict
								NSArray			*videoControlChildren = [configDescriptorChild objectForKey:@"children"];
								//	run through the children- each child is a dict, look for the dict with a "nodeName" that contains the string "VDC (Control) Input Terminal"
								for (NSDictionary *videoControlChild in videoControlChildren)	{
									NSString		*controlChildName = [videoControlChild objectForKey:@"nodeName"];
									if ([controlChildName containsString:@"VDC (Control) Input Terminal"])	{
										NSArray			*inputTerminalChildren = [videoControlChild objectForKey:@"children"];
										for (NSDictionary *inputTerminalChild in inputTerminalChildren)	{
											NSString		*terminalIDString = [inputTerminalChild objectForKey:@"Terminal ID"];
											if (terminalIDString != nil)	{
												inputTerminalID = (int)[terminalIDString integerValue];
												break;
											}
										}
										
										break;
									}
								}
								//	run through the children- each child is a dict, look for the dict with a "nodeName" that contains the string "VDC (Control) Processing Unit"
								for (NSDictionary *videoControlChild in videoControlChildren)	{
									NSString		*controlChildName = [videoControlChild objectForKey:@"nodeName"];
									if ([controlChildName containsString:@"VDC (Control) Processing Unit"])	{
										NSArray			*processingUnitChildren = [videoControlChild objectForKey:@"children"];
										for (NSDictionary *processingUnitChild in processingUnitChildren)	{
											NSString		*unitIDString = [processingUnitChild objectForKey:@"Unit ID:"];
											if (unitIDString != nil)	{
												processingUnitID = (int)[unitIDString integerValue];
												break;
											}
										}
										break;
									}
								}
								
								// extension Unit ID
								for (NSDictionary *videoControlChild in videoControlChildren)	{
									NSString		*controlChildName = [videoControlChild objectForKey:@"nodeName"];
									if ([controlChildName containsString:@"VDC (Control) Extension Unit"])	{
										NSArray			*extensionUnitChildren = [videoControlChild objectForKey:@"children"];
										for (NSDictionary *extensionUnitChild in extensionUnitChildren)	{
											NSString		*unitIDString = [extensionUnitChild objectForKey:@"Unit ID:"];
											if (unitIDString != nil)	{
												extensionUnitID = (int)[unitIDString integerValue];
												break;
											}
										}

										break;
									}
								}
								
								for (NSDictionary *videoControlChild in videoControlChildren)	{
									NSString		*controlChildName = [videoControlChild objectForKey:@"nodeName"];
									if ([controlChildName containsString:@"VDC (Control) Output Terminal"])	{
										NSArray			*outputTerminalChildren = [videoControlChild objectForKey:@"children"];
										//	run through the children- each child is a dict, look for the child with a string at the key "Unit ID:"
										for (NSDictionary *outputTerminalChild in outputTerminalChildren)	{
											NSString		*unitIDString = [outputTerminalChild objectForKey:@"Unit ID:"];
											if (unitIDString != nil)	{
												outputTerminalID = (int)[unitIDString integerValue];
												break;
											}
										}
										break;
									}
								}
							} else if ([configChildName containsString:@"Video/Streaming"]){
								NSArray			*videoStreamingChildren = [configDescriptorChild objectForKey:@"children"];
								for (NSDictionary *videoStreamingChild in videoStreamingChildren)	{
									NSString		*nodeName = [videoStreamingChild objectForKey:@"nodeName"];
									NSArray			*children = [videoStreamingChild objectForKey:@"children"];
									NSString *formatGuid = nil;
									NSNumber *formatIndex = nil;
									for (NSDictionary *videoStreamingChild in children)	{
										if (formatGuid == nil) {
											formatGuid = [videoStreamingChild objectForKey:@"Format GUID:"];
										}
										
										if (formatIndex == nil) {
											formatIndex = [videoStreamingChild objectForKey:@"bFormatIndex:"];
										}
									}
									
                                    NSLog(@"=======formatIndex %@ %@ %@", formatIndex, nodeName, formatGuid);
									if (formatIndex) {
										if (formatGuid != NULL){
											NSLog(@"formatGuid %@", formatGuid);
											if ([formatGuid isEqual:@"32595559-0000-0010-8000-00aa00389b71"]) {
												[videoName addObject:@"YUY2"];
											}
											
											if ([formatGuid isEqual:@"3231564E-0000-0010-8000-00AA00389B71"]) {
												[videoName addObject:@"NV12"];
											}
										} else {
											NSLog(@"nodeName %@", nodeName);
											NSArray *nodeNameList = [nodeName componentsSeparatedByString:@" "];
											if ([nodeNameList count] > 3) {
												[videoName addObject:nodeNameList[2]];
											}
										}
									}
								}
							}
						}
						
						break;
					}
				}
				
				break;
			}
		}
		
		if (prober != nil)	{
			prober = nil;
		}
		
		//	Find All USB Devices, get their locationId and check if it matches the requested one
		CFMutableDictionaryRef		matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
		io_iterator_t				serviceIterator;
		
		IOServiceGetMatchingServices( kIOMasterPortDefault, matchingDict, &serviceIterator );
		
		BOOL						successfullInit = NO;
		io_service_t				camera;
		while( (camera = IOIteratorNext(serviceIterator)) ) {
			// Get DeviceInterface
			IOUSBDeviceInterface	**deviceInterface = NULL;
			IOCFPlugInInterface		**plugInInterface = NULL;
			SInt32					score;
			kern_return_t			kr;
			
			kr = IOCreatePlugInInterfaceForService( camera, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score );
			if( (kIOReturnSuccess != kr) || !plugInInterface ) {
				NSXLog( @"CameraControl Error: IOCreatePlugInInterfaceForService returned 0x%08x.", kr );
				if (plugInInterface!=NULL)	{
					IODestroyPlugInInterface(plugInInterface);
					plugInInterface = NULL;
					break;
				}
			} else {
				HRESULT	res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID*) &deviceInterface );
				(*plugInInterface)->Release(plugInInterface);
				if( res || deviceInterface == NULL ) {
					NSXLog( @"CameraControl Error: QueryInterface returned %d.\n", (int)res );
					//	clean up the plugin interface
					if (plugInInterface!=NULL)	{
						IODestroyPlugInInterface(plugInInterface);
						plugInInterface = NULL;
						break;
					}
				} else {
					UInt32 currentLocationID = 0;
					(*deviceInterface)->GetLocationID(deviceInterface, &currentLocationID);
					//	if this is the USB device i was looking for...
					if( currentLocationID == deviceLocationID ) {
						//	get the usb interface
						interface = [self _getControlInferaceWithDeviceInterface:deviceInterface];
						[self generalInit];
						successfullInit = YES;
						//	clean up the plugin interface
						if (plugInInterface!=NULL)	{
							IODestroyPlugInInterface(plugInInterface);
							plugInInterface = NULL;
						}
						break;
					}
					//	clean up the plugin interface
					if (plugInInterface!=NULL)	{
						IODestroyPlugInInterface(plugInInterface);
						plugInInterface = NULL;
					}
				}
			}
			
		} // end while
		
		//	if i successfully init'ed the camera, i can return myself
		if (successfullInit)
			return self;
		//	else i couldn't successfully init myself, something went wrong/i couldn't connect: release self and return nil;
		NSXLog(@"ERR: couldn't create UVCController with locationID %d, %X",(unsigned int)locationID,(unsigned int)locationID);
		return nil;
	}
	return self;
}

- (IOUSBInterfaceInterface190 **) _getControlInferaceWithDeviceInterface:(IOUSBDeviceInterface **)deviceInterface {
	//NSXLog(@"%s",__func__);
	io_iterator_t					interfaceIterator;
	IOUSBFindInterfaceRequest		interfaceRequest;
	
	interfaceRequest.bInterfaceClass = UVC_CONTROL_INTERFACE_CLASS;
	interfaceRequest.bInterfaceSubClass = UVC_CONTROL_INTERFACE_SUBCLASS;
	interfaceRequest.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
	interfaceRequest.bAlternateSetting = kIOUSBFindInterfaceDontCare;
	
	IOReturn success = (*deviceInterface)->CreateInterfaceIterator( deviceInterface, &interfaceRequest, &interfaceIterator );
	if( success != kIOReturnSuccess ) {
		return NULL;
	}
	
	io_service_t		ioDeviceObj;
	HRESULT				result;
	
	if( (ioDeviceObj = IOIteratorNext(interfaceIterator)) ) {
		IOCFPlugInInterface				**ioPlugin = NULL;
		IOUSBInterfaceInterface190		**controlInterface;
		//IOUSBDeviceRef					deviceInterface = NULL;
		//	Create an intermediate plug-in
		SInt32						score;
		kern_return_t				kr;
		
		kr = IOCreatePlugInInterfaceForService( ioDeviceObj, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &ioPlugin, &score );
		
		//	Release the ioDeviceObj object after getting the plug-in
		kr = IOObjectRelease(ioDeviceObj);
		if( (kr != kIOReturnSuccess) || !ioPlugin ) {
			NSXLog( @"CameraControl Error: Unable to create a plug-in (%08x)\n", kr );
			return NULL;
		}
		
		//	Now create the device interface for the interface
		result = (*ioPlugin)->QueryInterface( ioPlugin, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID *) &controlInterface );
		//	No inter need the intermediate plug-in
		(*ioPlugin)->Release(ioPlugin);
		
		if (result || !controlInterface) {
			NSXLog( @"CameraControl Error: Couldn’t create a control interface for the interface (%08x)", (int) result );
			return NULL;
		}
		
		return controlInterface;
	}
	
	return NULL;
}

- (void) generalInit	{
	scanningMode.ctrlInfo = &_scanCtrl;
	autoExposureMode.ctrlInfo = &_autoExposureModeCtrl;
	autoExposurePriority.ctrlInfo = &_autoExposurePriorityCtrl;
	exposureTime.ctrlInfo = &_exposureTimeCtrl;
	iris.ctrlInfo = &_irisCtrl;
	autoFocus.ctrlInfo = &_autoFocusCtrl;
	focus.ctrlInfo = &_focusCtrl;
	zoom.ctrlInfo = &_zoomCtrl;
	panTilt.ctrlInfo = &_panTiltCtrl;
	panTiltRel.ctrlInfo = &_panTiltRelCtrl;
	roll.ctrlInfo = &_rollCtrl;
	rollRel.ctrlInfo = &_rollRelCtrl;
	
	backlight.ctrlInfo = &_backlightCtrl;
	bright.ctrlInfo = &_brightCtrl;
	contrast.ctrlInfo = &_contrastCtrl;
	gain.ctrlInfo = &_gainCtrl;
	powerLine.ctrlInfo = &_powerLineCtrl;
	autoHue.ctrlInfo = &_autoHueCtrl;
	hue.ctrlInfo = &_hueCtrl;
	saturation.ctrlInfo = &_saturationCtrl;
	sharpness.ctrlInfo = &_sharpnessCtrl;
	gamma.ctrlInfo = &_gammaCtrl;
	autoWhiteBalance.ctrlInfo = &_whiteBalanceAutoTempCtrl;
	whiteBalance.ctrlInfo = &_whiteBalanceTempCtrl;
	
	if (interface)	{
		(*interface)->GetInterfaceNumber(interface,&interfaceNumber);
	}
	
    uvcParamsCache = [NSMutableDictionary dictionary];
	[self _populateAllParams];
    [self imageCtrlInit];
    [self cameraCtrlInit];
	
	//	create the nib from my class name
//	theNib = [[NSNib alloc] initWithNibNamed:[self className] bundle:[NSBundle bundleForClass:[self class]]];
	//	unpack the nib, instantiating the object
//	[theNib instantiateWithOwner:self topLevelObjects:nil];
	
	if (uiCtrlr != nil)
		[uiCtrlr _pushCameraControlStateToUI];
}

- (void) dealloc {
	[self closeSettingsWindow];
	
	if( interface ) {
		(*interface)->USBInterfaceClose(interface);
		(*interface)->Release(interface);
	}
}

/*===================================================================================*/
#pragma mark --------------------- saving/restoring state
/*------------------------------------*/
- (NSMutableDictionary *) createSnapshot	{
	NSMutableDictionary		*returnMe = [NSMutableDictionary dictionaryWithCapacity:0];
	
	[returnMe setObject:[NSNumber numberWithBool:[self interlaced]] forKey:@"interlaced"];
	[returnMe setObject:[NSNumber numberWithInt:[self autoExposureMode]] forKey:@"autoExposureMode"];
	[returnMe setObject:[NSNumber numberWithBool:[self autoExposurePriority]] forKey:@"autoExposurePriority"];
	[returnMe setObject:[NSNumber numberWithLong:[self exposureTime]] forKey:@"exposureTime"];
	[returnMe setObject:[NSNumber numberWithLong:[self iris]] forKey:@"iris"];
	[returnMe setObject:[NSNumber numberWithBool:[self autoFocus]] forKey:@"autoFocus"];
	[returnMe setObject:[NSNumber numberWithLong:[self focus]] forKey:@"focus"];
	[returnMe setObject:[NSNumber numberWithLong:[self zoom]] forKey:@"zoom"];
	[returnMe setObject:[NSNumber numberWithLong:[self backlight]] forKey:@"backlight"];
	[returnMe setObject:[NSNumber numberWithLong:[self bright]] forKey:@"bright"];
	[returnMe setObject:[NSNumber numberWithLong:[self contrast]] forKey:@"contrast"];
	[returnMe setObject:[NSNumber numberWithLong:[self gain]] forKey:@"gain"];
	[returnMe setObject:[NSNumber numberWithLong:[self powerLine]] forKey:@"powerLine"];
	[returnMe setObject:[NSNumber numberWithBool:[self autoHue]] forKey:@"autoHue"];
	[returnMe setObject:[NSNumber numberWithLong:[self hue]] forKey:@"hue"];
	[returnMe setObject:[NSNumber numberWithLong:[self saturation]] forKey:@"saturation"];
	[returnMe setObject:[NSNumber numberWithLong:[self sharpness]] forKey:@"sharpness"];
	[returnMe setObject:[NSNumber numberWithLong:[self gamma]] forKey:@"gamma"];
	[returnMe setObject:[NSNumber numberWithBool:[self autoWhiteBalance]] forKey:@"autoWhiteBalance"];
	[returnMe setObject:[NSNumber numberWithLong:[self whiteBalance]] forKey:@"whiteBalance"];
	return returnMe;
}

- (void) loadSnapshot:(NSDictionary *)s	{
	if (s == nil)
		return;
	
	NSNumber		*tmpNum = nil;
	BOOL			needsToRepopulate = NO;
	
	//	if i have to repopulate the params, do so now!
	if (needsToRepopulate)	{
		//NSXLog(@"\t\trepopulating params in %s, input/processing ID changed!",__func__);
		[self _populateAllParams];
	}
	
	//	reset all the params to their defaults, or the changes won't "take" on some cameras!
	[self resetParamsToDefaults];
	
	//	proceed with loading the rest of the snap....
	tmpNum = [s objectForKey:@"interlaced"];
	if (tmpNum!=nil)	{
		[self setInterlaced:scanningMode.def];
		[self setInterlaced:[tmpNum boolValue]];
	}
	
	tmpNum = [s objectForKey:@"autoExposureMode"];
	if (tmpNum!=nil)	{
		[self setAutoExposureMode:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"autoExposurePriority"];
	if (tmpNum!=nil)	{
		[self setAutoExposurePriority:[tmpNum boolValue]];
	}
	
	tmpNum = [s objectForKey:@"exposureTime"];
	if (tmpNum!=nil)	{
		[self setExposureTime:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"iris"];
	if (tmpNum!=nil)	{
		[self setIris:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"autoFocus"];
	if (tmpNum!=nil)	{
		[self setAutoFocus:[tmpNum boolValue]];
	}
	
	tmpNum = [s objectForKey:@"focus"];
	if (tmpNum!=nil)	{
		[self setFocus:focus.def];
		[self setFocus:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"zoom"];
	if (tmpNum!=nil)	{
		[self setZoom:[tmpNum intValue]];
	}

	tmpNum = [s objectForKey:@"backlight"];
	if (tmpNum != nil)	{
		[self setBacklight:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"bright"];
	if (tmpNum!=nil)	{
		[self setBright:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"contrast"];
	if (tmpNum!=nil)	{
		[self setContrast:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"gain"];
	if (tmpNum!=nil)	{
		[self setGain:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"powerLine"];
	if (tmpNum!=nil)	{
		[self setPowerLine:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"autoHue"];
	if (tmpNum!=nil)	{
		[self setAutoHue:[tmpNum boolValue]];
	}
	
	tmpNum = [s objectForKey:@"hue"];
	if (tmpNum!=nil)	{
		[self setHue:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"saturation"];
	if (tmpNum!=nil)	{
		[self setSaturation:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"sharpness"];
	if (tmpNum!=nil)	{
		[self setSharpness:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"gamma"];
	if (tmpNum!=nil)	{
		[self setGamma:[tmpNum intValue]];
	}
	
	tmpNum = [s objectForKey:@"autoWhiteBalance"];
	if (tmpNum!=nil)	{
		[self setAutoWhiteBalance:[tmpNum boolValue]];
	}
	
	tmpNum = [s objectForKey:@"whiteBalance"];
	if (tmpNum!=nil)	{
		[self setWhiteBalance:[tmpNum intValue]];
	}
	
	if (uiCtrlr != nil)
		[uiCtrlr _pushCameraControlStateToUI];
}

/*===================================================================================*/
#pragma mark --------------------- backend
/*------------------------------------*/
- (BOOL) _sendControlRequest:(IOUSBDevRequest *)controlRequest {
	NSString *dataStr = @"";
	for (int i = 0; i < controlRequest->wLength; i++) {
		dataStr = [dataStr stringByAppendingFormat:@"0x%X ", ((UInt8 *)controlRequest->pData)[i]];
	}
	NSXLog(@"bmRequestType 0x%0X bRequest 0x%X wValue 0x%X wIndex 0x%X wLength 0x%X data %@", controlRequest->bmRequestType, controlRequest->bRequest,controlRequest->wValue,controlRequest->wIndex,controlRequest->wLength, dataStr);
	if( !interface ){
		NSXLog( @"CameraControl Error: No interface to send request" );
		return NO;
	}
	
	kern_return_t kr = (*interface)->ControlRequest( interface, 0, controlRequest );
	if( kr != kIOReturnSuccess ) {
		NSXLog( @"CameraControl Error: Control request failed: %08x", kr );
		kr = (*interface)->USBInterfaceClose(interface);
		return NO;
	}
    
    NSString *resStr = @"";
    for (int i = 0; i < controlRequest->wLength; i++) {
        resStr = [resStr stringByAppendingFormat:@"0x%X ", ((UInt8 *)controlRequest->pData)[i]];
    }
    NSXLog(@"response data %@", resStr);

	return YES;
}

- (NSUInteger)getFlipValue{
    int                    returnMe = 0;
    IOUSBDevRequest        controlRequest;
    controlRequest.bmRequestType = USBmakebmRequestType( kUSBIn, kUSBClass, kUSBInterface );
    controlRequest.bRequest = UVC_GET_CUR;
    controlRequest.wValue = (UVC_XU_FLIP_HORIZONTAL_VERTICAL_EXTENSION << 8) | 0x00;
    NSXLog(@"extensionUnitID %x interfaceNumber %x", extensionUnitID, interfaceNumber);
    controlRequest.wIndex = ((extensionUnitID <<8) | interfaceNumber);
    controlRequest.wLength = 1;
    controlRequest.wLenDone = 0;
    
    void *ret = malloc(controlRequest.wLength);
    bzero(ret, controlRequest.wLength);
    controlRequest.pData = ret;
    
    if (![self _sendControlRequest:&controlRequest]){
        returnMe = -1;
    } else {
        returnMe = controlRequest.wLenDone;
    }
    
    if (returnMe <= 0)    {
        controlRequest.pData = nil;
        returnMe = 0;
    } else {
        NSXLog(@"%d", *((short int *)ret));
        returnMe = *((short int *)ret);
    }
    
    free(ret);
    ret = nil;
    
    return (NSUInteger)returnMe;
}

- (BOOL)setUVCExtensionSettingValue:(UVCExtensionSettingValue)value {
    int len = 1;
    int       returnMe = 0;
    IOUSBDevRequest        controlRequest;
    controlRequest.bmRequestType = USBmakebmRequestType( kUSBOut, kUSBClass, kUSBInterface );
    controlRequest.bRequest = UVC_SET_CUR;
    controlRequest.wValue = (UVC_XU_FLIP_HORIZONTAL_VERTICAL_EXTENSION << 8) | 0x00;
    NSXLog(@"extensionUnitID %x interfaceNumber %x", extensionUnitID, interfaceNumber);
    controlRequest.wIndex = ((extensionUnitID <<8) | interfaceNumber);
    controlRequest.wLength = len;
    controlRequest.wLenDone = 0;
    
    uint8 *ret = malloc(len);
    bzero(ret,len);
    controlRequest.pData = ret;
    *ret = value;
    
    if (![self _sendControlRequest:&controlRequest]){
        returnMe = -1;
    } else {
        returnMe = controlRequest.wLenDone;
        if (UVCFactoryReset == value) {
            [self populateImageCtrlParams];
            [self saveCameraCtrlParamToCache];
            [self populateCameraCtrlParams];
            [self saveCameraCtrlParamToCache];
        }
    }
    
    free(ret);
    
    return returnMe>0;
}

- (int)getExtensionLen{
	int					returnMe = 0;
	IOUSBDevRequest		controlRequest;
	controlRequest.bmRequestType = USBmakebmRequestType( kUSBIn, kUSBClass, kUSBInterface );
	controlRequest.bRequest = UVC_GET_LEN;
	controlRequest.wValue = (UVC_XU_CONTROL_CHINGAN_EXTENSION << 8) | 0x00;
	NSXLog(@"extensionUnitID %x interfaceNumber %x", extensionUnitID, interfaceNumber);
	controlRequest.wIndex = ((extensionUnitID <<8) | interfaceNumber);
	controlRequest.wLength = 2;
	controlRequest.wLenDone = 0;
	
	void *ret = malloc(controlRequest.wLength);
	bzero(ret,2);
	controlRequest.pData = ret;
	
	if (![self _sendControlRequest:&controlRequest]){
		returnMe = -1;
	} else {
		returnMe = controlRequest.wLenDone;
	}
	
	if (returnMe <= 0)	{
		controlRequest.pData = nil;
	} else {
		NSXLog(@"%d", *((short int *)ret));
		UInt8 data[2];
		memcpy(data, ret, 2);
		NSXLog(@"%x %x", data[0], data[1]);
		returnMe = *((short int *)ret);
	}
	
	free(ret);
	ret = nil;
	
	return returnMe;
}

- (NSString *)getExtensionVersion{
	uint16 len = [self getExtensionLen];
	int					returnMe = 0;
	NSString *version = nil;
	IOUSBDevRequest		controlRequest;
	controlRequest.bmRequestType = USBmakebmRequestType( kUSBIn, kUSBClass, kUSBInterface );
	controlRequest.bRequest = UVC_GET_CUR;
	controlRequest.wValue = (UVC_XU_CONTROL_CHINGAN_EXTENSION << 8) | 0x00;
	NSXLog(@"extensionUnitID %x interfaceNumber %x", extensionUnitID, interfaceNumber);
	controlRequest.wIndex = ((extensionUnitID <<8) | interfaceNumber);
	controlRequest.wLength = len;
	controlRequest.wLenDone = 0;
	
	struct fireware_info *ret = malloc(sizeof(struct fireware_info));
	bzero(ret,len);
	controlRequest.pData = ret;
	
	if (![self _sendControlRequest:&controlRequest]){
		returnMe = -1;
	} else {
		returnMe = controlRequest.wLenDone;
	}
	
	if (returnMe <= 0)	{
		controlRequest.pData = nil;
	} else {
		NSString *cameraVer = [NSString stringWithFormat:@"Version : %d.%d.%d \n", ret->CamVersion[0], ret->CamVersion[1], ret->CamVersion[2]];
		NSString *time = [NSString stringWithFormat:@"Time : %d-%d-%d \n", ret->dwCamDate[0]<<8|ret->dwCamDate[1], ret->dwCamDate[2], ret->dwCamDate[3]];
		NSString *productVer = [NSString stringWithUTF8String:(char *)ret->ProductVer];
		NSString *authorized = ret->AuthorizedStated?@"\nAuthorized":@"";
		NSXLog(@"\n%@%@%@%@",cameraVer, time, productVer, authorized);
		version = [NSString stringWithFormat:@"%@%@%@%@",cameraVer,time,productVer,authorized];
	}
	
	free(ret);
	ret = nil;
	
	return version?:@"";
}

-(BOOL)setUpdateMode{
	uint16 len = [self getExtensionLen];
	int	   returnMe = 0;
	NSString *version = nil;
	IOUSBDevRequest		controlRequest;
	controlRequest.bmRequestType = USBmakebmRequestType( kUSBOut, kUSBClass, kUSBInterface );
	controlRequest.bRequest = UVC_SET_CUR;
	controlRequest.wValue = (UVC_XU_CONTROL_CHINGAN_EXTENSION << 8) | 0x00;
	NSXLog(@"extensionUnitID %x interfaceNumber %x", extensionUnitID, interfaceNumber);
	controlRequest.wIndex = ((extensionUnitID <<8) | interfaceNumber);
	controlRequest.wLength = len;
	controlRequest.wLenDone = 0;
	
	struct fireware_info *ret = malloc(sizeof(struct fireware_info));
	bzero(ret,len);
	memset(ret, 0xaa, 1);
	controlRequest.pData = ret;
	
    
	if (![self _sendControlRequest:&controlRequest]){
		returnMe = -1;
	} else {
		returnMe = controlRequest.wLenDone;
	}
	
	if (returnMe <= 0)	{
		controlRequest.pData = nil;
	} else {
		NSString *cameraVer = [NSString stringWithFormat:@"Version : %d.%d.%d \n", ret->CamVersion[0], ret->CamVersion[1], ret->CamVersion[2]];
		NSString *time = [NSString stringWithFormat:@"Time : %d-%d-%d \n", ret->dwCamDate[0]<<8|ret->dwCamDate[1], ret->dwCamDate[2], ret->dwCamDate[3]];
		NSString *productVer = [NSString stringWithUTF8String:(char *)ret->ProductVer];
		NSString *authorized = ret->AuthorizedStated?@"\nAuthorized":@"";
		NSXLog(@"\n%@%@%@%@",cameraVer, time, productVer, authorized);
		version = [NSString stringWithFormat:@"%@%@%@%@",cameraVer,time,productVer,authorized];
	}
	free(ret);
    
    return returnMe>0;
}

- (int) _requestValType:(int)requestType forControl:(const uvc_control_info_t *)ctrl returnVal:(void **)ret	{
	int					returnMe = 0;
	IOUSBDevRequest		controlRequest;
	controlRequest.bmRequestType = USBmakebmRequestType( kUSBIn, kUSBClass, kUSBInterface );
	controlRequest.bRequest = requestType;
	controlRequest.wValue = (ctrl->selector << 8) | 0x00;
	controlRequest.wIndex = (ctrl->unit==UVC_INPUT_TERMINAL_ID) ? inputTerminalID : processingUnitID;
	
	NSXLog(@"inputTerminalID %x, processingUnitID %x, unit %x", inputTerminalID, processingUnitID, ctrl->unit);
	controlRequest.wIndex = ((controlRequest.wIndex<<8) | interfaceNumber);
	controlRequest.wLength = (requestType==UVC_GET_INFO) ? 1 : ctrl->intendedSize;
	controlRequest.wLenDone = 0;
	
	*ret = malloc(controlRequest.wLength);
	bzero(*ret,controlRequest.wLength);
	controlRequest.pData = *ret;
	
	if (![self _sendControlRequest:&controlRequest]){
		returnMe = -1;
	} else {
		returnMe = controlRequest.wLenDone;
	}
	
	if (returnMe <= 0) {
		free(*ret);
		*ret = nil;
		controlRequest.pData = nil;
	}
	
	return returnMe;
}

- (BOOL) _setBytes:(void *)bytes sized:(int)size toControl:(const uvc_control_info_t *)ctrl	{
	BOOL			returnMe = NO;

	IOUSBDevRequest		controlRequest;
	controlRequest.bmRequestType = USBmakebmRequestType( kUSBOut, kUSBClass, kUSBInterface );
	controlRequest.bRequest = UVC_SET_CUR;
	controlRequest.wValue = (ctrl->selector << 8) | 0x00;
	controlRequest.wIndex = (ctrl->unit==UVC_INPUT_TERMINAL_ID) ? inputTerminalID : processingUnitID;
	controlRequest.wIndex = ((controlRequest.wIndex<<8) | interfaceNumber);
	controlRequest.wLength = size;
	controlRequest.wLenDone = 0;
	controlRequest.pData = bytes;
	returnMe = [self _sendControlRequest:&controlRequest];
	return returnMe;
}

- (BOOL) setRelativeZoomControl:(UInt8)bZoom{
	BOOL			returnMe = NO;
	UInt8 bytes[3];

	if (bZoom == 0) {
		bytes[2] = 0;
	}else{
		uvc_control_info_t controlInfo;
		
		controlInfo.unit = UVC_INPUT_TERMINAL_ID;
		controlInfo.selector = UVC_CT_ZOOM_RELATIVE_CONTROL;
		controlInfo.intendedSize = 3;
		UInt8 *returnData = nil;
		[self _requestValType:UVC_GET_MAX forControl:&controlInfo returnVal:(void**)&returnData];
		NSXLog(@"setRelativeZoomControl GET_MAX %x %x %x", returnData[0], returnData[1], returnData[2]);
		bytes[2] = returnData[2];
		free(returnData);
		returnData = nil;
	}
	
	bytes[0] = bZoom;
	bytes[1] = 0;
	NSXLog(@"setRelativeZoomControl bytes %x %x %x", bytes[0], bytes[1], bytes[2]);

	IOUSBDevRequest		controlRequest;
	controlRequest.bmRequestType = USBmakebmRequestType( kUSBOut, kUSBClass, kUSBInterface );
	controlRequest.bRequest = UVC_SET_CUR;
	controlRequest.wValue = (UVC_CT_ZOOM_RELATIVE_CONTROL << 8) | 0x00;
	controlRequest.wIndex = ((inputTerminalID<<8) | interfaceNumber);
	controlRequest.wLength = 3;
	controlRequest.wLenDone = 0;
	controlRequest.pData = bytes;
	returnMe = [self _sendControlRequest:&controlRequest];
	return returnMe;
}

// image ctrl
- (void)imageCtrlInit{
    [self populateImageCtrlParams];
    [self saveImageCtrlParamToCache];
}

- (BOOL)isAutoWhiteBalance{
    return autoWhiteBalance.val;
}

- (void)populateImageCtrlParams{
    [self _populateParam:&bright];
    [self _populateParam:&contrast];
    [self _populateParam:&hue];
    [self _populateParam:&saturation];
    [self _populateParam:&sharpness];
    [self _populateParam:&gamma];
    [self _populateParam:&autoWhiteBalance];
    [self _populateParam:&whiteBalance];
    [self _populateParam:&backlight];
    [self _populateParam:&gain];
    [self _populateParam:&powerLine];
}

- (void)saveImageCtrlParamToCache{
    NSXLog(@"saveImageCtrlParamToCache in %@", uvcParamsCache);
    UVCSetParamToLocal(@"bright", bright.val);
    UVCSetParamToLocal(@"contrast", contrast.val);
    UVCSetParamToLocal(@"hue", hue.val);
    UVCSetParamToLocal(@"saturation", saturation.val);
    UVCSetParamToLocal(@"sharpness", sharpness.val);
    UVCSetParamToLocal(@"gamma", gamma.val);
    UVCSetParamToLocal(@"autoWhiteBalance", autoWhiteBalance.val);
    UVCSetParamToLocal(@"whiteBalance", whiteBalance.val);
    UVCSetParamToLocal(@"backlight", backlight.val);
    UVCSetParamToLocal(@"gain", gain.val);
    UVCSetParamToLocal(@"powerLine", powerLine.val);
    NSXLog(@"saveImageCtrlParamToCache out %@", uvcParamsCache);
}

- (void)rollbackImageCtrlParams{
    NSXLog(@"rollbackImageCtrlParams in %@", uvcParamsCache);
    bright.val = UVCGetParamFromLocal(@"bright");
    [self _pushParamToDevice:&bright];
    contrast.val = UVCGetParamFromLocal(@"contrast");
    [self _pushParamToDevice:&contrast];
    hue.val = UVCGetParamFromLocal(@"hue");
    [self _pushParamToDevice:&hue];
    saturation.val = UVCGetParamFromLocal(@"saturation");
    [self _pushParamToDevice:&saturation];
    sharpness.val = UVCGetParamFromLocal(@"sharpness");
    [self _pushParamToDevice:&sharpness];
    gamma.val = UVCGetParamFromLocal(@"gamma");
    [self _pushParamToDevice:&gamma];
    autoWhiteBalance.val = UVCGetParamFromLocal(@"autoWhiteBalance");
    [self _pushParamToDevice:&autoWhiteBalance];
    whiteBalance.val = UVCGetParamFromLocal(@"whiteBalance");
    [self _pushParamToDevice:&whiteBalance];
    backlight.val = UVCGetParamFromLocal(@"backlight");
    [self _pushParamToDevice:&backlight];
    gain.val = UVCGetParamFromLocal(@"gain");
    [self _pushParamToDevice:&gain];
    powerLine.val = UVCGetParamFromLocal(@"powerLine");
    [self _pushParamToDevice:&powerLine];
}

- (void)resetDefaultImageCtrlParams{
    [self _resetParamToDefault:&bright];
    [self _resetParamToDefault:&contrast];
    [self _resetParamToDefault:&hue];
    [self _resetParamToDefault:&saturation];
    [self _resetParamToDefault:&sharpness];
    [self _resetParamToDefault:&gamma];
    [self _resetParamToDefault:&autoWhiteBalance];
    [self _resetParamToDefault:&whiteBalance];
    [self _resetParamToDefault:&backlight];
    [self _resetParamToDefault:&gain];
    [self _resetParamToDefault:&powerLine];
}

// camera ctrl
- (void)cameraCtrlInit{
    [self populateCameraCtrlParams];
    [self saveCameraCtrlParamToCache];
}

- (BOOL)isExposureAutoMode{
    return autoExposureMode.val == 0x04 || autoExposureMode.val == 0x02;
}

- (void)saveCameraCtrlParamToCache{
    UVCSetParamToLocal(@"zoom", zoom.val);
    UVCSetParamToLocal(@"focus", focus.val);
    UVCSetParamToLocal(@"autoExposureMode", autoExposureMode.val);
    UVCSetParamToLocal(@"exposureTime", exposureTime.val);
    UVCSetParamToLocal(@"iris", iris.val);
    UVCSetParamToLocal(@"pan", panTilt.pan.val);
    UVCSetParamToLocal(@"tilt", panTilt.tilt.val);
    UVCSetParamToLocal(@"roll", roll.val);
}

- (void)populateCameraCtrlParams{
    [self _populateParam:&zoom];
    [self _populateParam:&focus];
    [self _populateParam:&autoExposureMode];
    [self _populateParam:&exposureTime];
    [self _populateParam:&iris];
    [self populateAbsPanTiltParam:&panTilt];
    [self _populateParam:&roll];
}

- (void)rollbackCameraCtrlParams{
    zoom.val = UVCGetParamFromLocal(@"zoom");
    [self _pushParamToDevice:&zoom];
    
    focus.val = UVCGetParamFromLocal(@"focus");
    [self _pushParamToDevice:&focus];
    
    autoExposureMode.val = UVCGetParamFromLocal(@"autoExposureMode");
    [self _pushParamToDevice:&autoExposureMode];
    
    exposureTime.val = UVCGetParamFromLocal(@"exposureTime");
    [self _pushParamToDevice:&exposureTime];
    
    iris.val = UVCGetParamFromLocal(@"iris");
    [self _pushParamToDevice:&iris];
    
    panTilt.pan.val = UVCGetParamFromLocal(@"pan");
    panTilt.tilt.val = UVCGetParamFromLocal(@"tilt");
    [self pushAbsPanTiltToDevice:&panTilt];
    
    roll.val = UVCGetParamFromLocal(@"roll");
    [self _pushParamToDevice:&roll];
}

- (void)resetPTZ{
    [self _resetParamToDefault:&zoom];
    [self resetPanTilt];
}

- (void)resetDefaultCameraCtrlParams{
    [self _resetParamToDefault:&zoom];
    [self _resetParamToDefault:&focus];
    [self _resetParamToDefault:&autoExposureMode];
    [self _resetParamToDefault:&exposureTime];
    [self _resetParamToDefault:&iris];
    [self resetPanTilt];
    [self _resetParamToDefault:&roll];
}


- (void) _populateAllParams	{
	[self _populateParam:&scanningMode];
	[self _populateParam:&autoExposureMode];
	[self _populateParam:&autoExposurePriority];
	[self _populateParam:&exposureTime];
	[self _populateParam:&iris];
	[self _populateParam:&autoFocus];
	[self _populateParam:&focus];
	[self _populateParam:&zoom];
	[self populateAbsPanTiltParam:&panTilt];
	[self getRelativePanTiltInfo:&panTiltRel];
	[self _populateParam:&roll];
	[self _populateParam:&rollRel];
	[self _populateParam:&backlight];
	[self _populateParam:&bright];
	[self _populateParam:&contrast];
	[self _populateParam:&gain];
	[self _populateParam:&powerLine];
	[self _populateParam:&autoHue];
	[self _populateParam:&hue];
	[self _populateParam:&saturation];
	[self _populateParam:&sharpness];
	[self _populateParam:&gamma];
	[self _populateParam:&autoWhiteBalance];
	[self _populateParam:&whiteBalance];

	NSXLog(@"\t\t*******************");
	NSXLog(@"\t\t (min) - [val] - (max), def");
	NSXLog(@"\t\t*******************");
	NSXLogParam(@"\t\t scanning",scanningMode);
	NSXLogParam(@"\t\t auto exp mode",autoExposureMode);
	NSXLogParam(@"\t\t auto exp priority",autoExposurePriority);
	NSXLogParam(@"\t\t exposure time",exposureTime);
	NSXLogParam(@"\t\t iris",iris);
	NSXLogParam(@"\t\t auto focus",autoFocus);
	NSXLogParam(@"\t\t focus",focus);
	NSXLogParam(@"\t\t zoom",zoom);
	NSXLogParam(@"\t\t pan (abs)",panTilt.pan);
    NSXLogParam(@"\t\t tilt (abs)",panTilt.tilt);
	NSXLogParam(@"\t\t roll (abs)",roll);
	NSXLogParam(@"\t\t roll (rel)",rollRel);
	NSXLogParam(@"\t\t backlight",backlight);
	NSXLogParam(@"\t\t bright",bright);
	NSXLogParam(@"\t\t contrast",contrast);
	NSXLogParam(@"\t\t gain",gain);
	NSXLogParam(@"\t\t power",powerLine);
	NSXLogParam(@"\t\t auto hue",autoHue);
	NSXLogParam(@"\t\t hue",hue);
	NSXLogParam(@"\t\t sat",saturation);
	NSXLogParam(@"\t\t sharp",sharpness);
	NSXLogParam(@"\t\t gamma",gamma);
	NSXLogParam(@"\t\t auto wb",autoWhiteBalance);
	NSXLogParam(@"\t\t wb",whiteBalance);
	NSXLog(@"\t\t*******************");
}

- (void)getRelativePanTiltInfo:(RelativePanTiltInfo *)param {
	u_int8_t		*bytesPtr = nil;
	int			tmpint = 0;
	int				bytesRead = 0;
	
	bytesRead = [self _requestValType:UVC_GET_INFO forControl:param->ctrlInfo returnVal:(void **)&bytesPtr];
	if (bytesRead <= 0)	{
		NSXLog(@"err: couldn't get info");
		goto DISABLED_PARAM;
	}
	
	tmpint = 0x00000000;
	memcpy(&tmpint,bytesPtr,bytesRead);
	free(bytesPtr);
	bytesPtr = nil;
	
	BOOL canGetAndSet = (((tmpint & 0x01) == 0x01) && ((tmpint & 0x02) == 0x02)) ? YES : NO;
	if (!canGetAndSet)	{
		NSXLog(@"err: can't get or set");
		goto DISABLED_PARAM;
	}
	
	param->supported = YES;
	
	bytesRead = [self _requestValType:UVC_GET_CUR forControl:param->ctrlInfo returnVal:(void **)&bytesPtr];
	if (bytesRead <= 0)	{
		NSXLog(@"err: couldn't get current val");
		goto DISABLED_PARAM;
	}
	
	param->pan_direction = bytesPtr[0];
	param->current_pan_speed = bytesPtr[1];
	param->tilt_direction = bytesPtr[2];
	param->current_tilt_speed = bytesPtr[3];
	free(bytesPtr);
	bytesPtr = nil;

	//	min
	{
		bytesRead = [self _requestValType:UVC_GET_MIN forControl:param->ctrlInfo returnVal:(void **)&bytesPtr];
		if (bytesRead <= 0)
			goto DISABLED_PARAM;
		param->pan_direction = bytesPtr[0];
		param->min_pan_speed = bytesPtr[1];
		param->tilt_direction = bytesPtr[2];
		param->min_tilt_speed = bytesPtr[3];
		free(bytesPtr);
		bytesPtr = nil;
	}
	
	//	max
	{
		bytesRead = [self _requestValType:UVC_GET_MAX forControl:param->ctrlInfo returnVal:(void **)&bytesPtr];
		if (bytesRead <= 0)
			goto DISABLED_PARAM;
		param->pan_direction = bytesPtr[0];
		param->max_pan_speed = bytesPtr[1];
		param->tilt_direction = bytesPtr[2];
		param->max_tilt_speed = bytesPtr[3];
		free(bytesPtr);
		bytesPtr = nil;
	}
	
	//	default
	{
		bytesRead = [self _requestValType:UVC_GET_DEF forControl:param->ctrlInfo returnVal:(void **)&bytesPtr];
		if (bytesRead <= 0)
			goto DISABLED_PARAM;
		param->pan_direction = bytesPtr[0];
		param->default_pan_speed = bytesPtr[1];
		param->tilt_direction = bytesPtr[2];
		param->default_tilt_speed = bytesPtr[3];
		free(bytesPtr);
		bytesPtr = nil;
	}
	
	//	res
	{
		bytesRead = [self _requestValType:UVC_GET_RES forControl:param->ctrlInfo returnVal:(void **)&bytesPtr];
		if (bytesRead <= 0)
			goto DISABLED_PARAM;
		param->pan_direction = bytesPtr[0];
		param->resolution_pan_speed = bytesPtr[1];
		param->tilt_direction = bytesPtr[2];
		param->resolution_tilt_speed = bytesPtr[3];
		free(bytesPtr);
		bytesPtr = nil;
	}
	
	return;
	DISABLED_PARAM:
	param->supported = NO;
}


- (void)populateAbsPanTiltParam:(uvc_pan_tilt_abs_param *)param {
    //int            *intPtr = nil;
    void            *bytesPtr = nil;
    int            tmpint = 0;
    int             bytesRead = 0;
    
    bytesRead = [self _requestValType:UVC_GET_INFO forControl:param->ctrlInfo returnVal:&bytesPtr];
    if (bytesRead <= 0)    {
        goto DISABLED_PARAM;
    }
    
    tmpint = 0x00000000;
    memcpy(&tmpint,bytesPtr,bytesRead);
    free(bytesPtr);
    bytesPtr = nil;
    
    BOOL            canGetAndSet = (((tmpint & 0x01) == 0x01) && ((tmpint & 0x02) == 0x02)) ? YES : NO;
    if (!canGetAndSet)    {
        NSXLog(@"err: can't get or set");
        goto DISABLED_PARAM;
    }
    
    param->supported = YES;
    bytesRead = [self _requestValType:UVC_GET_CUR forControl:param->ctrlInfo returnVal:&bytesPtr];
    if (bytesRead <= 0)    {
        NSXLog(@"err: couldn't get current val");
        goto DISABLED_PARAM;
    }
    uint8 value[8];
    memcpy(value,bytesPtr,bytesRead);
    free(bytesPtr);
    bytesPtr = nil;
    param->pan.val = value[0] & ((int)value[1]>>8) & ((int)value[2]>>16) & ((int)value[3]>>24);
    param->tilt.val = value[4] & ((int)value[5]>>8) & ((int)value[6]>>16) & ((int)value[7]>>24);
    
    //    min
    if (param->ctrlInfo->hasMin)    {
        bytesRead = [self _requestValType:UVC_GET_MIN forControl:param->ctrlInfo returnVal:&bytesPtr];
        if (bytesRead != 8){
            NSXLog(@"err: couldn't get MIN val");
            goto DISABLED_PARAM;
        }
        uint8 value[8];
        memcpy(value,bytesPtr,bytesRead);
        free(bytesPtr);
        bytesPtr = nil;
        
        NSLog(@"%lu %lu", sizeof(int), sizeof(int));
        
        NSLog(@"0x%X 0x%X 0x%X 0x%X", value[0], (((int)value[1])<<8), ((int)value[2]<<16), ((int)value[3]<<24));
        param->pan.min = (int)(value[0] + (((int)value[1])<<8) + ((int)value[2]<<16) + ((int)value[3]<<24));
        NSLog(@"0x%X 0x%X 0x%X 0x%X", value[4], (((int)value[5])<<8), ((int)value[6]<<16), ((int)value[7]<<24));
        param->tilt.min = (int)(value[4] + ((int)value[5]<<8) + ((int)value[6]<<16) + ((int)value[7]<<24));
    }
    
    //    max
    if (param->ctrlInfo->hasMax)    {
        bytesRead = [self _requestValType:UVC_GET_MAX forControl:param->ctrlInfo returnVal:&bytesPtr];
        if (bytesRead != 8){
            NSXLog(@"err: couldn't get MAX val");
            goto DISABLED_PARAM;
        }
        uint8 value[8];
        memcpy(value,bytesPtr,bytesRead);
        free(bytesPtr);
        bytesPtr = nil;
        param->pan.max = value[0] + ((int)value[1]<<8) + ((int)value[2]<<16) + ((int)value[3]<<24);
        param->tilt.max = value[4] + ((int)value[5]<<8) + ((int)value[6]<<16) + ((int)value[7]<<24);
    }
    
    //    default
    if (param->ctrlInfo->hasDef)    {
        bytesRead = [self _requestValType:UVC_GET_DEF forControl:param->ctrlInfo returnVal:&bytesPtr];
        if (bytesRead != 8){
            NSXLog(@"err: couldn't get DEF val");
            goto DISABLED_PARAM;
        }
        uint8 value[8];
        memcpy(value,bytesPtr,bytesRead);
        free(bytesPtr);
        bytesPtr = nil;
        param->pan.def = value[0] + ((int)value[1]<<8) + ((int)value[2]<<16) + ((int)value[3]<<24);
        param->tilt.def = value[4] + ((int)value[5]<<8) + ((int)value[6]<<16) + ((int)value[7]<<24);
    }
    
    
    
    return;
    
    DISABLED_PARAM:
        param->supported = NO;
}

- (void) _populateParam:(uvc_param *)param	{
	//int			*intPtr = nil;
	void			*bytesPtr = nil;
	int			tmpint = 0;
	int				bytesRead = 0;
	
	bytesRead = [self _requestValType:UVC_GET_INFO forControl:param->ctrlInfo returnVal:&bytesPtr];
	if (bytesRead <= 0)	{
		goto DISABLED_PARAM;
	}
	
	tmpint = 0x00000000;
	memcpy(&tmpint,bytesPtr,bytesRead);
	free(bytesPtr);
	bytesPtr = nil;
	
	BOOL			canGetAndSet = (((tmpint & 0x01) == 0x01) && ((tmpint & 0x02) == 0x02)) ? YES : NO;
	if (!canGetAndSet)	{
		NSXLog(@"err: can't get or set");
		goto DISABLED_PARAM;
	}
	
	param->supported = YES;
	
	int			paramSize = param->ctrlInfo->intendedSize;
	int		valSizeMask;
	if (paramSize == 1) {
		valSizeMask = 0x00FF;
	} else if (paramSize == 2) {
		valSizeMask = 0xFFFF;
	} else if (paramSize == 4){
		valSizeMask = 0xFFFFFFFF;
	} else if (paramSize > 4)	{
		NSXLog(@"err: paramSize is %d, must be handled differently!",paramSize);
		goto DISABLED_PARAM;
	}
	
	int					shiftToGetSignBit = ((paramSize * 8) - 1);
	unsigned int		maskToRevealSign = (param->ctrlInfo->isSigned) ? (0x0001 << shiftToGetSignBit) : (0x0000);
	unsigned int		maskToRemoveSign = maskToRevealSign-1;

	bytesRead = [self _requestValType:UVC_GET_CUR forControl:param->ctrlInfo returnVal:&bytesPtr];
	if (bytesRead <= 0)	{
		NSXLog(@"err: couldn't get current val");
		goto DISABLED_PARAM;
	}
	tmpint = 0x00000000;
	memcpy(&tmpint,bytesPtr,bytesRead);
	free(bytesPtr);
	bytesPtr = nil;
	param->val = (tmpint & valSizeMask & maskToRemoveSign);

	param->actualSize = bytesRead;
	if ((tmpint & maskToRevealSign) != 0)
		param->val = param->val * -1;
	
	//	min
	if (param->ctrlInfo->hasMin)	{
		bytesRead = [self _requestValType:UVC_GET_MIN forControl:param->ctrlInfo returnVal:&bytesPtr];
		if (bytesRead <= 0)
			goto DISABLED_PARAM;
		tmpint = 0x00000000;
		memcpy(&tmpint,bytesPtr,bytesRead);
		free(bytesPtr);
		bytesPtr = nil;
		if ((tmpint & maskToRevealSign) == 0)
			param->min = (tmpint & valSizeMask & maskToRemoveSign);
		else
			param->min = -((~tmpint & valSizeMask) + 1);
	}
	
	//	max
	if (param->ctrlInfo->hasMax)	{
		bytesRead = [self _requestValType:UVC_GET_MAX forControl:param->ctrlInfo returnVal:&bytesPtr];
		if (bytesRead <= 0)
			goto DISABLED_PARAM;
		tmpint = 0x00000000;
		memcpy(&tmpint,bytesPtr,bytesRead);
		free(bytesPtr);
		bytesPtr = nil;
		if ((tmpint & maskToRevealSign) == 0)
			param->max = (tmpint & valSizeMask & maskToRemoveSign);
		else
			param->max = -((~tmpint & valSizeMask) + 1);
	}
	
	//	default
	if (param->ctrlInfo->hasDef)	{
		bytesRead = [self _requestValType:UVC_GET_DEF forControl:param->ctrlInfo returnVal:&bytesPtr];
		if (bytesRead <= 0)
			goto DISABLED_PARAM;
		tmpint = 0x00000000;
		memcpy(&tmpint,bytesPtr,bytesRead);
		free(bytesPtr);
		bytesPtr = nil;
		if ((tmpint & maskToRevealSign) == 0)
			param->def = (tmpint & valSizeMask & maskToRemoveSign);
		else
			param->def = -((~tmpint & valSizeMask) + 1);
	}
	
	return;
	
	DISABLED_PARAM:
		param->supported = NO;
		param->min = -1;
		param->max = -1;
		param->val = -1;
		param->def = -1;
		param->actualSize = -1;
}

- (BOOL) _pushParamToDevice:(uvc_param *)param	{
	if (param == nil) {
		return NO;
	}
	
	int			paramSize = param->actualSize;
	if (paramSize <= 0) {
		return NO;
	}
	
	BOOL		returnMe = NO;
	int			valToSend = 0x0000;
	if (param->ctrlInfo->isSigned)	{
		valToSend = (int)labs(param->val);
		if (param->val < 0){
			valToSend = (~valToSend + 1);
		}
	} else {
		valToSend = (int)param->val;
	}
	
	NSXLog(@"valToSend %d", valToSend);
	void			*bytesToSend = malloc(paramSize);
	bzero(bytesToSend,paramSize);
	memcpy(bytesToSend,&valToSend,paramSize);
	returnMe = [self _setBytes:bytesToSend sized:paramSize toControl:param->ctrlInfo];

	free(bytesToSend);
	bytesToSend = nil;

	return returnMe;
}

- (BOOL)pushPanTiltToDevice:(RelativePanTiltInfo *)param
			   panDirectiorn:(int8_t)panDirection
					panSpeed:(u_int8_t)panSpeed
			  tiltDirection:(int8_t)tiltDirection
				   tiltSpeed:(u_int8_t)tiltSpeed{
	u_int8_t data[4];
	data[0]=panDirection;
	data[1]=panSpeed;
	data[2]=tiltDirection;
	data[3]=tiltSpeed;
	
	NSXLog(@"DATA 0x%0x 0x%0x 0x%0x 0x%0x", data[0], data[1], data[2], data[3]);
	return [self _setBytes:data sized:4 toControl:param->ctrlInfo];
}

- (BOOL)setAbsPan:(int)pan{
    panTilt.pan.val = pan;
    return [self pushAbsPanTiltToDevice:&panTilt];
}

- (BOOL)setAbsTilt:(int)tilt{
    panTilt.tilt.val = tilt;
    return [self pushAbsPanTiltToDevice:&panTilt];
}

- (BOOL)pushAbsPanTiltToDevice:(uvc_pan_tilt_abs_param *)panTilt{
    uint8 data[8];
    memset(data, 0, 8);
    
    data[0] = panTilt->pan.val & 0xFF;
    data[1] = (panTilt->pan.val >> 8) & 0xFF;
    data[2] = (panTilt->pan.val >> 16) & 0xFF;
    data[3] = (panTilt->pan.val >> 24) & 0xFF;
    
    data[4] = panTilt->tilt.val & 0xFF;
    data[5] = (panTilt->tilt.val >> 8) & 0xFF;
    data[6] = (panTilt->tilt.val >> 16) & 0xFF;
    data[7] = (panTilt->tilt.val >> 24) & 0xFF;
    
    return [self _setBytes:data sized:8 toControl:&_panTiltCtrl];
}

- (BOOL)resetPanTilt{
    panTilt.pan.val = panTilt.pan.def?:3600;
    panTilt.tilt.val = panTilt.tilt.def?:3600;
	
    return [self pushAbsPanTiltToDevice:&panTilt];
}

- (void) _resetParamToDefault:(uvc_param *)param	{
	param->val = param->def;
	[self _pushParamToDevice:param];
}


/*===================================================================================*/
#pragma mark --------------------- misc
/*------------------------------------*/
- (void) resetParamsToDefaults	{
	[self _resetParamToDefault:&scanningMode];
	[self _resetParamToDefault:&autoExposureMode];
	[self _resetParamToDefault:&autoExposurePriority];
	[self _resetParamToDefault:&exposureTime];
	[self _resetParamToDefault:&iris];
	[self _resetParamToDefault:&autoFocus];
	[self _resetParamToDefault:&focus];
	[self _resetParamToDefault:&zoom];
//	[self _resetParamToDefault:&panTilt];
	[self resetPanTilt];
	[self _resetParamToDefault:&roll];
	[self _resetParamToDefault:&rollRel];
	[self _resetParamToDefault:&backlight];
	[self _resetParamToDefault:&bright];
	[self _resetParamToDefault:&contrast];
	[self _resetParamToDefault:&gain];
	[self _resetParamToDefault:&powerLine];
	[self _resetParamToDefault:&autoHue];
	[self _resetParamToDefault:&hue];
	[self _resetParamToDefault:&saturation];
	[self _resetParamToDefault:&sharpness];
	[self _resetParamToDefault:&gamma];
	[self _resetParamToDefault:&autoWhiteBalance];
	[self _resetParamToDefault:&whiteBalance];
}

- (void) openSettingsWindow	{
	NSXLog(@"");
	[settingsWindow makeKeyAndOrderFront:nil];
}

- (void) closeSettingsWindow {
	NSXLog(@"");
	[settingsWindow close];
}

/*===================================================================================*/
#pragma mark --------------------- key-val
/*------------------------------------*/
- (void) setInterlaced:(BOOL)n	{
	scanningMode.val = (n) ? 0x00 : 0x01;
	[self _pushParamToDevice:&scanningMode];
}

- (BOOL) interlaced	{
	if (!scanningMode.supported)
		return NO;
	if (scanningMode.val == 1)
		return YES;
	return NO;
}

- (BOOL) interlacedSupported	{
	return scanningMode.supported;
}

- (void) resetInterlaced	{
	[self _resetParamToDefault:&scanningMode];
}

- (void) setAutoExposureMode:(UVC_AEMode)n	{
	switch (n)	{
		case UVC_AEMode_Manual:
		case UVC_AEMode_Auto:
		case UVC_AEMode_ShutterPriority:
		case UVC_AEMode_AperturePriority:
			autoExposureMode.val = n;
			break;
		case UVC_AEMode_Undefined:
			break;
	}
	
	if (![self _pushParamToDevice:&autoExposureMode]){
		[uiCtrlr _pushCameraControlStateToUI];	//	this is meant to "reload" the UI from the existing camera state if pushing a param failed (because the auto-exposure mode isn't supported).  this does not work- i think the USB device will accept the value, even though it isn't supported (the val is changing, but the behavior is simply unsupported)
	}
	
	[self _pushParamToDevice:&exposureTime];;
}

- (UVC_AEMode) autoExposureMode	{
	if (!autoExposureMode.supported){
		return 0;
	}
	return (UVC_AEMode)autoExposureMode.val;
}

- (BOOL) autoExposureModeSupported	{
	return autoExposureMode.supported;
}

- (void) resetAutoExposureMode	{
	[self _resetParamToDefault:&autoExposureMode];
}

- (void) setAutoExposurePriority:(BOOL)n	{
	autoExposurePriority.val = (n) ? 0x01 : 0x00;
	[self _pushParamToDevice:&autoExposurePriority];
}

- (BOOL) autoExposurePriority	{
	if (!autoExposurePriority.supported)
		return NO;
	if (autoExposurePriority.val == 0x01)
		return YES;
	return NO;
}

- (BOOL) autoExposurePrioritySupported	{
	return autoExposurePriority.supported;
}

- (void) resetAutoExposurePriority	{
	[self _resetParamToDefault:&autoExposurePriority];
}

- (void) setVal:(int)newVal forParam:(uvc_param *)p	{
	p->val = fminl(fmaxl(newVal,p->min),p->max);
	[self _pushParamToDevice:p];
}

- (void) setExposureTime:(int)n	{
	[self setVal:n forParam:&exposureTime];
}

- (int) exposureTime	{
	if (!exposureTime.supported)
		return 0;
	return exposureTime.val;
}

- (BOOL) exposureTimeSupported	{
	return exposureTime.supported;
}

- (void) resetExposureTime	{
	[self _resetParamToDefault:&exposureTime];
}

- (int) minExposureTime	{
	return exposureTime.min;
}

- (int) maxExposureTime	{
	return exposureTime.max;
}

- (void) setIris:(int)n	{
	[self setVal:n forParam:&iris];
}

- (int) iris	{
	return (!iris.supported) ? 0 : iris.val;
}

- (BOOL) irisSupported	{
	return iris.supported;
}

- (void) resetIris	{
	[self _resetParamToDefault:&iris];
}

- (int) minIris	{
	return iris.min;
}

- (int) maxIris	{
	return iris.max;
}

- (void) setAutoFocus:(BOOL)n	{
	autoFocus.val = (n) ? 0x01 : 0x00;
	[self _pushParamToDevice:&autoFocus];
}

- (BOOL) autoFocus	{
	if (!autoFocus.supported)
		return NO;
	if (autoFocus.val == 0x01)
		return YES;
	return NO;
}

- (BOOL) autoFocusSupported	{
	return autoFocus.supported;
}

- (void) resetAutoFocus	{
	[self _resetParamToDefault:&autoFocus];
}

- (void) setFocus:(int)n	{
	[self setVal:n forParam:&focus];
}

- (int) focus	{
	return (!focus.supported) ? 0 : focus.val;
}

- (BOOL) focusSupported	{
	return focus.supported;
}

- (void) resetFocus	{
	[self _resetParamToDefault:&focus];
}

- (int) minFocus	{
	return (!focus.supported) ? 0 : focus.min;
}

- (int) maxFocus	{
	return (!focus.supported) ? 0 : focus.max;
}

- (int)minAbsPan{
    return panTilt.pan.min;
}

- (int)maxAbsPan{
    return panTilt.pan.max;
}

- (int)absPan{
    return panTilt.pan.val;
}

- (int)minAbsTilt{
    return panTilt.tilt.min;
}

- (int)maxAbsTilt{
    return panTilt.tilt.max;
}

- (int)absTilt{
    return panTilt.tilt.val;
}

- (void) setZoom:(int)n    {
    NSXLog(@"set zoom %ld", n);
    [self setVal:n forParam:&zoom];
}

- (int) zoom	{
	return (!zoom.supported) ? 0 : zoom.val;
}

- (BOOL) zoomSupported	{
	return zoom.supported;
}

- (void) resetZoom	{
	[self _resetParamToDefault:&zoom];
}

- (int) minZoom	{
	return (!zoom.supported) ? 0 : zoom.min;
}

- (int) maxZoom	{
	return (!zoom.supported) ? 0 : zoom.max;
}

-(int)minRoll{
    return roll.min;
}

- (int)maxRoll{
    return roll.max;
}

- (void) setRoll:(int)n{
    [self setVal:n forParam:&roll];
}

- (int) roll	{
	return roll.val;
}

- (BOOL) rollSupported	{
	return roll.supported;
}

- (void) setBacklight:(int)n	{
	[self setVal:n forParam:&backlight];
}

- (int) backlight	{
	return (!backlight.supported) ? 0 : backlight.val;
}

- (BOOL) backlightSupported	{
	return backlight.supported;
}

- (void) resetBacklight	{
	[self _resetParamToDefault:&backlight];
}

- (int) minBacklight	{
	return (!backlight.supported) ? 0 : backlight.min;
}

- (int) maxBacklight	{
	return (!backlight.supported) ? 0 : backlight.max;
}

- (void) setBright:(int)n	{
	[self setVal:n forParam:&bright];
}

- (int) bright	{
	return (!bright.supported) ? 0 : bright.val;
}

- (BOOL) brightSupported	{
	return bright.supported;
}

- (void) resetBright	{
	[self _resetParamToDefault:&bright];
}

- (int) minBright	{
	return (!bright.supported) ? 0 : bright.min;
}

- (int) maxBright	{
	return (!bright.supported) ? 0 : bright.max;
}

- (void) setContrast:(int)n	{
	[self setVal:n forParam:&contrast];
}

- (int) contrast	{
	return (!contrast.supported) ? 0 : contrast.val;
}

- (BOOL) contrastSupported	{
	return contrast.supported;
}

- (void) resetContrast	{
	[self _resetParamToDefault:&contrast];
}

- (int) minContrast	{
	return (!contrast.supported) ? 0 : contrast.min;
}

- (int) maxContrast	{
	return (!contrast.supported) ? 0 : contrast.max;
}

- (void) setGain:(int)n	{
	[self setVal:n forParam:&gain];
}

- (int) gain	{
	if (!gain.supported)
		return 0;
	return gain.val;
}

- (BOOL) gainSupported	{
	return gain.supported;
}

- (void) resetGain	{
	[self _resetParamToDefault:&gain];
}

- (int) minGain	{
	return (!gain.supported) ? 0 : gain.min;
}

- (int) maxGain	{
	return (!gain.supported) ? 0 : gain.max;
}

- (void) setPowerLine:(int)n	{
	[self setVal:n forParam:&powerLine];
}

- (int) powerLine	{
	if (!powerLine.supported)
		return 0;
	return powerLine.val;
}

- (BOOL) powerLineSupported	{
	return powerLine.supported;
}

- (void) resetPowerLine	{
	[self _resetParamToDefault:&powerLine];
}

- (int) minPowerLine {
	return (!powerLine.supported) ? 0 : powerLine.min;
}

- (int) maxPowerLine {
	return (!powerLine.supported) ? 0 : powerLine.max;
}

- (void) setAutoHue:(BOOL)n	{
	//BOOL			changed = (autoHue.val != ((n) ? 0x01 : 0x00)) ? YES : NO;
	autoHue.val = (n) ? 0x01 : 0x00;
	[self _pushParamToDevice:&autoHue];
}

- (BOOL) autoHue	{
	if (!autoHue.supported)
		return NO;
	if (autoHue.val == 1)
		return YES;
	return NO;
}

- (BOOL) autoHueSupported	{
	return autoHue.supported;
}

- (void) resetAutoHue	{
	[self _resetParamToDefault:&autoHue];
}

- (void) setHue:(int)n	{
	[self setVal:n forParam:&hue];
}

- (int) hue {
	return (!hue.supported) ? 0 : hue.val;
}

- (BOOL) hueSupported {
	return hue.supported;
}

- (void) resetHue	{
	[self _resetParamToDefault:&hue];
}

- (int) minHue	{
	return (!hue.supported) ? 0 : hue.min;
}

- (int) maxHue	{
	return (!hue.supported) ? 0 : hue.max;
}

- (void) setSaturation:(int)n	{
	[self setVal:n forParam:&saturation];
}

- (int) saturation	{
	return (!saturation.supported) ? 0 : saturation.val;
}

- (BOOL) saturationSupported {
	return saturation.supported;
}

- (void) resetSaturation {
	[self _resetParamToDefault:&saturation];
}

- (int) minSaturation	{
	return (!saturation.supported) ? 0 : saturation.min;
}

- (int) maxSaturation	{
	return (!saturation.supported) ? 0 : saturation.max;
}

- (void) setSharpness:(int)n {
	[self setVal:n forParam:&sharpness];
}

- (int) sharpness	{
	return (!sharpness.supported) ? 0 : sharpness.val;
}

- (BOOL) sharpnessSupported	{
	return sharpness.supported;
}

- (void) resetSharpness	{
	[self _resetParamToDefault:&sharpness];
}

- (int) minSharpness {
	return (!sharpness.supported) ? 0 : sharpness.min;
}

- (int) maxSharpness	{
	return (!sharpness.supported) ? 0 : sharpness.max;
}

- (void) setGamma:(int)n {
	[self setVal:n forParam:&gamma];
}

- (int) gamma {
	if (!gamma.supported)
		return 0;
	return gamma.val;
}

- (BOOL) gammaSupported	{
	return gamma.supported;
}

- (void) resetGamma	{
	[self _resetParamToDefault:&gamma];
}

- (int) minGamma {
	return (!gamma.supported) ? 0 : gamma.min;
}

- (int) maxGamma {
	return (!gamma.supported) ? 0 : gamma.max;
}

- (void) setAutoWhiteBalance:(BOOL)n {
	//BOOL			changed = (autoWhiteBalance.val != ((n) ? 0x01 : 0x00)) ? YES : NO;
	autoWhiteBalance.val = (n) ? 0x01 : 0x00;
	[self _pushParamToDevice:&autoWhiteBalance];
}

- (BOOL) autoWhiteBalance {
	if (!autoWhiteBalance.supported)
		return NO;
	if (autoWhiteBalance.val == 1)
		return YES;
	return NO;
}

- (BOOL) autoWhiteBalanceSupported {
	return autoWhiteBalance.supported;
}

- (void) resetAutoWhiteBalance {
	[self _resetParamToDefault:&autoWhiteBalance];
}

- (void) setWhiteBalance:(int)n {
	[self setVal:n forParam:&whiteBalance];
}

- (int) whiteBalance {
	return (!whiteBalance.supported) ? 0 : whiteBalance.val;
}

- (BOOL) whiteBalanceSupported	{
	return whiteBalance.supported;
}

- (void) resetWhiteBalance {
	[self _resetParamToDefault:&whiteBalance];
}

- (int) minWhiteBalance	{
	return whiteBalance.min;
}

- (int) maxWhiteBalance {
	return whiteBalance.max;
}

- (BOOL) panTilt:(UVC_PAN_TILT_DIRECTION)direction{
	switch (direction) {
		case UVC_PAN_TILT_UP:
			return [self pushPanTiltToDevice:&panTiltRel panDirectiorn:0 panSpeed:0 tiltDirection:1 tiltSpeed:panTiltRel.default_tilt_speed];
			
		case UVC_PAN_TILT_RIGHT:
			return [self pushPanTiltToDevice:&panTiltRel panDirectiorn:1 panSpeed:panTiltRel.default_pan_speed tiltDirection:0 tiltSpeed:0];
			
		case UVC_PAN_TILT_DOWN:
			return [self pushPanTiltToDevice:&panTiltRel panDirectiorn:0 panSpeed:0 tiltDirection:-1 tiltSpeed:panTiltRel.default_tilt_speed];
			
		case UVC_PAN_TILT_LEFT:
			return [self pushPanTiltToDevice:&panTiltRel panDirectiorn:-1 panSpeed:panTiltRel.default_pan_speed tiltDirection:0 tiltSpeed:0];
			
		default:
			return  [self pushPanTiltToDevice:&panTiltRel panDirectiorn:0 panSpeed:0 tiltDirection:0 tiltSpeed:0];;
	}
}
@end

