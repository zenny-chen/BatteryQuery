//
//  ViewController.m
//  BatteryQuery
//
//  Created by Zenny Chen on 2018/1/22.
//  Copyright © 2018年 GreenGames Studio. All rights reserved.
//

#import "ViewController.h"
#include <dlfcn.h>

@interface ViewController ()<UITableViewDataSource, UITableViewDelegate>

@end

@implementation ViewController
{
@private
    
    UIView *mBaseView;
    UILabel *mTitleLabel;
    UIButton *mRefreshButton;
    UITableView *mTableView;
    
    NSMutableArray<UITableViewCell*> *mTableCells;
}

- (NSDictionary*)fetchBatteryInfo
{
    mach_port_t *kIOMasterPortDefault;
    
    kern_return_t (*ioRegistryEntryCreateCFProperties)(mach_port_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, UInt32 options) = NULL;
    
    mach_port_t (*ioServiceGetMatchingService)(mach_port_t masterPort, CFDictionaryRef matching CF_RELEASES_ARGUMENT) = NULL;
    
    CFMutableDictionaryRef (*ioServiceMatching)(const char *name) = NULL;
    
    CFTypeRef (*ioPSCopyPowerSourcesInfo)(void) = NULL;
    
    CFArrayRef (*ioPSCopyPowerSourcesList)(CFTypeRef blob) = NULL;
    
    CFDictionaryRef (*ioPSGetPowerSourceDescription)(CFTypeRef blob, CFTypeRef ps) = NULL;
    
    CFMutableDictionaryRef powerSourceService = NULL;
    mach_port_t platformExpertDevice = 0;

    var handle = dlopen("/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit", RTLD_LAZY);
    
    ioRegistryEntryCreateCFProperties = dlsym(handle, "IORegistryEntryCreateCFProperties");
    kIOMasterPortDefault = dlsym(handle, "kIOMasterPortDefault");
    ioServiceMatching = dlsym(handle, "IOServiceMatching");
    ioServiceGetMatchingService = dlsym(handle, "IOServiceGetMatchingService");
    
    ioPSCopyPowerSourcesInfo = dlsym(handle, "IOPSCopyPowerSourcesInfo");
    ioPSCopyPowerSourcesList = dlsym(handle, "IOPSCopyPowerSourcesList");
    ioPSGetPowerSourceDescription = dlsym(handle, "IOPSGetPowerSourceDescription");
    
    if (ioRegistryEntryCreateCFProperties != NULL &&
        ioServiceMatching != NULL &&
        ioServiceGetMatchingService != NULL)
    {
        powerSourceService = ioServiceMatching("IOPMPowerSource");
        platformExpertDevice = ioServiceGetMatchingService(*kIOMasterPortDefault, powerSourceService);
    }
    
    NSMutableDictionary *batteryInfo = nil;
    
    if(powerSourceService != NULL && platformExpertDevice != 0)
    {
        CFMutableDictionaryRef prop = NULL;
        ioRegistryEntryCreateCFProperties(platformExpertDevice, &prop, 0, 0);
        if(prop != NULL)
        {
            batteryInfo = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)prop];
            CFRelease(prop);
        }
    }
    
    var blob = ioPSCopyPowerSourcesInfo();
    var sources = ioPSCopyPowerSourcesList(blob);
    CFDictionaryRef pSource = NULL;

    var numOfSources = CFArrayGetCount(sources);
    for(CFIndex i = 0; i < numOfSources; i++)
    {
        pSource = ioPSGetPowerSourceDescription(blob, CFArrayGetValueAtIndex(sources, i));
        if(pSource != NULL)
        {
            if(batteryInfo == nil)
                batteryInfo = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)pSource];
            else
                [batteryInfo setValuesForKeysWithDictionary:(NSDictionary*)pSource];
            
            break;
        }
    }
    
    dlclose(handle);
    CFRelease(blob);
    CFRelease(sources);
    
    return batteryInfo;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.view.backgroundColor = [UIColor colorWithRed:0.063 green:0.682 blue:1.0 alpha:1.0];
    
    if (@available(iOS 11.0, *))
    {
        
    }
    else
    {
        // Fallback on earlier versions
        var frame = self.view.frame;
        const var statusBarHeight = UIApplication.sharedApplication.statusBarFrame.size.height;
        frame.origin.y += statusBarHeight;
        frame.size.height -= statusBarHeight;
        
        [self setupViews:frame];
    }
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    
    [self setupViews:self.view.safeAreaLayoutGuide.layoutFrame];
}

- (void)setupViews:(CGRect)frame
{
    if(mBaseView == nil)
    {
        mBaseView = [UIView.alloc initWithFrame:frame];
        mBaseView.backgroundColor = UIColor.whiteColor;
        [self.view addSubview:mBaseView];
        [mBaseView release];
    }
    mBaseView.frame = frame;
    
    const var viewSize = frame.size;
    
    var yPos = 0.0;
    const var titleHeight = 50.0;
    
    if(mTitleLabel == nil)
    {
        mTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, yPos, viewSize.width, titleHeight)];
        mTitleLabel.backgroundColor = self.view.backgroundColor;
        mTitleLabel.textAlignment = NSTextAlignmentCenter;
        mTitleLabel.textColor = UIColor.whiteColor;
        mTitleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:18.0];
        mTitleLabel.text = @"Battery Query";
        [mBaseView addSubview:mTitleLabel];
        [mTitleLabel release];
    }
    mTitleLabel.frame = CGRectMake(0.0, yPos, viewSize.width, titleHeight);
    
    yPos = 11.0;
    var width = 70.0;
    if(mRefreshButton == nil)
    {
        mRefreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [mRefreshButton setTitle:@"Refresh" forState:UIControlStateNormal];
        [mRefreshButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        mRefreshButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        mRefreshButton.titleLabel.font = [UIFont fontWithName:@"Helvetica" size:14.0];
        [mRefreshButton addTarget:self action:@selector(refreshButtonTouched:) forControlEvents:UIControlEventTouchUpInside];
        [mBaseView addSubview:mRefreshButton];
    }
    mRefreshButton.frame = CGRectMake(viewSize.width - width - 20.0, yPos, width, 30.0);
    
    yPos = titleHeight + 30.0;
    frame = CGRectMake(0.0, yPos, viewSize.width, viewSize.height - yPos - 20.0);
    if(mTableView == nil)
    {
        mTableView = [UITableView.alloc initWithFrame:frame style:UITableViewStylePlain];
        mTableView.backgroundColor = UIColor.clearColor;
        mTableView.allowsSelection = NO;
        mTableView.dataSource = self;
        mTableView.delegate = self;
        mTableView.rowHeight = 40.0;
        
        [self refreshButtonTouched:nil];
        
        [mBaseView addSubview:mTableView];
        [mTableView release];
    }
    else
        mTableView.frame = frame;
}

- (void)refreshButtonTouched:(UIButton*)sender
{
    var info = [self fetchBatteryInfo];
    if(info == nil)
        return;
    
    if(mTableCells != nil)
    {
        [mTableCells removeAllObjects];
        [mTableCells release];
    }
    
    var keys = info.allKeys;
    mTableCells = [NSMutableArray.alloc initWithCapacity:keys.count + 1];
    const var cellHeight = mTableView.rowHeight;
    const var width = mTableView.frame.size.width * 0.4;
    for(NSString *key in info)
    {
        var cell = [UITableViewCell.alloc initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@""];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        var title = [UILabel.alloc initWithFrame:CGRectMake(20.0, 0.0, width, cellHeight)];
        title.textAlignment = NSTextAlignmentLeft;
        title.textColor = UIColor.blackColor;
        title.font = [UIFont fontWithName:@"Helvetica" size:15.0];
        title.adjustsFontSizeToFitWidth = YES;
        title.text = key;
        [cell.contentView addSubview:title];
        [title release];
        
        id value = info[key];
        NSString *valueStr = [value isKindOfClass:NSNumber.class] ? ((NSNumber*)value).stringValue : value;
        
        var valueLabel = [UILabel.alloc initWithFrame:CGRectMake(mTableView.frame.size.width - width - 20.0, 0.0, width, cellHeight)];
        valueLabel.textAlignment = NSTextAlignmentRight;
        valueLabel.textColor = UIColor.grayColor;
        valueLabel.font = [UIFont fontWithName:@"Helvetica" size:15.0];
        valueLabel.adjustsFontSizeToFitWidth = YES;
        valueLabel.text = valueStr;
        [cell.contentView addSubview:valueLabel];
        [valueLabel release];
        
        [mTableCells addObject:cell];
        [cell release];
    }
}

// MARK: UIViewTable data source & delegate

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return mTableCells[indexPath.row];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return mTableCells.count;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

